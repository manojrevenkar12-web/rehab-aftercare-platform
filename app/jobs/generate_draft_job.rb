# Runs a draft's workflow against the model. Safe to run twice: a draft that is no longer queued is
# left alone. A request that would leak identity fails the draft instead of reaching the model.
class GenerateDraftJob < ApplicationJob
  queue_as :ai
  retry_on Ai::Providers::OpenAiCompatible::Error, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(draft_id, client: Ai::Client.default)
    draft = AiDraft.find(draft_id)
    return unless draft.status == "queued"

    e = draft.enrolment
    pseudonymizer = Ai::Pseudonymizer.new(e.patient.identity)
    result = case draft.kind
    when "check_in_reply"
               facts, mapping = Ai::Facts.check_in(e.check_ins.find(draft.output.fetch("check_in_id")), pseudonymizer)
               Ai::Workflows::CheckInReply.new(client: client).call(facts, guard: pseudonymizer, mapping: mapping)
    when "closing_report"
               Ai::Workflows::ClosingReport.new(client: client).call(Ai::Facts.closing_report(e), guard: pseudonymizer)
    when "plan_change"
               Ai::Workflows::PlanChange.new(client: client).call(Ai::Facts.plan(e), library: Care::Library.to_h, guard: pseudonymizer)
    end
    output = result.output.is_a?(Hash) ? result.output.merge(draft.output.slice("check_in_id")) : draft.output
    draft.update!(status: result.blocking? ? "held" : "ready", output: output, findings: result.findings.map(&:to_h),
                  model: result.model, prompt_version: result.prompt_version)
    AuditEvent.record!(action: "ai_draft.generated", subject: draft,
                       data: { status: draft.status, model: result.model, findings: result.findings.map { |f| f.code.to_s } })
  rescue Ai::Client::LeakRefused => e
    draft.update!(status: "failed", error: e.message)
    AuditEvent.record!(action: "ai_draft.leak_refused", subject: draft, data: { kind: draft.kind })
  end
end
