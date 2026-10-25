module Ai
  module Workflows
    # Drafts a therapist's reply to a patient's check-in, and a two-line summary for the therapist.
    # Red flags come from the rules, not the model; the model must acknowledge each, and the
    # escalation advice for an emergency flag is added by code, word for word.
    class CheckInReply < Base
      PROMPT_VERSION = "check-in-reply/3"
      SYSTEM = <<~PROMPT
        You draft replies for a physiotherapist in a German digital rehabilitation aftercare
        programme. You receive one patient check-in as JSON. Return a JSON object with:
        "summary" (for the therapist, at most two sentences),
        "reply" (to the patient, in the patient's language given in "language", warm and specific,
        at most 120 words),
        "acknowledged_flags" (the code of every entry in "red_flags", exactly as given),
        "questions" (up to two follow-up questions for the patient).
        Rules: never give medication or dosing advice; never diagnose; use only numbers that appear
        in the input; keep placeholders such as [NAME-1] exactly as written and never invent new
        ones; if "red_flags" is not empty, say in the reply that the care team will look at it today.
      PROMPT
      ESCALATION = {
        "de" => "Wichtig: Bei Brustschmerzen, Atemnot, Lähmungen oder Gedanken, sich etwas anzutun, rufen Sie bitte sofort den Notruf 112 an.",
        "en" => "Important: if you have chest pain, trouble breathing, weakness or numbness, or thoughts of harming yourself, call 112 immediately."
      }.freeze

      def call(facts, guard: nil, mapping: {})
        reply = @client.chat(task: "check_in_reply", messages: messages(SYSTEM, facts), guard: guard)
        out = reply.content
        findings = schema_findings(out, %w[summary reply])
        if findings.empty?
          flags = Array(facts["red_flags"]).map { |f| f["code"] }
          missing = flags - Array(out["acknowledged_flags"])
          findings << Checks.blocking(:flag_not_acknowledged, "The draft does not acknowledge #{missing.join(', ')}.") if missing.any?
          if (dose = Checks.dosing_advice(out["reply"])).any?
            findings << Checks.blocking(:dosing_advice, "The reply gives medication advice (#{dose.first}).")
          end
          invented = Checks.placeholders(out["reply"]) - mapping.keys.map { |k| k.delete("[]") }
          findings << Checks.blocking(:invented_placeholder, "The reply contains placeholders that stand for nothing: #{invented.join(', ')}.") if invented.any?
          stray = Checks.ungrounded_numbers("#{out['summary']} #{out['reply']}", facts, allowed: %w[10 112])
          findings << Checks.warning(:ungrounded_number, "Numbers not in the check-in: #{stray.join(', ')}.") if stray.any?
          if Array(facts["red_flags"]).any? { |f| f["severity"] == "emergency" }
            out = out.merge("reply" => "#{out['reply'].to_s.strip}\n\n#{ESCALATION.fetch(facts['language'], ESCALATION['de'])}")
          end
        end
        Result.new(output: out, findings: findings, model: reply.model, prompt_version: PROMPT_VERSION, trace: [])
      end
    end
  end
end
