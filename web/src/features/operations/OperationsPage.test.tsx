import { screen, within } from "@testing-library/react";

import { admin, ops, therapist } from "../../test/fixtures";
import { fakeApi, renderApp } from "../../test/render";

describe("Operations", () => {
  it("leads with what needs attention, then the promise, the release decisions and the cost", async () => {
    fakeApi({ "GET /api/v1/session": [200, { user: admin }], "GET /api/v1/ops": [200, ops()] });
    renderApp("/operations");
    expect(await screen.findByRole("heading", { level: 1, name: "Operations" })).toBeInTheDocument();
    const alerts = await screen.findByRole("region", { name: "Needs attention" });
    expect(within(alerts).getAllByRole("listitem").map((li) => li.textContent)).toEqual([
      "Act nowplan change: plan-change/2 · simulated-1-mini is worse than plan-change/2 · simulated-1",
      "Look today1 check-in waiting longer than 24 h",
    ]);
    expect(screen.getByText("86%")).toBeInTheDocument();
    expect(screen.getByText(/of 21 due check-ins answered in time; the target is 95%/)).toBeInTheDocument();

    const gate = screen.getByRole("region", { name: "Prompt and model releases" });
    const plan = within(gate).getByRole("heading", { name: "Plan change" }).closest("li") as HTMLElement;
    expect(within(plan).getByText("Blocked")).toBeInTheDocument();
    expect(within(plan).getByRole("img", { name: "Change +17.2 pts, 95% interval +5.4 pts to +29.6 pts" })).toHaveAttribute("data-verdict", "worse");
    const reply = within(gate).getByRole("heading", { name: "Reply to check-in" }).closest("li") as HTMLElement;
    expect(within(reply).getByText("Pass")).toBeInTheDocument();

    const models = screen.getByRole("region", { name: /Model calls/ });
    expect(within(models).getByRole("row", { name: /Reply to check-in/ })).toHaveTextContent("≈20,100 / 5,900");
    expect(within(models).getByText(/placeholders/)).toBeInTheDocument();
  });

  it("says when nothing needs attention and when no worker is running", async () => {
    fakeApi({
      "GET /api/v1/session": [200, { user: admin }],
      "GET /api/v1/ops": [200, ops({ alerts: [], queue: { queues: [], failed: [{ job: "GenerateDraftJob", count: 2, last_failed_at: null }], workers_alive: 0 } })],
    });
    renderApp("/operations");
    expect(await screen.findByText(/Nothing needs attention/)).toBeInTheDocument();
    expect(screen.getByText(/No worker has reported/)).toBeInTheDocument();
    expect(screen.getByText(/2 failed jobs of/)).toBeInTheDocument();
  });

  it("explains a failure to load", async () => {
    fakeApi({ "GET /api/v1/session": [200, { user: admin }], "GET /api/v1/ops": [500, { error: "boom" }] });
    renderApp("/operations");
    expect(await screen.findByRole("alert")).toHaveTextContent("Could not load the operations view");
  });

  it("is not in a therapist's navigation and sends them back to the caseload", async () => {
    const api = fakeApi({ "GET /api/v1/session": [200, { user: therapist }], "GET /api/v1/caseload": [200, { patients: [], today: "2026-11-21" }] });
    renderApp("/operations");
    const nav = await screen.findByRole("navigation", { name: "Main" });
    expect(within(nav).queryByRole("link", { name: "Operations" })).not.toBeInTheDocument();
    expect(api.calls.some((c) => c.key === "GET /api/v1/ops")).toBe(false);
  });
});
