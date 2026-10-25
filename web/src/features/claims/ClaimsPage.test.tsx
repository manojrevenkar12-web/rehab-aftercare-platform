import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import { billing, claim } from "../../test/fixtures";
import { fakeApi, renderApp } from "../../test/render";

describe("Billing", () => {
  it("groups claims by what billing has to do, warns about placeholder rates, and submits", async () => {
    let status = "ready";
    const api = fakeApi({
      "GET /api/v1/session": [200, { user: billing }],
      "GET /api/v1/claims": () => [
        200,
        {
          claims: [
            claim({ status: status as never }),
            claim({ id: 10, number: "RN-260999001-0000003", status: "needs_review", problems: [{ code: "early_end", severity: "blocking", message: "Ended early: a person decides what is billed." }] }),
          ],
        },
      ],
      "POST /api/v1/claims/9/submit": () => {
        status = "submitted";
        return [200, claim({ status: "submitted" })];
      },
    });
    renderApp("/billing");
    expect(await screen.findByRole("note")).toHaveTextContent("Rates are placeholders");
    const headings = screen.getAllByRole("heading", { level: 2 }).map((h) => h.textContent);
    expect(headings).toEqual(["Needs a decision 1", "Ready to submit 1"]);

    const ready = screen.getByRole("region", { name: /Ready to submit/ });
    await userEvent.click(within(ready).getByRole("button", { name: "Submit to DRV" }));
    expect(api.calls.some((c) => c.key === "POST /api/v1/claims/9/submit")).toBe(true);
    expect(await screen.findByRole("region", { name: /Submitted/ })).toBeInTheDocument();
  });

  it("needs units and a note to decide an early-end claim", async () => {
    const api = fakeApi({
      "GET /api/v1/session": [200, { user: billing }],
      "GET /api/v1/claims": [200, { claims: [claim({ status: "needs_review", units_billed: 9 })] }],
      "POST /api/v1/claims/9/review": [200, claim({ status: "ready" })],
    });
    renderApp("/billing");
    await userEvent.click(await screen.findByRole("button", { name: "Decide units to bill" }));
    const bill = screen.getByRole("button", { name: "Bill these units" });
    expect(bill).toBeDisabled();
    await userEvent.type(screen.getByLabelText("Note for the file"), "Agreed with the DRV case worker");
    await userEvent.click(bill);
    expect(api.calls.find((c) => c.key === "POST /api/v1/claims/9/review")?.body).toEqual({ units: 9, note: "Agreed with the DRV case worker" });
  });
});
