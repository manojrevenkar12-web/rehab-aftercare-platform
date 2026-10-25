module Care
  # A person's decision on a draft. Approval is what makes a draft do anything: a reply is sent to
  # the patient (possibly edited), closing documentation becomes the unsigned report, a plan
  # change is applied. A draft with a blocking finding cannot be approved as it is.
  class DraftReview
    class Refused < StandardError; end

    def initialize(draft, actor:)
      @draft = draft
      @actor = actor
    end

    def approve!(edits: nil)
      AiDraft.transaction do
        @draft.lock!
        raise Refused, "draft is #{@draft.status}" unless @draft.status == "ready" || (@draft.status == "held" && edits.present?)

        final = edits.present? ? @draft.output.merge(edits.stringify_keys) : @draft.output
        recheck!(final) if edits.present?
        apply!(final)
        @draft.update!(status: "approved", reviewed_by: @actor, reviewed_at: Time.current, output: final)
        AuditEvent.record!(actor: @actor, action: "ai_draft.approved", subject: @draft,
                           data: { kind: @draft.kind, edited: edits.present?, fields_edited: edits&.keys })
      end
      @draft
    end

    def reject!(reason:)
      raise Refused, "a rejection needs a reason" if reason.blank?

      @draft.with_lock do
        raise Refused, "draft is #{@draft.status}" unless %w[ready held failed].include?(@draft.status)

        @draft.update!(status: "rejected", reviewed_by: @actor, reviewed_at: Time.current)
      end
      AuditEvent.record!(actor: @actor, action: "ai_draft.rejected", subject: @draft, data: { kind: @draft.kind, reason: reason })
      @draft
    end

    private

    # Edited text goes through the same checks as the model's, minus the ones only a model fails.
    def recheck!(final)
      text = final.slice("reply", "course", "outcome", "adherence", "recommendation").values.join(" ")
      raise Refused, "the edited text still contains medication advice" if Ai::Checks.dosing_advice(text).any?
      return unless @draft.kind == "plan_change"

      facts = Ai::Facts.plan(@draft.enrolment)
      blocking = Ai::PlanRules.check(final["changes"], plan: facts["plan"], context: facts["context"], library: Care::Library.to_h)
                              .select { |f| f.severity == :blocking }
      raise Refused, blocking.map(&:message).join(" ") if blocking.any?
    end

    def apply!(final)
      e = @draft.enrolment
      case @draft.kind
      when "check_in_reply"
        check_in = e.check_ins.find(final.fetch("check_in_id"))
        check_in.update!(status: "answered")
      when "closing_report"
        report = e.closing_report || e.build_closing_report
        raise Refused, "the closing report is already signed" if report.signed?

        report.update!(sections: final.slice(*::ClosingReport::SECTIONS), ai_draft: @draft)
      when "plan_change"
        facts = Ai::Facts.plan(e)
        blocking = Ai::PlanRules.check(final["changes"], plan: facts["plan"], context: facts["context"], library: Care::Library.to_h)
                                .select { |f| f.severity == :blocking }
        raise Refused, blocking.map(&:message).join(" ") if blocking.any?

        final["changes"].each { |c| apply_change(e, c) }
      end
    end

    def apply_change(enrolment, change)
      exercise = Exercise.find_by!(key: change["exercise_key"])
      item = enrolment.plan_items.find_by(exercise: exercise, active: true)
      case change["action"]
      when "add" then enrolment.plan_items.create!(exercise: exercise, **change.slice("sets", "reps", "per_week").symbolize_keys)
      when "modify" then item.update!(change.slice("sets", "reps", "per_week"))
      when "remove" then item.update!(active: false)
      end
    end
  end
end
