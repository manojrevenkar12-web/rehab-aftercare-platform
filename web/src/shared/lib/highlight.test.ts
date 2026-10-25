import { highlight } from "./highlight";

describe("highlight", () => {
  it("marks each flag's evidence where it occurs, case-insensitively", () => {
    const parts = highlight("Seit gestern DRUCK auf der Brust und Atemnot.", [
      { evidence: "Atemnot", code: "breathlessness", severity: "emergency" },
      { evidence: "Druck auf der Brust", code: "chest_pain", severity: "emergency" },
    ]);
    expect(parts.map((p) => [p.text, p.mark?.code])).toEqual([
      ["Seit gestern ", undefined],
      ["DRUCK auf der Brust", "chest_pain"],
      [" und ", undefined],
      ["Atemnot", "breathlessness"],
      [".", undefined],
    ]);
  });

  it("leaves the message whole when the evidence is not in it, and never overlaps marks", () => {
    expect(highlight("Alles gut", [{ evidence: "pain 9/10", code: "severe_pain", severity: "urgent" }])).toEqual([{ text: "Alles gut" }]);
    const parts = highlight("keine Luft mehr", [
      { evidence: "keine Luft", code: "breathlessness", severity: "emergency" },
      { evidence: "Luft mehr", code: "x", severity: "urgent" },
    ]);
    expect(parts.filter((p) => p.mark)).toHaveLength(1);
    expect(parts.map((p) => p.text).join("")).toBe("keine Luft mehr");
  });
});
