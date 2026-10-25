import type { ReactNode } from "react";

import styles from "./Tag.module.css";

export type Tone = "emergency" | "urgent" | "ok" | "accent" | "neutral";

/** A short status word. The tone is also written out for screen readers, never colour alone. */
export function Tag({ tone = "neutral", children, title }: { tone?: Tone; children: ReactNode; title?: string }) {
  return (
    <span className={`${styles.tag} ${styles[tone]}`} title={title}>
      {children}
    </span>
  );
}

export const severityTone = (s: string): Tone =>
  s === "emergency" || s === "blocking" ? "emergency" : s === "urgent" || s === "warning" ? "urgent" : s === "notice" ? "accent" : "neutral";
