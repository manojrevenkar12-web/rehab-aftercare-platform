import type { OpsSnapshot } from "../../shared/api/types";
import { draftKind } from "../../shared/lib/labels";
import { formatDayTime } from "../../shared/lib/format";
import { DASH, euros, num, pct, plural, seconds, taskName } from "./format";
import styles from "./Operations.module.css";

/** Model calls made for this clinic: how many, how many failed, how long they took, what they cost. */
export function ModelCalls({ models, days }: { models: OpsSnapshot["models"]; days: number }) {
  const estimated = models.tasks.some((t) => t.tokens_estimated);
  return (
    <section aria-labelledby="models-title" className={styles.section}>
      <h2 id="models-title" className={styles.sectionTitle}>
        Model calls, last {days} days
      </h2>
      <p className={styles.sectionLead}>
        {euros(models.cost_eur)} in total at the rates in <code>config/ai/costs.yml</code>, which are placeholders until the contracted model's prices are
        set.{estimated && " Token counts marked ≈ are estimated at four characters a token, because the model did not report them."}
      </p>
      {models.tasks.length === 0 ? (
        <p className={styles.none}>No model calls in this window.</p>
      ) : (
        <div className={styles.scroll}>
          <table className={styles.table}>
            <caption className="visually-hidden">Model calls by workflow</caption>
            <thead>
              <tr>
                <th scope="col">Workflow</th>
                <th scope="col">Prompt</th>
                <th scope="col" className={styles.n}>Calls</th>
                <th scope="col" className={styles.n}>Failed</th>
                <th scope="col" className={styles.n}>Median</th>
                <th scope="col" className={styles.n}>95th pct</th>
                <th scope="col" className={styles.n}>Tokens in / out</th>
                <th scope="col" className={styles.n}>Cost</th>
                <th scope="col" className={styles.n}>Per call</th>
              </tr>
            </thead>
            <tbody>
              {models.tasks.map((t) => (
                <tr key={t.task}>
                  <th scope="row">{taskName[t.task] ?? t.task}</th>
                  <td className={styles.code}>{t.prompt_version ?? DASH}</td>
                  <td className={styles.n}>{num(t.calls)}</td>
                  <td className={styles.n} data-alarm={(t.error_share ?? 0) > 0.05 || undefined}>
                    {t.errors + t.refused > 0 ? `${num(t.errors + t.refused)} (${pct(t.error_share)})` : "0"}
                  </td>
                  <td className={styles.n}>{seconds(t.latency_ms.p50)}</td>
                  <td className={styles.n}>{seconds(t.latency_ms.p95)}</td>
                  <td className={styles.n}>
                    {t.tokens_estimated && "≈"}
                    {num(t.input_tokens)} / {num(t.output_tokens)}
                  </td>
                  <td className={styles.n}>{euros(t.cost_eur)}</td>
                  <td className={styles.n}>{euros(t.cost_per_call_eur, { small: true })}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}

/** What the AI drafted for this clinic and what people did with it. */
export function Drafts({ drafts }: { drafts: OpsSnapshot["drafts"] }) {
  return (
    <section aria-labelledby="drafts-title" className={styles.section}>
      <h2 id="drafts-title" className={styles.sectionTitle}>
        AI drafts and their reviews
      </h2>
      {drafts.length === 0 ? (
        <p className={styles.none}>No drafts in this window.</p>
      ) : (
        <div className={styles.scroll}>
          <table className={styles.table}>
            <caption className="visually-hidden">AI drafts by kind</caption>
            <thead>
              <tr>
                <th scope="col">Kind</th>
                <th scope="col" className={styles.n}>Drafted</th>
                <th scope="col" className={styles.n}>Held by checks</th>
                <th scope="col" className={styles.n}>Waiting</th>
                <th scope="col" className={styles.n}>Approved as written</th>
                <th scope="col" className={styles.n}>Edited</th>
                <th scope="col" className={styles.n}>Rejected</th>
                <th scope="col" className={styles.n}>Median review</th>
              </tr>
            </thead>
            <tbody>
              {drafts.map((d) => (
                <tr key={d.kind}>
                  <th scope="row">{draftKind[d.kind]}</th>
                  <td className={styles.n}>{num(d.generated)}</td>
                  <td className={styles.n}>{num(d.held_by_checks)}</td>
                  <td className={styles.n}>{num(d.waiting_review)}</td>
                  <td className={styles.n}>
                    {num(d.approved_unchanged)} <span className={styles.factNote}>({pct(d.share_unchanged)})</span>
                  </td>
                  <td className={styles.n}>{num(d.approved_edited)}</td>
                  <td className={styles.n}>{num(d.rejected)}</td>
                  <td className={styles.n}>{d.median_review_minutes == null ? DASH : `${d.median_review_minutes} min`}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}

/** The shared job queue: drafts and screens wait here for a worker. */
export function Jobs({ queue }: { queue: OpsSnapshot["queue"] }) {
  return (
    <section aria-labelledby="jobs-title" className={styles.section}>
      <h2 id="jobs-title" className={styles.sectionTitle}>
        Background jobs
      </h2>
      <p className={styles.sectionLead} data-alarm={queue.workers_alive === 0 || undefined}>
        {queue.workers_alive === 0
          ? "No worker has reported in the last few minutes: drafts and screens are not being made. Start bin/jobs or check its logs."
          : `${plural(queue.workers_alive, "worker")} running. All clinics share this queue.`}
      </p>
      <div className={styles.scroll}>
        <table className={styles.table}>
          <caption className="visually-hidden">Jobs by queue</caption>
          <thead>
            <tr>
              <th scope="col">Queue</th>
              <th scope="col" className={styles.n}>Waiting</th>
              <th scope="col" className={styles.n}>Running</th>
              <th scope="col" className={styles.n}>Scheduled</th>
              <th scope="col" className={styles.n}>Oldest waiting</th>
            </tr>
          </thead>
          <tbody>
            {queue.queues.map((q) => (
              <tr key={q.queue}>
                <th scope="row" className={styles.code}>
                  {q.queue}
                </th>
                <td className={styles.n}>{num(q.ready)}</td>
                <td className={styles.n}>{num(q.running)}</td>
                <td className={styles.n}>{num(q.scheduled)}</td>
                <td className={styles.n}>{q.oldest_ready_minutes == null ? DASH : `${q.oldest_ready_minutes} min`}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {queue.failed.length > 0 && (
        <ul className={styles.failed}>
          {queue.failed.map((f) => (
            <li key={f.job}>
              {plural(f.count, "failed job")} of <span className={styles.code}>{f.job}</span>
              {f.last_failed_at && `, the last at ${formatDayTime(f.last_failed_at)}`}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
