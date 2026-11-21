import { motion as m } from "framer-motion";

import type { ReleaseMetric, ReleaseVerdict } from "../../shared/api/types";
import { draftKind } from "../../shared/lib/labels";
import { motion } from "../../shared/theme/motion";
import { Tag, type Tone } from "../../shared/ui/Tag";
import { num, pct, points } from "./format";
import styles from "./Operations.module.css";

const decisionTone: Record<ReleaseVerdict["decision"], Tone> = { pass: "ok", wait: "neutral", block: "emergency" };
const decisionWord: Record<ReleaseVerdict["decision"], string> = { pass: "Pass", wait: "Waiting for reviews", block: "Blocked" };
const metricName = { rejected: "Rejected by the reviewer", needed_changes: "Rejected or edited before approval" } as const;

/** Each workflow's newest prompt or model against the one before, judged by what reviewers did with the drafts. */
export function ReleaseGateSection({ releases, margin, minReviews }: { releases: ReleaseVerdict[]; margin: number; minReviews: number }) {
  return (
    <section aria-labelledby="gate-title" className={styles.section}>
      <h2 id="gate-title" className={styles.sectionTitle}>
        Prompt and model releases
      </h2>
      <p className={styles.sectionLead}>
        Reviews from all clinics, because a release is the same everywhere. A release is blocked when reviewers reject or rewrite its drafts more often
        than the one before, with 95% confidence; it passes when it is at most {points(margin).replace("+", "")} worse. Each needs {minReviews} reviews first.
      </p>
      <p className={styles.plotKey} aria-hidden="true">
        <span>
          <svg width="10" height="14">
            <line x1="5" x2="5" y1="1" y2="13" className={styles.plotZero} />
          </svg>
          no change
        </span>
        <span>
          <svg width="10" height="14">
            <line x1="5" x2="5" y1="1" y2="13" className={styles.plotMargin} />
          </svg>
          margin
        </span>
        <span>
          <svg width="34" height="14">
            <line x1="4" x2="30" y1="7" y2="7" className={styles.plotInterval} />
            <circle cx="17" cy="7" r="5" className={styles.plotPoint} />
          </svg>
          change and its 95% interval; left of the line is better
        </span>
      </p>
      <m.ul className={styles.gate} initial="hidden" animate="shown" variants={{ shown: { transition: { staggerChildren: motion.unitStagger * 6 } } }}>
        {releases.map((r) => (
          <m.li
            key={r.kind}
            className={styles.gateRow}
            data-decision={r.decision}
            variants={{ hidden: { opacity: 0, y: 6 }, shown: { opacity: 1, y: 0 } }}
            transition={{ duration: motion.base, ease: motion.ease }}
          >
            <div className={styles.gateHead}>
              <h3 className={styles.gateKind}>{draftKind[r.kind]}</h3>
              <Tag tone={decisionTone[r.decision]}>{decisionWord[r.decision]}</Tag>
            </div>
            <p className={styles.gateReleases}>
              {r.baseline ? (
                <>
                  <span className={styles.release}>{r.baseline.label}</span> ({num(r.baseline.reviewed)} reviews) to{" "}
                </>
              ) : null}
              <span className={styles.release}>{r.candidate?.label ?? "no release yet"}</span>
              {r.candidate && <> ({num(r.candidate.reviewed)} reviews)</>}
            </p>
            {(["rejected", "needed_changes"] as const).map((key) => {
              const metric = r.metrics[key];
              return metric ? <MetricRow key={key} name={metricName[key]} metric={metric} margin={margin} /> : null;
            })}
            <p className={styles.gateReason}>{r.reasons[0]}</p>
          </m.li>
        ))}
      </m.ul>
    </section>
  );
}

function MetricRow({ name, metric, margin }: { name: string; metric: ReleaseMetric; margin: number }) {
  return (
    <div className={styles.metric}>
      <span className={styles.metricName}>{name}</span>
      <span className={styles.metricRates}>
        {pct(metric.baseline, 1)} → {pct(metric.candidate, 1)}
      </span>
      <IntervalPlot metric={metric} margin={margin} />
    </div>
  );
}

const W = 240;
const H = 26;
const SPAN = 0.3; // the axis runs from 30 points better to 30 points worse

/**
 * The 95% interval of the change, against zero (no change) and the margin. Left of zero is better.
 * Whole interval right of zero: worse, block. Whole interval left of the margin: pass.
 */
export function IntervalPlot({ metric, margin }: { metric: ReleaseMetric; margin: number }) {
  const { low, high, difference } = metric;
  const x = (v: number) => ((Math.max(-SPAN, Math.min(SPAN, v)) + SPAN) / (2 * SPAN)) * W;
  if (low == null || high == null || difference == null) {
    return <span className={styles.metricNone}>no reviews to compare yet</span>;
  }
  const verdict = low > 0 ? "worse" : high < margin ? "fine" : "open";
  const summary = `Change ${points(difference)}, 95% interval ${points(low)} to ${points(high)}`;
  return (
    <svg className={styles.plot} viewBox={`0 0 ${W} ${H}`} width={W} height={H} role="img" aria-label={summary} data-verdict={verdict}>
      <title>{summary}</title>
      <line x1={0} x2={W} y1={H / 2} y2={H / 2} className={styles.plotAxis} />
      <line x1={x(0)} x2={x(0)} y1={3} y2={H - 3} className={styles.plotZero} />
      <line x1={x(margin)} x2={x(margin)} y1={3} y2={H - 3} className={styles.plotMargin} />
      <line x1={x(low)} x2={x(high)} y1={H / 2} y2={H / 2} className={styles.plotInterval} />
      <circle cx={x(difference)} cy={H / 2} r={5} className={styles.plotPoint} />
    </svg>
  );
}
