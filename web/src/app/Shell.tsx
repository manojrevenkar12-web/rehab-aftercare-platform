import { NavLink, Outlet } from "react-router-dom";

import { useSession } from "../features/auth/session";
import type { Role } from "../shared/api/types";
import { roleName } from "../shared/lib/labels";
import styles from "./Shell.module.css";

const NAV: { to: string; label: string; roles: Role[] }[] = [
  { to: "/", label: "Caseload", roles: ["therapist", "physician", "clinic_admin", "billing"] },
  { to: "/billing", label: "Billing", roles: ["billing", "clinic_admin"] },
  { to: "/audit", label: "Audit trail", roles: ["clinic_admin"] },
];

export function Shell() {
  const { user, signOut } = useSession();
  if (!user) return null;
  return (
    <div className={styles.shell}>
      <a className={styles.skip} href="#main">
        Skip to content
      </a>
      <header className={styles.bar}>
        <div className={styles.brand}>
          <span className={styles.product}>Rehab Aftercare</span>
          <span className={styles.clinic}>{user.clinic}</span>
        </div>
        <nav aria-label="Main" className={styles.nav}>
          {NAV.filter((n) => n.roles.includes(user.role)).map((n) => (
            <NavLink key={n.to} to={n.to} end={n.to === "/"} className={({ isActive }) => (isActive ? `${styles.link} ${styles.active}` : styles.link)}>
              {n.label}
            </NavLink>
          ))}
        </nav>
        <div className={styles.user}>
          <span className={styles.userName}>{user.name}</span>
          <span className={styles.userRole}>{roleName[user.role]}</span>
          <button type="button" className={styles.signOut} onClick={() => void signOut()}>
            Sign out
          </button>
        </div>
      </header>
      <main id="main" className={styles.main} tabIndex={-1}>
        <Outlet />
      </main>
    </div>
  );
}
