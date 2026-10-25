import type { AuditLog, Caseload, Claim, Draft, DraftKind, Timeline, User } from "./types";

export class ApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

const TOKEN_KEY = "aftercare.token";

/** The session token lives in sessionStorage: it dies with the tab, and never in a cookie. */
export const session = {
  get(): string | null {
    try {
      return sessionStorage.getItem(TOKEN_KEY);
    } catch {
      return null;
    }
  },
  set(token: string | null) {
    try {
      if (token) sessionStorage.setItem(TOKEN_KEY, token);
      else sessionStorage.removeItem(TOKEN_KEY);
    } catch {
      /* storage blocked: the session lasts until reload */
    }
  },
};

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = session.get();
  const headers = new Headers(init.headers);
  headers.set("Accept", "application/json");
  if (init.body) headers.set("Content-Type", "application/json");
  if (token) headers.set("Authorization", `Bearer ${token}`);
  let res: Response;
  try {
    res = await fetch(path, { ...init, headers });
  } catch {
    throw new ApiError(0, "The aftercare API did not answer.");
  }
  if (res.status === 204) return undefined as T;
  const body = (await res.json().catch(() => ({}))) as { error?: string };
  if (!res.ok) throw new ApiError(res.status, body.error || `HTTP ${res.status}`);
  return body as T;
}

const post = <T>(path: string, body?: unknown) => request<T>(path, { method: "POST", body: body === undefined ? undefined : JSON.stringify(body) });

export const api = {
  signIn: (email: string, password: string) => post<{ token: string; user: User }>("/api/v1/session", { email, password }),
  signOut: () => request<void>("/api/v1/session", { method: "DELETE" }),
  me: () => request<{ user: User }>("/api/v1/session"),
  caseload: () => request<Caseload>("/api/v1/caseload"),
  timeline: (enrolmentId: number) => request<Timeline>(`/api/v1/enrolments/${enrolmentId}/timeline`),
  requestDraft: (enrolmentId: number, kind: DraftKind, checkInId?: number) =>
    post<Draft>(`/api/v1/enrolments/${enrolmentId}/drafts`, { kind, check_in_id: checkInId }),
  draft: (id: number) => request<Draft>(`/api/v1/drafts/${id}`),
  approveDraft: (id: number, edits?: Record<string, unknown>) => post<Draft>(`/api/v1/drafts/${id}/approve`, edits ? { edits } : {}),
  rejectDraft: (id: number, reason: string) => post<Draft>(`/api/v1/drafts/${id}/reject`, { reason }),
  signClosingReport: (enrolmentId: number) => post<unknown>(`/api/v1/enrolments/${enrolmentId}/closing_report/sign`),
  claims: () => request<{ claims: Claim[] }>("/api/v1/claims"),
  assembleClaim: (enrolmentId: number) => post<Claim>(`/api/v1/enrolments/${enrolmentId}/claim/assemble`),
  submitClaim: (id: number) => post<Claim>(`/api/v1/claims/${id}/submit`),
  markPaid: (id: number) => post<Claim>(`/api/v1/claims/${id}/paid`),
  markRejected: (id: number, reason: string) => post<Claim>(`/api/v1/claims/${id}/rejected`, { reason }),
  decideReview: (id: number, units: number, note: string) => post<Claim>(`/api/v1/claims/${id}/review`, { units, note }),
  audit: () => request<AuditLog>("/api/v1/audit_events"),
};
