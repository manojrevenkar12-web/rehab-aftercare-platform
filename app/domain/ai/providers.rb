module Ai
  module Providers
    module_function

    # AI_PROVIDER=openai_compatible with AI_BASE_URL, AI_MODEL and AI_API_KEY uses a real
    # OpenAI-compatible endpoint (for health data: an EU-hosted one under a data-processing
    # agreement). Anything else uses the deterministic simulated model.
    def from_env(env = ENV)
      if env["AI_PROVIDER"] == "openai_compatible"
        OpenAiCompatible.new(base_url: env.fetch("AI_BASE_URL"), model: env.fetch("AI_MODEL"), api_key: env.fetch("AI_API_KEY"))
      else
        Simulated.new
      end
    end
  end
end
