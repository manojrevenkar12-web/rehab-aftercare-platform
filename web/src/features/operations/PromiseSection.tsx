import type { OpsSnapshot } from "../../shared/api/types";
import { formatDay } from "../../shared/lib/format";
import { hours, num, pct, plural } from "./format";
import styles from "./Operations.module.css";

const BAR_W = 22;
const GAP = 8;
const H = 88;

/** The promise to patients: every check-in answered by a person within the programme's hours. */
export function PromiseSection({ c, target, today }: { c: OpsSnapshot["check_ins"]; target: number; today: string }) {
  const missed = c.share_met != null && c.share_met < target;
  const max = Math.max(1, ...c.by_day.map((d) => d.on_time + d.late));
  const width = c.by_day.length * (BAR_W + GAP);
  return (
    <section aria-labelledby="promise-title" className={styles.section}>
      <h2 id="promise-title" className={styles.sectionTitle}>
        Check-ins answered within {c.promise_hours} hours
      </h2>
      <div className={styles.promise}>
        <p className={styles.figure} data-missed={missed || undefined}>
          <span className={styles.figureValue}>{pct(c.share_met)}</span>
          <span className={styles.figureLabel}>
            of {plural(c.due, "due check-in")} answered in time; the target is {pct(target)}
          </span>
        </p>
        <dl className={styles.facts}>
          <div>
            <dt>Median wait</dt>
            <dd>{hours(c.hours_to_answer.median)}</dd>
          </div>
          <div>
            <dt>Slowest tenth</dt>
            <dd>{hours(c.hours_to_answer.p90)}</dd>
          </div>
          <div>
            <dt>Open now</dt>
            <dd>
              {num(c.open)}
              {c.open_escalated > 0 && <span className={styles.factNote}> ({c.open_escalated} with a red flag)</span>}
            </dd>
          </div>
          <div data-alarm={c.open_overdue > 0 || undefined}>
            <dt>Open past {c.promise_hours} h</dt>
            <dd>
              {num(c.open_overdue)}
              {c.oldest_open_hours != null && <span className={styles.factNote}> (oldest {hours(c.oldest_open_hours)})</span>}
            </dd>
          </div>
        </dl>
      </div>
      <figure className={styles.daily}>
        <svg
          viewBox={`0 0 ${width} ${H + 18}`}
          className={styles.dailyChart}
          style={{ maxWidth: width }}
          role="img"
          aria-labelledby="daily-caption"
        >
          {c.by_day.map((d, i) => {
            const x = i * (BAR_W + GAP);
            const onH = (d.on_time / max) * H;
            const lateH = (d.late / max) * H;
            return (
              <g key={d.date}>
                <title>{`${formatDay(d.date, today)}: ${d.on_time} on time, ${d.late} late`}</title>
                <rect x={x} y={0} width={BAR_W} height={H} className={styles.dayHit} />
                {d.on_time > 0 && <rect x={x} y={H - onH} width={BAR_W} height={onH} rx={3} className={styles.onTime} />}
                {d.late > 0 && <rect x={x} y={H - onH - lateH - (d.on_time > 0 ? 2 : 0)} width={BAR_W} height={lateH} rx={3} className={styles.late} />}
                {(i === 0 || i === c.by_day.length - 1) && (
                  <text x={i === 0 ? x : x + BAR_W} y={H + 14} textAnchor={i === 0 ? "start" : "end"} className={styles.axisText}>
                    {formatDay(d.date, today)}
                  </text>
                )}
              </g>
            );
          })}
        </svg>
        <figcaption id="daily-caption" className={styles.legend}>
          <span className={styles.key} data-series="on-time">
            Answered in time
          </span>
          <span className={styles.key} data-series="late">
            Late or still waiting past {c.promise_hours} h
          </span>
          <span className="visually-hidden">
            {c.by_day.map((d) => `${formatDay(d.date, today)}: ${d.on_time} on time, ${d.late} late.`).join(" ")}
          </span>
        </figcaption>
      </figure>
    </section>
  );
}
