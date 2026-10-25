import type { PlanChange } from "../../shared/api/types";
import styles from "./DraftCard.module.css";

const verb: Record<PlanChange["action"], string> = { add: "Add", remove: "Remove", modify: "Change" };

export function PlanChanges({ changes }: { changes: PlanChange[] }) {
  if (changes.length === 0) return <p className={styles.prose}>The model suggests no change to the plan.</p>;
  return (
    <table className={styles.changes}>
      <caption className="visually-hidden">Suggested plan changes</caption>
      <thead>
        <tr>
          <th scope="col">Change</th>
          <th scope="col">Exercise</th>
          <th scope="col">Dose</th>
          <th scope="col">Reason</th>
        </tr>
      </thead>
      <tbody>
        {changes.map((c, i) => (
          <tr key={`${c.exercise_key}-${i}`}>
            <td>{verb[c.action]}</td>
            <td>{c.exercise_key.replace(/_/g, " ")}</td>
            <td>{c.action === "remove" ? "" : `${c.sets} × ${c.reps}, ${c.per_week}/week`}</td>
            <td>{c.reason}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
