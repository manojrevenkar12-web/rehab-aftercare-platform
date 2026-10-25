module Ai
  # The facts a workflow gives a model, built from the database. Facts carry the pseudonym and
  # clinical numbers, never identity; free text passes through the pseudonymizer first.
  module Facts
    module_function

    def check_in(check_in, pseudonymizer)
      e = check_in.enrolment
      previous = e.check_ins.where("submitted_at < ?", check_in.submitted_at).order(:submitted_at).last
      redacted = pseudonymizer.call(check_in.message)
      facts = {
        "patient" => e.patient.pseudonym,
        "language" => language_of(check_in.message),
        "programme" => e.programme_rules.name,
        "units_done" => e.units_done,
        "units_required" => e.units_required,
        "pain_score" => check_in.pain_score,
        "previous_pain_score" => previous&.pain_score,
        "message" => redacted.text,
        "red_flags" => Array(check_in.red_flags).map { |f| f.slice("code", "severity") }
      }.compact
      [facts, redacted.mapping]
    end

    def closing_report(enrolment)
      units = enrolment.counted_units.sort_by(&:performed_on)
      first3 = units.first(3).filter_map(&:pain_before)
      last3 = units.last(3).filter_map(&:pain_after)
      weeks = units.any? ? [((units.last.performed_on - units.first.performed_on).to_i / 7.0).ceil, 1].max : 0
      before = first3.any? ? (first3.sum.to_f / first3.size).round(1) : nil
      after = last3.any? ? (last3.sum.to_f / last3.size).round(1) : nil
      flags = enrolment.check_ins.flat_map { |c| Array(c.red_flags).map { |f| f["code"] } }.uniq
      {
        "patient" => enrolment.patient.pseudonym,
        "programme" => enrolment.programme_rules.name,
        "status" => enrolment.status,
        "units_required" => enrolment.units_required,
        "units_done" => units.size,
        "first_unit" => units.first&.performed_on&.iso8601,
        "last_unit" => units.last&.performed_on&.iso8601,
        "weeks" => weeks,
        "units_per_week" => weeks.positive? ? (units.size.to_f / weeks).round(1) : nil,
        "pain_start" => before,
        "pain_end" => after,
        "pain_change" => before && after ? (after - before).round(1) : nil,
        "effort_mean" => mean(units.filter_map(&:effort)),
        "check_ins" => enrolment.check_ins.count,
        "red_flags_seen" => flags,
        "end_reason" => enrolment.end_reason
      }.compact
    end

    def plan(enrolment)
      flags = enrolment.check_ins.order(submitted_at: :desc).limit(3).flat_map { |c| Array(c.red_flags).map { |f| f["code"] } }
      {
        "patient" => enrolment.patient.pseudonym,
        "indication" => enrolment.patient.indication,
        "context" => PlanRules.context_tags(enrolment.patient.indication, flags),
        "plan" => enrolment.plan_items.where(active: true).includes(:exercise).map do |i|
          { "exercise_key" => i.exercise.key, "level" => i.exercise.level, "body_region" => i.exercise.body_region,
            "sets" => i.sets, "reps" => i.reps, "per_week" => i.per_week }
        end,
        "recent_units" => enrolment.counted_units.sort_by(&:performed_on).last(6).map do |u|
          { "on" => u.performed_on.iso8601, "pain_before" => u.pain_before, "pain_after" => u.pain_after, "effort" => u.effort }
        end
      }
    end

    def mean(values)
      values.any? ? (values.sum.to_f / values.size).round(1) : nil
    end

    def language_of(text)
      text.to_s.match?(/\b(ich|nicht|und|schmerz\w*|heute|mein\w*|habe)\b/i) ? "de" : "en"
    end
  end
end
