require "rails_helper"

RSpec.describe "Presenters.caseload_row" do
  let(:s) { Scenario.build }
  let(:e) { s[:enrolment] }

  it "counts a check-in nobody has answered within the SLA as overdue, flagged or not" do
    e.check_ins.create!(message: "Alles gut", pain_score: 2, submitted_at: 30.hours.ago, status: "new")
    e.check_ins.create!(message: "Auch gut", pain_score: 2, submitted_at: 2.hours.ago, status: "new")
    row = Presenters.caseload_row(e.patient.reload, Date.current, clinical: true)
    expect(row).to include(unanswered: 2, overdue: 1, escalations: 0)
    expect(row[:attention]).to be >= 2
  end

  it "shows nothing clinical to people who may not see it" do
    e.check_ins.create!(message: "Alles gut", pain_score: 2, submitted_at: 30.hours.ago, status: "new")
    row = Presenters.caseload_row(e.patient.reload, Date.current, clinical: false)
    expect(row).to include(unanswered: 0, overdue: 0, escalations: 0)
  end
end
