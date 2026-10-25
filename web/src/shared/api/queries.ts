import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { api } from "./client";
import type { Draft, DraftKind } from "./types";

export const keys = {
  me: ["me"] as const,
  caseload: ["caseload"] as const,
  timeline: (id: number) => ["timeline", id] as const,
  draft: (id: number) => ["draft", id] as const,
  claims: ["claims"] as const,
  audit: ["audit"] as const,
};

export const useMe = (enabled: boolean) => useQuery({ queryKey: keys.me, queryFn: api.me, enabled, retry: false });
export const useCaseload = () => useQuery({ queryKey: keys.caseload, queryFn: api.caseload });
export const useTimeline = (id: number) => useQuery({ queryKey: keys.timeline(id), queryFn: () => api.timeline(id) });
export const useClaims = () => useQuery({ queryKey: keys.claims, queryFn: api.claims });
export const useAudit = () => useQuery({ queryKey: keys.audit, queryFn: api.audit });

/** A queued draft is polled until the model has answered. */
export const useDraft = (id: number, initial?: Draft) =>
  useQuery({
    queryKey: keys.draft(id),
    queryFn: () => api.draft(id),
    initialData: initial,
    refetchInterval: (q) => (q.state.data?.status === "queued" ? 1500 : false),
  });

export function useRequestDraft(enrolmentId: number) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ kind, checkInId }: { kind: DraftKind; checkInId?: number }) => api.requestDraft(enrolmentId, kind, checkInId),
    onSuccess: () => qc.invalidateQueries({ queryKey: keys.timeline(enrolmentId) }),
  });
}

export function useReviewDraft(draftId: number, enrolmentId: number) {
  const qc = useQueryClient();
  const done = () => {
    void qc.invalidateQueries({ queryKey: keys.timeline(enrolmentId) });
    void qc.invalidateQueries({ queryKey: keys.draft(draftId) });
    void qc.invalidateQueries({ queryKey: keys.caseload });
  };
  return {
    approve: useMutation({ mutationFn: (edits?: Record<string, unknown>) => api.approveDraft(draftId, edits), onSuccess: done }),
    reject: useMutation({ mutationFn: (reason: string) => api.rejectDraft(draftId, reason), onSuccess: done }),
  };
}

export function useSignReport(enrolmentId: number) {
  const qc = useQueryClient();
  return useMutation({ mutationFn: () => api.signClosingReport(enrolmentId), onSuccess: () => qc.invalidateQueries({ queryKey: keys.timeline(enrolmentId) }) });
}

export type ClaimAction =
  | { id: number; action: "submit" }
  | { id: number; action: "paid" }
  | { id: number; action: "rejected"; reason: string }
  | { id: number; action: "review"; units: number; note: string };

export function useClaimAction() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (a: ClaimAction) => {
      switch (a.action) {
        case "submit":
          return api.submitClaim(a.id);
        case "paid":
          return api.markPaid(a.id);
        case "rejected":
          return api.markRejected(a.id, a.reason);
        case "review":
          return api.decideReview(a.id, a.units, a.note);
      }
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: keys.claims }),
  });
}

export function useAssembleClaim() {
  const qc = useQueryClient();
  return useMutation({ mutationFn: (enrolmentId: number) => api.assembleClaim(enrolmentId), onSuccess: () => qc.invalidateQueries({ queryKey: keys.claims }) });
}
