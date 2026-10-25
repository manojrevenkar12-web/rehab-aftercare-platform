module Care
  # Records a patient's check-in and runs the red-flag rules on it straight away. A check-in with
  # a red flag is escalated: it goes to the top of the therapist's list whatever happens next.
  class CheckInIntake
    def self.call(enrolment:, message:, pain_score:, actor:, at: Time.current)
      previous = enrolment.check_ins.order(:submitted_at).last
      flags = Ai::RedFlags.find(message: message, pain_score: pain_score, previous_pain_score: previous&.pain_score)
      check_in = enrolment.check_ins.create!(
        message: message, pain_score: pain_score, submitted_at: at,
        red_flags: flags.map { |f| { "code" => f.code, "severity" => f.severity, "evidence" => f.evidence } },
        status: flags.any? ? "escalated" : "new"
      )
      AuditEvent.record!(actor: actor, action: flags.any? ? "check_in.escalated" : "check_in.received", subject: enrolment,
                         data: { check_in_id: check_in.id, flags: flags.map(&:code) })
      check_in
    end
  end
end
