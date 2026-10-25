# Evaluation: dev

Set `dev`, recorded 2026-10-25T13:56:03Z at 8c625d5.

## Red flags (rules)

| Measure | Value |
|---|---:|
| Cases | 42 |
| Emergency flags found | 17 of 17 (100.0%) |
| Urgent flags found | 11 of 11 (100.0%) |
| Harmless messages escalated | 0.0% |

## Pseudonymisation

7 texts, 14 identity mentions: 0 survived (0.0%); 0 clinical words lost.


## AI drafts (simulated model)

9 faithful runs, 0.0% held; 34 runs with an injected mistake, 100.0% held.

| Injected mistake | Held |
|---|---:|
| drop_flag | 2/2 |
| dosing | 6/6 |
| invented_placeholder | 3/3 |
| invent_number | 3/3 |
| stray_number | 3/3 |
| missing_section | 3/3 |
| unknown_exercise | 2/2 |
| level_jump | 2/2 |
| too_many | 3/3 |
| out_of_bounds | 3/3 |
| no_answer | 3/3 |
| contraindicated | 1/1 |

## Model screen guarantees (simulated adversarial model)

168 runs in which the model invents a quote, an unknown flag, tries to remove a flag or returns no JSON: 0 violations.
