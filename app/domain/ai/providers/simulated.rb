module Ai
  module Providers
    # A deterministic stand-in for a model, so tests and the evaluation run without a network or
    # a key and give the same answer every time. It writes plausible drafts from the facts it is
    # given, and can be told to make specific mistakes (`faults`), which is how the evaluation
    # proves that the checks catch them.
    class Simulated
      FAULTS = %i[drop_flag dosing invented_placeholder stray_number invent_number missing_section
                  unknown_exercise contraindicated level_jump too_many out_of_bounds no_answer].freeze

      attr_reader :model, :faults, :calls

      def initialize(faults: [])
        unknown = faults - FAULTS
        raise ArgumentError, "unknown faults #{unknown}" if unknown.any?

        @faults = faults
        @model = faults.empty? ? "simulated-1" : "simulated-1+#{faults.join('+')}"
        @calls = 0
      end

      def chat(task:, messages:, tools: [])
        @calls += 1
        facts = JSON.parse(messages.find { |m| m[:role] == "user" }[:content])
        case task
        when "check_in_reply" then reply(check_in(facts))
        when "closing_report" then reply(closing(facts))
        when "plan_change" then agent_step(facts, messages)
        else raise ArgumentError, "unknown task #{task}"
        end
      end

      private

      def reply(content, tool_calls: [])
        Client::Reply.new(content: content, tool_calls: tool_calls, model: @model)
      end

      def fault?(name)
        @faults.include?(name)
      end

      # --- check-in replies --------------------------------------------------------------------

      def check_in(f)
        de = f["language"] == "de"
        flags = Array(f["red_flags"]).map { |x| x["code"] }
        acknowledged = fault?(:drop_flag) ? flags.drop(1) : flags
        trend = f["previous_pain_score"] ? (de ? " (zuvor #{f['previous_pain_score']})" : " (previously #{f['previous_pain_score']})") : ""
        summary = de ? "Schmerz #{f['pain_score']}/10#{trend}; #{f['units_done']} von #{f['units_required']} Einheiten." : "Pain #{f['pain_score']}/10#{trend}; #{f['units_done']} of #{f['units_required']} units done."
        summary += de ? " Warnzeichen: #{flags.join(', ')}." : " Red flags: #{flags.join(', ')}." if flags.any?
        reply = if de
                  "Vielen Dank für Ihre Rückmeldung. Sie haben bereits #{f['units_done']} von #{f['units_required']} Einheiten geschafft."
        else
                  "Thank you for your update. You have already completed #{f['units_done']} of #{f['units_required']} units."
        end
        reply += de ? " Ihr Behandlungsteam schaut sich Ihre Angaben heute noch an." : " Your care team will look at this today." if flags.any?
        reply += de ? " Machen Sie die Übungen nur so weit, wie es sich gut anfühlt." : " Only do the exercises as far as they feel comfortable."
        reply += " Nehmen Sie bei Bedarf 400 mg Ibuprofen." if fault?(:dosing)
        reply += " Liebe Grüße an [NAME-3]." if fault?(:invented_placeholder)
        reply += de ? " Sie liegen 85 % über dem Durchschnitt." : " You are 85% above average." if fault?(:stray_number)
        { "summary" => summary, "reply" => reply, "acknowledged_flags" => acknowledged,
          "questions" => [ de ? "Wann treten die Beschwerden auf?" : "When do the symptoms occur?" ] }
      end

      # --- closing documentation ---------------------------------------------------------------

      FLAG_PHRASES = { "chest_pain" => "Brustschmerzen", "breathlessness" => "Atemnot", "neurological" => "neurologische Symptome",
                       "fall" => "ein Sturz", "wound_or_fever" => "Fieber", "self_harm" => "suizidale Gedanken",
                       "severe_pain" => "starke Schmerzen", "pain_jump" => "ein Schmerzanstieg" }.freeze

      def de_date(iso)
        iso && Date.iso8601(iso).strftime("%d.%m.%Y")
      end

      def de_num(n)
        n.to_s.tr(".", ",")
      end

      def closing(f)
        units_done = fault?(:invent_number) ? f["units_done"].to_i + 2 : f["units_done"]
        course = "Die Nachsorge (#{f['programme']}) begann am #{de_date(f['first_unit'])} und endete am #{de_date(f['last_unit'])}. " \
                 "In #{f['weeks']} Wochen absolvierte der/die Rehabilitand/in #{units_done} von #{f['units_required']} Einheiten."
        outcome = if f["pain_start"] && f["pain_end"]
                    "Der Schmerz lag zu Beginn im Mittel bei #{de_num(f['pain_start'])} und am Ende bei #{de_num(f['pain_end'])} von 10."
        else
                    "Schmerzwerte wurden nicht durchgehend erfasst."
        end
        outcome += " Die Belastbarkeit stieg um 45 %." if fault?(:stray_number)
        adherence = "Im Mittel #{de_num(f['units_per_week'])} Einheiten pro Woche"
        adherence += f["effort_mean"] ? ", mittlere Anstrengung #{de_num(f['effort_mean'])} von 10." : "."
        flags = Array(f["red_flags_seen"]).map { |c| FLAG_PHRASES.fetch(c, c) }
        recommendation = "Fortführung des Heimtrainings in eigener Verantwortung."
        recommendation = "Im Verlauf wurden #{flags.join(' und ')} gemeldet und ärztlich abgeklärt. " + recommendation if flags.any?
        recommendation += " Bei Schmerzen 500 mg Paracetamol." if fault?(:dosing)
        out = { "course" => course, "outcome" => outcome, "adherence" => adherence, "recommendation" => recommendation }
        out.delete("recommendation") if fault?(:missing_section)
        out
      end

      # --- plan-change agent -------------------------------------------------------------------

      def agent_step(f, messages)
        return reply(nil, tool_calls: [ call("search_exercises", { "body_region" => "lumbar", "max_level" => 1 }) ]) if fault?(:no_answer)

        tool_results = messages.select { |m| m[:role] == "tool" }.map { |m| JSON.parse(m[:content]) }
        plan = f["plan"]
        region = plan.first&.dig("body_region") || "lumbar"
        max_level = plan.map { |p| p["level"] }.max || 1
        case tool_results.size
        when 0
          level = fault?(:level_jump) ? max_level + 3 : max_level + 1
          reply(nil, tool_calls: [ call("search_exercises", { "body_region" => region, "max_level" => level }) ])
        when 1
          candidates = Array(tool_results.first).reject { |c| plan.any? { |p| p["exercise_key"] == c["exercise_key"] } }
          @candidates = candidates
          return reply(nil, tool_calls: [ call("check_contraindications", { "exercise_key" => "none" }) ]) if candidates.empty?

          reply(nil, tool_calls: candidates.max_by(3) { |c| c["level"] }.map { |c| call("check_contraindications", { "exercise_key" => c["exercise_key"] }) })
        else
          reply(final_plan(f, tool_results.drop(1)))
        end
      end

      def final_plan(f, checks)
        plan = f["plan"]
        units = f["recent_units"]
        rising = units.size >= 2 && units.last["pain_after"].to_i > units.first["pain_before"].to_i
        levels = Array(@candidates).to_h { |c| [ c["exercise_key"], c["level"] ] }
        safe = checks.select { |c| c.is_a?(Hash) && c["ruled_out_by"] == [] }.map { |c| c["exercise_key"] }
                     .sort_by { |k| [ -levels.fetch(k, 0), k ] }
        unsafe = checks.select { |c| c.is_a?(Hash) && Array(c["ruled_out_by"]).any? }.map { |c| c["exercise_key"] }
        changes = []
        if rising && plan.any?
          top = plan.max_by { |p| p["level"] }
          changes << { "action" => "modify", "exercise_key" => top["exercise_key"], "sets" => top["sets"],
                       "reps" => [ top["reps"] - 4, 4 ].max, "per_week" => top["per_week"], "reason" => "Pain rose over the last units; reduce load." }
        else
          key = fault?(:contraindicated) ? (unsafe.first || safe.first) : safe.first
          key = "ex_does_not_exist" if fault?(:unknown_exercise)
          changes << { "action" => "add", "exercise_key" => key, "sets" => 2, "reps" => 10, "per_week" => 3, "reason" => "Steady progress; add one exercise one level up." } if key
        end
        changes.first["sets"] = 9 if fault?(:out_of_bounds) && changes.any?
        changes += Array.new(3) { changes.first || { "action" => "modify", "exercise_key" => plan.first["exercise_key"], "sets" => 2, "reps" => 8, "per_week" => 3, "reason" => "keep" } } if fault?(:too_many)
        { "changes" => changes, "rationale" => rising ? "Pain is rising, so the plan gets lighter." : "Progress is steady, so one exercise is added." }
      end

      def call(name, arguments)
        { id: "call_#{@calls}_#{name}_#{arguments.values.join('_')}", name: name, arguments: arguments }
      end
    end
  end
end
