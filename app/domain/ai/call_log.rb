module Ai
  # Writes one AiCall per model request. It records numbers only: the messages and the reply are
  # health data and never reach the ledger or the log. Tokens come from the provider's usage when
  # it reports them; otherwise they are estimated at four characters per token and marked so.
  # A failure to record is logged and swallowed: losing a ledger row must never fail a draft.
  module CallLog
    module_function

    def record(task:, prompt_version:, model:, provider:, outcome:, latency_ms:, messages:, reply: nil)
      usage = reply&.usage
      input, output, estimated =
        if usage
          [ usage.fetch(:input_tokens).to_i, usage.fetch(:output_tokens).to_i, false ]
        else
          [ estimate(messages), reply ? estimate(reply.content) + estimate(reply.tool_calls) : 0, true ]
        end
      AiCall.create!(clinic_id: CallContext.clinic_id, task: task, prompt_version: prompt_version, model: model.to_s,
                     provider: provider, outcome: outcome, latency_ms: latency_ms, input_tokens: input,
                     output_tokens: output, tokens_estimated: estimated,
                     cost_microeuros: Costs.microeuros(model, input_tokens: input, output_tokens: output),
                     created_at: Time.current)
    rescue StandardError => e
      Rails.logger.warn("ai call not recorded for #{task}: #{e.class}")
      nil
    end

    def estimate(value)
      return 0 if value.blank?

      text = value.is_a?(String) ? value : JSON.generate(value)
      (text.length / 4.0).ceil
    end
  end
end
