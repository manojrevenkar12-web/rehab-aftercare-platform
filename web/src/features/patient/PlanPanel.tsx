import { useRequestDraft } from "../../shared/api/queries";
import type { Timeline } from "../../shared/api/types";
import { Button } from "../../shared/ui/Button";
import { EmptyState } from "../../shared/ui/states";
import styles from "./Panel.module.css";

export function PlanPanel({ timeline, canDraft }: { timeline: Timeline; canDraft: boolean }) {
  const request = useRequestDraft(timeline.enrolment.id);
  const pending = timeline.drafts.some((d) => d.kind === "plan_change" && ["queued", "ready", "held"].includes(d.status));
  const active = timeline.enrolment.status === "active" || timeline.enrolment.status === "approved";
  return (
    <section className={styles.panel} aria-labelledby="plan">
      <h2 id="plan" className={styles.title}>
        Exercise plan
      </h2>
      {timeline.plan.length === 0 ? (
        <EmptyState title="No exercises in the plan">Add exercises in the plan editor, or ask for a suggestion.</EmptyState>
      ) : (
        <ul className={styles.rows}>
          {timeline.plan.map((p) => (
            <li key={p.exercise_key} className={styles.row}>
              <span className={styles.rowName}>{p.name}</span>
              <span className={styles.rowMeta}>
                Level {p.level}, {p.sets} × {p.reps}, {p.per_week}/week
              </span>
            </li>
          ))}
        </ul>
      )}
      {canDraft && active && (
        <Button disabled={pending} busy={request.isPending} onClick={() => request.mutate({ kind: "plan_change" })} title={pending ? "A suggestion is waiting for review" : undefined}>
          Suggest a plan change
        </Button>
      )}
    </section>
  );
}
