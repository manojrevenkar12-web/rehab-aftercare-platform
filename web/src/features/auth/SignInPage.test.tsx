import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import { session } from "../../shared/api/client";
import { therapist } from "../../test/fixtures";
import { fakeApi, renderApp } from "../../test/render";

describe("Sign-in", () => {
  it("says what went wrong and keeps the form", async () => {
    fakeApi({ "POST /api/v1/session": [401, { error: "Wrong e-mail or password." }] });
    renderApp("/", { token: null });
    await userEvent.type(await screen.findByLabelText("E-mail"), "theo@demo.example");
    await userEvent.type(screen.getByLabelText("Password"), "nope");
    await userEvent.click(screen.getByRole("button", { name: "Sign in" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("Wrong e-mail or password.");
    expect(session.get()).toBeNull();
  });

  it("signs in as a demo person and lands on their start page", async () => {
    fakeApi({
      "POST /api/v1/session": [201, { token: "abc", user: therapist }],
      "GET /api/v1/session": [200, { user: therapist }],
      "GET /api/v1/caseload": [200, { today: "2026-10-25", patients: [] }],
    });
    renderApp("/", { token: null });
    await userEvent.click(await screen.findByRole("button", { name: /Theo Brandt/ }));
    expect(await screen.findByText("No patients assigned to you")).toBeInTheDocument();
    expect(session.get()).toBe("abc");
  });

  it("drops an expired session and asks to sign in again", async () => {
    fakeApi({ "GET /api/v1/session": [401, { error: "Session expired." }] });
    renderApp("/", { token: "old" });
    expect(await screen.findByRole("button", { name: "Sign in" })).toBeInTheDocument();
    expect(session.get()).toBeNull();
  });
});
