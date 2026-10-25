module Ai
  # Checks run on every model output before a person sees it. A blocking finding holds the draft:
  # it is shown with the finding, cannot be approved as it is, and is counted in the evaluation.
  module Checks
    Finding = Data.define(:code, :severity, :message) do
      def to_h
        { "code" => code.to_s, "severity" => severity.to_s, "message" => message }
      end
    end

    module_function

    def blocking(code, message)
      Finding.new(code: code, severity: :blocking, message: message)
    end

    def warning(code, message)
      Finding.new(code: code, severity: :warning, message: message)
    end

    NUMBER = /\b\d{4}-\d{2}-\d{2}\b|\b\d{1,2}\.\d{1,2}\.\d{2,4}\b|(?<![\w.,])\d{1,4}(?:[.,]\d+)?(?:\s?%)?(?![\w])/

    # Every number or date in `text` must be one the facts contain (in any of its usual forms).
    # Free-standing small counts in `allowed` (e.g. the 0-10 pain scale's "10") are always fine.
    def ungrounded_numbers(text, facts, allowed: [])
      known = number_forms(facts) | allowed.map(&:to_s)
      text.to_s.scan(NUMBER).map(&:strip).reject { |n| known.include?(normalise(n)) }.uniq
    end

    def number_forms(value, out = Set.new)
      case value
      when Hash then value.each_value { |v| number_forms(v, out) }
      when Array then value.each { |v| number_forms(v, out) }
      when Integer then out << value.to_s << value.abs.to_s
      when Float
        [value, value.abs].each do |v|
          out << v.round(1).to_s << v.round.to_s << format("%.1f", v) << v.to_s << v.round(1).to_s.sub(/\.0\z/, "")
        end
      when String
        if value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
          d = Date.iso8601(value)
          out << value << d.strftime("%d.%m.%Y") << d.strftime("%-d.%-m.%Y") << d.strftime("%d.%m.%y")
        elsif value.match?(/\A-?\d+(\.\d+)?\z/)
          out << value
        end
      end
      out.to_a.map { |v| normalise(v) }.to_set
    end

    def normalise(n)
      n.to_s.delete(" %").tr(",", ".").sub(/\.0\z/, "")
    end

    # Medication and dosing advice is a physician's call, not a drafted message's.
    DOSING = /\b\d+\s?(mg|milligramm|ml|tabletten?|tablets?|tropfen|drops)\b|\b(ibuprofen|paracetamol|diclofenac|novalgin|metamizol|tramadol|aspirin)\b/i

    def dosing_advice(text)
      text.to_s.scan(DOSING).any? ? [text.to_s[DOSING]] : []
    end

    PLACEHOLDER = /\[(NAME(?:-\d+)?|BIRTH-DATE|INSURANCE-NO|E-MAIL|PHONE)\]/

    def placeholders(text)
      text.to_s.scan(PLACEHOLDER).flatten.uniq
    end

    def missing_keys(hash, keys)
      keys.map(&:to_s).reject { |k| hash.is_a?(Hash) && hash[k].to_s.strip.present? }
    end
  end
end
