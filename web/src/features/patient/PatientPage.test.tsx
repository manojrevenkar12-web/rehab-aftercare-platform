import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import { draft, therapist, timeline } from "../../test/fixtures";
import { fakeApi, renderApp } from "../../test/render";

describe("Patient page", () => {
  it("marks the words that raised a flag, and says what was seen but not escalated", async () => {
    fakeApi({ "GET /api/v1/session": [200, { user: therapist }], "GET /api/v1/enrolments/7/timeline": [200, timeline()] });
    renderApp("/enrolments/7");
    expect(await screen.findByRole("heading", { name: "Anna Becker" })).toBeInTheDocument();
    const mark = screen.getByText("Druck auf der Brust");
    expect(mark.tagName).toBe("MARK");
    expect(screen.getByText(/Not escalated: Fall, because the message is about someone else/)).toBeInTheDocument();
    expect(screen.getByText("Nothing to review")).toBeInTheDocument();
  });

  it("requests a reply draft for a check-in and shows it", async () => {
    let drafts: unknown[] = [];
    fakeApi({
      "GET /api/v1/session": [200, { user: therapist }],
      "GET /api/v1/enrolments/7/timeline": () => [200, timeline({ drafts: drafts as never })],
      "POST /api/v1/enrolments/7/drafts": () => {
        drafts = [draft()];
        return [202, draft()];
      },
      "GET /api/v1/drafts/41": [200, draft()],
    });
    renderApp("/enrolments/7");
    await userEvent.click(await screen.findByRole("button", { name: "Draft a reply" }));
    const review = await screen.findByRole("region", { name: "AI drafts to review" });
    expect(await within(review).findByText("Vielen Dank für Ihre Rückmeldung.")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Draft a reply" })).not.toBeInTheDocument();
  });

  it("sends people without clinical access back to their start page", async () => {
    fakeApi({ "GET /api/v1/session": [200, { user: { ...therapist, role: "billing" } }], "GET /api/v1/claims": [200, { claims: [] }] });
    renderApp("/enrolments/7");
    expect(await screen.findByRole("heading", { name: "Billing" })).toBeInTheDocument();
  });
});
