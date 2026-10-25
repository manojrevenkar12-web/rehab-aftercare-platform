require "rails_helper"

RSpec.describe "Evaluation" do
  it "passes the gate on the dev set" do
    doc = { "results" => Evals::Runner.new(Rails.root.join("evals/dev")).run }
    expect(Evals::Gate.check(doc)).to eq([])
  end

  it "fails the gate when a threshold is missed, and when a measure is missing" do
    doc = { "results" => { "red_flags" => { "emergency_recall" => 0.9, "urgent_recall" => 1.0, "false_escalation_rate" => 0.0 } } }
    failures = Evals::Gate.check(doc)
    expect(failures).to include("red flags: emergency recall: 0.9 < 1.0")
    expect(failures).to include("drafts: injected mistakes held: missing from the report")
  end

  it "records a held-out first run once" do
    Dir.mktmpdir do |dir|
      Evals::Report.write("heldout-x", {}, set: "heldout/x", first_run_only: true, root: Pathname(dir))
      expect { Evals::Report.write("heldout-x", {}, set: "heldout/x", first_run_only: true, root: Pathname(dir)) }
        .to raise_error(Evals::Report::AlreadyRecorded)
    end
  end

  it "counts only the injected mistakes that changed a draft" do
    r = Evals::Runner.new(Rails.root.join("evals/dev")).run(suites: %w[drafts])["drafts"]
    expect(r["fault_runs"]).to be < r["faithful_runs"] * Ai::Providers::Simulated::FAULTS.size
    expect(r["escaped"]).to eq([])
  end
end
