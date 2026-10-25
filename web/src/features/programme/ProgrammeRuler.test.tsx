import { render, screen } from "@testing-library/react";
import { MotionConfig } from "framer-motion";

import { enrolment, timeline } from "../../test/fixtures";
import { ProgrammeRuler, summary } from "./ProgrammeRuler";

describe("ProgrammeRuler", () => {
  it("says in words what the picture shows", () => {
    expect(summary(enrolment(), "2026-10-25")).toBe("14 of 18 units done. Started 20 Aug, in the ideal window. Finish by 6 Aug 2027.");
    expect(summary(enrolment({ started_on: null, units_done: 0 }), "2026-10-25")).toBe(
      "0 of 18 units done. Not started; start at the latest by 6 Nov. Finish by 6 Aug 2027.",
    );
    expect(summary(enrolment({ started_on: "2026-10-01" }), "2026-10-25")).toContain("after the ideal start");
  });

  it("places the DRV windows, the units and today on one line from the end of rehab", () => {
    const t = timeline();
    const { container } = render(
      <MotionConfig reducedMotion="always">
        <ProgrammeRuler enrolment={t.enrolment} units={t.units} today={t.today} rehabEndedOn={t.patient.rehab_ended_on} />
      </MotionConfig>,
    );
    expect(screen.getByRole("figure")).toHaveAccessibleName(/14 of 18 units done/);
    expect(screen.getByRole("img", { name: "14 of 18 units done" })).toBeInTheDocument();
    // a unit too short to count is drawn, but differently
    expect(container.querySelectorAll(".unit")).toHaveLength(1);
    expect(container.querySelectorAll(".unitShort")).toHaveLength(1);
    // the ideal window is 42 of 365 days wide
    const ideal = container.querySelector<HTMLElement>(".bandIdeal")!;
    expect(parseFloat(ideal.style.width)).toBeCloseTo((42 / 365) * 100, 1);
    expect(screen.getByText("Today")).toBeInTheDocument();
    expect(screen.getByText("Start at the latest").nextSibling).toHaveTextContent("6 Nov");
  });
});
