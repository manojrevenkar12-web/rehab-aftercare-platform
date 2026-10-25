require "rails_helper"

RSpec.describe Aftercare::DeadlineCheck do
  let(:rehab_end) { Date.new(2026, 1, 15) }

  def check(status: "approved", started_on: nil, units: [])
    described_class.new(rehab_ended_on: rehab_end, status: status, started_on: started_on, unit_dates: units)
  end

  def codes(c, today) = c.findings(today).map(&:code)

  it "derives the programme window from the rehab end" do
    c = check
    expect([ c.ideal_start, c.latest_start, c.latest_finish ]).to eq([ Date.new(2026, 2, 26), Date.new(2026, 4, 15), Date.new(2027, 1, 15) ])
  end

  it "is quiet before the ideal start, notes a late start, warns a week before the last day, blocks after it" do
    expect(codes(check, Date.new(2026, 2, 20))).to be_empty
    expect(codes(check, Date.new(2026, 3, 1))).to eq([ :start_late ])
    expect(codes(check, Date.new(2026, 4, 8))).to eq([ :start_due ])
    expect(codes(check, Date.new(2026, 4, 16))).to eq([ :start_missed ])
  end

  it "counts a break from the last unit and flags it past six weeks" do
    started = Date.new(2026, 2, 1)
    c = check(status: "active", started_on: started, units: [ started, Date.new(2026, 2, 10) ])
    expect(codes(c, Date.new(2026, 3, 10))).to be_empty
    expect(codes(c, Date.new(2026, 3, 18))).to eq([ :break_long ])
    expect(codes(c, Date.new(2026, 3, 25))).to eq([ :break_exceeded ])
    expect(c.longest_break_days(Date.new(2026, 3, 25))).to eq(43)
  end

  it "warns a month before the twelve-month limit and blocks after it" do
    started = Date.new(2026, 2, 1)
    units = [ started, Date.new(2026, 12, 20) ]
    expect(codes(check(status: "active", started_on: started, units: units), Date.new(2026, 12, 20))).to eq([ :finish_due ])
    expect(codes(check(status: "active", started_on: started, units: units + [ Date.new(2027, 1, 15) ]), Date.new(2027, 1, 16))).to eq([ :finish_missed ])
  end

  it "has nothing to say about a finished enrolment" do
    expect(codes(check(status: "completed", started_on: Date.new(2026, 2, 1)), Date.new(2028, 1, 1))).to be_empty
  end
end
