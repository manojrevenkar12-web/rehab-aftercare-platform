import type { Unit } from "../../shared/api/types";
import { formatDay } from "../../shared/lib/format";
import { EmptyState } from "../../shared/ui/states";
import styles from "./PainTrend.module.css";

const W = 600;
const H = 120;
const PAD = 8;

/** Pain before and after each unit, 0 to 10, in the order the units were done. */
export function PainTrend({ units }: { units: Unit[] }) {
  const rows = units.filter((u) => u.pain_before !== null && u.pain_after !== null);
  return (
    <section className={styles.section} aria-labelledby="pain">
      <h2 id="pain" className={styles.title}>
        Pain around training
      </h2>
      {rows.length < 2 ? (
        <EmptyState title="Not enough units yet">The trend appears after two units with pain scores.</EmptyState>
      ) : (
        <Chart rows={rows} />
      )}
    </section>
  );
}

function Chart({ rows }: { rows: Unit[] }) {
  const x = (i: number) => PAD + (i / (rows.length - 1)) * (W - 2 * PAD);
  const y = (v: number) => PAD + (1 - v / 10) * (H - 2 * PAD);
  const line = (k: "pain_before" | "pain_after") => rows.map((u, i) => `${i ? "L" : "M"}${x(i).toFixed(1)},${y(u[k] ?? 0).toFixed(1)}`).join(" ");
  const first = rows[0]!;
  const last = rows[rows.length - 1]!;
  const label = `Pain after training went from ${first.pain_after} to ${last.pain_after} out of 10 between ${formatDay(first.performed_on)} and ${formatDay(last.performed_on)}.`;
  return (
    <figure className={styles.figure}>
      <svg viewBox={`0 0 ${W} ${H}`} className={styles.chart} role="img" aria-label={label} preserveAspectRatio="none">
        {[0, 5, 10].map((v) => (
          <line key={v} x1={0} x2={W} y1={y(v)} y2={y(v)} className={styles.grid} />
        ))}
        <path d={line("pain_before")} className={styles.before} />
        <path d={line("pain_after")} className={styles.after} />
      </svg>
      <figcaption className={styles.legend}>
        <span className={styles.keyAfter}>After training, now {last.pain_after}/10</span>
        <span className={styles.keyBefore}>Before training, now {last.pain_before}/10</span>
      </figcaption>
    </figure>
  );
}
