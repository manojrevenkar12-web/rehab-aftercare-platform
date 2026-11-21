export type Role = "clinic_admin" | "physician" | "therapist" | "billing" | "patient";
export type Severity = "blocking" | "urgent" | "notice";

export interface User {
  id: number;
  name: string;
  email: string;
  role: Role;
  clinic: string;
}

export interface DeadlineFinding {
  code: string;
  severity: Severity;
  due_on: string;
  message: string;
}

export type EnrolmentStatus = "referred" | "approved" | "active" | "completed" | "ended_early" | "expired";

export interface Enrolment {
  id: number;
  programme: string;
  programme_name: string;
  status: EnrolmentStatus;
  units_done: number;
  units_required: number;
  unit_minutes: number;
  cost_approval_ref: string | null;
  started_on: string | null;
  completed_on: string | null;
  ended_on: string | null;
  end_reason: string | null;
  ideal_start: string;
  latest_start: string;
  latest_finish: string;
  deadlines: DeadlineFinding[];
  claim_status: ClaimStatus | null;
}

export interface CaseloadRow {
  id: number;
  pseudonym: string;
  name: string;
  indication: string;
  rehab_ended_on: string;
  enrolment: Enrolment | null;
  escalations: number;
  /** check-ins nobody has answered yet, and those past the answer-within SLA */
  unanswered: number;
  overdue: number;
  attention: number;
}

export interface Caseload {
  patients: CaseloadRow[];
  today: string;
}

export interface RedFlag {
  code: string;
  severity: "emergency" | "urgent";
  evidence: string;
  /** "model" when the model screen added it; rules otherwise */
  source?: "model";
}

export type SetAsideReason = "someone_else" | "past" | "fear" | "near_miss" | "resolved" | "hearsay" | "usual_exertion";

/** A rule hit the context set aside: shown, not escalated. */
export interface SetAside {
  code: string;
  severity: "emergency" | "urgent";
  evidence: string;
  reason: SetAsideReason;
}

export interface CheckIn {
  id: number;
  submitted_at: string;
  pain_score: number;
  message: string;
  status: "new" | "escalated" | "answered";
  red_flags: RedFlag[];
  set_aside: SetAside[];
  screen: { model?: string; added?: string[]; error?: string } | null;
}

export interface Unit {
  id: number;
  performed_on: string;
  duration_minutes: number;
  source: "patient_app" | "therapist";
  counts: boolean;
  pain_before: number | null;
  pain_after: number | null;
  effort: number | null;
  note: string | null;
}

export type DraftKind = "check_in_reply" | "closing_report" | "plan_change";
export type DraftStatus = "queued" | "ready" | "held" | "failed" | "approved" | "rejected";

export interface Finding {
  code: string;
  severity: "blocking" | "warning";
  message: string;
}

export interface PlanChange {
  action: "add" | "remove" | "modify";
  exercise_key: string;
  sets: number;
  reps: number;
  per_week: number;
  reason: string;
}

export interface Draft {
  id: number;
  kind: DraftKind;
  status: DraftStatus;
  model: string | null;
  prompt_version: string;
  output: {
    check_in_id?: number;
    summary?: string;
    reply?: string;
    acknowledged_flags?: string[];
    questions?: string[];
    course?: string;
    outcome?: string;
    adherence?: string;
    recommendation?: string;
    changes?: PlanChange[];
    rationale?: string;
  };
  findings: Finding[];
  error: string | null;
  created_at: string;
  reviewed_at: string | null;
  reviewed_by: string | null;
}

export interface PlanItem {
  exercise_key: string;
  name: string;
  level: number;
  sets: number;
  reps: number;
  per_week: number;
}

export interface ClosingReport {
  id: number;
  sections: Record<"course" | "outcome" | "adherence" | "recommendation", string>;
  signed: boolean;
  signed_at: string | null;
  signed_by: string | null;
  from_draft: number | null;
}

export interface Timeline {
  today: string;
  enrolment: Enrolment;
  patient: { id: number; pseudonym: string; name: string; indication: string; rehab_ended_on: string };
  units: Unit[];
  check_ins: CheckIn[];
  drafts: Draft[];
  plan: PlanItem[];
  closing_report: ClosingReport | null;
}

export type ClaimStatus = "draft" | "ready" | "submitted" | "paid" | "rejected" | "needs_review";

export interface Problem {
  code: string;
  message: string;
  severity: "blocking" | "info";
}

export interface Claim {
  id: number;
  number: string;
  status: ClaimStatus;
  amount: string;
  currency: string;
  units_billed: number;
  patient: string;
  programme: string;
  enrolment_id: number;
  problems: Problem[];
  updated_at: string;
  rate_source: string | null;
  documents?: Record<string, unknown>;
  rejection_reason?: string | null;
}

export interface AuditEvent {
  id: number;
  action: string;
  actor: string | null;
  subject: string | null;
  data: Record<string, unknown>;
  at: string;
  digest: string;
}

export interface AuditLog {
  events: AuditEvent[];
  chain_broken_at: number | null;
}

// --- operations (GET /api/v1/ops) ----------------------------------------------------------

export type ReleaseDecision = "pass" | "wait" | "block";

export interface ReleaseCohort {
  prompt_version: string;
  model: string;
  label: string;
  generated: number;
  held_by_checks: number;
  reviewed: number;
  rejected: number;
  edited: number;
  unchanged: number;
  first_seen: string | null;
}

export interface ReleaseMetric {
  baseline: number | null;
  candidate: number | null;
  difference: number | null;
  low: number | null;
  high: number | null;
}

export interface ReleaseVerdict {
  kind: DraftKind;
  decision: ReleaseDecision;
  reasons: string[];
  metrics: Partial<Record<"rejected" | "needed_changes", ReleaseMetric>>;
  baseline: ReleaseCohort | null;
  candidate: ReleaseCohort | null;
}

export interface OpsAlert {
  level: "critical" | "warning";
  code: string;
  message: string;
}

export interface OpsSnapshot {
  clinic: { id: number; name: string };
  generated_at: string;
  window: { from: string; to: string; days: number };
  targets: { check_in_share: number; release_min_reviews: number; release_margin: number };
  check_ins: {
    promise_hours: number;
    submitted: number;
    due: number;
    met: number;
    share_met: number | null;
    hours_to_answer: { median: number | null; p90: number | null };
    open: number;
    open_escalated: number;
    open_overdue: number;
    oldest_open_hours: number | null;
    by_day: { date: string; submitted: number; on_time: number; late: number }[];
  };
  drafts: {
    kind: DraftKind;
    generated: number;
    held_by_checks: number;
    waiting_review: number;
    approved_unchanged: number;
    approved_edited: number;
    rejected: number;
    failed: number;
    share_unchanged: number | null;
    median_review_minutes: number | null;
  }[];
  models: {
    tasks: {
      task: string;
      prompt_version: string | null;
      calls: number;
      errors: number;
      refused: number;
      error_share: number | null;
      latency_ms: { p50: number | null; p95: number | null };
      input_tokens: number;
      output_tokens: number;
      tokens_estimated: boolean;
      cost_eur: number;
      cost_per_call_eur: number | null;
    }[];
    cost_eur: number;
    cost_by_day: { date: string; cost_eur: number }[];
    models_used: string[];
    unpriced_models: string[];
  };
  queue: {
    queues: { queue: string; ready: number; scheduled: number; running: number; oldest_ready_minutes: number | null }[];
    failed: { job: string; count: number; last_failed_at: string | null }[];
    workers_alive: number;
  };
  releases: ReleaseVerdict[];
  alerts: OpsAlert[];
}
