module Evals
  # Runs the evaluation suites over a case folder and writes a report. Three suites:
  #
  # - red_flags: patient check-in messages labelled with the flags a clinician would expect;
  #   measures the rules' recall per severity and how often they escalate a harmless message.
  # - pseudonymization: texts that mention a patient's identity in written-out forms; measures
  #   how many mentions survive and whether clinical words are lost with them.
  # - drafts: the three AI workflows on varied facts, run on the faithful simulated model (no
  #   draft may be held) and with every injected mistake (every one must be held).
  class Runner
    SUITES = %w[red_flags pseudonymization drafts].freeze

    def initialize(dir)
      @dir = Pathname(dir)
    end

    def run(suites: SUITES)
      suites.to_h { |s| [ s, (@dir.join("#{s}.yml").exist? ? send(s, load(s)) : nil) ] }.compact
    end

    private

    def load(name) = YAML.safe_load_file(@dir.join("#{name}.yml"), permitted_classes: [ Date ]).fetch("cases")

    def red_flags(cases)
      severities = YAML.safe_load_file(Rails.root.join("config/ai/red_flags.yml")).fetch("flags").transform_values { |v| v["severity"] }
      severities.merge!("severe_pain" => "urgent", "pain_jump" => "urgent")
      rows = cases.map do |c|
        found = Ai::RedFlags.find(message: c.fetch("message"), pain_score: c["pain_score"], previous_pain_score: c["previous_pain_score"]).map(&:code)
        expected = Array(c["expected"])
        { "id" => c["id"], "expected" => expected, "found" => found, "missed" => expected - found, "extra" => found - expected }
      end
      by_severity = %w[emergency urgent].to_h do |sev|
        exp = rows.flat_map { |r| r["expected"].select { |f| severities[f] == sev }.map { |f| [ r, f ] } }
        hit = exp.count { |r, f| r["found"].include?(f) }
        [ sev, { "expected" => exp.size, "found" => hit, "recall" => ratio(hit, exp.size) } ]
      end
      clean = rows.select { |r| r["expected"].empty? }
      {
        "cases" => rows.size,
        "emergency_recall" => by_severity.dig("emergency", "recall"),
        "urgent_recall" => by_severity.dig("urgent", "recall"),
        "by_severity" => by_severity,
        "false_escalation_rate" => ratio(clean.count { |r| r["found"].any? }, clean.size),
        "wrong" => rows.select { |r| r["missed"].any? || r["extra"].any? }
      }
    end

    def pseudonymization(cases)
      mentions = 0
      leaked = []
      lost = []
      cases.each do |c|
        identity = c.fetch("identity").transform_keys(&:to_sym)
        identity[:birth_date] = Date.parse(identity[:birth_date].to_s) if identity[:birth_date]
        out = Ai::Pseudonymizer.new(identity).call(c.fetch("text")).text
        Array(c["mentions"]).each do |m|
          mentions += 1
          leaked << { "id" => c["id"], "mention" => m } if out.include?(m)
        end
        Array(c["keep"]).each { |w| lost << { "id" => c["id"], "word" => w } unless out.include?(w) }
      end
      { "cases" => cases.size, "mentions" => mentions, "leak_rate" => ratio(leaked.size, mentions), "leaked" => leaked,
        "clinical_words_lost" => lost.size, "lost" => lost }
    end

    FAULTS = {
      "check_in_reply" => %i[drop_flag dosing invented_placeholder],
      "closing_report" => %i[invent_number stray_number dosing missing_section],
      "plan_change" => %i[unknown_exercise level_jump too_many out_of_bounds no_answer contraindicated]
    }.freeze

    def drafts(cases)
      library = YAML.safe_load_file(Rails.root.join("config/aftercare/exercises.yml")).fetch("exercises").transform_values(&:stringify_keys)
      faithful = []
      faults = []
      cases.each do |c|
        kind = c.fetch("kind")
        facts = c.fetch("facts")
        r = run_draft(kind, facts, library, [])
        faithful << { "id" => c["id"], "held" => r.blocking?, "findings" => r.findings.map { |f| f.code.to_s } }
        FAULTS.fetch(kind).each do |fault|
          bad = run_draft(kind, facts, library, [ fault ])
          # a mistake that changed nothing in this case (e.g. an exercise swap when the agent only
          # reduces load) is not a test of the checks
          next if bad.output == r.output

          faults << { "id" => c["id"], "fault" => fault.to_s, "held" => bad.blocking?, "findings" => bad.findings.map { |f| f.code.to_s } }
        end
      end
      { "cases" => cases.size, "faithful_runs" => faithful.size, "false_hold_rate" => ratio(faithful.count { |f| f["held"] }, faithful.size),
        "fault_runs" => faults.size, "fault_catch_rate" => ratio(faults.count { |f| f["held"] }, faults.size),
        "by_fault" => faults.group_by { |f| f["fault"] }.transform_values { |v| "#{v.count { |f| f['held'] }}/#{v.size}" },
        "false_holds" => faithful.select { |f| f["held"] }, "escaped" => faults.reject { |f| f["held"] } }
    end

    def run_draft(kind, facts, library, faults)
      client = Ai::Client.new(provider: Ai::Providers::Simulated.new(faults: faults))
      case kind
      when "check_in_reply" then Ai::Workflows::CheckInReply.new(client: client).call(facts)
      when "closing_report" then Ai::Workflows::ClosingReport.new(client: client).call(facts)
      when "plan_change" then Ai::Workflows::PlanChange.new(client: client).call(facts, library: library)
      end
    end

    def ratio(a, b) = b.zero? ? nil : (a.to_f / b).round(4)
  end
end
