module Ops
  # The operations view for one clinic over a window (config/ops.yml): are check-ins answered within
  # the promise, are the jobs moving, what do the model calls cost and how long do they take, and
  # did the newest prompt or model make drafts worse. Counts, rates and times only: nothing a
  # patient wrote and nothing that identifies one.
  class Snapshot
    def initialize(clinic, now: Time.current, gate: ReleaseGate.new)
      @clinic = clinic
      @now = now
      @days = Config.fetch(:window_days)
      @from = (now - @days.days).beginning_of_day
      @gate = gate
    end

    def to_h
      @to_h ||= begin
        doc = { clinic: { id: @clinic.id, name: @clinic.name }, generated_at: @now.iso8601,
                window: { from: @from.iso8601, to: @now.iso8601, days: @days },
                targets: { check_in_share: Config.fetch(:check_ins, :sla_share_min), release_min_reviews: Config.fetch(:release_gate, :min_reviews),
                           release_margin: Config.fetch(:release_gate, :non_inferiority_margin) },
                check_ins: check_ins, drafts: drafts, models: models, queue: queue, releases: releases }
        doc.merge(alerts: Alerts.new(doc).to_a)
      end
    end

    private

    def hours_promised = Aftercare::Programmes.check_in_answer_hours

    def clinic_check_ins
      CheckIn.joins(enrolment: :patient).where(patients: { clinic_id: @clinic.id })
    end

    # A check-in is due once it is answered or older than the promise; it met the promise if its
    # reply went out within it. Check-ins answered before answered_at existed are left out.
    def check_ins
      limit = hours_promised.hours
      rows = clinic_check_ins.where(submitted_at: @from..@now).pluck(:submitted_at, :answered_at, :status)
      answered = rows.select { |_, at, _| at }
      waits = answered.map { |sub, at, _| (at - sub) / 3600.0 }
      late_open = rows.select { |sub, at, st| at.nil? && st != "answered" && sub <= @now - limit }
      met = answered.count { |sub, at, _| at - sub <= limit }
      due = answered.size + late_open.size
      open = clinic_check_ins.where.not(status: "answered").pluck(:submitted_at, :status)
      overdue = open.select { |sub, _| sub <= @now - limit }
      {
        promise_hours: hours_promised, submitted: rows.size, due: due, met: met, share_met: Stats.share(met, due),
        hours_to_answer: { median: round(Stats.percentile(waits, 50)), p90: round(Stats.percentile(waits, 90)) },
        open: open.size, open_escalated: open.count { |_, st| st == "escalated" }, open_overdue: overdue.size,
        oldest_open_hours: round(open.map { |sub, _| (@now - sub) / 3600.0 }.max),
        by_day: by_day(rows, limit)
      }
    end

    def by_day(rows, limit)
      days = (@from.to_date..@now.to_date).to_a
      grouped = rows.group_by { |sub, _, _| sub.in_time_zone.to_date }
      days.map do |d|
        day = grouped.fetch(d, [])
        { date: d.iso8601, submitted: day.size,
          on_time: day.count { |sub, at, _| at && at - sub <= limit },
          late: day.count { |sub, at, st| (at && at - sub > limit) || (at.nil? && st != "answered" && sub <= @now - limit) } }
      end
    end

    def drafts
      scope = AiDraft.joins(enrolment: :patient).where(patients: { clinic_id: @clinic.id }).where(created_at: @from..@now)
      rows = scope.where.not(status: "queued").group(:kind).pluck(
        :kind,
        Arel.sql("count(*)"),
        Arel.sql(%(count(*) FILTER (WHERE ai_drafts.findings @> '[{"severity": "blocking"}]'::jsonb))),
        Arel.sql("count(*) FILTER (WHERE ai_drafts.status IN ('ready', 'held'))"),
        Arel.sql("count(*) FILTER (WHERE ai_drafts.status = 'approved' AND NOT coalesce(ai_drafts.edited, false))"),
        Arel.sql("count(*) FILTER (WHERE ai_drafts.status = 'approved' AND ai_drafts.edited)"),
        Arel.sql("count(*) FILTER (WHERE ai_drafts.status = 'rejected')"),
        Arel.sql("count(*) FILTER (WHERE ai_drafts.status = 'failed')"),
        Arel.sql("percentile_cont(0.5) WITHIN GROUP (ORDER BY extract(epoch FROM ai_drafts.reviewed_at - ai_drafts.created_at)) " \
                 "FILTER (WHERE ai_drafts.reviewed_at IS NOT NULL)")
      )
      rows.sort_by(&:first).map do |kind, generated, held, waiting, unchanged, edited, rejected, failed, review_s|
        reviewed = unchanged + edited + rejected
        { kind: kind, generated: generated, held_by_checks: held, waiting_review: waiting, approved_unchanged: unchanged,
          approved_edited: edited, rejected: rejected, failed: failed, share_unchanged: Stats.share(unchanged, reviewed),
          median_review_minutes: review_s && (review_s / 60.0).round }
      end
    end

    def models
      scope = AiCall.where(clinic_id: @clinic.id, created_at: @from..@now)
      tasks = scope.group(:task).pluck(
        :task,
        Arel.sql("count(*)"),
        Arel.sql("count(*) FILTER (WHERE outcome = 'error')"),
        Arel.sql("count(*) FILTER (WHERE outcome = 'refused')"),
        Arel.sql("percentile_disc(0.5) WITHIN GROUP (ORDER BY latency_ms) FILTER (WHERE outcome = 'ok')"),
        Arel.sql("percentile_disc(0.95) WITHIN GROUP (ORDER BY latency_ms) FILTER (WHERE outcome = 'ok')"),
        Arel.sql("coalesce(sum(input_tokens), 0)"),
        Arel.sql("coalesce(sum(output_tokens), 0)"),
        Arel.sql("coalesce(sum(cost_microeuros), 0)"),
        Arel.sql("bool_or(tokens_estimated)")
      )
      versions = scope.where.not(prompt_version: nil).group(:task).pluck(:task, Arel.sql("max(prompt_version)")).to_h
      used = scope.distinct.pluck(:model)
      daily = scope.pluck(:created_at, :cost_microeuros).group_by { |at, _| at.in_time_zone.to_date }.transform_values { |v| v.sum(&:last) }
      {
        tasks: tasks.sort_by(&:first).map do |task, calls, errors, refused, p50, p95, input, output, cost, estimated|
          { task: task, prompt_version: versions[task], calls: calls, errors: errors, refused: refused,
            error_share: Stats.share(errors, calls), latency_ms: { p50: p50, p95: p95 },
            input_tokens: input, output_tokens: output, tokens_estimated: estimated, cost_eur: euros(cost),
            cost_per_call_eur: calls.zero? ? nil : euros(cost.fdiv(calls)) }
        end,
        cost_eur: euros(scope.sum(:cost_microeuros)),
        cost_by_day: (@from.to_date..@now.to_date).map { |d| { date: d.iso8601, cost_eur: euros(daily.fetch(d, 0)) } },
        models_used: used.sort, unpriced_models: used.reject { |m| Ai::Costs.priced?(m) }.sort
      }
    end

    # Solid Queue is shared by all clinics; this is its state as counts, never job arguments or
    # error text (an error message could quote what a job was working on).
    def queue
      heartbeat = Config.fetch(:queue, :worker_heartbeat_minutes).minutes
      ready = SolidQueue::ReadyExecution.group(:queue_name).pluck(:queue_name, Arel.sql("count(*)"), Arel.sql("min(created_at)"))
      scheduled = SolidQueue::ScheduledExecution.group(:queue_name).count
      running = SolidQueue::ClaimedExecution.joins(:job).group("solid_queue_jobs.queue_name").count
      failed = SolidQueue::FailedExecution.joins(:job).group("solid_queue_jobs.class_name")
                                          .pluck(Arel.sql("solid_queue_jobs.class_name"), Arel.sql("count(*)"), Arel.sql("max(solid_queue_failed_executions.created_at)"))
      names = (ready.map(&:first) + scheduled.keys + running.keys + %w[ai default]).uniq.sort
      ready_by = ready.to_h { |q, n, oldest| [ q, [ n, oldest ] ] }
      {
        queues: names.map do |q|
          n, oldest = ready_by.fetch(q, [ 0, nil ])
          { queue: q, ready: n, scheduled: scheduled.fetch(q, 0), running: running.fetch(q, 0),
            oldest_ready_minutes: oldest && ((@now - oldest) / 60.0).round(1) }
        end,
        failed: failed.sort_by(&:first).map { |klass, n, last| { job: klass, count: n, last_failed_at: last&.iso8601 } },
        workers_alive: SolidQueue::Process.where(kind: "Worker").where(last_heartbeat_at: (@now - heartbeat)..).count
      }
    end

    def releases
      @gate.all.map(&:to_h)
    end

    def euros(microeuros) = (microeuros / 1_000_000.0).round(4)
    def round(x) = x&.round(1)

    # Turns the numbers into what needs a person, worst first.
    class Alerts
      LEVELS = %w[critical warning].freeze

      def initialize(doc)
        @doc = doc
      end

      def to_a
        out = []
        c = @doc[:check_ins]
        min_share = Config.fetch(:check_ins, :sla_share_min)
        if c[:share_met] && c[:share_met] < min_share
          out << alert("critical", "check_in_promise", "#{pct(c[:share_met])} of due check-ins were answered within #{c[:promise_hours]} h (target #{pct(min_share)})")
        end
        if c[:open_overdue].positive?
          out << alert("warning", "check_ins_overdue", "#{c[:open_overdue]} check-in#{'s' if c[:open_overdue] > 1} waiting longer than #{c[:promise_hours]} h")
        end
        q = @doc[:queue]
        out << alert("critical", "no_workers", "no jobs worker has reported in the last #{Config.fetch(:queue, :worker_heartbeat_minutes)} minutes") if q[:workers_alive].zero?
        q[:queues].each do |row|
          next unless row[:oldest_ready_minutes] && row[:oldest_ready_minutes] > Config.fetch(:queue, :oldest_ready_minutes_max)

          out << alert("warning", "queue_backlog", "#{row[:queue]} queue: oldest job has waited #{row[:oldest_ready_minutes].round} minutes")
        end
        failed = q[:failed].sum { |f| f[:count] }
        out << alert("warning", "failed_jobs", "#{failed} failed job#{'s' if failed > 1} (#{q[:failed].map { |f| f[:job] }.join(', ')})") if failed > Config.fetch(:queue, :failed_max)
        model_alerts(out)
        @doc[:releases].each do |r|
          next unless r[:decision] == "block"

          out << alert("critical", "release_blocked", "#{r[:kind].tr('_', ' ')}: #{r.dig(:candidate, :label)} is worse than #{r.dig(:baseline, :label)} — #{r[:reasons].first}")
        end
        out.sort_by { |a| LEVELS.index(a[:level]) }
      end

      private

      def model_alerts(out)
        m = @doc[:models]
        m[:tasks].each do |t|
          if t[:error_share] && t[:error_share] > Config.fetch(:models, :error_share_max)
            out << alert("warning", "model_errors", "#{t[:task]}: #{pct(t[:error_share])} of model calls failed")
          end
          p95 = t.dig(:latency_ms, :p95)
          if p95 && p95 > Config.fetch(:models, :p95_latency_ms_max)
            out << alert("warning", "model_latency", "#{t[:task]}: 95th percentile latency #{(p95 / 1000.0).round(1)} s")
          end
        end
        budget = Config.fetch(:models, :daily_cost_eur_max)
        over = m[:cost_by_day].select { |d| d[:cost_eur] > budget }
        out << alert("warning", "model_cost", "model cost above €#{budget}/day on #{over.size} day#{'s' if over.size > 1}") if over.any?
        out << alert("warning", "unpriced_model", "no rate in config/ai/costs.yml for #{m[:unpriced_models].join(', ')}; its cost is a default guess") if m[:unpriced_models].any?
      end

      def alert(level, code, message) = { level: level, code: code, message: message }
      def pct(x) = format("%.0f%%", x * 100)
    end
  end
end
