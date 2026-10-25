module Care
  # Asks for an AI draft. The same input gives the same draft (one row per enrolment, kind and
  # input digest), so a double click or a retried request does not pay for a second model call.
  class DraftRequest
    def self.call(enrolment:, kind:, actor:, check_in: nil)
      facts = facts_for(enrolment, kind, check_in)
      digest = OpenSSL::Digest::SHA256.hexdigest(JSON.generate(AuditEvent.canonical(facts.merge("check_in_id" => check_in&.id))))
      prompt = { "check_in_reply" => Ai::Workflows::CheckInReply, "closing_report" => Ai::Workflows::ClosingReport,
                 "plan_change" => Ai::Workflows::PlanChange }.fetch(kind)::PROMPT_VERSION
      draft = AiDraft.create_or_find_by!(enrolment: enrolment, kind: kind, input_digest: digest) do |d|
        d.requested_by = actor
        d.prompt_version = prompt
        d.output = check_in ? { "check_in_id" => check_in.id } : {}
      end
      if draft.previously_new_record?
        GenerateDraftJob.perform_later(draft.id)
        AuditEvent.record!(actor: actor, action: "ai_draft.requested", subject: draft, data: { kind: kind })
      end
      draft
    end

    def self.facts_for(enrolment, kind, check_in)
      case kind
      when "check_in_reply" then Ai::Facts.check_in(check_in || raise(ArgumentError, "a check-in reply needs a check-in"), pseudonymizer(enrolment)).first
      when "closing_report" then Ai::Facts.closing_report(enrolment)
      when "plan_change" then Ai::Facts.plan(enrolment)
      else raise ArgumentError, "unknown draft kind #{kind}"
      end
    end

    def self.pseudonymizer(enrolment)
      Ai::Pseudonymizer.new(enrolment.patient.identity)
    end
  end
end
