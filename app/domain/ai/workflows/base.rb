module Ai
  module Workflows
    Result = Data.define(:output, :findings, :model, :prompt_version, :trace) do
      def blocking?
        findings.any? { |f| f.severity == :blocking }
      end
    end

    class Base
      def initialize(client: Client.default)
        @client = client
      end

      private

      def messages(system, facts)
        [ { role: "system", content: system }, { role: "user", content: JSON.generate(facts) } ]
      end

      def schema_findings(output, keys)
        return [ Checks.blocking(:not_json, "The model did not return a JSON object.") ] unless output.is_a?(Hash)

        missing = Checks.missing_keys(output, keys)
        missing.any? ? [ Checks.blocking(:missing_fields, "Missing #{missing.join(', ')}.") ] : []
      end
    end
  end
end
