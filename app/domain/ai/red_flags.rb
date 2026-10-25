module Ai
  # Finds red flags in a check-in by rule. Deterministic, explainable (each flag carries the words
  # that triggered it) and independent of any model.
  #
  # A pattern hit becomes a flag unless its own words say it is not happening to the patient now:
  #
  # - negated before it in the same clause ("keine Atemnot") or denied right after it
  #   ("Brustschmerzen? Nein.", "Fieber hatte ich keins");
  # - set aside by context in the same sentence (config `context`): someone else's event
  #   ("mein Mann ist gestürzt"), a past one ("2019 Herzinfarkt mit Brustschmerzen") unless the
  #   sentence also says it is happening again or now, fear of it ("Angst, dass ich stürze"),
  #   or a near miss ("fast hingefallen").
  #
  # A hit set aside by context is not dropped: it is returned in `set_aside` with the reason, and
  # the therapist sees it next to the check-in. Only negations and denials remove a hit entirely.
  class RedFlags
    Flag = Data.define(:code, :severity, :evidence)
    SetAside = Data.define(:code, :severity, :evidence, :reason)
    Screen = Data.define(:flags, :set_aside)

    def self.config
      @config ||= YAML.safe_load_file(Rails.root.join("config/ai/red_flags.yml"))
    end

    def self.reload!
      @config = nil
    end

    def self.find(...) = screen(...).flags

    def self.screen(message:, pain_score: nil, previous_pain_score: nil)
      new(config).screen(message: message, pain_score: pain_score, previous_pain_score: previous_pain_score)
    end

    def initialize(config)
      macros = config.fetch("macros", {}).merge("past_year" => past_years)
      # Ruby's \w is ASCII-only; the patients write "Hüfte", so word classes are made Unicode
      re = lambda do |p|
        expanded = p.gsub(/\{(\w+)\}/) { macros.fetch(Regexp.last_match(1), Regexp.last_match(0)) }
        Regexp.new(expanded.gsub("\\w", "\\p{Word}").gsub("\\W", "\\P{Word}"), Regexp::IGNORECASE)
      end
      @negations = config.fetch("negations").map(&:downcase)
      @window = config.fetch("negation_window")
      @denial_after = re.(config.fetch("denial_after"))
      @denial_question = re.(config.fetch("denial_question"))
      @flags = config.fetch("flags").to_h do |code, spec|
        [ code, { severity: spec.fetch("severity"), patterns: spec.fetch("patterns").map(&re) } ]
      end
      @context = config.fetch("context").to_h do |reason, spec|
        [ reason, { flags: spec["flags"], patterns: spec.fetch("patterns").map(&re), unless: Array(spec["unless"]).map(&re),
                    before_only: spec.fetch("before_only", false), first_person: spec["first_person"] && re.(spec["first_person"]),
                    across_and: spec.fetch("across_and", false), own_clause: Array(spec["own_clause"]).map(&re) } ]
      end
      @temperature = config.fetch("temperature")
      @pain = config.fetch("pain")
    end

    def screen(message:, pain_score: nil, previous_pain_score: nil)
      text = message.to_s
      flags = []
      set_aside = []
      @flags.each do |code, spec|
        hits = spec[:patterns].flat_map { |re| matches(text, re) }.sort_by { |m| m.begin(0) }
        hits = hits.reject { |m| negated?(text, m) || denied_after?(text, m) || (code == "wound_or_fever" && normal_temperature?(text, m)) }
        live = hits.find { |m| context_reason(text, m, code).nil? }
        if live
          flags << Flag.new(code: code, severity: spec[:severity], evidence: live[0])
        elsif (m = hits.first)
          set_aside << SetAside.new(code: code, severity: spec[:severity], evidence: sentence_of(text, m).strip, reason: context_reason(text, m, code))
        end
      end
      if flags.none? { |f| f.code == "wound_or_fever" } && (reading = fever_reading(text))
        set_aside.reject! { |s| s.code == "wound_or_fever" }
        flags << Flag.new(code: "wound_or_fever", severity: @flags.dig("wound_or_fever", :severity), evidence: reading)
      end
      flags.concat(pain_flags(pain_score, previous_pain_score))
      Screen.new(flags: flags, set_aside: set_aside)
    end

    private

    def past_years
      "(?:#{(1930...Date.current.year).to_a.reverse.join('|')})"
    end

    def matches(text, regexp)
      text.to_enum(:scan, regexp).map { Regexp.last_match }
    end

    CLAUSE_BREAK = /[.,;:!?\n]|\b(?:aber|doch|jedoch|sondern|und|but|and|however)\b/i
    SENTENCE_BREAK = /[.;!?\n]+(?=\s|\z)|\b(?:aber|doch|jedoch|sondern|und|but|and|however)\b/i
    CONTRAST_BREAK = /[.;!?\n]+(?=\s|\z)|\b(?:aber|doch|jedoch|sondern|but|however)\b/i
    AND = /\b(?:und|and|oder|or)\b/i

    # A negation counts only inside the same clause, a few words before the match:
    # "keine Brustschmerzen, aber Atemnot" negates the pain, not the breathlessness.
    def negated?(text, match)
      clause = text[0...match.begin(0)].split(CLAUSE_BREAK, -1).last.to_s
      clause.downcase.scan(/[[:alpha:]']+/).last(@window).any? { |w| @negations.include?(w) }
    end

    # "Brustschmerzen? Nein." / "Fieber hatte ich keins" / "chest pain - none": the words right
    # after the match deny it. The denial has to end its clause, so "Schmerzen, die nicht
    # weggehen" stays a hit.
    def denied_after?(text, match)
      rest = text[match.end(0)..].to_s
      return true if rest.match?(@denial_question)

      rest = rest.sub(/\A\s*[?:,–-]\s*/, " ")
      clause = rest.split(/[.,;!?\n]|\b(?:aber|doch|jedoch|sondern|but|however)\b/i, 2).first.to_s
      clause.match?(@denial_after)
    end

    def sentence_of(text, match)
      start = (text[0...match.begin(0)] =~ /[^.;!?\n]*\z/) || 0
      stop = text.index(/[.;!?\n]/, match.end(0)) || text.length
      text[start...stop]
    end

    # The context reason that sets this hit aside, or nil when the hit stands.
    def context_reason(text, match, code)
      before = text[0...match.begin(0)].split(SENTENCE_BREAK, -1).last.to_s
      after = text[match.end(0)..].to_s.split(SENTENCE_BREAK, 2).first.to_s
      sentence = "#{before}#{match[0]}#{after}"
      @context.each do |reason, spec|
        next if spec[:flags] && !spec[:flags].include?(code)
        next if spec[:unless].any? { |re| sentence.match?(re) }

        scope = spec[:before_only] ? before : "#{before} #{after}"
        if spec[:across_and]
          # "Angst, dass ich stürze und hinfalle": the fear covers both verbs, but not
          # "Angst zu stürzen und habe Brustschmerzen", where the hit has a clause of its own
          wide = text[0...match.begin(0)].split(CONTRAST_BREAK, -1).last.to_s
          own = "#{wide.split(AND, -1).last}#{match[0]}"
          scope = wide unless spec[:own_clause].any? { |re| own.match?(re) }
        end
        hit = spec[:patterns].lazy.filter_map { |re| scope.match(re) }.first
        next unless hit
        # "Meine Frau sagt, ich rede verwaschen": a first-person word between the other person
        # and the symptom makes it the patient's own.
        next if spec[:first_person] && spec[:before_only] && "#{before[hit.end(0)..]}#{match[0]}".match?(spec[:first_person])

        return reason
      end
      nil
    end

    TEMPERATURE = /(?<![\d.,])(3[5-9]|4[0-2])(?:[.,](\d))?\s*(°\s*C?|grad\b)?/i

    def temperatures(text)
      matches(text, TEMPERATURE).filter_map do |m|
        decimal = !m[2].nil?
        context = text[[ m.begin(0) - 40, 0 ].max...[ m.end(0) + 15, text.length ].min]
        next unless decimal || m[3] || context.match?(Regexp.new(@temperature.fetch("context"), Regexp::IGNORECASE))
        next if text[m.end(0)..].to_s.match?(/\A\s*(jahre|years|kg|min|minuten|minutes|cm|mal|times|wochen|weeks)/i)

        [ "#{m[1]}.#{m[2] || 0}".to_f, m[0].strip ]
      end
    end

    # "Fieber gemessen: 37,4" is a normal reading, not a fever.
    def normal_temperature?(text, match)
      return false unless match[0].match?(/fieber|fever/i)

      readings = temperatures(sentence_of(text, match))
      readings.any? && readings.all? { |t, _| t < @temperature.fetch("fever_at") }
    end

    def fever_reading(text)
      reading = temperatures(text).find { |t, _| t >= @temperature.fetch("fever_at") }
      return unless reading

      m = text.match(Regexp.new(Regexp.escape(reading[1])))
      return if m && context_reason(text, m, "wound_or_fever")

      reading[1]
    end

    def pain_flags(pain_score, previous_pain_score)
      if pain_score && pain_score >= @pain.fetch("severe_at")
        [ Flag.new(code: "severe_pain", severity: "urgent", evidence: "pain #{pain_score}/10") ]
      elsif pain_score && previous_pain_score && pain_score - previous_pain_score >= @pain.fetch("jump_of")
        [ Flag.new(code: "pain_jump", severity: "urgent", evidence: "pain #{previous_pain_score} → #{pain_score}") ]
      else
        []
      end
    end
  end
end
