module Evals
  # Writes a run to reports/evals/<label>.json and .md. Held-out first runs are written once:
  # a second run with the same label is refused.
  module Report
    class AlreadyRecorded < StandardError; end

    module_function

    def write(label, results, set:, first_run_only: false, root: Rails.root.join("reports/evals"))
      path = root.join("#{label}.json")
      raise AlreadyRecorded, "#{path} exists: a held-out first run is never rewritten" if first_run_only && path.exist?

      doc = { "label" => label, "set" => set, "recorded_at" => Time.current.utc.iso8601, "git" => git_sha, "results" => results }
      FileUtils.mkdir_p(root)
      File.write(path, JSON.pretty_generate(doc))
      File.write(root.join("#{label}.md"), markdown(doc))
      doc
    end

    def git_sha
      `git rev-parse --short HEAD 2>/dev/null`.strip.presence
    end

    def markdown(doc)
      r = doc["results"]
      lines = [ "# Evaluation: #{doc['label']}", "", "Set `#{doc['set']}`, recorded #{doc['recorded_at']} at #{doc['git'] || 'unknown commit'}.", "" ]
      if (rf = r["red_flags"])
        lines += [ "## Red flags (rules)", "", "| Measure | Value |", "|---|---:|",
                  "| Cases | #{rf['cases']} |",
                  "| Emergency flags found | #{rf.dig('by_severity', 'emergency', 'found')} of #{rf.dig('by_severity', 'emergency', 'expected')} (#{pct(rf['emergency_recall'])}) |",
                  "| Urgent flags found | #{rf.dig('by_severity', 'urgent', 'found')} of #{rf.dig('by_severity', 'urgent', 'expected')} (#{pct(rf['urgent_recall'])}) |",
                  "| Harmless messages escalated | #{pct(rf['false_escalation_rate'])} |", "" ]
        if rf["wrong"].any?
          lines += [ "| Case | Expected | Found |", "|---|---|---|" ]
          lines += rf["wrong"].map { |w| "| #{w['id']} | #{w['expected'].join(', ')} | #{w['found'].join(', ')} |" }
          lines << ""
        end
      end
      if (ps = r["pseudonymization"])
        lines += [ "## Pseudonymisation", "", "#{ps['cases']} texts, #{ps['mentions']} identity mentions: #{ps['leaked'].size} survived (#{pct(ps['leak_rate'])}); #{ps['clinical_words_lost']} clinical words lost.", "" ]
        lines += ps["leaked"].map { |l| "- leaked in #{l['id']}: `#{l['mention']}`" }
        lines += ps["lost"].map { |l| "- lost in #{l['id']}: `#{l['word']}`" }
        lines << ""
      end
      if (dr = r["drafts"])
        lines += [ "## AI drafts (simulated model)", "", "#{dr['faithful_runs']} faithful runs, #{pct(dr['false_hold_rate'])} held; #{dr['fault_runs']} runs with an injected mistake, #{pct(dr['fault_catch_rate'])} held.", "",
                  "| Injected mistake | Held |", "|---|---:|" ]
        lines += dr["by_fault"].map { |f, v| "| #{f} | #{v} |" }
        lines << ""
      end
      lines.join("\n")
    end

    def pct(x) = x.nil? ? "n/a" : "#{(x * 100).round(1)}%"
  end
end
