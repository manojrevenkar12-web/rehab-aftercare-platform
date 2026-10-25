import { motion as m } from "framer-motion";
import { Link, useParams } from "react-router-dom";

import { useTimeline } from "../../shared/api/queries";
import type { Timeline } from "../../shared/api/types";
import { formatDay } from "../../shared/lib/format";
import { enrolmentStatus } from "../../shared/lib/labels";
import { motion } from "../../shared/theme/motion";
import { ErrorState, QueryView } from "../../shared/ui/states";
import { Tag, severityTone } from "../../shared/ui/Tag";
import { useSession } from "../auth/session";
import { DraftsPanel } from "../drafts/DraftsPanel";
import { ProgrammeRuler } from "../programme/ProgrammeRuler";
import { CheckInList } from "./CheckInList";
import { ClosingReportPanel } from "./ClosingReportPanel";
import { PainTrend } from "./PainTrend";
import styles from "./PatientPage.module.css";
import { PlanPanel } from "./PlanPanel";

export function PatientPage() {
  const id = Number(useParams().id);
  const query = useTimeline(id);
  if (!Number.isInteger(id) || id <= 0) return <ErrorState error={new Error("This address does not name a programme.")} what="the patient" />;
  return (
    <QueryView query={query} what="the patient" lines={8}>
      {(t) => <PatientView t={t} />}
    </QueryView>
  );
}

function PatientView({ t }: { t: Timeline }) {
  const { user } = useSession();
  const e = t.enrolment;
  return (
    <div className={styles.page}>
      <Link to="/" className={styles.back}>
        Back to caseload
      </Link>
      <header className={styles.header}>
        <div className={styles.identity}>
          <h1 className={styles.name}>{t.patient.name}</h1>
          <p className={styles.sub}>
            <span>{e.programme_name}</span>
            <span className={styles.sep} aria-hidden="true" />
            <span>{t.patient.pseudonym}</span>
          </p>
        </div>
        <dl className={styles.facts}>
          <div>
            <dt>Status</dt>
            <dd>{enrolmentStatus[e.status]}</dd>
          </div>
          <div>
            <dt>Cost approval</dt>
            <dd>{e.cost_approval_ref ?? "Not yet approved"}</dd>
          </div>
          <div>
            <dt>Started</dt>
            <dd>{e.started_on ? formatDay(e.started_on, t.today) : "Not yet"}</dd>
          </div>
        </dl>
      </header>

      {e.deadlines.length > 0 && (
        <ul className={styles.deadlines} aria-label="DRV deadlines">
          {e.deadlines.map((d) => (
            <li key={d.code}>
              <Tag tone={severityTone(d.severity)}>{d.message}</Tag>
            </li>
          ))}
        </ul>
      )}

      <m.section className={styles.rulerBox} aria-label="Programme" initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: motion.base }}>
        <ProgrammeRuler enrolment={e} units={t.units} today={t.today} rehabEndedOn={t.patient.rehab_ended_on} />
      </m.section>

      <div className={styles.columns}>
        <div className={styles.main}>
          <CheckInList timeline={t} canDraft={user?.role === "therapist"} />
          <PainTrend units={t.units} />
        </div>
        <aside className={styles.side} aria-label="Drafts, plan and report">
          <DraftsPanel timeline={t} />
          <PlanPanel timeline={t} canDraft={user?.role === "therapist"} />
          <ClosingReportPanel timeline={t} role={user?.role} />
        </aside>
      </div>
    </div>
  );
}
