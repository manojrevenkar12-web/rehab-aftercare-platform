import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render } from "@testing-library/react";
import { MotionConfig } from "framer-motion";
import type { ReactElement } from "react";
import { MemoryRouter } from "react-router-dom";
import { vi } from "vitest";

import { AppRoutes } from "../app/App";
import { session } from "../shared/api/client";
import { SessionProvider } from "../features/auth/session";

type Handler = (body: unknown, init: RequestInit) => [number, unknown] | Promise<[number, unknown]>;

/**
 * A fake API: "METHOD /path" → handler returning [status, json]. Unknown routes answer 404 and
 * are recorded, so a test fails loudly when the UI calls something it should not.
 */
export function fakeApi(routes: Record<string, Handler | [number, unknown]>) {
  const calls: { key: string; body: unknown }[] = [];
  const fetchMock = vi.fn(async (input: RequestInfo | URL, init: RequestInit = {}) => {
    const url = new URL(String(input), "http://localhost");
    const key = `${(init.method ?? "GET").toUpperCase()} ${url.pathname}`;
    const body = init.body ? JSON.parse(String(init.body)) : undefined;
    calls.push({ key, body });
    const route = routes[key];
    const [status, json] = route === undefined ? [404, { error: `no fake for ${key}` }] : typeof route === "function" ? await route(body, init) : route;
    return new Response(status === 204 ? null : JSON.stringify(json), { status, headers: { "Content-Type": "application/json" } });
  });
  vi.stubGlobal("fetch", fetchMock);
  return { calls, fetchMock };
}

export function testClient() {
  return new QueryClient({ defaultOptions: { queries: { retry: false, staleTime: Infinity }, mutations: { retry: false } } });
}

/** Renders the whole app at `route`, signed in when a token is given. */
export function renderApp(route: string, { token = "t" }: { token?: string | null } = {}) {
  session.set(token);
  return render(
    <QueryClientProvider client={testClient()}>
      <MotionConfig reducedMotion="always">
        <MemoryRouter initialEntries={[route]}>
          <SessionProvider>
            <AppRoutes />
          </SessionProvider>
        </MemoryRouter>
      </MotionConfig>
    </QueryClientProvider>,
  );
}

export function renderWithClient(ui: ReactElement) {
  return render(
    <QueryClientProvider client={testClient()}>
      <MotionConfig reducedMotion="always">
        <MemoryRouter>{ui}</MemoryRouter>
      </MotionConfig>
    </QueryClientProvider>,
  );
}
