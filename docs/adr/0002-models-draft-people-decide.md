# 0002: Models draft, code checks, people decide

## Status

Accepted, 2026-10-25.

## Context

LLMs can write a reply to a patient, the closing documentation and suggested plan changes faster
than a therapist can. They also invent numbers, give medication advice, drop warnings and
suggest exercises a patient must not do. A published evaluation of LLM-generated rehabilitation
instructions found hallucinated monitoring conditions in about 2.5% of cases (arXiv 2511.18274).

## Decision

- A model's output is a **draft**. It does nothing until a permitted person approves it. The
  policy for each kind is in `app/policies/ai_draft_policy.rb`.
- **Code checks** every draft before a person sees it (`app/domain/ai/checks.rb`,
  `app/domain/ai/plan_rules.rb`). A **blocking** finding holds the draft, and a held draft cannot
  be approved as it is. Edits go through the same checks again. The blocking findings are:
  - numbers not in the facts;
  - dosing advice;
  - invented placeholders;
  - a red flag the draft did not acknowledge;
  - missing sections;
  - unknown or contraindicated exercises;
  - level jumps;
  - doses outside the limits;
  - too many changes.
- **Code, not the model, writes safety text.** The emergency advice (call 112) is appended word
  for word whenever an emergency flag is present.
- The plan-change agent uses tools (`search_exercises`, `check_contraindications`) and has a
  turn limit. Its final plan is checked by the same rules whatever the tools said.
- The evaluation injects each kind of mistake into a simulated model and requires every one to
  be held (`fault_catch_rate: 1.0`). It also requires no faithful draft to be held.

## Consequences

- No model output reaches a patient without a person.
- The checks catch the mistakes we can describe. Others (tone, clinical judgement) are the
  reviewer's job, which is why review is not optional.
