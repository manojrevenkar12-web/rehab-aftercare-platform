require "rails_helper"

RSpec.describe DemoData do
  it "loads a consistent demo clinic, twice without duplicating anything" do
    load Rails.root.join("db/seeds.rb")
    expect { load Rails.root.join("db/seeds.rb") }.not_to change(Patient, :count)
    demo = Clinic.find_by!(ik_number: "260999001")
    expect(Patient.where(clinic: demo).count).to eq(8)
    expect(Claim.order(:id).pluck(:status)).to eq(%w[submitted needs_review])
    expect(CheckIn.where(status: "escalated").count).to eq(2)
    expect(CheckIn.where("jsonb_array_length(set_aside) > 0").count).to eq(1)
    expect(AiDraft.where(kind: "check_in_reply").where.not(status: %w[approved rejected]).pluck(:status)).to contain_exactly("ready", "held")
    expect(AuditEvent.verify_chain).to be_nil
  end

  it "gives the operations view and the release gate something to measure" do
    load Rails.root.join("db/seeds.rb")
    demo = Clinic.find_by!(ik_number: "260999001")
    snap = Ops::Snapshot.new(demo).to_h
    expect(snap[:check_ins][:due]).to be > 15
    expect(snap[:check_ins][:share_met]).to be < 1.0 # two answers missed the promise, and Karl is still waiting
    expect(snap[:check_ins][:open_overdue]).to eq(1)
    expect(snap[:models][:tasks].pluck(:task)).to include("check_in_reply", "check_in_screen")
    decisions = snap[:releases].to_h { |r| [ r[:kind], r[:decision] ] }
    expect(decisions).to eq("check_in_reply" => "pass", "closing_report" => "wait", "plan_change" => "block")
    expect(snap[:alerts].pluck(:code)).to include("release_blocked", "check_ins_overdue")
    expect(JSON.generate(snap)).not_to include("Karl", "Weber", "Knie") # no names, no patient text
  end
end
