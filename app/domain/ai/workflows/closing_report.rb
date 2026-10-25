module Ai
  module Workflows
    # Drafts the closing documentation from the logged units. Every number and date in the draft
    # must be one the facts contain: an invented outcome in a document sent to the DRV is blocking.
    class ClosingReport < Base
      PROMPT_VERSION = "closing-report/2"
      SYSTEM = <<~PROMPT
        You draft the closing documentation of a German digital rehabilitation aftercare programme
        (DRV) for a physician to check and sign. You receive the programme's facts as JSON.
        Return a JSON object with four German sections, each two to four sentences:
        "course" (Verlauf), "outcome" (Ergebnis), "adherence" (Mitwirkung),
        "recommendation" (Empfehlung).
        Use only numbers and dates that appear in the facts, written as they appear or as German
        dates (DD.MM.YYYY). Do not compute new figures. Do not give medication advice. Mention every
        red flag listed in "red_flags_seen". Refer to the patient only as "der/die Rehabilitand/in".
      PROMPT

      def call(facts, guard: nil)
        reply = @client.chat(task: "closing_report", messages: messages(SYSTEM, facts), guard: guard)
        out = reply.content
        findings = schema_findings(out, %w[course outcome adherence recommendation])
        if findings.empty?
          text = out.values_at("course", "outcome", "adherence", "recommendation").join(" ")
          stray = Checks.ungrounded_numbers(text, facts, allowed: %w[10])
          findings << Checks.blocking(:ungrounded_number, "Numbers or dates not in the facts: #{stray.join(', ')}.") if stray.any?
          if (dose = Checks.dosing_advice(text)).any?
            findings << Checks.blocking(:dosing_advice, "Medication advice (#{dose.first}).")
          end
          unmentioned = Array(facts["red_flags_seen"]).reject { |code| text.downcase.include?(flag_word(code)) }
          findings << Checks.warning(:flag_not_mentioned, "Red flags not mentioned: #{unmentioned.join(', ')}.") if unmentioned.any?
          if (ph = Checks.placeholders(text)).any?
            findings << Checks.blocking(:placeholder, "The draft contains placeholders: #{ph.join(', ')}.")
          end
        end
        Result.new(output: out, findings: findings, model: reply.model, prompt_version: PROMPT_VERSION, trace: [])
      end

      FLAG_WORDS = { "chest_pain" => "brust", "breathlessness" => "atem", "neurological" => "neurolog", "fall" => "sturz",
                     "wound_or_fever" => "fieber", "self_harm" => "suizid", "severe_pain" => "schmerz", "pain_jump" => "schmerz" }.freeze

      def flag_word(code)
        FLAG_WORDS.fetch(code, code.tr("_", " "))
      end
    end
  end
end
