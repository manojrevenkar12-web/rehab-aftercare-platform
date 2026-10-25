require "rails_helper"

RSpec.describe Enrolment do
  let(:therapist) { create(:user, :therapist) }
  let(:patient) { create(:patient, clinic: therapist.clinic, rehab_ended_on: Date.new(2026, 9, 1)) }
  let(:enrolment) { create(:enrolment, :approved, patient: patient) }

  before { travel_to Date.new(2026, 12, 1) }

  def unit(day, key: SecureRandom.hex(4), minutes: 20, pain: [5, 4])
    enrolment.record_unit!({ performed_on: day, duration_minutes: minutes, source: "therapist", pain_before: pain[0], pain_after: pain[1],
                             idempotency_key: key }, actor: therapist)
  end

  it "takes its unit count from the programme and the indication" do
    expect(enrolment.units_required).to eq(18)
    neuro = create(:enrolment, programme: "irena_digital", patient: create(:patient, clinic: therapist.clinic, indication: "neurology"))
    expect(neuro.units_required).to eq(36)
  end

  it "starts with the first unit and completes with the last required one" do
    unit(Date.new(2026, 9, 10))
    expect(enrolment.reload).to have_attributes(status: "active", started_on: Date.new(2026, 9, 10))
    17.times { |i| unit(Date.new(2026, 9, 11) + i.days) }
    expect(enrolment.reload).to have_attributes(status: "completed", completed_on: Date.new(2026, 9, 27))
    expect { unit(Date.new(2026, 9, 28)) }.to raise_error(Enrolment::TransitionError, /completed/)
  end

  it "records a retried unit once" do
    a = unit(Date.new(2026, 9, 10), key: "app-retry-1")
    b = unit(Date.new(2026, 9, 10), key: "app-retry-1")
    expect(b).to eq(a)
    expect(enrolment.training_units.count).to eq(1)
  end

  it "does not count units shorter than the programme's minimum" do
    unit(Date.new(2026, 9, 10), minutes: 12)
    expect(enrolment.reload.units_done).to eq(0)
    expect(enrolment.training_units.count).to eq(1)
  end

  it "refuses units dated in the future" do
    travel_to Date.new(2026, 10, 1)
    expect { unit(Date.new(2026, 10, 2)) }.to raise_error(ActiveRecord::RecordInvalid, /future/)
  end

  it "refuses a first unit after the latest start" do
    travel_to Date.new(2027, 1, 10)
    expect { unit(Date.new(2027, 1, 5)) }.to raise_error(Enrolment::TransitionError, /start by 2026-12-01/)
  end

  it "refuses units before rehab ended" do
    expect { unit(Date.new(2026, 8, 30)) }.to raise_error(ActiveRecord::RecordInvalid, /before rehab ended/)
  end

  it "expires by itself when the start was missed, and writes why" do
    travel_to Date.new(2026, 12, 5)
    enrolment.apply_deadlines!(today: Date.current)
    expect(enrolment.reload).to have_attributes(status: "expired", end_reason: "start_missed")
    expect(AuditEvent.where(action: "enrolment.expired").count).to eq(1)
  end

  it "leaves a long break to the therapist" do
    unit(Date.new(2026, 9, 10))
    enrolment.apply_deadlines!(today: Date.new(2026, 11, 30))
    expect(enrolment.reload.status).to eq("active")
    expect(enrolment.deadlines.findings(Date.new(2026, 11, 30)).map(&:code)).to eq([:break_exceeded])
    enrolment.end_early!(reason: "goal_unreachable", on: Date.new(2026, 11, 30), actor: therapist)
    expect(enrolment.reload.status).to eq("ended_early")
  end

  it "only moves along allowed paths" do
    fresh = create(:enrolment, patient: patient)
    expect { fresh.end_early!(reason: "patient_withdrew", on: Date.current, actor: therapist) }.to raise_error(Enrolment::TransitionError)
    expect { enrolment.approve!(cost_approval_ref: "x", approved_on: Date.current, actor: therapist) }.to raise_error(Enrolment::TransitionError)
  end
end
