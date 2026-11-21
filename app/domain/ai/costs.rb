module Ai
  # What a call cost, from config/ai/costs.yml. Kept in micro-euros (integer) so sums are exact.
  module Costs
    module_function

    def config
      @config ||= YAML.safe_load_file(Rails.root.join("config/ai/costs.yml"))
    end

    def rates(model)
      key = config.fetch("models").keys.select { |prefix| model.to_s.start_with?(prefix) }.max_by(&:length)
      key ? config.fetch("models").fetch(key) : config.fetch("default")
    end

    def priced?(model)
      config.fetch("models").keys.any? { |prefix| model.to_s.start_with?(prefix) }
    end

    # cents per million tokens = micro-euros per hundred tokens; round half up at the end only
    def microeuros(model, input_tokens:, output_tokens:)
      r = rates(model)
      ((input_tokens * r.fetch("input_cents_per_million")) + (output_tokens * r.fetch("output_cents_per_million")) + 50) / 100
    end
  end
end
