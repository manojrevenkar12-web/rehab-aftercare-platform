require "net/http"

module Ai
  module Providers
    # Chat completions over HTTP against any OpenAI-compatible endpoint (an EU-hosted model, a
    # gateway, vLLM). No SDK: one request shape, explicit timeouts, retries only on errors that
    # are safe to retry.
    class OpenAiCompatible
      class Error < StandardError; end

      RETRYABLE = [408, 409, 429, 500, 502, 503, 504].freeze

      attr_reader :model

      def initialize(base_url:, model:, api_key:, timeout: 60, retries: 2)
        @uri = URI.join(base_url.end_with?("/") ? base_url : "#{base_url}/", "chat/completions")
        @model = model
        @api_key = api_key
        @timeout = timeout
        @retries = retries
      end

      def chat(task:, messages:, tools: [])
        body = { model: @model, messages: messages, temperature: 0 }
        body[:tools] = tools if tools.any?
        body[:response_format] = { type: "json_object" } if tools.empty?
        attempt = 0
        loop do
          attempt += 1
          begin
            res = post(body)
          rescue Net::OpenTimeout, Net::ReadTimeout => e
            raise Error, "timed out: #{e.message}" if attempt > @retries

            backoff(attempt)
            next
          end
          if RETRYABLE.include?(res.code.to_i) && attempt <= @retries
            backoff(attempt)
            next
          end
          raise Error, "HTTP #{res.code}: #{res.body.to_s[0, 200]}" unless res.is_a?(Net::HTTPSuccess)

          return parse(JSON.parse(res.body))
        end
      end

      private

      def backoff(attempt)
        sleep(0.5 * (2**attempt))
      end

      def post(body)
        Net::HTTP.start(@uri.host, @uri.port, use_ssl: @uri.scheme == "https", open_timeout: 10, read_timeout: @timeout) do |http|
          req = Net::HTTP::Post.new(@uri, "Content-Type" => "application/json", "Authorization" => "Bearer #{@api_key}")
          req.body = JSON.generate(body)
          http.request(req)
        end
      end

      def parse(doc)
        msg = doc.dig("choices", 0, "message") || raise(Error, "no message in response")
        calls = Array(msg["tool_calls"]).map do |c|
          { id: c["id"], name: c.dig("function", "name"), arguments: JSON.parse(c.dig("function", "arguments").presence || "{}") }
        end
        content = msg["content"].present? ? JSON.parse(msg["content"]) : nil
        Client::Reply.new(content: content, tool_calls: calls, model: doc["model"] || @model)
      rescue JSON::ParserError => e
        raise Error, "the model did not return JSON: #{e.message[0, 120]}"
      end
    end
  end
end
