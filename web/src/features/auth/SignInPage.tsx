import { AnimatePresence, motion as m } from "framer-motion";
import { useState, type FormEvent } from "react";
import { Navigate, useLocation, useNavigate } from "react-router-dom";

import { ApiError } from "../../shared/api/client";
import { motion } from "../../shared/theme/motion";
import { Button } from "../../shared/ui/Button";
import { startPage } from "./RequireSession";
import { useSession } from "./session";
import styles from "./SignInPage.module.css";

/** Demo staff created by `bin/rails db:seed`; shown in development and in builds made with VITE_DEMO=1. */
const DEMO = [
  { email: "theo@demo.example", who: "Theo Brandt", role: "Therapist" },
  { email: "petra@demo.example", who: "Dr. Petra Lindqvist", role: "Physician" },
  { email: "bea@demo.example", who: "Bea Kowalski", role: "Billing" },
  { email: "ada@demo.example", who: "Ada Nowak", role: "Clinic admin" },
];
const DEMO_PASSWORD = "demo-password-1";

export function SignInPage({ showDemo = import.meta.env.DEV || import.meta.env.VITE_DEMO === "1" }: { showDemo?: boolean }) {
  const { user, signIn } = useSession();
  const navigate = useNavigate();
  const from = (useLocation().state as { from?: string } | null)?.from;
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  if (user) return <Navigate to={from ?? startPage(user.role)} replace />;

  async function submit(e?: FormEvent, as?: { email: string; password: string }) {
    e?.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const u = await signIn(as?.email ?? email, as?.password ?? password);
      navigate(from ?? startPage(u.role), { replace: true });
    } catch (err) {
      setError(err instanceof ApiError && err.status !== 0 ? err.message : "The server did not answer. Try again in a moment.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className={styles.page}>
      <m.section
        className={styles.panel}
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: motion.slow, ease: motion.ease }}
        aria-labelledby="sign-in-title"
      >
        <h1 id="sign-in-title" className={styles.title}>
          Rehab Aftercare
        </h1>
        <p className={styles.lead}>Digital aftercare after medical rehabilitation: training, check-ins, reports and DRV billing.</p>

        <form className={styles.form} onSubmit={(e) => void submit(e)} noValidate>
          <label className={styles.field}>
            <span>E-mail</span>
            <input type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} required />
          </label>
          <label className={styles.field}>
            <span>Password</span>
            <input type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} required />
          </label>
          <AnimatePresence>
            {error && (
              <m.p className={styles.error} role="alert" initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: "auto" }} exit={{ opacity: 0, height: 0 }}>
                {error}
              </m.p>
            )}
          </AnimatePresence>
          <Button type="submit" variant="primary" busy={busy} disabled={!email || !password}>
            {busy ? "Signing in" : "Sign in"}
          </Button>
        </form>

        {showDemo && (
          <div className={styles.demo}>
            <h2 className={styles.demoTitle}>Demo clinic</h2>
            <p className={styles.demoLead}>Invented staff and patients. Pick someone to see the console as they do.</p>
            <ul className={styles.people}>
              {DEMO.map((d) => (
                <li key={d.email}>
                  <button type="button" className={styles.person} disabled={busy} onClick={() => void submit(undefined, { email: d.email, password: DEMO_PASSWORD })}>
                    <span className={styles.personName}>{d.who}</span>
                    <span className={styles.personRole}>{d.role}</span>
                  </button>
                </li>
              ))}
            </ul>
          </div>
        )}
      </m.section>
    </main>
  );
}
