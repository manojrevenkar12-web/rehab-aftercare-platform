module Ai
  # Replaces a patient's identity in free text with placeholders before anything is sent to a
  # model, and puts it back in the model's answer. Health content stays (the model needs it);
  # who the patient is does not leave.
  #
  # It knows the patient's own identity (name parts, birth date in common German and ISO formats,
  # insurance number with or without spaces, phone, email) and also catches the shapes of
  # identifiers it was not told about: other e-mail addresses, phone numbers, insurance numbers.
  # `leaks` is the last check before a request leaves: it looks for any identity value in the
  # serialised request and the request is refused if it finds one.
  class Pseudonymizer
    Result = Data.define(:text, :mapping)

    EMAIL = /[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}/
    PHONE = /(?<!\w)(?:\+49|0049|0)[\s\/.-]?(?:\(?\d{2,5}\)?[\s\/.-]?)\d{3,}(?:[\s.-]?\d{2,})*/
    # Rentenversicherungsnummer: area (2 digits), birth date (6), initial (letter), serial (2), check (1)
    RVNR = /\b\d{2}\s?\d{6}\s?[A-Z]\s?\d{2}\s?\d\b/
    MIN_NAME_PART = 3

    def initialize(identity)
      @identity = identity.compact
    end

    def call(text)
      return Result.new(text: text, mapping: {}) if text.blank?

      mapping = {}
      out = text.dup
      # Structured identifiers first (an e-mail address contains the name), then names.
      ordered = replacements.reject { |k, _| k.start_with?("[NAME") }.to_a +
                [ [ "[E-MAIL]", [ EMAIL ] ], [ "[INSURANCE-NO]", [ RVNR ] ], [ "[PHONE]", [ PHONE ] ] ] +
                replacements.select { |k, _| k.start_with?("[NAME") }.to_a
      ordered.each do |placeholder, patterns|
        patterns.each do |re|
          out = out.gsub(re) do |hit|
            mapping[placeholder] ||= hit
            placeholder
          end
        end
      end
      Result.new(text: out, mapping: mapping)
    end

    # Puts identity back into a model's answer; placeholders the model invented stay visible.
    def restore(text, mapping = placeholder_values)
      mapping.reduce(text.to_s) { |acc, (placeholder, value)| acc.gsub(placeholder, value.to_s) }
    end

    # What each placeholder stands for, from the identity itself: drafts are stored pseudonymised
    # and restored only when an authorised person reads them.
    def placeholder_values
      out = {}
      out["[NAME]"] = @identity[:full_name] if @identity[:full_name]
      name_parts.each_with_index { |part, i| out["[NAME-#{i + 1}]"] = part }
      out["[BIRTH-DATE]"] = @identity[:birth_date].strftime("%d.%m.%Y") if @identity[:birth_date]
      out["[INSURANCE-NO]"] = @identity[:insurance_number] if @identity[:insurance_number]
      out["[E-MAIL]"] = @identity[:email] if @identity[:email]
      out["[PHONE]"] = @identity[:phone] if @identity[:phone]
      out
    end

    # Identity values present in a serialised request. Anything here means the request must not
    # be sent.
    def leaks(serialised)
      haystack = normalise(serialised)
      needles.select { |label, value| haystack.include?(normalise(value)) }.keys
    end

    private

    def replacements
      @replacements ||= begin
        out = {}
        out["[NAME]"] = [ word(@identity[:full_name]) ] if @identity[:full_name]
        name_parts.each_with_index { |part, i| out["[NAME-#{i + 1}]"] = [ word(part) ] }
        out["[BIRTH-DATE]"] = date_patterns(@identity[:birth_date]) if @identity[:birth_date]
        out["[INSURANCE-NO]"] = [ spaced(@identity[:insurance_number]) ] if @identity[:insurance_number]
        out["[E-MAIL]"] = [ Regexp.new(Regexp.escape(@identity[:email]), Regexp::IGNORECASE) ] if @identity[:email]
        out["[PHONE]"] = [ digits_pattern(@identity[:phone]) ] if @identity[:phone]
        out
      end
    end

    def name_parts
      @identity[:full_name].to_s.split(/[\s-]+/).select { |p| p.length >= MIN_NAME_PART }
    end

    def needles
      out = {}
      name_parts.each_with_index { |p, i| out["name_part_#{i}"] = p }
      if (b = @identity[:birth_date])
        out["birth_date"] = b.strftime("%d.%m.%Y")
        out["birth_date_short"] = b.strftime("%-d.%-m.%Y")
      end
      out["insurance_number"] = @identity[:insurance_number] if @identity[:insurance_number]
      out["email"] = @identity[:email] if @identity[:email]
      out["phone"] = @identity[:phone].gsub(/\D/, "") if @identity[:phone]
      out
    end

    def normalise(value)
      value.to_s.downcase.gsub(/[\s.\/()-]/, "").gsub("ä", "ae").gsub("ö", "oe").gsub("ü", "ue").gsub("ß", "ss")
    end

    # "Wöhrle" is also written "Woehrle" or "Wohrle", and "Strauß" "Strauss"; either way round.
    SPELLINGS = { "ä" => "(?:ä|ae|a)", "ö" => "(?:ö|oe|o)", "ü" => "(?:ü|ue|u)", "ß" => "(?:ß|ss)",
                  "ae" => "(?:ae|ä)", "oe" => "(?:oe|ö)", "ue" => "(?:ue|ü)", "ss" => "(?:ss|ß)" }.freeze

    def word(value)
      body = value.downcase.scan(/ae|oe|ue|ss|./m).map { |c| SPELLINGS[c] || Regexp.escape(c) }.join
      Regexp.new("(?<![[:alpha:]])#{body}(?:s|'s|’s)?(?![[:alpha:]])", Regexp::IGNORECASE)
    end

    def spaced(value)
      Regexp.new(value.gsub(/\s/, "").chars.map { |c| Regexp.escape(c) }.join("\\s?"), Regexp::IGNORECASE)
    end

    def digits_pattern(phone)
      digits = phone.gsub(/\D/, "").sub(/\A(?:49|0049)/, "").sub(/\A0/, "")
      Regexp.new("(?:\\+49|0049|0)?[\\s/().-]*" + digits.chars.join("[\\s/().-]*"))
    end

    # 7.2.1959, 07.02.59, 7-2-1959, 7/2/59, 1959-02-07, 7. Februar 1959, 7. Feb. '59,
    # February 7th, 1959
    def date_patterns(date)
      d, m, yy = date.day, date.month, format("%02d", date.year % 100)
      year = "'?(?:#{date.year}|#{yy})"
      day = "0?#{d}"
      month = "(?:#{month_names(m).map { |n| Regexp.escape(n) }.join('|')})"
      [
        Regexp.new("(?<!\\d)#{day}\\s?([./-])\\s?0?#{m}\\s?\\1\\s?#{year}(?!\\d)"),
        Regexp.new("(?<!\\d)#{date.year}-0?#{m}-#{day}(?!\\d)"),
        Regexp.new("(?<!\\d)#{day}(?:\\.|st|nd|rd|th)?\\s*(?:of\\s+)?#{month}\\.?,?\\s*#{year}(?!\\d)", Regexp::IGNORECASE),
        Regexp.new("#{month}\\.?\\s+#{day}(?:st|nd|rd|th)?,?\\s+#{year}(?!\\d)", Regexp::IGNORECASE)
      ]
    end

    def month_names(m)
      de = %w[Januar Februar März April Mai Juni Juli August September Oktober November Dezember]
      en = Date::MONTHNAMES.compact
      short = [ de[m - 1][0, 3], en[m - 1][0, 3], (m == 3 ? "Mrz" : nil), (m == 9 ? "Sept" : nil), (m == 2 ? "Febr" : nil) ]
      ([ de[m - 1], en[m - 1], de[m - 1].sub("ä", "ae") ] + short).compact.uniq.sort_by { |n| -n.length }
    end
  end
end
