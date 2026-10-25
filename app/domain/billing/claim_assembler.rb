module Billing
  # Builds (or rebuilds) the claim for a finished enrolment. Safe to run any number of times:
  # there is one claim per enrolment, and a claim that has been submitted is never touched.
  #
  # A claim is `ready` only when every document is there and agrees with the others; otherwise it
  # stays a `draft` with the problems listed, or goes to `needs_review` when the rules do not say
  # how to bill (an early end).
  class ClaimAssembler
    FROZEN = %w[submitted paid].freeze

    def self.call(enrolment, actor: nil)
      new(enrolment, actor).call
    end

    def initialize(enrolment, actor)
      @enrolment = enrolment
      @actor = actor
    end

    def call
      Claim.transaction do
        @enrolment.lock!
        claim = Claim.lock.find_or_initialize_by(enrolment: @enrolment)
        return claim if FROZEN.include?(claim.status)

        problems = check
        blocking = problems.select { |p| p[:severity] == "blocking" }
        units = @enrolment.units_done.clamp(0, @enrolment.units_required)
        rules = @enrolment.programme_rules
        status = if blocking.any? { |p| p[:code] == "early_end" } && blocking.size == 1 then "needs_review"
        elsif blocking.any? then "draft"
        else "ready"
        end
        claim.assign_attributes(
          number: claim.number || number_for(@enrolment),
          status: status,
          units_billed: units,
          amount_cents: status == "needs_review" ? 0 : units * rules.rate_cents_per_unit,
          documents: documents(units, rules),
          problems: problems
        )
        changed = claim.changed?
        claim.save!
        AuditEvent.record!(actor: @actor, action: "claim.assembled", subject: claim,
                           data: { status: claim.status, units: units, problems: problems.pluck(:code) }) if changed
        claim
      end
    end

    private

    def check
      e = @enrolment
      out = []
      out << problem("not_finished", "The enrolment is #{e.status}; only finished enrolments are billed.") unless e.finished?
      out << problem("expired", "The enrolment expired (#{e.end_reason}); there is nothing to bill.") if e.status == "expired"
      out << problem("early_end", "Ended early (#{e.end_reason}) after #{e.units_done} of #{e.units_required} units: the rules do not say how this is paid, so a person decides.") if e.status == "ended_early"
      out << problem("no_cost_approval", "No cost approval (G4802) reference.") if e.cost_approval_ref.blank?
      report = e.closing_report
      if report.nil?
        out << problem("no_closing_report", "No closing documentation.")
      elsif !report.signed?
        out << problem("closing_report_unsigned", "The closing documentation is not signed by a physician.")
      end
      if e.status == "completed" && e.units_done < e.units_required
        out << problem("units_short", "#{e.units_done} counted units, #{e.units_required} required.")
      end
      short = e.training_units.reject(&:counts?)
      out << problem("short_units", "#{short.size} unit(s) shorter than #{e.programme_rules.min_unit_minutes} minutes are not billed.", severity: "info") if short.any?
      out
    end

    def documents(units, rules)
      e = @enrolment
      {
        "invoice" => { "programme" => rules.key, "units" => units, "rate_cents_per_unit" => rules.rate_cents_per_unit,
                       "rate_source" => rules.rate_source },
        "participation_record" => { "units" => e.counted_units.map { |u| { "on" => u.performed_on.iso8601, "minutes" => u.duration_minutes } },
                                    "first_unit" => e.started_on&.iso8601, "last_unit" => e.training_units.maximum(:performed_on)&.iso8601 },
        "closing_documentation" => { "closing_report_id" => e.closing_report&.id, "signed_at" => e.closing_report&.signed_at&.iso8601 },
        "cost_approval_ref" => e.cost_approval_ref
      }
    end

    def problem(code, message, severity: "blocking")
      { code: code, message: message, severity: severity }
    end

    def number_for(enrolment)
      "RN-#{enrolment.patient.clinic.ik_number}-#{enrolment.id.to_s.rjust(7, '0')}"
    end
  end
end
