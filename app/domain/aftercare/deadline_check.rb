module Aftercare
  # Where an enrolment stands against the DRV time rules on a given day. Pure: it reads the
  # enrolment and its unit dates, and returns findings; it changes nothing.
  class DeadlineCheck
    Finding = Data.define(:code, :severity, :due_on, :message)

    attr_reader :ideal_start, :latest_start, :latest_finish

    def initialize(rehab_ended_on:, status:, started_on: nil, unit_dates: [], rules: Programmes.deadlines)
      @rehab_ended_on = rehab_ended_on
      @status = status
      @started_on = started_on
      @unit_dates = unit_dates.sort
      @rules = rules
      @ideal_start = rehab_ended_on + rules.ideal_start_weeks.weeks
      @latest_start = rehab_ended_on + rules.latest_start_months.months
      @latest_finish = rehab_ended_on + rules.latest_finish_months.months
    end

    def findings(today)
      return [] if %w[completed ended_early expired].include?(@status)

      out = []
      if @started_on.nil?
        out.concat(start_findings(today))
      else
        out.concat(break_findings(today))
        out.concat(finish_findings(today))
      end
      out
    end

    def longest_break_days(today)
      dates = [ *@unit_dates, today ]
      dates.each_cons(2).map { |a, b| (b - a).to_i }.max || 0
    end

    private

    def warn_from(day)
      day - @rules.warn_days_before.days
    end

    def start_findings(today)
      if today > @latest_start
        [ Finding.new(:start_missed, :blocking, @latest_start, "No unit by #{@latest_start}: the programme can no longer start.") ]
      elsif today >= warn_from(@latest_start)
        [ Finding.new(:start_due, :urgent, @latest_start, "Must start by #{@latest_start}.") ]
      elsif today > @ideal_start
        [ Finding.new(:start_late, :notice, @latest_start, "Past the 6-week ideal start (#{@ideal_start}); latest start #{@latest_start}.") ]
      else
        []
      end
    end

    def break_findings(today)
      last = @unit_dates.last || @started_on
      gap = (today - last).to_i
      limit = @rules.max_break_weeks * 7
      if gap > limit
        [ Finding.new(:break_exceeded, :blocking, last + limit.days,
                     "No unit for #{gap} days (limit #{limit}): a therapist must decide whether the aftercare goal is still reachable.") ]
      elsif gap > limit - @rules.warn_days_before
        [ Finding.new(:break_long, :urgent, last + limit.days, "No unit for #{gap} days; the break limit is reached on #{last + limit.days}.") ]
      else
        []
      end
    end

    def finish_findings(today)
      if today > @latest_finish
        [ Finding.new(:finish_missed, :blocking, @latest_finish, "Past the last day (#{@latest_finish}); no extension is possible.") ]
      elsif today >= @latest_finish - 30.days
        [ Finding.new(:finish_due, :urgent, @latest_finish, "The programme must finish by #{@latest_finish}.") ]
      else
        []
      end
    end
  end
end
