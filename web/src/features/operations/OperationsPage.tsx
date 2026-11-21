import { useOps } from "../../shared/api/queries";
import { formatDayTime } from "../../shared/lib/format";
import { QueryView } from "../../shared/ui/states";
import { AlertList } from "./AlertList";
import { PromiseSection } from "./PromiseSection";
import { ReleaseGateSection } from "./ReleaseGateSection";
import { Drafts, Jobs, ModelCalls } from "./Tables";
import styles from "./Operations.module.css";

/** How the clinic's aftercare is running: replies on time, jobs moving, model cost and speed, release decisions. */
export function OperationsPage() {
  const query = useOps();
  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <h1 className={styles.title}>Operations</h1>
        <p className={styles.lead}>
          Counts, times and costs only. No patient and nothing a patient wrote appears on this page.
          {query.data && ` Last ${query.data.window.days} days, updated ${formatDayTime(query.data.generated_at)}.`}
        </p>
      </header>
      <QueryView query={query} what="the operations view" lines={10}>
        {(d) => (
          <>
            <AlertList alerts={d.alerts} />
            <PromiseSection c={d.check_ins} target={d.targets.check_in_share} today={d.generated_at} />
            <ReleaseGateSection releases={d.releases} margin={d.targets.release_margin} minReviews={d.targets.release_min_reviews} />
            <Drafts drafts={d.drafts} />
            <ModelCalls models={d.models} days={d.window.days} />
            <Jobs queue={d.queue} />
          </>
        )}
      </QueryView>
    </div>
  );
}
