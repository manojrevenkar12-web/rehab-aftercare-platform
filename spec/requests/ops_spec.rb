require "rails_helper"

RSpec.describe "Operations view", type: :request do
  include ActiveJob::TestHelper

  let(:s) { Scenario.build }
  let(:e) { s[:enrolment] }
  let(:now) { Time.zone.local(2026, 11, 20, 12) }

  before { travel_to now }

  def check_in!(submitted, answered: nil)
    CheckIn.create!(enrolment: e, submitted_at: submitted, pain_score: 3, message: "Knie schmerzt", status: answered ? "answered" : "new", answered_at: answered)
  end

  it "is for the clinic's administrator only" do
    api :get, "/api/v1/ops"
    expect(response).to have_http_status(:unauthorized)
    %i[therapist physician billing patient_user].each do |who|
      api :get, "/api/v1/ops", user: s[who]
      expect(response).to have_http_status(:forbidden)
    end
    api :get, "/api/v1/ops", user: s[:admin]
    expect(response).to have_http_status(:ok)
  end

  it "measures the 24-hour promise from answered_at, counts open overdue check-ins, and shows no patient text" do
    check_in!(now - 50.hours, answered: now - 46.hours)  # 4 h
    check_in!(now - 40.hours, answered: now - 10.hours)  # 30 h: late
    check_in!(now - 30.hours)                            # open and overdue
    check_in!(now - 2.hours)                             # open, not yet due
    api :get, "/api/v1/ops", user: s[:admin]
    c = json["check_ins"]
    expect(c).to include("promise_hours" => 24, "submitted" => 4, "due" => 3, "met" => 1, "open" => 2, "open_overdue" => 1)
    expect(c["share_met"]).to be_within(0.001).of(1 / 3.0)
    expect(c["hours_to_answer"]).to eq("median" => 4.0, "p90" => 30.0)
    expect(json["alerts"].pluck("code")).to include("check_in_promise", "check_ins_overdue", "no_workers")
    expect(response.body).not_to include("Knie", "Anna", "Becker")
  end

  it "adds up the clinic's own model calls and leaves out other clinics'" do
    other = create(:clinic)
    [ [ s[:clinic].id, 1200 ], [ s[:clinic].id, 3400 ], [ s[:clinic].id, 2100 ], [ other.id, 99_000 ] ].each do |clinic_id, ms|
      AiCall.create!(clinic_id: clinic_id, task: "check_in_reply", prompt_version: "check-in-reply/3", model: "simulated-1", provider: "simulated",
                     outcome: "ok", latency_ms: ms, input_tokens: 1000, output_tokens: 1000, cost_microeuros: 2000, created_at: now - 1.hour)
    end
    AiCall.create!(clinic_id: s[:clinic].id, task: "check_in_reply", model: "simulated-1", provider: "simulated", outcome: "error",
                   latency_ms: 60_000, created_at: now - 1.hour)
    api :get, "/api/v1/ops", user: s[:admin]
    t = json.dig("models", "tasks").sole
    expect(t).to include("task" => "check_in_reply", "prompt_version" => "check-in-reply/3", "calls" => 4, "errors" => 1, "cost_eur" => 0.006)
    expect(t["latency_ms"]).to eq("p50" => 2100, "p95" => 3400)
    expect(json["alerts"].pluck("code")).to include("model_errors")
  end

  it "records whether a reviewer changed a draft and when the reply went out" do
    ci = Care::CheckInIntake.call(enrolment: e, message: "Seit heute Druck auf der Brust beim Training.", pain_score: 4, actor: s[:patient_user])
    draft = Care::DraftRequest.call(enrolment: e, kind: "check_in_reply", actor: s[:therapist], check_in: ci)
    perform_enqueued_jobs
    travel 3.hours
    Care::DraftReview.new(draft.reload, actor: s[:therapist]).approve!(edits: { reply: "Bitte rufen Sie uns heute an. Bei Brustschmerzen 112." })
    expect(draft.reload.edited).to be(true)
    expect(ci.reload.answered_at).to be_within(1.second).of(Time.current)
    expect(AiCall.where(clinic_id: s[:clinic].id).pluck(:task)).to contain_exactly("check_in_screen", "check_in_reply")
  end

  it "does not count an edit that changes nothing" do
    ci = Care::CheckInIntake.call(enrolment: e, message: "Alles gut heute.", pain_score: 2, actor: s[:patient_user])
    draft = Care::DraftRequest.call(enrolment: e, kind: "check_in_reply", actor: s[:therapist], check_in: ci)
    perform_enqueued_jobs
    draft.reload
    Care::DraftReview.new(draft, actor: s[:therapist]).approve!(edits: { reply: draft.output["reply"] })
    expect(draft.reload.edited).to be(false)
  end
end
