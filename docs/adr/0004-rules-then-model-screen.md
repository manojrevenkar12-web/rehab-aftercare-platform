# 0004: Red flags by rules, then an add-only model screen, then an answer-time SLA

## Status

Accepted, 2026-10-25, after held-out set2.

## Context

A check-in can report an emergency: chest pain, breathlessness, stroke signs or thoughts of
self-harm. It can also report something urgent: a fall, fever or an infected wound. The first
design used keyword rules only. They are deterministic, explainable and need no model.

The blind sets showed the limits:

| Set | Emergency flags found | Harmless messages escalated |
|---|---:|---:|
| set1, first run | 41.7% | 28% |
| set1 after studying its failures | 100% | 0% |
| set2, first run (new writer pass, after those changes) | 44.8% | 14% |

The rules fit what they were tuned on and miss how other people write: dialect, paraphrase,
relatives writing for the patient, and indirect descriptions.

## Decision

1. **Rules first.** They run at intake, synchronously, and need no network. Every flag carries
   the words that triggered it. A hit is dropped if it is negated or denied. It is **set aside,
   not dropped**, when context makes it someone else's event, a past one, a fear, a near miss,
   hearsay or the patient's usual exertion. Set-aside hits are stored and shown to the
   therapist.
2. **A model screen second** (`ScreenCheckInJob`). It reads the pseudonymised message and may
   **only add** flags. Each added flag needs a quote that is found in the message, or it is
   dropped and recorded. It cannot remove a rule flag. If it fails, the rules' result stands and
   the failure is recorded on the check-in.
3. **A person always reads.** Every check-in is answered within
   `check_ins.answer_within_hours` (24 h). A late one raises the patient in the caseload. The
   screens decide the order, not whether a message is read.

## Consequences

- The guarantees of step 2 are tested against adversarial simulated outputs and gated at 0
  violations.
- The recall step 2 adds depends on the model and is measured with `evals:screen` on a real
  provider. That has not been run in this repository; see the README.
- set2 stays held out for that measurement. Its rule failures were not studied.
