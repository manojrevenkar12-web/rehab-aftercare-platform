# 0005: Billing unknowns go to a person

## Status

Accepted, 2026-10-25.

## Context

The sources say what a completed programme needs:

- cost approval (G4802);
- an invoice;
- a participation record (G4832);
- closing documentation (G4819), signed;
- records kept for 10 years.

They do not say how an early end is paid. The DRV rate table could not be read from here.

## Decision

- A claim is assembled only from recorded facts. Anything missing is a listed problem, and a
  claim with a blocking problem stays `draft`.
- An early end makes the claim `needs_review`. Billing decides the units to bill and must leave
  a note. The decision is audited.
- Rates are configuration and marked `rate_source: placeholder`. Every claim carries the source
  of its rate, and the console warns while any claim uses a placeholder.

## Consequences

- The system never invents money. The price of that is a manual step for early ends, until the
  real rule is known and configured.
