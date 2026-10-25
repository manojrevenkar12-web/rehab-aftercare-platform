import { motion as m } from "framer-motion";

import { useCaseload } from "../../shared/api/queries";
import type { CaseloadRow as Row } from "../../shared/api/types";
import { formatLongDay, plural } from "../../shared/lib/format";
import { motion } from "../../shared/theme/motion";
import { useSession } from "../auth/session";
import { EmptyState, QueryView } from "../../shared/ui/states";
import styles from "./CaseloadPage.module.css";
import { CaseloadRow } from "./CaseloadRow";

/** The therapist's day: who needs attention first, then everyone else. */
export function CaseloadPage() {
  const query = useCaseload();
  return (
    <QueryView
      query={query}
      what="your caseload"
      lines={6}
      isEmpty={(d) => d.patients.length === 0}
      empty={
        <EmptyState title="No patients assigned to you">
          Patients appear here once the clinic assigns them to you for aftercare.
        </EmptyState>
      }
    >
      {(data) => {
        const urgent = data.patients.filter((p) => p.attention > 0);
        const rest = data.patients.filter((p) => p.attention === 0);
        return (
          <div className={styles.page}>
            <header className={styles.header}>
              <h1 className={styles.title}>{formatLongDay(data.today)}</h1>
              <p className={styles.summary}>{summary(data.patients)}</p>
            </header>
            {urgent.length > 0 && <Group title="Needs you today" rows={urgent} today={data.today} />}
            {rest.length > 0 && <Group title={urgent.length ? "Everyone else" : "Your patients"} rows={rest} today={data.today} />}
          </div>
        );
      }}
    </QueryView>
  );
}

function Group({ title, rows, today }: { title: string; rows: Row[]; today: string }) {
  const { user } = useSession();
  const canOpen = user?.role === "therapist" || user?.role === "physician";
  return (
    <section className={styles.group} aria-label={title}>
      <h2 className={styles.groupTitle}>
        {title} <span className={styles.groupCount}>{rows.length}</span>
      </h2>
      <m.ul className={styles.rows} initial="hidden" animate="shown" variants={{ shown: { transition: { staggerChildren: motion.unitStagger * 2 } } }}>
        {rows.map((r) => (
          <CaseloadRow key={r.id} row={r} today={today} canOpen={canOpen} />
        ))}
      </m.ul>
    </section>
  );
}

export function summary(rows: Row[]): string {
  const flagged = rows.filter((r) => r.escalations > 0).length;
  const deadlines = rows.filter((r) => r.enrolment?.deadlines.some((d) => d.severity !== "notice")).length;
  const overdue = rows.filter((r) => r.overdue > 0).length;
  if (!flagged && !deadlines && !overdue) return `Nothing urgent across ${plural(rows.length, "patient")}.`;
  const parts = [];
  if (flagged) parts.push(`${plural(flagged, "patient")} reported a red flag`);
  if (overdue) parts.push(`${plural(overdue, "patient")} waited too long for an answer`);
  if (deadlines) parts.push(`${plural(deadlines, "programme")} ${deadlines === 1 ? "has" : "have"} a DRV deadline coming up`);
  const sentence = parts.length > 1 ? `${parts.slice(0, -1).join(", ")} and ${parts[parts.length - 1]}` : parts[0];
  return `${sentence}.`;
}
