/**
 * Splits a patient's message into plain and marked parts, marking each red flag's evidence (the
 * words the rule matched) so the therapist sees why it was escalated. Case-insensitive; the first
 * occurrence of each evidence string is marked; overlapping marks keep the earlier one.
 */
export interface Part {
  text: string;
  mark?: { code: string; severity: string };
}

export function highlight(message: string, marks: { evidence: string; code: string; severity: string }[]): Part[] {
  const lower = message.toLowerCase();
  const spans = marks
    .map((m) => ({ ...m, start: m.evidence ? lower.indexOf(m.evidence.toLowerCase()) : -1 }))
    .filter((m) => m.start >= 0)
    .map((m) => ({ ...m, end: m.start + m.evidence.length }))
    .sort((a, b) => a.start - b.start);

  const parts: Part[] = [];
  let at = 0;
  for (const s of spans) {
    if (s.start < at) continue;
    if (s.start > at) parts.push({ text: message.slice(at, s.start) });
    parts.push({ text: message.slice(s.start, s.end), mark: { code: s.code, severity: s.severity } });
    at = s.end;
  }
  if (at < message.length) parts.push({ text: message.slice(at) });
  return parts;
}
