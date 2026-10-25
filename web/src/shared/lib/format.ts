/** Dates and words as the console shows them. Dates are ISO strings from the API (Europe/Berlin). */

const day = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short" });
const dayYear = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short", year: "numeric" });
const dayTime = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
const longDay = new Intl.DateTimeFormat("en-GB", { weekday: "long", day: "numeric", month: "long" });

/** "2026-10-25" → a Date at local noon, so no time zone can move it to another day. */
export function parseDay(iso: string): Date {
  const [y, m, d] = iso.slice(0, 10).split("-").map(Number);
  return new Date(y ?? 1970, (m ?? 1) - 1, d ?? 1, 12);
}

export const daysBetween = (from: string, to: string) => Math.round((parseDay(to).getTime() - parseDay(from).getTime()) / 86_400_000);

export function formatDay(iso: string | null | undefined, today?: string): string {
  if (!iso) return "";
  const date = parseDay(iso);
  const sameYear = !today || parseDay(today).getFullYear() === date.getFullYear();
  return (sameYear ? day : dayYear).format(date);
}

export const formatLongDay = (iso: string) => longDay.format(parseDay(iso));
export const formatDayTime = (iso: string) => dayTime.format(new Date(iso));

/** "in 12 days", "today", "3 days ago" */
export function relativeDays(iso: string, today: string): string {
  const n = daysBetween(today, iso);
  if (n === 0) return "today";
  if (n === 1) return "tomorrow";
  if (n === -1) return "yesterday";
  return n > 0 ? `in ${n} days` : `${-n} days ago`;
}

export const plural = (n: number, one: string, many = `${one}s`) => `${n} ${n === 1 ? one : many}`;
