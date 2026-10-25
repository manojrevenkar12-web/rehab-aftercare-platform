import { useAudit } from "../../shared/api/queries";
import { formatDayTime } from "../../shared/lib/format";
import { EmptyState, QueryView } from "../../shared/ui/states";
import styles from "./AuditPage.module.css";

/** The clinic's audit trail, newest first, with the result of checking the hash chain. */
export function AuditPage() {
  const query = useAudit();
  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <h1 className={styles.title}>Audit trail</h1>
        <p className={styles.lead}>
          Every access to clinical data, every AI draft and every billing step. Events cannot be changed or deleted, and each
          one carries the hash of the one before it.
        </p>
      </header>
      <QueryView query={query} what="the audit trail" lines={8} isEmpty={(d) => d.events.length === 0} empty={<EmptyState title="No events yet" />}>
        {(d) => (
          <>
            <p className={d.chain_broken_at ? styles.broken : styles.intact} role="status">
              {d.chain_broken_at
                ? `The chain is broken at event ${d.chain_broken_at}: an event was changed outside the application. Tell the data protection officer.`
                : "Chain intact: every event links to the one before it."}
            </p>
            <div className={styles.scroll}>
              <table className={styles.table}>
                <caption className="visually-hidden">Latest 200 audit events</caption>
                <thead>
                  <tr>
                    <th scope="col">When</th>
                    <th scope="col">Who</th>
                    <th scope="col">What</th>
                    <th scope="col">On</th>
                    <th scope="col">Hash</th>
                  </tr>
                </thead>
                <tbody>
                  {d.events.map((e) => (
                    <tr key={e.id}>
                      <td>{formatDayTime(e.at)}</td>
                      <td>{e.actor ?? "System"}</td>
                      <td>{e.action.replace(/[._]/g, " ")}</td>
                      <td>{e.subject}</td>
                      <td className={styles.hash}>{e.digest}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}
      </QueryView>
    </div>
  );
}
