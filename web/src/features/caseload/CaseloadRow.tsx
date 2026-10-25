import { motion as m } from "framer-motion";
import { Link } from "react-router-dom";

import type { CaseloadRow as Row } from "../../shared/api/types";
import { formatDay, plural } from "../../shared/lib/format";
import { claimStatus, deadlineText, enrolmentStatus, programmeShort } from "../../shared/lib/labels";
import { motion } from "../../shared/theme/motion";
import { Tag, severityTone } from "../../shared/ui/Tag";
import { UnitStrip } from "../programme/UnitStrip";
import styles from "./CaseloadRow.module.css";

export function CaseloadRow({ row, today, canOpen = true }: { row: Row; today: string; canOpen?: boolean }) {
  const e = row.enrolment;
  const level =
    row.escalations > 0 || e?.deadlines.some((d) => d.severity === "blocking")
      ? "emergency"
      : row.overdue > 0 || e?.deadlines.some((d) => d.severity === "urgent")
        ? "urgent"
        : "none";
  const name = (
    <>
      <span className={styles.name}>{row.name}</span>
      <span className={styles.pseudonym}>{row.pseudonym}</span>
    </>
  );
  return (
    <m.li
      className={styles.row}
      data-level={level}
      variants={{ hidden: { opacity: 0, y: 4 }, shown: { opacity: 1, y: 0 } }}
      transition={{ duration: motion.base, ease: motion.ease }}
    >
      <div className={styles.who}>
        {e && canOpen ? (
          <Link to={`/enrolments/${e.id}`} className={styles.link}>
            {name}
          </Link>
        ) : (
          name
        )}
        <span className={styles.meta}>
          {capitalise(row.indication)}, rehab ended {formatDay(row.rehab_ended_on, today)}
        </span>
      </div>

      {e ? (
        <>
          <div className={styles.programme}>
            <span className={styles.programmeName}>{programmeShort(e.programme)}</span>
            <span className={styles.status}>{enrolmentStatus[e.status]}</span>
          </div>
          <div className={styles.progress}>
            <UnitStrip done={e.units_done} required={e.units_required} />
            <span className={styles.units}>
              {e.units_done}/{e.units_required}
            </span>
          </div>
        </>
      ) : (
        <p className={styles.none}>No programme yet</p>
      )}

      <ul className={styles.signals} aria-label="What needs attention">
        {row.escalations > 0 && (
          <li>
            <Tag tone="emergency">{plural(row.escalations, "red flag")}</Tag>
          </li>
        )}
        {row.overdue > 0 ? (
          <li>
            <Tag tone="urgent">{plural(row.overdue, "check-in")} past the answer time</Tag>
          </li>
        ) : row.unanswered > 0 ? (
          <li>
            <Tag tone="accent">{plural(row.unanswered, "check-in")} to answer</Tag>
          </li>
        ) : null}
        {e?.deadlines.map((d) => (
          <li key={d.code}>
            <Tag tone={severityTone(d.severity)} title={d.message}>
              {deadlineText(d.code, d.due_on, (iso) => formatDay(iso, today))}
            </Tag>
          </li>
        ))}
        {e?.claim_status && (
          <li>
            <Tag tone="neutral">Claim: {claimStatus[e.claim_status].toLowerCase()}</Tag>
          </li>
        )}
      </ul>
    </m.li>
  );
}

const capitalise = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
