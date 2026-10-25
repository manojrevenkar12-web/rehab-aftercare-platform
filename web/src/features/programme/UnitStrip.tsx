import styles from "./UnitStrip.module.css";

/** One square per unit the programme requires; done ones filled. Reads as "14 of 18 units". */
export function UnitStrip({ done, required }: { done: number; required: number }) {
  // 18 units on one row; longer programmes (24, 36, 42) on two even rows
  const perRow = required <= 18 ? required : Math.ceil(required / 2);
  return (
    <span className={styles.strip} role="img" aria-label={`${done} of ${required} units done`} style={{ gridTemplateColumns: `repeat(${perRow}, var(--unit-size))` }}>
      {Array.from({ length: required }, (_, i) => (
        <span key={i} className={i < done ? styles.done : styles.todo} />
      ))}
    </span>
  );
}
