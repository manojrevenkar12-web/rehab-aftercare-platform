import { AnimatePresence, motion as m } from "framer-motion";
import { useState } from "react";

import { useAssembleClaim, useClaimAction } from "../../shared/api/queries";
import type { Claim } from "../../shared/api/types";
import { programmeShort } from "../../shared/lib/labels";
import { motion } from "../../shared/theme/motion";
import { Button } from "../../shared/ui/Button";
import styles from "./ClaimRow.module.css";

type Form = null | "reject" | "review";

export function ClaimRow({ claim: c, canAct }: { claim: Claim; canAct: boolean }) {
  const act = useClaimAction();
  const assemble = useAssembleClaim();
  const [form, setForm] = useState<Form>(null);
  const [reason, setReason] = useState("");
  const [units, setUnits] = useState(String(c.units_billed));
  const [note, setNote] = useState("");
  const blocking = c.problems.filter((p) => p.severity === "blocking");
  const info = c.problems.filter((p) => p.severity !== "blocking");
  const error = act.error ?? assemble.error;

  return (
    <li className={styles.row} data-status={c.status}>
      <div className={styles.what}>
        <span className={styles.number}>{c.number}</span>
        <span className={styles.meta}>
          {c.patient}, {programmeShort(c.programme)}, {c.units_billed} units
        </span>
      </div>
      {c.status === "needs_review" ? (
        <p className={styles.unpriced}>Not priced until decided</p>
      ) : (
        <p className={styles.amount}>
          {c.amount} <span className={styles.currency}>{c.currency}</span>
        </p>
      )}

      {(blocking.length > 0 || info.length > 0) && (
        <ul className={styles.problems}>
          {blocking.map((p) => (
            <li key={p.code} data-severity="blocking">
              {p.message}
            </li>
          ))}
          {info.map((p) => (
            <li key={p.code}>{p.message}</li>
          ))}
        </ul>
      )}

      {canAct && (
        <div className={styles.actions}>
          {c.status === "ready" && (
            <Button variant="primary" busy={act.isPending} onClick={() => act.mutate({ id: c.id, action: "submit" })}>
              Submit to DRV
            </Button>
          )}
          {c.status === "submitted" && (
            <>
              <Button variant="primary" busy={act.isPending} onClick={() => act.mutate({ id: c.id, action: "paid" })}>
                Mark paid
              </Button>
              <Button variant="danger" onClick={() => setForm(form === "reject" ? null : "reject")}>
                Mark rejected
              </Button>
            </>
          )}
          {c.status === "needs_review" && (
            <Button variant="primary" onClick={() => setForm(form === "review" ? null : "review")}>
              Decide units to bill
            </Button>
          )}
          {(c.status === "draft" || c.status === "rejected") && (
            <Button busy={assemble.isPending} onClick={() => assemble.mutate(c.enrolment_id)}>
              Check again
            </Button>
          )}
        </div>
      )}

      <AnimatePresence initial={false}>
        {form && (
          <m.form
            key={form}
            className={styles.form}
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: "auto" }}
            exit={{ opacity: 0, height: 0 }}
            transition={{ duration: motion.base, ease: motion.ease }}
            onSubmit={(e) => {
              e.preventDefault();
              if (form === "reject") act.mutate({ id: c.id, action: "rejected", reason }, { onSuccess: () => setForm(null) });
              else act.mutate({ id: c.id, action: "review", units: Number(units), note }, { onSuccess: () => setForm(null) });
            }}
          >
            {form === "reject" ? (
              <label className={styles.field}>
                <span>Reason the DRV gave</span>
                <input value={reason} onChange={(e) => setReason(e.target.value)} autoFocus />
              </label>
            ) : (
              <>
                <label className={styles.field}>
                  <span>Units to bill</span>
                  <input type="number" min={0} max={c.units_billed} value={units} onChange={(e) => setUnits(e.target.value)} autoFocus />
                </label>
                <label className={styles.field}>
                  <span>Note for the file</span>
                  <input value={note} onChange={(e) => setNote(e.target.value)} placeholder="For example: agreed with the DRV case worker" />
                </label>
              </>
            )}
            <Button
              type="submit"
              variant="primary"
              busy={act.isPending}
              disabled={form === "reject" ? !reason.trim() : !note.trim() || units === ""}
            >
              {form === "reject" ? "Record rejection" : "Bill these units"}
            </Button>
          </m.form>
        )}
      </AnimatePresence>
      {error && (
        <p className={styles.error} role="alert">
          {error.message}
        </p>
      )}
    </li>
  );
}
