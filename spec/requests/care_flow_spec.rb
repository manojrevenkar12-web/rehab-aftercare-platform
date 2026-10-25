require "rails_helper"

RSpec.describe "Care flow through the API", type: :request do
  include ActiveJob::TestHelper

  let(:s) { Scenario.build }
  let(:e) { s[:enrolment] }

  before { travel_to Time.zone.local(2026, 11, 20, 9) }

  def unit_params(day, key, pain: [ 5, 3 ])
    { unit: { performed_on: day.iso8601, duration_minutes: 20, pain_before: pain[0], pain_after: pain[1], effort: 5, idempotency_key: key } }
  end

  it "records units from the patient's app once per key, and refuses billing staff" do
    api :post, "/api/v1/enrolments/#{e.id}/units", user: s[:patient_user], params: unit_params(Date.new(2026, 9, 10), "app-1")
    expect(response).to have_http_status(:created)
    expect(json.dig("unit", "source")).to eq("patient_app")
    expect(json.dig("enrolment", "status")).to eq("active")
    api :post, "/api/v1/enrolments/#{e.id}/units", user: s[:patient_user], params: unit_params(Date.new(2026, 9, 10), "app-1")
    expect(e.training_units.count).to eq(1)
    api :post, "/api/v1/enrolments/#{e.id}/units", user: s[:billing], params: unit_params(Date.new(2026, 9, 11), "b-1")
    expect(response).to have_http_status(:forbidden)
  end

  it "escalates a red-flag check-in, drafts a reply once, and lets the assigned therapist approve it" do
    api :post, "/api/v1/enrolments/#{e.id}/check_ins", user: s[:patient_user],
                                                        params: { message: "Hallo, hier Anna Becker. Seit heute Druck auf der Brust beim Training.", pain_score: 4 }
    expect(response).to have_http_status(:created)
    check_in = json
    expect(check_in["status"]).to eq("escalated")
    expect(check_in["red_flags"].pluck("code")).to eq(%w[chest_pain])

    api :get, "/api/v1/caseload", user: s[:therapist]
    expect(json["patients"].first).to include("escalations" => 1)

    api :post, "/api/v1/enrolments/#{e.id}/drafts", user: s[:therapist], params: { kind: "check_in_reply", check_in_id: check_in["id"] }
    expect(response).to have_http_status(:accepted)
    draft_id = json["id"]
    perform_enqueued_jobs
    api :post, "/api/v1/enrolments/#{e.id}/drafts", user: s[:therapist], params: { kind: "check_in_reply", check_in_id: check_in["id"] }
    expect(response).to have_http_status(:ok)
    expect(json["id"]).to eq(draft_id)

    api :get, "/api/v1/drafts/#{draft_id}", user: s[:therapist]
    expect(json).to include("status" => "ready", "findings" => [])
    expect(json.dig("output", "reply")).to include("112")

    sent = WebMock::RequestRegistry.instance.requested_signatures.hash.keys
    expect(sent).to be_empty # the simulated model makes no HTTP calls

    api :post, "/api/v1/drafts/#{draft_id}/approve", user: s[:colleague]
    expect(response).to have_http_status(:forbidden)
    api :post, "/api/v1/drafts/#{draft_id}/approve", user: s[:therapist], params: { edits: { reply: "Danke, wir rufen Sie heute an. Bei Brustschmerzen bitte 112." } }
    expect(json["status"]).to eq("approved")
    expect(e.check_ins.first.status).to eq("answered")
  end

  it "never lets identity reach the model: the facts are pseudonymised" do
    provider = Ai::Providers::Simulated.new
    allow(Ai::Client).to receive(:default).and_return(Ai::Client.new(provider: provider))
    seen = []
    allow(provider).to receive(:chat).and_wrap_original { |m, **kw| seen << JSON.generate(kw[:messages]) && m.call(**kw) }
    ci = Care::CheckInIntake.call(enrolment: e, message: "Anna Becker, geb. 14.03.1968, Tel 030 1234567: Knie schmerzt", pain_score: 3, actor: s[:patient_user])
    Care::DraftRequest.call(enrolment: e, kind: "check_in_reply", actor: s[:therapist], check_in: ci)
    perform_enqueued_jobs
    expect(seen.size).to eq(2) # the screen, then the reply
    seen.each do |request|
      expect(request).not_to include("Becker", "Anna", "1968", "1234567")
      expect(request).to include("[NAME]", "Knie schmerzt")
    end
  end

  it "takes a completed enrolment from closing report draft to a paid claim" do
    18.times { |i| e.record_unit!({ performed_on: Date.new(2026, 9, 10) + (i * 3).days, duration_minutes: 20, source: "therapist", pain_before: 6 - (i / 6), pain_after: 4 - (i / 6), effort: 5, idempotency_key: "u#{i}" }, actor: s[:therapist]) }
    expect(e.reload.status).to eq("completed")

    api :post, "/api/v1/enrolments/#{e.id}/drafts", user: s[:physician], params: { kind: "closing_report" }
    perform_enqueued_jobs
    draft = AiDraft.find(json["id"])
    expect(draft.reload).to have_attributes(status: "ready", findings: [])
    api :post, "/api/v1/drafts/#{draft.id}/approve", user: s[:therapist]
    expect(e.reload.closing_report).not_to be_signed

    api :post, "/api/v1/enrolments/#{e.id}/claim/assemble", user: s[:billing]
    expect(json).to include("status" => "draft")
    expect(json["problems"].pluck("code")).to eq(%w[closing_report_unsigned])

    api :post, "/api/v1/enrolments/#{e.id}/closing_report/sign", user: s[:therapist]
    expect(response).to have_http_status(:forbidden)
    api :post, "/api/v1/enrolments/#{e.id}/closing_report/sign", user: s[:physician]
    expect(json["signed"]).to be(true)

    api :post, "/api/v1/enrolments/#{e.id}/claim/assemble", user: s[:billing]
    claim = json
    expect(claim).to include("status" => "ready", "units_billed" => 18, "amount" => "450.00")
    api :post, "/api/v1/claims/#{claim['id']}/submit", user: s[:billing]
    api :post, "/api/v1/claims/#{claim['id']}/paid", user: s[:billing]
    expect(json["status"]).to eq("paid")

    api :get, "/api/v1/enrolments/#{e.id}/timeline", user: s[:billing]
    expect(response).to have_http_status(:forbidden)
    api :get, "/api/v1/claims", user: s[:billing]
    expect(json["claims"].size).to eq(1)
    expect(json["claims"].first.keys).not_to include("documents")

    api :get, "/api/v1/audit_events", user: s[:admin]
    expect(json["chain_broken_at"]).to be_nil
    expect(json["events"].pluck("action")).to include("claim.paid", "closing_report.signed", "ai_draft.approved", "enrolment.completed")
  end

  it "applies an approved plan change, and refuses an edit that breaks the plan rules" do
    load Rails.root.join("db/seeds.rb")
    e.plan_items.create!(exercise: Exercise.find_by!(key: "pelvic_tilt"), sets: 2, reps: 10, per_week: 3)
    3.times { |i| e.record_unit!({ performed_on: Date.new(2026, 11, 1) + i.days, duration_minutes: 20, source: "therapist", pain_before: 4, pain_after: 3, effort: 4, idempotency_key: "p#{i}" }, actor: s[:therapist]) }
    api :post, "/api/v1/enrolments/#{e.id}/drafts", user: s[:therapist], params: { kind: "plan_change" }
    perform_enqueued_jobs
    draft = AiDraft.find(json["id"])
    expect(draft.reload.status).to eq("ready")
    bad = { changes: [ { action: "add", exercise_key: "split_squat", sets: 2, reps: 8, per_week: 3, reason: "push it" } ] }
    api :post, "/api/v1/drafts/#{draft.id}/approve", user: s[:therapist], params: { edits: bad }
    expect(response).to have_http_status(:conflict)
    expect(json["error"]).to include("level 4")
    api :post, "/api/v1/drafts/#{draft.id}/approve", user: s[:therapist]
    expect(e.plan_items.where(active: true).count).to eq(2)
  end

  it "shows identity and clinical detail only to people who treat the patient, and logs each view" do
    api :get, "/api/v1/patients/#{s[:patient].id}", user: s[:billing]
    expect(json.keys).not_to include("insurance_number", "birth_date")
    api :get, "/api/v1/patients/#{s[:patient].id}", user: s[:therapist]
    expect(json).to include("insurance_number" => s[:patient].insurance_number)
    api :get, "/api/v1/patients/#{s[:patient].id}", user: s[:colleague]
    expect(response).to have_http_status(:forbidden)
    api :get, "/api/v1/patients/#{s[:patient].id}", user: s[:outsider]
    expect(response).to have_http_status(:forbidden)
    expect(AuditEvent.where(action: "patient.viewed").pluck(:data)).to eq([ { "clinical" => false }, { "clinical" => true } ])
  end
end
