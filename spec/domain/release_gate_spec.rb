require "rails_helper"

RSpec.describe Ops::ReleaseGate do
  let(:s) { Scenario.build }
  let(:gate) { described_class.new(config: { "min_reviews" => 40, "confidence_z" => 1.96, "non_inferiority_margin" => 0.05 }) }

  # n reviewed drafts of a release: `rejected` rejected, `edited` approved after edits, the rest approved as written
  def release!(version, model, n:, rejected: 0, edited: 0, held: 0, days_ago: 10, kind: "check_in_reply")
    @seq = (@seq || 0) + 1
    at = days_ago.days.ago
    rows = Array.new(n + held) do |i|
      status = if i >= n then "held" elsif i < rejected then "rejected" else "approved" end
      { enrolment_id: s[:enrolment].id, requested_by_id: s[:therapist].id, kind: kind, status: status, input_digest: "r#{@seq}-#{i}",
        model: model, prompt_version: version, edited: status == "approved" && i < rejected + edited,
        findings: status == "held" ? [ { "code" => "dosing_advice", "severity" => "blocking" } ] : [],
        reviewed_at: status == "held" ? nil : at + 1.hour, created_at: at + i.seconds, updated_at: at + 1.hour }
    end
    AiDraft.insert_all!(rows)
  end

  it "waits until both releases have enough reviews" do
    release!("check-in-reply/2", "m", n: 100, rejected: 5, days_ago: 30)
    release!("check-in-reply/3", "m", n: 12, rejected: 6, days_ago: 2)
    v = gate.latest("check_in_reply")
    expect(v.decision).to eq("wait")
    expect(v.reasons.first).to include("12 of 40")
  end

  it "blocks a release whose drafts reviewers reject more often" do
    release!("plan-change/2", "big", n: 90, rejected: 7, edited: 18, days_ago: 60, kind: "plan_change")
    release!("plan-change/2", "mini", n: 60, rejected: 15, edited: 18, days_ago: 5, kind: "plan_change")
    v = gate.latest("plan_change")
    expect(v.decision).to eq("block")
    expect(v.candidate.release.model).to eq("mini")
    expect(v.metrics["rejected"][:low]).to be > 0
    expect(v.reasons.join).to include("rejected rose from 7.8% to 25.0%")
  end

  it "passes a release that is, with confidence, no more than the margin worse" do
    release!("check-in-reply/2", "m", n: 180, rejected: 11, edited: 54, days_ago: 60)
    release!("check-in-reply/3", "m", n: 170, rejected: 6, edited: 30, days_ago: 20)
    v = gate.latest("check_in_reply")
    expect(v.decision).to eq("pass")
    expect(v.metrics.values.pluck(:high)).to all(be < 0.05)
  end

  it "waits when the same rates on small samples cannot rule out a worse release" do
    release!("check-in-reply/2", "m", n: 50, rejected: 5, edited: 5, days_ago: 60)
    release!("check-in-reply/3", "m", n: 50, rejected: 5, edited: 5, days_ago: 20)
    v = gate.latest("check_in_reply")
    expect(v.decision).to eq("wait")
    expect(v.reasons.first).to include("could still be up to")
  end

  it "ignores a release nobody has reviewed yet when picking the newest" do
    release!("check-in-reply/2", "m", n: 50, days_ago: 60)
    release!("check-in-reply/3", "m", n: 50, days_ago: 20)
    release!("check-in-reply/3", "m+dosing", n: 0, held: 3, days_ago: 1)
    expect(gate.latest("check_in_reply").candidate.release.model).to eq("m")
    expect(gate.cohorts("check_in_reply").map(&:held)).to eq([ 0, 0 ])
  end

  it "compares two named releases, for a deploy pipeline" do
    release!("check-in-reply/2", "m", n: 90, rejected: 7, days_ago: 60)
    release!("check-in-reply/3", "m", n: 60, rejected: 15, days_ago: 20)
    v = gate.compare("check_in_reply", baseline: described_class::Release.parse("check-in-reply/2@m"),
                                       candidate: described_class::Release.parse("check-in-reply/3@m"))
    expect(v).to be_blocked
    expect { described_class::Release.parse("check-in-reply/3") }.to raise_error(ArgumentError)
  end

  it "says there is nothing to compare for a kind with one release" do
    release!("closing-report/2", "m", n: 5, kind: "closing_report")
    expect(gate.latest("closing_report")).to have_attributes(decision: "wait", reasons: [ "no earlier release to compare with" ])
  end

  describe Ops::Stats do
    it "matches Newcombe's published interval for 56/70 against 48/80" do
      d = described_class.difference(56, 70, 48, 80)
      expect([ d[:low], d[:high] ]).to match([ be_within(0.0001).of(0.0524), be_within(0.0001).of(0.3339) ])
    end

    it "gives Wilson's interval and nearest-rank percentiles" do
      expect(described_class.wilson(81, 263)).to match([ be_within(0.0001).of(0.2553), be_within(0.0001).of(0.3662) ])
      expect(described_class.percentile((1..10).to_a, 90)).to eq(9)
      expect(described_class.percentile([], 50)).to be_nil
    end
  end
end
