import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import { fakeApi, renderApp } from "../../test/render";
import { billing, row, therapist } from "../../test/fixtures";
import { summary } from "./CaseloadPage";

describe("Caseload", () => {
  it("shows a skeleton, then patients who need attention first", async () => {
    fakeApi({
      "GET /api/v1/session": [200, { user: therapist }],
      "GET /api/v1/caseload": [
        200,
        {
          today: "2026-10-25",
          patients: [
            row({ id: 1, name: "Anna Becker", escalations: 1, attention: 4 }),
            row({ id: 2, name: "Olaf Krüger", pseudonym: "P-OK000001" }),
          ],
        },
      ],
    });
    renderApp("/");
    expect(await screen.findByRole("status")).toBeInTheDocument();
    expect(await screen.findByRole("heading", { name: /Sunday,? 25 October/ })).toBeInTheDocument();
    const urgent = screen.getByRole("region", { name: "Needs you today" });
    expect(within(urgent).getByRole("link", { name: /Anna Becker/ })).toHaveAttribute("href", "/enrolments/7");
    expect(within(urgent).getByText("1 red flag")).toBeInTheDocument();
    expect(within(screen.getByRole("region", { name: "Everyone else" })).getByText("Olaf Krüger")).toBeInTheDocument();
  });

  it("explains an empty caseload", async () => {
    fakeApi({ "GET /api/v1/session": [200, { user: therapist }], "GET /api/v1/caseload": [200, { today: "2026-10-25", patients: [] }] });
    renderApp("/");
    expect(await screen.findByText("No patients assigned to you")).toBeInTheDocument();
  });

  it("offers a retry when the API fails, and recovers", async () => {
    let fail = true;
    fakeApi({
      "GET /api/v1/session": [200, { user: therapist }],
      "GET /api/v1/caseload": () => (fail ? [500, { error: "database unavailable" }] : [200, { today: "2026-10-25", patients: [row()] }]),
    });
    renderApp("/");
    expect(await screen.findByRole("alert")).toHaveTextContent("database unavailable");
    fail = false;
    await userEvent.click(screen.getByRole("button", { name: "Try again" }));
    expect(await screen.findByText("Anna Becker")).toBeInTheDocument();
  });

  it("does not link billing staff to clinical pages", async () => {
    fakeApi({ "GET /api/v1/session": [200, { user: billing }], "GET /api/v1/caseload": [200, { today: "2026-10-25", patients: [row()] }] });
    renderApp("/");
    await waitFor(() => expect(screen.getByText("Anna Becker")).toBeInTheDocument());
    expect(screen.queryByRole("link", { name: /Anna Becker/ })).not.toBeInTheDocument();
  });

  it("sums up the day in one sentence", () => {
    expect(summary([row(), row()])).toBe("Nothing urgent across 2 patients.");
    expect(summary([row({ escalations: 2 }), row({ overdue: 1 })])).toBe(
      "1 patient reported a red flag and 1 patient waited too long for an answer.",
    );
  });
});
