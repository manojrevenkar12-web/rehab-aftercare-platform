# 0003: Pseudonymise before any model

## Status

Accepted, 2026-10-25.

## Context

Check-ins are health data under GDPR Art. 9. Patients write their name, date of birth, phone
number and pension insurance number into messages. Model providers are processors at best.

## Decision

- Every text sent to a model first passes `Ai::Pseudonymizer`. It replaces the patient's
  identity, and any other e-mail, phone or insurance number, with placeholders. Facts sent to
  models carry only the pseudonym (`P-XXXXXXXX`).
- `Ai::Client#chat` checks the serialised request for any identity value of the patient and
  **refuses to send it** if one is found. The draft then fails visibly.
- Drafts are stored pseudonymised. Placeholders are restored only when an authorised person
  reads the draft.
- Health text never goes to logs (`config/initializers/filter_parameter_logging.rb`). Audit
  events record what happened, not what was written.

## Consequences

- Each identity form we missed was found by a blind set:
  - set1 leaked 4 of 48 mentions (transliterated umlauts, hyphenated dates, two-digit years,
    dotted phone numbers);
  - after the fixes, set2 leaked 1 of 60 (a phone number spelled out in words).
- The leak guard is the backstop for forms the replacer misses. Spelled-out numbers are a known
  gap.
