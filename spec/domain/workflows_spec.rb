require "rails_helper"

RSpec.describe "AI workflows on the simulated model" do
  def client(*faults) = Ai::Client.new(provider: Ai::Providers::Simulated.new(faults: faults))
  def codes(result) = result.findings.map(&:code)

  let(:library) do
    YAML.safe_load_file(Rails.root.join("config/aftercare/exercises.yml")).fetch("exercises").transform_values(&:stringify_keys)
  end

  describe Ai::Workflows::CheckInReply do
    let(:facts) do
      { "patient" => "P-1", "language" => "de", "programme" => "T-RENA digital", "units_done" => 7, "units_required" => 18,
        "pain_score" => 6, "previous_pain_score" => 3, "message" => "Seit dem Sturz gestern tut der Rücken weh, [NAME-1].",
        "red_flags" => [ { "code" => "fall", "severity" => "urgent" }, { "code" => "pain_jump", "severity" => "urgent" } ] }
    end

    it "drafts a reply that acknowledges every rule flag and passes the checks" do
      r = described_class.new(client: client).call(facts, mapping: { "[NAME-1]" => "Anna" })
      expect(r.findings).to be_empty
      expect(r.output["acknowledged_flags"]).to eq(%w[fall pain_jump])
      expect(r.output["reply"]).to include("7 von 18", "heute")
    end

    it "adds the emergency advice itself, word for word, for an emergency flag" do
      f = facts.merge("red_flags" => [ { "code" => "chest_pain", "severity" => "emergency" } ])
      r = described_class.new(client: client).call(f)
      expect(r.output["reply"]).to end_with(described_class::ESCALATION["de"])
    end

    {
      drop_flag: :flag_not_acknowledged, dosing: :dosing_advice, invented_placeholder: :invented_placeholder, stray_number: :ungrounded_number
    }.each do |fault, finding|
      it "catches a model that makes the #{fault} mistake (#{finding})" do
        expect(codes(described_class.new(client: client(fault)).call(facts, mapping: { "[NAME-1]" => "Anna" }))).to include(finding)
      end
    end

    it "refuses to send identity to the model" do
      guard = Ai::Pseudonymizer.new(full_name: "Anna Becker")
      leaky = facts.merge("message" => "Anna Becker hier, alles gut")
      expect { described_class.new(client: client).call(leaky, guard: guard) }.to raise_error(Ai::Client::LeakRefused, /name_part/)
    end
  end

  describe Ai::Workflows::ClosingReport do
    let(:facts) do
      { "patient" => "P-1", "programme" => "T-RENA digital", "status" => "completed", "units_required" => 18, "units_done" => 18,
        "first_unit" => "2026-09-10", "last_unit" => "2026-11-19", "weeks" => 10, "units_per_week" => 1.8,
        "pain_start" => 5.7, "pain_end" => 2.3, "pain_change" => -3.4, "effort_mean" => 5.5, "check_ins" => 4,
        "red_flags_seen" => [ "fall" ] }
    end

    it "drafts four grounded sections" do
      r = described_class.new(client: client).call(facts)
      expect(r.findings).to be_empty
      expect(r.output["course"]).to include("10.09.2026", "18 von 18")
      expect(r.output["outcome"]).to include("5,7", "2,3")
    end

    { invent_number: :ungrounded_number, stray_number: :ungrounded_number, dosing: :dosing_advice, missing_section: :missing_fields }.each do |fault, finding|
      it "holds a draft when the model makes the #{fault} mistake" do
        r = described_class.new(client: client(fault)).call(facts)
        expect(codes(r)).to include(finding)
        expect(r).to be_blocking
      end
    end
  end

  describe Ai::Workflows::PlanChange do
    let(:facts) do
      { "patient" => "P-1", "indication" => "orthopaedics", "context" => [ "orthopaedics" ],
        "plan" => [ { "exercise_key" => "pelvic_tilt", "level" => 1, "body_region" => "lumbar", "sets" => 2, "reps" => 10, "per_week" => 3 } ],
        "recent_units" => [ { "on" => "2026-11-01", "pain_before" => 4, "pain_after" => 3, "effort" => 5 },
                           { "on" => "2026-11-05", "pain_before" => 3, "pain_after" => 2, "effort" => 5 } ] }
    end

    it "looks things up with tools and proposes a safe progression" do
      r = described_class.new(client: client).call(facts, library: library)
      expect(r.findings).to be_empty
      expect(r.trace.map { |t| t["tool"] }).to start_with("search_exercises")
      expect(r.output["changes"].first).to include("action" => "add")
      expect(library.fetch(r.output["changes"].first["exercise_key"])["level"]).to eq(2)
    end

    it "reduces load instead when pain is rising" do
      rising = facts.merge("recent_units" => [ { "on" => "2026-11-01", "pain_before" => 3, "pain_after" => 4, "effort" => 6 },
                                              { "on" => "2026-11-05", "pain_before" => 4, "pain_after" => 6, "effort" => 7 } ])
      r = described_class.new(client: client).call(rising, library: library)
      expect(r.output["changes"]).to eq([ { "action" => "modify", "exercise_key" => "pelvic_tilt", "sets" => 2, "reps" => 6, "per_week" => 3,
                                           "reason" => "Pain rose over the last units; reduce load." } ])
    end

    it "blocks an exercise ruled out by a recent fall even if the model ignores its own tool result" do
      fallen = facts.merge("context" => %w[orthopaedics balance_impaired])
      r = described_class.new(client: client(:contraindicated)).call(fallen, library: library)
      expect(codes(r)).to include(:contraindicated)
    end

    { unknown_exercise: :unknown_exercise, level_jump: :level_jump, too_many: :too_many_changes, out_of_bounds: :out_of_bounds, no_answer: :no_answer }.each do |fault, finding|
      it "blocks the #{fault} mistake" do
        expect(codes(described_class.new(client: client(fault)).call(facts, library: library))).to include(finding)
      end
    end
  end
end
