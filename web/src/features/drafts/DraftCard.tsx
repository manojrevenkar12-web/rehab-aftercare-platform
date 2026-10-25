import { AnimatePresence, motion as m } from "framer-motion";
import { useState } from "react";

import { ApiError } from "../../shared/api/client";
import { useDraft, useReviewDraft } from "../../shared/api/queries";
import type { Draft, Finding } from "../../shared/api/types";
import { formatDayTime } from "../../shared/lib/format";
import { closingSectionName, closingSections, draftKind, draftStatus } from "../../shared/lib/labels";
import { motion } from "../../shared/theme/motion";
import { Button } from "../../shared/ui/Button";
import { Skeleton } from "../../shared/ui/states";
import { Tag, type Tone } from "../../shared/ui/Tag";
import styles from "./DraftCard.module.css";
import { PlanChanges } from "./PlanChanges";

const statusTone: Record<Draft["status"], Tone> = {
  queued: "neutral",
  ready: "accent",
  held: "emergency",
  failed: "emergency",
  approved: "ok",
  rejected: "neutral",
};

type Edits = Record<string, string>;

/**
 * A model's draft as a person reviews it: what it says, what the checks found, and the three
 * decisions. A held draft cannot be approved as it is; edited text is checked again on approval.
 */
export function DraftCard({ draft: initial, enrolmentId }: { draft: Draft; enrolmentId: number }) {
  const { data: draft = initial } = useDraft(initial.id, initial);
  const review = useReviewDraft(draft.id, enrolmentId);
  const [editing, setEditing] = useState(false);
  const [edits, setEdits] = useState<Edits>({});
  const [rejecting, setRejecting] = useState(false);
  const [reason, setReason] = useState("");

  const open = draft.status === "ready" || draft.status === "held" || draft.status === "failed";
  const approvable = draft.status === "ready" || draft.status === "held";
  const blocking = draft.findings.filter((f) => f.severity === "blocking");
  const edited = Object.keys(edits).length > 0;
  const error = review.approve.error ?? review.reject.error;
  const fields = editableFields(draft);

  return (
    <m.article layout className={styles.card} data-status={draft.status} aria-labelledby={`draft-${draft.id}`} transition={{ duration: motion.base, ease: motion.ease }}>
      <header className={styles.head}>
        <h3 id={`draft-${draft.id}`} className={styles.kind}>
          {draftKind[draft.kind]}
        </h3>
        <Tag tone={statusTone[draft.status]}>{draftStatus[draft.status]}</Tag>
      </header>
      <p className={styles.meta}>
        {formatDayTime(draft.created_at)}, {draft.model ?? "model"} with prompt {draft.prompt_version}
        {draft.reviewed_by && `. ${draftStatus[draft.status]} by ${draft.reviewed_by}`}
      </p>

      <AnimatePresence mode="wait" initial={false}>
        {draft.status === "queued" ? (
          <m.div key="queued" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
            <Skeleton lines={3} label="The model is drafting" />
          </m.div>
        ) : draft.status === "failed" ? (
          <m.p key="failed" className={styles.failed} initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
            {sentence(draft.error ?? "The model did not answer")} Write this one yourself, or request a new draft.
          </m.p>
        ) : (
          <m.div key="body" className={styles.body} initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: motion.base }}>
            {draft.findings.length > 0 && <Findings findings={draft.findings} />}
            <DraftBody draft={draft} editing={editing} edits={edits} onEdit={(k, v) => setEdits((e) => ({ ...e, [k]: v }))} />
          </m.div>
        )}
      </AnimatePresence>

      {open && (
        <div className={styles.decide}>
          {error && (
            <p className={styles.refused} role="alert">
              {error instanceof ApiError ? error.message : "That did not work. Try again."}
            </p>
          )}
          {rejecting ? (
            <form
              className={styles.reject}
              onSubmit={(e) => {
                e.preventDefault();
                review.reject.mutate(reason);
              }}
            >
              <label className={styles.field}>
                <span>Why reject it?</span>
                <input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="For example: tone is wrong for this patient" autoFocus />
              </label>
              <div className={styles.actions}>
                <Button type="submit" variant="danger" disabled={!reason.trim()} busy={review.reject.isPending}>
                  Reject draft
                </Button>
                <Button onClick={() => setRejecting(false)}>Keep it</Button>
              </div>
            </form>
          ) : (
            <div className={styles.actions}>
              {approvable && (
                <Button
                  variant="primary"
                  disabled={draft.status === "held" && !edited}
                  busy={review.approve.isPending}
                  onClick={() => review.approve.mutate(edited ? edits : undefined)}
                  title={draft.status === "held" && !edited ? "Held drafts must be edited before approval" : undefined}
                >
                  {edited ? "Approve with my edits" : "Approve"}
                </Button>
              )}
              {approvable && fields.length > 0 && !editing && <Button onClick={() => setEditing(true)}>Edit</Button>}
              <Button variant="danger" onClick={() => setRejecting(true)}>
                Reject
              </Button>
            </div>
          )}
          {draft.status === "held" && blocking.length > 0 && !edited && (
            <p className={styles.heldHint}>This draft is held: fix what the checks found by editing it, or reject it.</p>
          )}
        </div>
      )}
    </m.article>
  );
}

const sentence = (s: string) => (/[.!?]$/.test(s.trim()) ? s.trim() : `${s.trim()}.`);

function Findings({ findings }: { findings: Finding[] }) {
  return (
    <ul className={styles.findings} aria-label="What the checks found">
      {findings.map((f, i) => (
        <li key={`${f.code}-${i}`} className={styles.finding} data-severity={f.severity}>
          <span className={styles.findingSeverity}>{f.severity === "blocking" ? "Blocks approval" : "Check"}</span>
          {f.message}
        </li>
      ))}
    </ul>
  );
}

function editableFields(d: Draft): string[] {
  if (d.kind === "check_in_reply") return ["reply"];
  if (d.kind === "closing_report") return [...closingSections];
  return [];
}

function DraftBody({ draft, editing, edits, onEdit }: { draft: Draft; editing: boolean; edits: Edits; onEdit: (k: string, v: string) => void }) {
  const o = draft.output;
  const text = (k: string) => edits[k] ?? (o as Record<string, unknown>)[k]?.toString() ?? "";
  const field = (k: string, label: string, rows: number) =>
    editing ? (
      <label className={styles.field} key={k}>
        <span>{label}</span>
        <textarea rows={rows} value={text(k)} onChange={(e) => onEdit(k, e.target.value)} />
      </label>
    ) : (
      <div className={styles.section} key={k}>
        <h4 className={styles.sectionTitle}>{label}</h4>
        <p className={styles.prose}>{text(k)}</p>
      </div>
    );

  if (draft.kind === "check_in_reply") {
    return (
      <>
        {o.summary && (
          <div className={styles.section}>
            <h4 className={styles.sectionTitle}>Summary for you</h4>
            <p className={styles.prose}>{o.summary}</p>
          </div>
        )}
        {field("reply", "Reply to the patient", 6)}
        {o.questions && o.questions.length > 0 && (
          <div className={styles.section}>
            <h4 className={styles.sectionTitle}>Questions it suggests asking</h4>
            <ul className={styles.list}>
              {o.questions.map((q) => (
                <li key={q}>{q}</li>
              ))}
            </ul>
          </div>
        )}
      </>
    );
  }
  if (draft.kind === "closing_report") return <>{closingSections.map((k) => field(k, closingSectionName[k], 4))}</>;
  return (
    <>
      <PlanChanges changes={o.changes ?? []} />
      {o.rationale && (
        <div className={styles.section}>
          <h4 className={styles.sectionTitle}>Why</h4>
          <p className={styles.prose}>{o.rationale}</p>
        </div>
      )}
    </>
  );
}
