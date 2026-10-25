module Ai
  module Workflows
    # A model reads a check-in after the rules and may add red flags the rules missed. It cannot
    # remove one: the result is the rules' flags plus the model's accepted ones. A model flag is
    # accepted only when its code is known and its quote is the patient's own words, found in the
    # (pseudonymised) message; anything else is dropped and recorded as dropped.
    class CheckInScreen < Base
      PROMPT_VERSION = "check-in-screen/1"

      Outcome = Data.define(:added, :dropped, :model, :prompt_version, :error)

      def self.config
        @config ||= YAML.safe_load_file(Rails.root.join("config/ai/screen.yml"))
      end

      def self.reload! = @config = nil

      def self.enabled? = config.fetch("enabled")

      def system_prompt
        table = self.class.config.fetch("flags").map { |code, spec| "- #{code}: #{spec.fetch('means')}" }.join("\n")
        <<~PROMPT
          You screen messages that patients in German rehabilitation aftercare send to their
          therapist. Some red flags have already been found by keyword rules and are listed in
          "already_flagged". Your job is to find red flags the rules missed. The flags are:
          #{table}
          Read the message as a careful clinician would: dialect, typos, indirect descriptions and
          messages written by a relative count; denials, fears, other people's events, past events
          that are over, near misses and figures of speech do not.
          Return a JSON object {"flags": [{"code": "...", "quote": "..."}]} with one entry per
          flag you find that is not in "already_flagged". "quote" must be copied exactly from the
          message: the words that show the flag. Return {"flags": []} if there is nothing to add.
        PROMPT
      end

      def call(facts, guard: nil)
        reply = @client.chat(task: "check_in_screen", messages: messages(system_prompt, facts), guard: guard)
        judge(reply.content, facts, model: reply.model)
      rescue Client::LeakRefused
        raise
      rescue StandardError => e
        Outcome.new(added: [], dropped: [], model: @client.model, prompt_version: PROMPT_VERSION, error: "#{e.class}: #{e.message}")
      end

      private

      def judge(content, facts, model:)
        cfg = self.class.config
        known = cfg.fetch("flags")
        already = Array(facts["already_flagged"])
        proposed = content.is_a?(Hash) ? Array(content["flags"]).first(cfg.fetch("max_flags")) : []
        added = []
        dropped = []
        proposed.each do |f|
          code = f.is_a?(Hash) ? f["code"].to_s : ""
          quote = f.is_a?(Hash) ? f["quote"].to_s.strip : ""
          next if already.include?(code) || added.any? { |a| a["code"] == code } # nothing to add

          reason = if !known.key?(code) then "unknown flag"
          elsif quote.length < cfg.fetch("min_quote_chars") || !quoted?(facts["message"], quote) then "quote not in the message"
          end
          if reason
            dropped << { "code" => code, "quote" => quote, "reason" => reason }
          else
            added << { "code" => code, "severity" => known.dig(code, "severity"), "evidence" => quote, "source" => "model" }
          end
        end
        error = content.is_a?(Hash) ? nil : "the model did not return a JSON object"
        Outcome.new(added: added, dropped: dropped, model: model, prompt_version: PROMPT_VERSION, error: error)
      end

      def quoted?(message, quote)
        squash = ->(s) { s.to_s.downcase.gsub(/[[:space:]]+/, " ").strip }
        squash.(message).include?(squash.(quote))
      end
    end
  end
end
