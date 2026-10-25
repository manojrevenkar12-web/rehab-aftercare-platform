# Runs the model screen on a check-in after the rules. It can only add flags; a check-in it adds a
# flag to is escalated. If the model is unavailable the rules' result stands and the failure is
# recorded on the check-in. Safe to run twice: a screened check-in is left alone.
class ScreenCheckInJob < ApplicationJob
  queue_as :ai
  discard_on ActiveRecord::RecordNotFound

  def perform(check_in_id, client: Ai::Client.default)
    check_in = CheckIn.find(check_in_id)
    return if check_in.screen.present?

    e = check_in.enrolment
    pseudonymizer = Ai::Pseudonymizer.new(e.patient.identity)
    facts = {
      "message" => pseudonymizer.call(check_in.message).text,
      "pain_score" => check_in.pain_score,
      "already_flagged" => Array(check_in.red_flags).map { |f| f["code"] }
    }
    outcome = Ai::Workflows::CheckInScreen.new(client: client).call(facts, guard: pseudonymizer)
    record(check_in, outcome)
  rescue Ai::Client::LeakRefused => err
    check_in.update!(screen: { "error" => err.message, "screened_at" => Time.current.iso8601 })
    AuditEvent.record!(action: "check_in.screen_leak_refused", subject: e, data: { check_in_id: check_in.id })
  end

  private

  def record(check_in, outcome)
    CheckIn.transaction do
      check_in.lock!
      flags = Array(check_in.red_flags) + outcome.added
      status = outcome.added.any? && check_in.status == "new" ? "escalated" : check_in.status
      check_in.update!(red_flags: flags, status: status, screen: {
        "model" => outcome.model, "prompt_version" => outcome.prompt_version, "added" => outcome.added.map { |f| f["code"] },
        "dropped" => outcome.dropped, "error" => outcome.error, "screened_at" => Time.current.iso8601
      }.compact)
    end
    AuditEvent.record!(action: outcome.added.any? ? "check_in.escalated_by_screen" : "check_in.screened", subject: check_in.enrolment,
                       data: { check_in_id: check_in.id, added: outcome.added.map { |f| f["code"] }, dropped: outcome.dropped.size,
                               model: outcome.model, error: outcome.error }.compact)
  end
end
