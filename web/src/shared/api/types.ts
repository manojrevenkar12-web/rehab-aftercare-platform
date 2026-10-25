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
}

export interface CheckIn {
  id: number;
  submitted_at: string;
  pain_score: number;
  message: string;
  status: "new" | "escalated" | "answered";
  red_flags: RedFlag[];
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
  enrolment: Enrolment;
  patient: { id: number; pseudonym: string; name: string; indication: string };
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
  documents?: Record<string, unknown>;
  rejection_reason?: string | null;
}
