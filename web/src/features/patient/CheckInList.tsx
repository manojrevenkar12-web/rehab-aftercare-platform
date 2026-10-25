import { useRequestDraft } from "../../shared/api/queries";
import type { CheckIn, Timeline } from "../../shared/api/types";
import { formatDayTime } from "../../shared/lib/format";
import { highlight } from "../../shared/lib/highlight";
import { flagName, setAsideReason } from "../../shared/lib/labels";
import { Button } from "../../shared/ui/Button";
import { EmptyState } from "../../shared/ui/states";
import { Tag } from "../../shared/ui/Tag";
import styles from "./CheckInList.module.css";

/**
 * The patient's check-ins, newest first, with the words that raised each red flag marked in the
 * message itself and, below it, what the rules saw but did not escalate.
 */
export function CheckInList({ timeline, canDraft }: { timeline: Timeline; canDraft: boolean }) {
  const request = useRequestDraft(timeline.enrolment.id);
  const drafted = new Set(timeline.drafts.filter((d) => d.kind === "check_in_reply" && d.status !== "rejected").map((d) => d.output.check_in_id));
  return (
    <section className={styles.section} aria-labelledby="check-ins">
      <h2 id="check-ins" className={styles.title}>
        Check-ins
      </h2>
      {timeline.check_ins.length === 0 ? (
        <EmptyState title="No check-ins yet">The patient's messages from the app appear here, with any red flags marked.</EmptyState>
      ) : (
        <ol className={styles.list}>
          {timeline.check_ins.map((c) => (
            <CheckInItem
              key={c.id}
              c={c}
              action={
                canDraft && c.status !== "answered" && !drafted.has(c.id) ? (
                  <Button
                    busy={request.isPending && request.variables?.checkInId === c.id}
                    onClick={() => request.mutate({ kind: "check_in_reply", checkInId: c.id })}
                  >
                    Draft a reply
                  </Button>
                ) : null
              }
            />
          ))}
        </ol>
      )}
      {request.isError && (
        <p className={styles.error} role="alert">
          Could not request a draft: {request.error.message}
        </p>
      )}
    </section>
  );
}

function CheckInItem({ c, action }: { c: CheckIn; action: React.ReactNode }) {
  const level = c.red_flags.some((f) => f.severity === "emergency") ? "emergency" : c.red_flags.length ? "urgent" : "none";
  return (
    <li className={styles.item} data-level={level}>
      <div className={styles.meta}>
        <time dateTime={c.submitted_at}>{formatDayTime(c.submitted_at)}</time>
        <span>Pain {c.pain_score}/10</span>
        {c.status === "answered" && <Tag tone="ok">Answered</Tag>}
      </div>
      <blockquote className={styles.message} lang="de">
        {highlight(c.message, c.red_flags).map((p, i) =>
          p.mark ? (
            <mark key={i} className={styles.mark} data-severity={p.mark.severity}>
              {p.text}
            </mark>
          ) : (
            <span key={i}>{p.text}</span>
          ),
        )}
      </blockquote>
      {c.red_flags.length > 0 && (
        <ul className={styles.flags} aria-label="Red flags">
          {c.red_flags.map((f) => (
            <li key={f.code}>
              <Tag tone={f.severity === "emergency" ? "emergency" : "urgent"} title={f.source === "model" ? "Added by the model screen" : "Found by the rules"}>
                {flagName[f.code] ?? f.code}
                {f.source === "model" && <span className={styles.source}>model</span>}
                <span className="visually-hidden">, {f.severity}</span>
              </Tag>
            </li>
          ))}
        </ul>
      )}
      {c.set_aside.length > 0 && (
        <ul className={styles.asides} aria-label="Seen but not escalated">
          {c.set_aside.map((s) => (
            <li key={s.code}>
              Not escalated: {flagName[s.code] ?? s.code}, because the message is {setAsideReason[s.reason] ?? s.reason} (“{s.evidence}”).
            </li>
          ))}
        </ul>
      )}
      {c.screen?.error && <p className={styles.asides}>The model screen did not run ({c.screen.error}); the rules' result stands.</p>}
      {action && <div className={styles.action}>{action}</div>}
    </li>
  );
}
