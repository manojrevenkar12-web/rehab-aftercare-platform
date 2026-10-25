import { useClaims } from "../../shared/api/queries";
import type { Claim, ClaimStatus } from "../../shared/api/types";
import { claimStatus } from "../../shared/lib/labels";
import { EmptyState, QueryView } from "../../shared/ui/states";
import { useSession } from "../auth/session";
import { ClaimRow } from "./ClaimRow";
import styles from "./ClaimsPage.module.css";

/** The order billing works in: decisions first, then what can go out, then what is missing. */
const ORDER: ClaimStatus[] = ["needs_review", "ready", "draft", "submitted", "rejected", "paid"];

export function ClaimsPage() {
  const query = useClaims();
  const { user } = useSession();
  const canAct = user?.role === "billing";
  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <h1 className={styles.title}>Billing</h1>
        <p className={styles.lead}>
          One claim per completed programme: invoice, participation record (G4832) and closing documentation (G4819) for the
          Deutsche Rentenversicherung.
        </p>
      </header>
      <QueryView
        query={query}
        what="claims"
        lines={6}
        isEmpty={(d) => d.claims.length === 0}
        empty={<EmptyState title="No claims yet">A claim is assembled when a programme is completed or ends early.</EmptyState>}
      >
        {(d) => (
          <>
            {placeholderRates(d.claims) && (
              <p className={styles.notice} role="note">
                Rates are placeholders, not the DRV rate table. Set the real rates in config/aftercare/programmes.yml before
                submitting anything.
              </p>
            )}
            {ORDER.map((status) => {
              const rows = d.claims.filter((c) => c.status === status);
              if (rows.length === 0) return null;
              return (
                <section key={status} className={styles.group} aria-labelledby={`claims-${status}`}>
                  <h2 id={`claims-${status}`} className={styles.groupTitle}>
                    {claimStatus[status]} <span className={styles.count}>{rows.length}</span>
                  </h2>
                  <ul className={styles.rows}>
                    {rows.map((c) => (
                      <ClaimRow key={c.id} claim={c} canAct={canAct} />
                    ))}
                  </ul>
                </section>
              );
            })}
          </>
        )}
      </QueryView>
    </div>
  );
}

const placeholderRates = (claims: Claim[]) => claims.some((c) => c.rate_source?.startsWith("placeholder"));
