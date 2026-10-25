import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { api } from "./client";
import type { Draft, DraftKind } from "./types";

export const keys = {
  me: ["me"] as const,
  caseload: ["caseload"] as const,
  timeline: (id: number) => ["timeline", id] as const,
  draft: (id: number) => ["draft", id] as const,
  claims: ["claims"] as const,
};

export const useMe = (enabled: boolean) => useQuery({ queryKey: keys.me, queryFn: api.me, enabled, retry: false });
export const useCaseload = () => useQuery({ queryKey: keys.caseload, queryFn: api.caseload });
export const useTimeline = (id: number) => useQuery({ queryKey: keys.timeline(id), queryFn: () => api.timeline(id) });
export const useClaims = () => useQuery({ queryKey: keys.claims, queryFn: api.claims });

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

export function useClaimAction() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, action, reason }: { id: number; action: "submit" | "paid" | "rejected"; reason?: string }) =>
      action === "submit" ? api.submitClaim(id) : action === "paid" ? api.markPaid(id) : api.markRejected(id, reason ?? ""),
    onSuccess: () => qc.invalidateQueries({ queryKey: keys.claims }),
  });
}
