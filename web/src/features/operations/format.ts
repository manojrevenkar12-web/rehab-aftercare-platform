/** Numbers as the operations view shows them. Missing values are a dash, never a zero. */

export const DASH = "–";

export function pct(x: number | null | undefined, digits = 0): string {
  return x == null ? DASH : `${(x * 100).toFixed(digits)}%`;
}

/** A difference between two shares, in percentage points with a sign. */
export function points(x: number | null | undefined): string {
  if (x == null) return DASH;
  const v = x * 100;
  return `${v > 0 ? "+" : v < 0 ? "−" : "±"}${Math.abs(v).toFixed(1)} pts`;
}

export function hours(h: number | null | undefined): string {
  if (h == null) return DASH;
  return h < 1 ? `${Math.round(h * 60)} min` : `${h.toFixed(h < 10 ? 1 : 0)} h`;
}

export function seconds(ms: number | null | undefined): string {
  return ms == null ? DASH : `${(ms / 1000).toFixed(1)} s`;
}

const eur = new Intl.NumberFormat("en-GB", { style: "currency", currency: "EUR", minimumFractionDigits: 2, maximumFractionDigits: 2 });
const eurSmall = new Intl.NumberFormat("en-GB", { style: "currency", currency: "EUR", minimumFractionDigits: 4, maximumFractionDigits: 4 });

/** Cents for totals; four decimals for the price of one call, which is a fraction of a cent. */
export function euros(x: number | null | undefined, { small = false } = {}): string {
  return x == null ? DASH : (small ? eurSmall : eur).format(x);
}

const count = new Intl.NumberFormat("en-GB");
export const num = (x: number | null | undefined) => (x == null ? DASH : count.format(x));

export const plural = (n: number, one: string, many = `${one}s`) => `${n} ${n === 1 ? one : many}`;

export const taskName: Record<string, string> = {
  check_in_reply: "Reply to check-in",
  check_in_screen: "Check-in screen",
  closing_report: "Closing report",
  plan_change: "Plan change",
};
