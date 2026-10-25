import type { ClaimStatus, DraftKind, DraftStatus, EnrolmentStatus, Role, SetAsideReason } from "../api/types";

/** Plain names for codes the API sends. One place, so a word means the same thing everywhere. */

export const flagName: Record<string, string> = {
  chest_pain: "Chest pain",
  breathlessness: "Breathlessness",
  neurological: "Neurological signs",
  self_harm: "Thoughts of self-harm",
  fall: "Fall",
  wound_or_fever: "Wound or fever",
  severe_pain: "Severe pain",
  pain_jump: "Pain went up",
};

export const setAsideReason: Record<SetAsideReason, string> = {
  someone_else: "about someone else",
  past: "about the past",
  fear: "a worry, not an event",
  near_miss: "a near miss",
  resolved: "already over",
  hearsay: "something read or heard",
  usual_exertion: "their usual exertion",
};

export const roleName: Record<Role, string> = {
  clinic_admin: "Clinic admin",
  physician: "Physician",
  therapist: "Therapist",
  billing: "Billing",
  patient: "Patient",
};

export const enrolmentStatus: Record<EnrolmentStatus, string> = {
  referred: "Referred",
  approved: "Approved, not started",
  active: "In training",
  completed: "Completed",
  ended_early: "Ended early",
  expired: "Expired",
};

export const draftKind: Record<DraftKind, string> = {
  check_in_reply: "Reply to check-in",
  closing_report: "Closing report",
  plan_change: "Plan change",
};

export const draftStatus: Record<DraftStatus, string> = {
  queued: "Drafting",
  ready: "Ready for review",
  held: "Held by checks",
  failed: "Failed",
  approved: "Approved",
  rejected: "Rejected",
};

export const claimStatus: Record<ClaimStatus, string> = {
  draft: "Missing documents",
  needs_review: "Needs a decision",
  ready: "Ready to submit",
  submitted: "Submitted",
  paid: "Paid",
  rejected: "Rejected",
};

/** "t_rena_digital" → "T-RENA" */
export function programmeShort(code: string): string {
  const base = code.replace(/_digital$/, "");
  return base === "psy_rena" ? "Psy-RENA" : base.replace("_", "-").toUpperCase();
}

export const closingSections = ["course", "outcome", "adherence", "recommendation"] as const;
export const closingSectionName: Record<(typeof closingSections)[number], string> = {
  course: "Course of aftercare",
  outcome: "Outcome",
  adherence: "Adherence",
  recommendation: "Recommendation",
};

/** A deadline finding in a few words: "Start by 6 Nov". */
export function deadlineText(code: string, dueOn: string, fmt: (iso: string) => string): string {
  switch (code) {
    case "start_missed":
      return "Start window missed";
    case "start_due":
      return `Start by ${fmt(dueOn)}`;
    case "start_late":
      return `Late start, by ${fmt(dueOn)}`;
    case "break_exceeded":
      return "Break limit passed";
    case "break_long":
      return `Break limit on ${fmt(dueOn)}`;
    case "finish_missed":
      return "Finish date passed";
    case "finish_due":
      return `Finish by ${fmt(dueOn)}`;
    default:
      return code.replace(/_/g, " ");
  }
}
