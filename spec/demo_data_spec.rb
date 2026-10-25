require "rails_helper"

RSpec.describe DemoData do
  it "loads a consistent demo clinic, twice without duplicating anything" do
    load Rails.root.join("db/seeds.rb")
    expect { load Rails.root.join("db/seeds.rb") }.not_to change(Patient, :count)
    expect(Patient.count).to eq(6)
    expect(Claim.pluck(:status)).to eq(%w[submitted])
    expect(CheckIn.where(status: "escalated").count).to eq(2)
    expect(AuditEvent.verify_chain).to be_nil
  end
end
