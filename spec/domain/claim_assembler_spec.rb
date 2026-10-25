require "rails_helper"

RSpec.describe Billing::ClaimAssembler do
  let(:s) { Scenario.build }
  let(:enrolment) { s[:enrolment] }

  before { travel_to Date.new(2026, 12, 1) }

  def complete!(e = enrolment, n: e.units_required)
    n.times do |i|
      e.record_unit!({ performed_on: Date.new(2026, 9, 5) + i.days, duration_minutes: 20, source: "therapist", pain_before: 5, pain_after: 3,
                       idempotency_key: "u#{i}" }, actor: s[:therapist])
    end
  end

  def sign_report!(e = enrolment)
    report = e.create_closing_report!(sections: ClosingReport::SECTIONS.index_with { "text" })
    report.sign!(s[:physician])
  end

  it "bills a completed, documented enrolment and lists every document" do
    complete!
    sign_report!
    claim = described_class.call(enrolment.reload, actor: s[:billing])
    expect(claim).to have_attributes(status: "ready", units_billed: 18, amount_cents: 18 * 2500)
    expect(claim.documents.keys).to include("invoice", "participation_record", "closing_documentation", "cost_approval_ref")
    expect(claim.documents.dig("participation_record", "units").size).to eq(18)
    expect(claim.documents.dig("invoice", "rate_source")).to start_with("placeholder")
    expect(claim.number).to eq("RN-#{s[:clinic].ik_number}-#{enrolment.id.to_s.rjust(7, '0')}")
  end

  it "keeps a claim in draft with the reasons while anything is missing" do
    complete!
    claim = described_class.call(enrolment.reload)
    expect(claim.status).to eq("draft")
    expect(claim.problems.pluck("code")).to eq(%w[no_closing_report])
    enrolment.create_closing_report!(sections: ClosingReport::SECTIONS.index_with { "text" })
    expect(described_class.call(enrolment.reload).problems.pluck("code")).to eq(%w[closing_report_unsigned])
  end

  it "does not bill an active enrolment" do
    complete!(n: 3)
    expect(described_class.call(enrolment.reload).problems.pluck("code")).to include("not_finished", "no_closing_report")
  end

  it "puts an early end to a person instead of pricing it" do
    complete!(n: 7)
    enrolment.end_early!(reason: "patient_withdrew", on: Date.new(2026, 10, 1), actor: s[:therapist])
    sign_report!
    claim = described_class.call(enrolment.reload)
    expect(claim).to have_attributes(status: "needs_review", amount_cents: 0, units_billed: 7)
    Billing::ClaimLifecycle.new(claim, actor: s[:billing]).decide_review!(units: 7, note: "Withdrew for work reasons; bill the units done.")
    expect(claim.reload).to have_attributes(status: "ready", amount_cents: 7 * 2500)
    expect { Billing::ClaimLifecycle.new(claim, actor: s[:billing]).decide_review!(units: 7, note: "again") }.to raise_error(Billing::ClaimLifecycle::Error)
  end

  it "is idempotent, and never touches a submitted claim" do
    complete!
    sign_report!
    a = described_class.call(enrolment.reload)
    b = described_class.call(enrolment.reload)
    expect(b.id).to eq(a.id)
    expect(Claim.count).to eq(1)
    expect(AuditEvent.where(action: "claim.assembled").count).to eq(1)
    Billing::ClaimLifecycle.new(a, actor: s[:billing]).submit!
    enrolment.closing_report.update_columns(signed_at: nil)
    expect(described_class.call(enrolment.reload).status).to eq("submitted")
  end

  it "does not bill short units, and says so" do
    complete!
    enrolment.training_units.create!(performed_on: Date.new(2026, 11, 1), duration_minutes: 10, source: "patient_app", idempotency_key: "short")
    sign_report!
    claim = described_class.call(enrolment.reload)
    expect(claim).to have_attributes(status: "ready", units_billed: 18)
    expect(claim.problems.pluck("code", "severity")).to eq([ %w[short_units info] ])
  end
end

RSpec.describe Billing::ClaimLifecycle do
  let(:s) { Scenario.build }
  let(:claim) { Claim.create!(enrolment: s[:enrolment], number: "RN-1", status: "ready", amount_cents: 100, units_billed: 1) }
  let(:life) { described_class.new(claim, actor: s[:billing]) }

  it "submits, then settles as paid or rejected with a reason" do
    life.submit!
    expect { life.submit! }.to raise_error(described_class::Error, /is submitted/)
    expect { life.mark_rejected!(reason: "") }.to raise_error(described_class::Error, /reason/)
    life.mark_rejected!(reason: "G4832 missing a signature")
    expect(claim.reload).to have_attributes(status: "rejected", rejection_reason: "G4832 missing a signature")
    expect(AuditEvent.where(action: %w[claim.submitted claim.rejected]).count).to eq(2)
  end

  it "cannot pay a claim that was never submitted" do
    expect { life.mark_paid! }.to raise_error(described_class::Error)
  end
end
