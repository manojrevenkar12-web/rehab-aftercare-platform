module Ai
  # The rules a proposed training-plan change must pass, checked by code whatever the model says.
  module PlanRules
    MAX_CHANGES = 3
    BOUNDS = { "sets" => 1..5, "reps" => 1..30, "per_week" => 1..7 }.freeze
    ACTIONS = %w[add remove modify].freeze

    # What makes an exercise unsafe for this patient now: the indication and recent red flags.
    FLAG_TAGS = { "fall" => "balance_impaired", "neurological" => "neuro_acute", "chest_pain" => "cardiac_unstable",
                  "breathlessness" => "cardiac_unstable", "severe_pain" => "acute_pain", "pain_jump" => "acute_pain",
                  "wound_or_fever" => "infection" }.freeze

    module_function

    def context_tags(indication, flag_codes)
      ([indication.to_s] + flag_codes.filter_map { |c| FLAG_TAGS[c] }).uniq
    end

    # Returns findings; empty means the change may be shown for approval.
    def check(changes, plan:, context:, library:)
      out = []
      changes = Array(changes)
      out << Checks.blocking(:too_many_changes, "#{changes.size} changes proposed; at most #{MAX_CHANGES}.") if changes.size > MAX_CHANGES
      current = plan.to_h { |p| [p["exercise_key"], p] }
      max_level = (plan.map { |p| p["level"] }.max || 1)
      changes.each do |c|
        key = c["exercise_key"]
        ex = library[key]
        unless ACTIONS.include?(c["action"])
          out << Checks.blocking(:unknown_action, "Unknown action #{c['action'].inspect}.")
          next
        end
        if ex.nil?
          out << Checks.blocking(:unknown_exercise, "#{key.inspect} is not in the exercise library.")
          next
        end
        if c["action"] == "remove"
          out << Checks.blocking(:remove_missing, "#{key} is not in the plan.") unless current.key?(key)
          next
        end
        out << Checks.blocking(:modify_missing, "#{key} is not in the plan.") if c["action"] == "modify" && !current.key?(key)
        bad = Array(ex["contraindications"]) & context
        out << Checks.blocking(:contraindicated, "#{key} is contraindicated (#{bad.join(', ')}).") if bad.any?
        if ex["level"] > max_level + 1
          out << Checks.blocking(:level_jump, "#{key} is level #{ex['level']}; the plan's highest is #{max_level}.")
        end
        BOUNDS.each do |field, range|
          v = c[field]
          out << Checks.blocking(:out_of_bounds, "#{key}: #{field} #{v.inspect} outside #{range}.") unless v.is_a?(Integer) && range.cover?(v)
        end
        out << Checks.warning(:no_reason, "#{key}: no reason given.") if c["reason"].to_s.strip.empty?
      end
      out
    end
  end
end
