/** Motion constants. Durations in seconds (Framer Motion's unit). */
export const motion = {
  fast: 0.14,
  base: 0.22,
  slow: 0.4,
  unitStagger: 0.018,
  ease: [0.2, 0.8, 0.2, 1] as const,
  spring: { type: "spring", stiffness: 420, damping: 32 } as const,
};
