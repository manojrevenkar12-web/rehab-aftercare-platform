module Ops
  # Decides whether a new prompt version or model made a workflow's drafts worse, from what
  # reviewers did with them: rejected, approved after edits, or approved as written.
  #
  # A release is a (prompt_version, model) pair. For each draft kind the newest release with
  # reviewed drafts is the candidate and the release before it the baseline. Reviews are pooled
  # over all clinics, because a release is the same everywhere. Two rates are compared:
  #   rejected       - share of reviewed drafts a person rejected
  #   needed_changes - share rejected or edited before approval
  # The decision, with Newcombe intervals on the difference (candidate - baseline):
  #   wait  - fewer than min_reviews on either side, or the evidence does not settle it yet
  #   block - either rate is higher, with 95% confidence (the interval lies above zero)
  #   pass  - both rates are, with 95% confidence, at most non_inferiority_margin higher
  # This is the gate after release: the offline evaluation (bin/rails evals:gate) is the one that
  # runs before a merge. Neither changes what a reviewer must do; both only decide what ships.
  class ReleaseGate
    Release = Data.define(:prompt_version, :model) do
      def label = "#{prompt_version} · #{model}"
      def to_h = { prompt_version: prompt_version, model: model, label: label }

      def self.parse(text)
        version, model = text.to_s.split("@", 2)
        raise ArgumentError, "a release is prompt_version@model, got #{text.inspect}" if version.blank? || model.blank?

        new(prompt_version: version, model: model)
      end
    end

    Cohort = Data.define(:release, :generated, :held, :reviewed, :rejected, :edited, :first_seen) do
      def needed_changes = rejected + edited
      def unchanged = reviewed - needed_changes
    end

    Verdict = Data.define(:kind, :decision, :baseline, :candidate, :metrics, :reasons) do
      def blocked? = decision == "block"

      def to_h
        { kind: kind, decision: decision, reasons: reasons, metrics: metrics,
          baseline: baseline && cohort_h(baseline), candidate: candidate && cohort_h(candidate) }
      end

      private

      def cohort_h(c)
        c.release.to_h.merge(generated: c.generated, held_by_checks: c.held, reviewed: c.reviewed, rejected: c.rejected,
                             edited: c.edited, unchanged: c.unchanged, first_seen: c.first_seen&.iso8601)
      end
    end

    METRICS = { "rejected" => :rejected, "needed_changes" => :needed_changes }.freeze

    def initialize(scope: AiDraft.all, config: Config.fetch(:release_gate))
      @scope = scope
      @min = config.fetch("min_reviews")
      @z = config.fetch("confidence_z")
      @margin = config.fetch("non_inferiority_margin")
    end

    # Releases of a kind that have at least one reviewed draft, oldest first.
    def cohorts(kind)
      rows = @scope.where(kind: kind).where.not(model: nil).where.not(status: "queued").group(:prompt_version, :model).pluck(
        :prompt_version, :model,
        Arel.sql("count(*)"),
        Arel.sql(%(count(*) FILTER (WHERE findings @> '[{"severity": "blocking"}]'::jsonb))),
        Arel.sql("count(*) FILTER (WHERE status IN ('approved', 'rejected'))"),
        Arel.sql("count(*) FILTER (WHERE status = 'rejected')"),
        Arel.sql("count(*) FILTER (WHERE status = 'approved' AND edited)"),
        Arel.sql("min(created_at)")
      )
      rows.map { |v, m, gen, held, rev, rej, ed, first| Cohort.new(Release.new(v, m), gen, held, rev, rej, ed, first) }
          .select { |c| c.reviewed.positive? }
          .sort_by { |c| [ c.first_seen, c.release.label ] }
    end

    # The newest release of a kind against the one before it.
    def latest(kind)
      list = cohorts(kind)
      return Verdict.new(kind, "wait", nil, list.last, {}, [ "no earlier release to compare with" ]) if list.size < 2

      decide(kind, list[-2], list[-1])
    end

    # Two named releases, e.g. for a deploy pipeline: compare("check_in_reply", baseline: r1, candidate: r2)
    def compare(kind, baseline:, candidate:)
      list = cohorts(kind).index_by(&:release)
      b = list[baseline] || empty(baseline)
      c = list[candidate] || empty(candidate)
      decide(kind, b, c)
    end

    def all(kinds = AiDraft::KINDS)
      kinds.map { |k| latest(k) }
    end

    private

    def empty(release)
      Cohort.new(release, 0, 0, 0, 0, 0, nil)
    end

    def decide(kind, base, cand)
      metrics = METRICS.to_h do |name, attr|
        d = Stats.difference(cand.public_send(attr), cand.reviewed, base.public_send(attr), base.reviewed, z: @z)
        [ name, { baseline: Stats.share(base.public_send(attr), base.reviewed), candidate: Stats.share(cand.public_send(attr), cand.reviewed),
                  difference: d&.dig(:diff), low: d&.dig(:low), high: d&.dig(:high) } ]
      end
      short = [ [ "baseline", base ], [ "candidate", cand ] ].select { |_, c| c.reviewed < @min }
      if short.any?
        reasons = short.map { |side, c| "#{side} #{c.release.label} has #{c.reviewed} of #{@min} reviews needed" }
        return Verdict.new(kind, "wait", base, cand, metrics, reasons)
      end

      worse = metrics.select { |_, m| m[:low].positive? }
      if worse.any?
        reasons = worse.map { |name, m| "#{name.tr('_', ' ')} rose from #{pct(m[:baseline])} to #{pct(m[:candidate])} (95% interval of the rise #{pts(m[:low])} to #{pts(m[:high])})" }
        return Verdict.new(kind, "block", base, cand, metrics, reasons)
      end

      open = metrics.reject { |_, m| m[:high] < @margin }
      if open.any?
        reasons = open.map { |name, m| "#{name.tr('_', ' ')} could still be up to #{pts(m[:high])} worse; the margin is #{pts(@margin)}" }
        return Verdict.new(kind, "wait", base, cand, metrics, reasons)
      end

      Verdict.new(kind, "pass", base, cand, metrics,
                  metrics.map { |name, m| "#{name.tr('_', ' ')} #{pct(m[:baseline])} → #{pct(m[:candidate])} (worst case #{pts(m[:high])}, margin #{pts(@margin)})" })
    end

    def pct(x) = x.nil? ? "–" : format("%.1f%%", x * 100)
    def pts(x) = format("%+.1f points", x * 100)
  end
end
