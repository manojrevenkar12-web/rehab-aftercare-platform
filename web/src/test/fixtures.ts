import type { CaseloadRow, Claim, Draft, Enrolment, OpsSnapshot, Timeline, User } from "../shared/api/types";

/** Invented data in the API's shapes. */
export const therapist: User = { id: 1, name: "Theo Brandt", email: "theo@demo.example", role: "therapist", clinic: "Reha-Zentrum Spreebogen (demo)" };
export const billing: User = { ...therapist, id: 3, name: "Bea Kowalski", email: "bea@demo.example", role: "billing" };
export const admin: User = { ...therapist, id: 4, name: "Ada Nowak", email: "ada@demo.example", role: "clinic_admin" };

export const enrolment = (over: Partial<Enrolment> = {}): Enrolment => ({
  id: 7,
  programme: "t_rena_digital",
  programme_name: "T-RENA digital (training therapy, individual)",
  status: "active",
  units_done: 14,
  units_required: 18,
  unit_minutes: 20,
  cost_approval_ref: "G4802-2026-1000",
  started_on: "2026-08-20",
  completed_on: null,
  ended_on: null,
  end_reason: null,
  ideal_start: "2026-09-17",
  latest_start: "2026-11-06",
  latest_finish: "2027-08-06",
  deadlines: [],
  claim_status: null,
  ...over,
});

export const row = (over: Partial<CaseloadRow> = {}): CaseloadRow => ({
  id: 1,
  pseudonym: "P-AB12CD34",
  name: "Anna Becker",
  indication: "orthopaedics",
  rehab_ended_on: "2026-08-06",
  enrolment: enrolment(),
  escalations: 0,
  unanswered: 0,
  overdue: 0,
  attention: 0,
  ...over,
});

export const draft = (over: Partial<Draft> = {}): Draft => ({
  id: 41,
  kind: "check_in_reply",
  status: "ready",
  model: "simulated-1",
  prompt_version: "check-in-reply/3",
  output: { check_in_id: 5, summary: "Pain 4/10; 14 of 18 units done.", reply: "Vielen Dank für Ihre Rückmeldung.", questions: [] },
  findings: [],
  error: null,
  created_at: "2026-10-25T09:00:00+02:00",
  reviewed_at: null,
  reviewed_by: null,
  ...over,
});

export const timeline = (over: Partial<Timeline> = {}): Timeline => ({
  today: "2026-10-25",
  enrolment: enrolment(),
  patient: { id: 1, pseudonym: "P-AB12CD34", name: "Anna Becker", indication: "orthopaedics", rehab_ended_on: "2026-08-06" },
  units: [
    { id: 1, performed_on: "2026-08-20", duration_minutes: 20, source: "patient_app", counts: true, pain_before: 6, pain_after: 4, effort: 4, note: null },
    { id: 2, performed_on: "2026-08-24", duration_minutes: 12, source: "patient_app", counts: false, pain_before: 6, pain_after: 3, effort: 4, note: null },
  ],
  check_ins: [
    {
      id: 5,
      submitted_at: "2026-10-24T21:00:00+02:00",
      pain_score: 4,
      message: "Seit gestern Druck auf der Brust beim Training. Meine Frau ist auch gestürzt.",
      status: "escalated",
      red_flags: [{ code: "chest_pain", severity: "emergency", evidence: "Druck auf der Brust" }],
      set_aside: [{ code: "fall", severity: "urgent", evidence: "Meine Frau ist auch gestürzt", reason: "someone_else" }],
      screen: null,
    },
  ],
  drafts: [],
  plan: [{ exercise_key: "bridging", name: "Bridging", level: 1, sets: 2, reps: 10, per_week: 3 }],
  closing_report: null,
  ...over,
});

export const claim = (over: Partial<Claim> = {}): Claim => ({
  id: 9,
  number: "RN-260999001-0000002",
  status: "ready",
  amount: "450.00",
  currency: "EUR",
  units_billed: 18,
  patient: "P-JH55XY01",
  programme: "t_rena_digital",
  enrolment_id: 2,
  problems: [],
  updated_at: "2026-10-25T10:00:00+02:00",
  rate_source: "placeholder (illustrative, not the DRV rate)",
  ...over,
});

const cohort = (label: string, reviewed: number, rejected: number, edited: number) => {
  const [prompt_version = "", model = ""] = label.split(" · ");
  return { prompt_version, model, label, generated: reviewed, held_by_checks: 0, reviewed, rejected, edited, unchanged: reviewed - rejected - edited, first_seen: "2026-10-01T10:00:00+02:00" };
};

export const ops = (over: Partial<OpsSnapshot> = {}): OpsSnapshot => ({
  clinic: { id: 1, name: "Reha-Zentrum Spreebogen (demo)" },
  generated_at: "2026-11-21T10:00:00+01:00",
  window: { from: "2026-11-07T00:00:00+01:00", to: "2026-11-21T10:00:00+01:00", days: 14 },
  targets: { check_in_share: 0.95, release_min_reviews: 40, release_margin: 0.05 },
  check_ins: {
    promise_hours: 24, submitted: 24, due: 21, met: 18, share_met: 18 / 21, hours_to_answer: { median: 5.2, p90: 27.4 },
    open: 4, open_escalated: 2, open_overdue: 1, oldest_open_hours: 30,
    by_day: [
      { date: "2026-11-19", submitted: 2, on_time: 2, late: 0 },
      { date: "2026-11-20", submitted: 2, on_time: 1, late: 1 },
      { date: "2026-11-21", submitted: 1, on_time: 0, late: 0 },
    ],
  },
  drafts: [
    { kind: "check_in_reply", generated: 22, held_by_checks: 1, waiting_review: 2, approved_unchanged: 17, approved_edited: 3, rejected: 0, failed: 0, share_unchanged: 0.85, median_review_minutes: 290 },
  ],
  models: {
    tasks: [
      { task: "check_in_reply", prompt_version: "check-in-reply/3", calls: 23, errors: 1, refused: 0, error_share: 1 / 23, latency_ms: { p50: 2800, p95: 5900 },
        input_tokens: 20_100, output_tokens: 5_900, tokens_estimated: true, cost_eur: 0.019, cost_per_call_eur: 0.00083 },
    ],
    cost_eur: 0.019,
    cost_by_day: [{ date: "2026-11-21", cost_eur: 0.002 }],
    models_used: ["simulated-1"],
    unpriced_models: [],
  },
  queue: { queues: [{ queue: "ai", ready: 0, scheduled: 0, running: 0, oldest_ready_minutes: null }], failed: [], workers_alive: 1 },
  releases: [
    { kind: "check_in_reply", decision: "pass", reasons: ["rejected 6.1% → 3.5% (worst case +2.2 points, margin +5.0 points)"],
      metrics: { rejected: { baseline: 0.061, candidate: 0.035, difference: -0.026, low: -0.07, high: 0.022 }, needed_changes: { baseline: 0.361, candidate: 0.212, difference: -0.149, low: -0.24, high: -0.05 } },
      baseline: cohort("check-in-reply/2 · simulated-1", 180, 11, 54), candidate: cohort("check-in-reply/3 · simulated-1", 170, 6, 30) },
    { kind: "plan_change", decision: "block", reasons: ["rejected rose from 7.8% to 25.0% (95% interval of the rise +5.4 points to +29.6 points)"],
      metrics: { rejected: { baseline: 0.078, candidate: 0.25, difference: 0.172, low: 0.054, high: 0.296 }, needed_changes: { baseline: 0.278, candidate: 0.55, difference: 0.272, low: 0.11, high: 0.42 } },
      baseline: cohort("plan-change/2 · simulated-1", 90, 7, 18), candidate: cohort("plan-change/2 · simulated-1-mini", 60, 15, 18) },
  ],
  alerts: [
    { level: "critical", code: "release_blocked", message: "plan change: plan-change/2 · simulated-1-mini is worse than plan-change/2 · simulated-1" },
    { level: "warning", code: "check_ins_overdue", message: "1 check-in waiting longer than 24 h" },
  ],
  ...over,
});
