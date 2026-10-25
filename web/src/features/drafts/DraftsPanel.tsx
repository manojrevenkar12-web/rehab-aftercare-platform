import { AnimatePresence } from "framer-motion";

import type { Timeline } from "../../shared/api/types";
import { EmptyState } from "../../shared/ui/states";
import { DraftCard } from "./DraftCard";
import styles from "./DraftsPanel.module.css";

/** Drafts waiting for a decision first, then the ones already decided. */
export function DraftsPanel({ timeline }: { timeline: Timeline }) {
  const waiting = timeline.drafts.filter((d) => ["queued", "ready", "held", "failed"].includes(d.status));
  const decided = timeline.drafts.filter((d) => d.status === "approved" || d.status === "rejected");
  return (
    <section className={styles.panel} aria-labelledby="drafts">
      <h2 id="drafts" className={styles.title}>
        AI drafts to review
      </h2>
      {waiting.length === 0 ? (
        <EmptyState title="Nothing to review">Ask for a reply to a check-in, a plan change or the closing report; drafts wait here for your decision.</EmptyState>
      ) : (
        <div className={styles.list}>
          <AnimatePresence initial={false}>
            {waiting.map((d) => (
              <DraftCard key={d.id} draft={d} enrolmentId={timeline.enrolment.id} />
            ))}
          </AnimatePresence>
        </div>
      )}
      {decided.length > 0 && (
        <details className={styles.history}>
          <summary>Decided drafts ({decided.length})</summary>
          <div className={styles.list}>
            {decided.map((d) => (
              <DraftCard key={d.id} draft={d} enrolmentId={timeline.enrolment.id} />
            ))}
          </div>
        </details>
      )}
    </section>
  );
}
