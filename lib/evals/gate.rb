module Evals
  # Compares a report with config/evals.yml. Returns the list of failures (empty = pass).
  module Gate
    module_function

    def check(doc, thresholds = YAML.safe_load_file(Rails.root.join("config/evals.yml")))
      r = doc.fetch("results")
      out = []
      t = thresholds
      at_least(out, r.dig("red_flags", "emergency_recall"), t.dig("red_flags", "emergency_recall"), "red flags: emergency recall")
      at_least(out, r.dig("red_flags", "urgent_recall"), t.dig("red_flags", "urgent_recall"), "red flags: urgent recall")
      at_most(out, r.dig("red_flags", "false_escalation_rate"), t.dig("red_flags", "false_escalation_rate"), "red flags: false escalations")
      at_most(out, r.dig("pseudonymization", "leak_rate"), t.dig("pseudonymization", "leak_rate"), "pseudonymisation: leak rate")
      at_most(out, r.dig("pseudonymization", "clinical_words_lost"), t.dig("pseudonymization", "clinical_words_lost"), "pseudonymisation: clinical words lost")
      at_least(out, r.dig("drafts", "fault_catch_rate"), t.dig("drafts", "fault_catch_rate"), "drafts: injected mistakes held")
      at_most(out, r.dig("drafts", "false_hold_rate"), t.dig("drafts", "false_hold_rate"), "drafts: faithful drafts held")
      at_most(out, r.dig("screen_guarantees", "violations"), t.dig("screen", "violations"), "model screen: guarantee violations")
      out
    end

    def at_least(out, value, min, what)
      out << "#{what}: missing from the report" if value.nil?
      out << "#{what}: #{value} < #{min}" if value && value < min
    end

    def at_most(out, value, max, what)
      out << "#{what}: missing from the report" if value.nil?
      out << "#{what}: #{value} > #{max}" if value && value > max
    end
  end
end
