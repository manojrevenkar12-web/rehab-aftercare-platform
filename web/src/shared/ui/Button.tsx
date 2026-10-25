import { motion as m } from "framer-motion";
import type { ButtonHTMLAttributes } from "react";

import { motion } from "../theme/motion";
import styles from "./Button.module.css";

type Props = Omit<ButtonHTMLAttributes<HTMLButtonElement>, "onAnimationStart" | "onDrag" | "onDragStart" | "onDragEnd"> & {
  variant?: "primary" | "quiet" | "danger";
  busy?: boolean;
};

/** The console's one button. `busy` keeps its width and says what is happening to screen readers. */
export function Button({ variant = "quiet", busy = false, disabled, children, className, ...rest }: Props) {
  return (
    <m.button
      type="button"
      {...rest}
      className={[styles.button, styles[variant], className].filter(Boolean).join(" ")}
      disabled={disabled || busy}
      aria-busy={busy || undefined}
      whileTap={disabled || busy ? undefined : { scale: 0.97 }}
      transition={{ duration: motion.fast }}
    >
      {children}
    </m.button>
  );
}
