module Ai
  # The one way the application talks to a model. Every request is checked for patient identity
  # before it leaves; a request that would leak is refused, not sent. Every request, sent or
  # refused, is recorded in the call ledger as numbers (Ai::CallLog), never as text.
  class Client
    class LeakRefused < StandardError; end

    # usage: { input_tokens:, output_tokens: } when the provider reports it, else nil
    Reply = Data.define(:content, :tool_calls, :model, :usage) do
      def initialize(content:, tool_calls:, model:, usage: nil)
        super
      end
    end

    attr_reader :provider

    def self.default
      new(provider: Providers.from_env)
    end

    # log: where calls are recorded; nil turns recording off (the offline evaluation does this,
    # so thousands of replayed cases do not show up as clinic traffic).
    def initialize(provider:, log: CallLog)
      @provider = provider
      @log = log
    end

    # messages: [{role:, content:}] in the OpenAI chat format; tools: function specs.
    def chat(task:, messages:, tools: [], guard: nil, prompt_version: nil)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      if guard
        found = guard.leaks(JSON.generate(messages))
        if found.any?
          record(task, prompt_version, "refused", started, messages)
          raise LeakRefused, "request for #{task} contains patient identity (#{found.join(', ')}); not sent"
        end
      end
      begin
        reply = provider.chat(task: task, messages: messages, tools: tools)
      rescue StandardError
        record(task, prompt_version, "error", started, messages)
        raise
      end
      record(task, prompt_version, "ok", started, messages, reply)
      reply
    end

    def model
      provider.model
    end

    private

    def record(task, prompt_version, outcome, started, messages, reply = nil)
      return unless @log

      latency = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      @log.record(task: task, prompt_version: prompt_version, model: reply&.model || safe_model,
                  provider: provider_name, outcome: outcome, latency_ms: latency, messages: messages, reply: reply)
    end

    def safe_model
      provider.model
    rescue StandardError
      "unknown"
    end

    def provider_name
      provider.class.name.to_s.demodulize.underscore.presence || "unknown"
    end
  end
end
