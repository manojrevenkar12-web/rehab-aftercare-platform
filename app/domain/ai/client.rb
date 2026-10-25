module Ai
  # The one way the application talks to a model. Every request is checked for patient identity
  # before it leaves; a request that would leak is refused, not sent.
  class Client
    class LeakRefused < StandardError; end

    Reply = Data.define(:content, :tool_calls, :model)

    attr_reader :provider

    def self.default
      new(provider: Providers.from_env)
    end

    def initialize(provider:)
      @provider = provider
    end

    # messages: [{role:, content:}] in the OpenAI chat format; tools: function specs.
    def chat(task:, messages:, tools: [], guard: nil)
      if guard
        found = guard.leaks(JSON.generate(messages))
        raise LeakRefused, "request for #{task} contains patient identity (#{found.join(', ')}); not sent" if found.any?
      end
      provider.chat(task: task, messages: messages, tools: tools)
    end

    def model
      provider.model
    end
  end
end
