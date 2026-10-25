module Ai
  module Workflows
    # An agent that proposes up to three changes to a patient's training plan. It may look things
    # up with tools; it cannot change anything. Code checks every proposal against the plan rules,
    # and a therapist's approval is what applies it.
    class PlanChange < Base
      PROMPT_VERSION = "plan-change/2"
      MAX_TURNS = 6
      SYSTEM = <<~PROMPT
        You help a physiotherapist adjust a patient's home training plan in rehabilitation aftercare.
        You receive the current plan, the patient's context tags and recent training units. Use the
        tools to look at exercises and their contraindications. When done, answer with JSON:
        {"changes": [{"action": "add|remove|modify", "exercise_key": "...", "sets": n, "reps": n,
        "per_week": n, "reason": "..."}], "rationale": "..."}. At most three changes; progress at
        most one level above the plan's highest; never propose an exercise contraindicated for any
        context tag; when pain is rising, reduce load rather than add exercises.
      PROMPT
      TOOLS = [
        { type: "function", function: { name: "search_exercises", description: "Exercises by body region up to a level",
                                         parameters: { type: "object", properties: { body_region: { type: "string" }, max_level: { type: "integer" } }, required: %w[body_region] } } },
        { type: "function", function: { name: "check_contraindications", description: "Which of the patient's context tags rule an exercise out",
                                         parameters: { type: "object", properties: { exercise_key: { type: "string" } }, required: %w[exercise_key] } } }
      ].freeze

      # library: exercise_key => {"name", "body_region", "level", "contraindications"}
      def call(facts, library:, guard: nil)
        msgs = messages(SYSTEM, facts)
        trace = []
        reply = nil
        MAX_TURNS.times do
          reply = @client.chat(task: "plan_change", messages: msgs, tools: TOOLS, guard: guard)
          break if reply.tool_calls.empty?

          msgs << { role: "assistant", content: nil, tool_calls: reply.tool_calls.map { |c| tool_call_message(c) } }
          reply.tool_calls.each do |call|
            result = run_tool(call, facts, library)
            trace << { "tool" => call[:name], "arguments" => call[:arguments], "result_size" => Array(result).size }
            msgs << { role: "tool", tool_call_id: call[:id], content: JSON.generate(result) }
          end
          reply = nil
        end
        if reply.nil?
          return Result.new(output: {}, findings: [ Checks.blocking(:no_answer, "No answer after #{MAX_TURNS} turns.") ],
                            model: @client.model, prompt_version: PROMPT_VERSION, trace: trace)
        end

        out = reply.content
        findings = schema_findings(out, %w[rationale])
        findings << Checks.blocking(:missing_fields, "No changes list.") unless out.is_a?(Hash) && out["changes"].is_a?(Array)
        if findings.empty?
          findings += PlanRules.check(out["changes"], plan: facts["plan"], context: facts["context"], library: library)
        end
        Result.new(output: out, findings: findings, model: reply.model, prompt_version: PROMPT_VERSION, trace: trace)
      end

      private

      def tool_call_message(call)
        { id: call[:id], type: "function", function: { name: call[:name], arguments: JSON.generate(call[:arguments]) } }
      end

      def run_tool(call, facts, library)
        args = call[:arguments] || {}
        case call[:name]
        when "search_exercises"
          max = args["max_level"] || 5
          library.select { |_, e| e["body_region"] == args["body_region"] && e["level"] <= max }
                 .map { |k, e| { "exercise_key" => k, "name" => e["name"], "level" => e["level"] } }
        when "check_contraindications"
          ex = library[args["exercise_key"]]
          ex ? { "exercise_key" => args["exercise_key"], "ruled_out_by" => Array(ex["contraindications"]) & facts["context"] } : { "error" => "unknown exercise" }
        else
          { "error" => "unknown tool #{call[:name]}" }
        end
      end
    end
  end
end
