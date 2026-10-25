import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { MotionConfig } from "framer-motion";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";

import { AuditPage } from "../features/audit/AuditPage";
import { RequireSession } from "../features/auth/RequireSession";
import { SessionProvider } from "../features/auth/session";
import { SignInPage } from "../features/auth/SignInPage";
import { CaseloadPage } from "../features/caseload/CaseloadPage";
import { ClaimsPage } from "../features/claims/ClaimsPage";
import { PatientPage } from "../features/patient/PatientPage";
import { ApiError } from "../shared/api/client";
import { Shell } from "./Shell";

export function makeQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 15_000,
        // a 4xx will not get better by asking again
        retry: (n, err) => !(err instanceof ApiError && err.status >= 400 && err.status < 500) && n < 2,
      },
    },
  });
}

export function AppRoutes() {
  return (
    <Routes>
      <Route path="/sign-in" element={<SignInPage />} />
      <Route
        element={
          <RequireSession>
            <Shell />
          </RequireSession>
        }
      >
        <Route index element={<CaseloadPage />} />
        <Route
          path="enrolments/:id"
          element={
            <RequireSession roles={["therapist", "physician"]}>
              <PatientPage />
            </RequireSession>
          }
        />
        <Route
          path="billing"
          element={
            <RequireSession roles={["billing", "clinic_admin"]}>
              <ClaimsPage />
            </RequireSession>
          }
        />
        <Route
          path="audit"
          element={
            <RequireSession roles={["clinic_admin"]}>
              <AuditPage />
            </RequireSession>
          }
        />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}

export function App({ client = makeQueryClient() }: { client?: QueryClient }) {
  return (
    <QueryClientProvider client={client}>
      <MotionConfig reducedMotion="user">
        <BrowserRouter>
          <SessionProvider>
            <AppRoutes />
          </SessionProvider>
        </BrowserRouter>
      </MotionConfig>
    </QueryClientProvider>
  );
}
