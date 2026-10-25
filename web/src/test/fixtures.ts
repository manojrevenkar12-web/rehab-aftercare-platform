import type { CaseloadRow, Claim, Draft, Enrolment, Timeline, User } from "../shared/api/types";

/** Invented data in the API's shapes. */
export const therapist: User = { id: 1, name: "Theo Brandt", email: "theo@demo.example", role: "therapist", clinic: "Reha-Zentrum Spreebogen (demo)" };
export const billing: User = { ...therapist, id: 3, name: "Bea Kowalski", email: "bea@demo.example", role: "billing" };

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
