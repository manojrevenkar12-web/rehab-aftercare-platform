require "rails_helper"

RSpec.describe DemoData do
  it "loads a consistent demo clinic, twice without duplicating anything" do
    load Rails.root.join("db/seeds.rb")
    expect { load Rails.root.join("db/seeds.rb") }.not_to change(Patient, :count)
    expect(Patient.count).to eq(8)
    expect(Claim.order(:id).pluck(:status)).to eq(%w[submitted needs_review])
    expect(CheckIn.where(status: "escalated").count).to eq(2)
    expect(CheckIn.where("jsonb_array_length(set_aside) > 0").count).to eq(1)
    expect(AiDraft.where(kind: "check_in_reply").pluck(:status)).to contain_exactly("ready", "held")
    expect(AuditEvent.verify_chain).to be_nil
  end
end
