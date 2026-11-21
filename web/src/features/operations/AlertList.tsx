import type { OpsAlert } from "../../shared/api/types";
import styles from "./Operations.module.css";

/** What needs a person now, worst first. The level is written out, not only coloured. */
export function AlertList({ alerts }: { alerts: OpsAlert[] }) {
  if (alerts.length === 0) {
    return (
      <p className={styles.allClear} role="status">
        Nothing needs attention: check-ins are answered on time, jobs are moving and no release is blocked.
      </p>
    );
  }
  return (
    <section aria-labelledby="alerts-title" className={styles.alerts}>
      <h2 id="alerts-title" className="visually-hidden">
        Needs attention
      </h2>
      <ul className={styles.alertList}>
        {alerts.map((a) => (
          <li key={`${a.code}-${a.message}`} className={styles.alert} data-level={a.level}>
            <span className={styles.alertLevel}>{a.level === "critical" ? "Act now" : "Look today"}</span>
            <span>{a.message}</span>
          </li>
        ))}
      </ul>
    </section>
  );
}
