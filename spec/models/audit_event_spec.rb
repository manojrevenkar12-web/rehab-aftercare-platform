require "rails_helper"

RSpec.describe AuditEvent do
  let(:user) { create(:user) }

  it "chains every event to the one before, and verifies" do
    3.times { |i| described_class.record!(actor: user, action: "thing.done", data: { "n" => i, "nested" => { "b" => 1, "a" => [ 2, { "z" => 1, "y" => 2 } ] } }) }
    expect(described_class.order(:id).pluck(:prev_digest).drop(1)).to eq(described_class.order(:id).pluck(:digest).first(2))
    expect(described_class.verify_chain).to be_nil
  end

  it "is append-only in the database, not just in Ruby" do
    e = described_class.record!(actor: user, action: "thing.done")
    expect { described_class.transaction(requires_new: true) { described_class.where(id: e.id).update_all(action: "other") } }
      .to raise_error(ActiveRecord::StatementInvalid, /append-only/)
    expect { described_class.transaction(requires_new: true) { described_class.where(id: e.id).delete_all } }
      .to raise_error(ActiveRecord::StatementInvalid, /append-only/)
  end

  it "notices an edited event" do
    described_class.record!(actor: user, action: "a")
    second = described_class.record!(actor: user, action: "b", data: { "units" => 3 })
    described_class.record!(actor: user, action: "c")
    conn = described_class.connection
    conn.execute("ALTER TABLE audit_events DISABLE TRIGGER audit_events_no_update")
    conn.execute("UPDATE audit_events SET data = '{\"units\": 30}' WHERE id = #{second.id}")
    conn.execute("ALTER TABLE audit_events ENABLE TRIGGER audit_events_no_update")
    expect(described_class.verify_chain).to eq(second.id)
  end
end
