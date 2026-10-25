import { useRequestDraft, useSignReport } from "../../shared/api/queries";
import type { Role, Timeline } from "../../shared/api/types";
import { formatDayTime } from "../../shared/lib/format";
import { closingSectionName, closingSections } from "../../shared/lib/labels";
import { Button } from "../../shared/ui/Button";
import { EmptyState } from "../../shared/ui/states";
import { Tag } from "../../shared/ui/Tag";
import styles from "./Panel.module.css";

/** The closing documentation the DRV needs (form G4819): drafted, approved, then signed by a physician. */
export function ClosingReportPanel({ timeline, role }: { timeline: Timeline; role?: Role }) {
  const e = timeline.enrolment;
  const report = timeline.closing_report;
  const request = useRequestDraft(e.id);
  const sign = useSignReport(e.id);
  const finished = e.status === "completed" || e.status === "ended_early";
  const pending = timeline.drafts.some((d) => d.kind === "closing_report" && ["queued", "ready", "held"].includes(d.status));

  return (
    <section className={styles.panel} aria-labelledby="closing">
      <h2 id="closing" className={styles.title}>
        Closing report
      </h2>
      {!report ? (
        <>
          <EmptyState title={finished ? "Not written yet" : "Written when the programme ends"}>
            {finished ? "Ask for a draft from the training record, then review it." : "It becomes available once the patient completes or ends the programme."}
          </EmptyState>
          {finished && (role === "therapist" || role === "physician") && (
            <Button variant="primary" disabled={pending} busy={request.isPending} onClick={() => request.mutate({ kind: "closing_report" })}>
              {pending ? "Draft waiting for review" : "Draft the closing report"}
            </Button>
          )}
        </>
      ) : (
        <>
          <p>
            {report.signed ? (
              <Tag tone="ok">
                Signed by {report.signed_by}, {report.signed_at && formatDayTime(report.signed_at)}
              </Tag>
            ) : (
              <Tag tone="urgent">Not signed</Tag>
            )}
          </p>
          <dl className={styles.sections}>
            {closingSections.map((k) => (
              <div key={k}>
                <dt>{closingSectionName[k]}</dt>
                <dd>{report.sections[k]}</dd>
              </div>
            ))}
          </dl>
          {!report.signed && role === "physician" && (
            <Button variant="primary" busy={sign.isPending} onClick={() => sign.mutate()}>
              Sign the report
            </Button>
          )}
          {!report.signed && role !== "physician" && <p className={styles.note}>A physician signs it before it can be billed.</p>}
          {sign.isError && (
            <p className={styles.error} role="alert">
              Could not sign: {sign.error.message}
            </p>
          )}
        </>
      )}
    </section>
  );
}
