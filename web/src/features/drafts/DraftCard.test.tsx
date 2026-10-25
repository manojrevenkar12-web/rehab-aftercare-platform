import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import { draft } from "../../test/fixtures";
import { fakeApi, renderWithClient } from "../../test/render";
import { DraftCard } from "./DraftCard";

describe("DraftCard", () => {
  it("cannot approve a held draft until it is edited, then sends the edit", async () => {
    const held = draft({
      status: "held",
      findings: [{ code: "dosing_advice", severity: "blocking", message: "The reply gives medication advice (400 mg)." }],
      output: { check_in_id: 5, summary: "s", reply: "Nehmen Sie 400 mg Ibuprofen." },
    });
    const api = fakeApi({ "POST /api/v1/drafts/41/approve": (body) => [200, { ...held, status: "approved", output: { ...held.output, ...(body as { edits: object }).edits } }] });
    renderWithClient(<DraftCard draft={held} enrolmentId={7} />);

    expect(screen.getByText("The reply gives medication advice (400 mg).")).toBeInTheDocument();
    const approve = screen.getByRole("button", { name: "Approve" });
    expect(approve).toBeDisabled();

    await userEvent.click(screen.getByRole("button", { name: "Edit" }));
    const reply = screen.getByLabelText("Reply to the patient");
    await userEvent.clear(reply);
    await userEvent.type(reply, "Bitte sprechen Sie mit Ihrer Ärztin.");
    await userEvent.click(screen.getByRole("button", { name: "Approve with my edits" }));
    expect(api.calls.find((c) => c.key === "POST /api/v1/drafts/41/approve")?.body).toEqual({ edits: { reply: "Bitte sprechen Sie mit Ihrer Ärztin." } });
  });

  it("asks why before rejecting, and shows the server's refusal", async () => {
    fakeApi({ "POST /api/v1/drafts/41/reject": [422, { error: "draft is approved" }] });
    renderWithClient(<DraftCard draft={draft()} enrolmentId={7} />);
    await userEvent.click(screen.getByRole("button", { name: "Reject" }));
    const submit = screen.getByRole("button", { name: "Reject draft" });
    expect(submit).toBeDisabled();
    await userEvent.type(screen.getByLabelText("Why reject it?"), "Too long");
    await userEvent.click(submit);
    expect(await screen.findByRole("alert")).toHaveTextContent("draft is approved");
  });

  it("shows a skeleton while the model drafts, and a failure plainly", () => {
    const { unmount } = renderWithClient(<DraftCard draft={draft({ status: "queued", output: {} })} enrolmentId={7} />);
    expect(screen.getByText("The model is drafting")).toBeInTheDocument();
    unmount();
    renderWithClient(<DraftCard draft={draft({ status: "failed", error: "request contains patient identity; not sent" })} enrolmentId={7} />);
    expect(screen.getByText(/not sent\. Write this one yourself/)).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Approve" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Reject" })).toBeInTheDocument();
  });
});
