module Ai
  # Finds red flags in a check-in by rule. Deterministic, explainable (each flag carries the words
  # that triggered it) and independent of any model.
  class RedFlags
    Flag = Data.define(:code, :severity, :evidence)

    def self.config
      @config ||= YAML.safe_load_file(Rails.root.join("config/ai/red_flags.yml"))
    end

    def self.reload!
      @config = nil
    end

    def self.find(message:, pain_score: nil, previous_pain_score: nil)
      new(config).find(message: message, pain_score: pain_score, previous_pain_score: previous_pain_score)
    end

    def initialize(config)
      @negations = config.fetch("negations").map(&:downcase)
      @window = config.fetch("negation_window")
      @flags = config.fetch("flags").to_h do |code, spec|
        [ code, { severity: spec.fetch("severity"), patterns: spec.fetch("patterns").map { |p| Regexp.new(p, Regexp::IGNORECASE) } } ]
      end
      @pain = config.fetch("pain")
    end

    def find(message:, pain_score: nil, previous_pain_score: nil)
      text = message.to_s
      out = @flags.filter_map do |code, spec|
        hit = spec[:patterns].lazy.flat_map { |re| matches(text, re) }.find { |m| !negated?(text, m) }
        Flag.new(code: code, severity: spec[:severity], evidence: hit[0]) if hit
      end
      if pain_score && pain_score >= @pain.fetch("severe_at")
        out << Flag.new(code: "severe_pain", severity: "urgent", evidence: "pain #{pain_score}/10")
      elsif pain_score && previous_pain_score && pain_score - previous_pain_score >= @pain.fetch("jump_of")
        out << Flag.new(code: "pain_jump", severity: "urgent", evidence: "pain #{previous_pain_score} → #{pain_score}")
      end
      out
    end

    private

    def matches(text, regexp)
      text.to_enum(:scan, regexp).map { Regexp.last_match }
    end

    CLAUSE_BREAK = /[.,;:!?\n]|\b(?:aber|doch|jedoch|sondern|und|but|and|however)\b/i

    # A negation counts only inside the same clause, a few words before the match:
    # "keine Brustschmerzen, aber Atemnot" negates the pain, not the breathlessness.
    def negated?(text, match)
      clause = text[0...match.begin(0)].split(CLAUSE_BREAK, -1).last.to_s
      clause.downcase.scan(/[[:alpha:]']+/).last(@window).any? { |w| @negations.include?(w) }
    end
  end
end
