import { motion as m } from "framer-motion";

import type { Enrolment, Unit } from "../../shared/api/types";
import { daysBetween, formatDay, plural } from "../../shared/lib/format";
import { motion } from "../../shared/theme/motion";
import styles from "./ProgrammeRuler.module.css";
import { UnitStrip } from "./UnitStrip";

/**
 * The programme on one line: from the end of rehab to the last day the DRV allows, with the
 * window in which training should start, every training unit on the day it was done, and today.
 * A therapist sees at a glance whether a patient started in time, how regularly they train and
 * how much time is left.
 */
export function ProgrammeRuler({ enrolment, units, today, rehabEndedOn }: { enrolment: Enrolment; units: Unit[]; today: string; rehabEndedOn: string }) {
  const span = Math.max(daysBetween(rehabEndedOn, enrolment.latest_finish), 1);
  const at = (iso: string) => `${(Math.min(Math.max(daysBetween(rehabEndedOn, iso), 0), span) / span) * 100}%`;
  const width = (from: string, to: string) => `${(Math.max(daysBetween(from, to), 0) / span) * 100}%`;
  const todayInside = daysBetween(rehabEndedOn, today) >= 0 && daysBetween(today, enrolment.latest_finish) >= 0;

  const marks = [
    { key: "end", date: rehabEndedOn, label: "Rehab ended" },
    { key: "ideal", date: enrolment.ideal_start, label: "Start ideally by" },
    { key: "latest", date: enrolment.latest_start, label: "Start at the latest" },
    { key: "finish", date: enrolment.latest_finish, label: "Finish by" },
  ];

  return (
    <figure className={styles.ruler} aria-label={summary(enrolment, today)}>
      <div className={styles.head}>
        <UnitStrip done={enrolment.units_done} required={enrolment.units_required} />
        <p className={styles.count}>
          <strong>{enrolment.units_done}</strong> of {plural(enrolment.units_required, "unit")} of {enrolment.unit_minutes} minutes
        </p>
      </div>

      <div className={styles.track} aria-hidden="true">
        <span className={styles.bandIdeal} style={{ left: 0, width: width(rehabEndedOn, enrolment.ideal_start) }} />
        <span className={styles.bandLate} style={{ left: at(enrolment.ideal_start), width: width(enrolment.ideal_start, enrolment.latest_start) }} />
        {units.map((u, i) => (
          <m.span
            key={u.id}
            className={u.counts ? styles.unit : styles.unitShort}
            style={{ left: at(u.performed_on) }}
            initial={{ scaleY: 0, opacity: 0 }}
            animate={{ scaleY: 1, opacity: 1 }}
            transition={{ delay: motion.slow / 2 + i * motion.unitStagger, duration: motion.base, ease: motion.ease }}
            title={`${formatDay(u.performed_on)}: ${u.duration_minutes} min${u.counts ? "" : " (too short to count)"}`}
          />
        ))}
        {todayInside && (
          <m.span
            className={styles.today}
            style={{ left: at(today) }}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: motion.slow, duration: motion.base }}
          >
            <span className={styles.todayLabel}>Today</span>
          </m.span>
        )}
      </div>

      <ol className={styles.marks}>
        {marks.map((mk) => (
          <li key={mk.key} className={styles.mark} data-mark={mk.key} style={{ left: at(mk.date) }}>
            <span className={styles.markLabel}>{mk.label}</span>
            <time dateTime={mk.date}>{formatDay(mk.date, today)}</time>
          </li>
        ))}
      </ol>
    </figure>
  );
}

export function summary(e: Enrolment, today: string): string {
  const parts = [`${e.units_done} of ${e.units_required} units done.`];
  if (e.started_on) {
    const late = daysBetween(e.ideal_start, e.started_on) > 0;
    parts.push(`Started ${formatDay(e.started_on, today)}${late ? ", after the ideal start" : ", in the ideal window"}.`);
  } else {
    parts.push(`Not started; start at the latest by ${formatDay(e.latest_start, today)}.`);
  }
  parts.push(`Finish by ${formatDay(e.latest_finish, today)}.`);
  return parts.join(" ");
}
