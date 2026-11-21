# 0006: An operations ledger, and a release gate on reviewers' decisions

## Status

Accepted, 2026-11-21.

## Context

Three questions had no answer in the product:

1. Are check-ins answered within the 24 hours the programme promises? `answered` was a status
   with no time, so the promise could only be guessed from `updated_at`.
2. Are the jobs that make drafts and run the screen keeping up, and what do the model calls cost
   and how long do they take, per workflow?
3. When a prompt is rewritten or the model is swapped (for a cheaper or EU-hosted one), are the
   drafts as good as before? The offline evaluation (`evals:gate`) checks that the code checks
   hold injected mistakes. It cannot say whether therapists find the drafts useful.

The best signal for the third question is already produced every day: a therapist approves a
draft as written, edits it, or rejects it. Every draft records its `prompt_version` and `model`.

## Decision

- **A call ledger, numbers only.** `Ai::Client` writes one `ai_calls` row per request (sent,
  refused by the leak guard, or failed): workflow, prompt version, model, provider, latency,
  tokens, cost in integer micro-euros, outcome, clinic. It never stores messages or replies, so
  the ledger holds no health data and can be kept and aggregated freely. Providers that report
  token usage are used as reported; otherwise tokens are estimated (four characters a token) and
  marked as estimated. Rates are in `config/ai/costs.yml` and are placeholders. A failed ledger
  write is logged and swallowed: it must never fail a draft. The offline evaluation turns the
  ledger off (`log: nil`) so replayed cases are not clinic traffic.
- **Measured, not inferred.** `check_ins.answered_at` is set when an approved reply is applied,
  and `ai_drafts.edited` records whether the reviewer changed anything (an "edit" that changes
  nothing is not counted).
- **The operations view** (`GET /api/v1/ops`, console page *Operations*, clinic administrators
  only) shows, for the administrator's clinic over the window in `config/ops.yml`: the share of
  due check-ins answered within the promise, waits, open and overdue check-ins; drafts and what
  reviewers did; model calls with p50/p95 latency, tokens and cost; and the shared Solid Queue as
  counts (no job arguments, no error text, which could quote a patient). Alerts come from the
  thresholds in `config/ops.yml`; the promise itself stays in `config/aftercare/programmes.yml`.
- **The release gate** (`Ops::ReleaseGate`, `bin/rails ai:release_gate`, shown in the view). A
  release is a `(prompt_version, model)` pair. For each draft kind, the newest release with
  reviewed drafts is compared with the one before it on two rates: rejected, and rejected or
  edited. Reviews are **pooled over all clinics**, because a release is the same everywhere and
  one clinic is too small to decide. The interval is Newcombe's hybrid score interval for a
  difference of two proportions (checked against his published example in the spec):
  - **wait** until both releases have `min_reviews` reviews;
  - **block** when either rate is higher with 95% confidence (the interval is above zero);
  - **pass** when both rates are, with 95% confidence, at most `non_inferiority_margin` higher;
  - otherwise **wait**: the evidence does not settle it yet.
  The task exits 1 on block and, for two named releases, 2 on wait, so a deploy pipeline can stop
  a rollout to further clinics.

## Consequences

- Two gates, at two moments: `evals:gate` before a merge (checks hold every injected mistake),
  the release gate after a release meets real reviewers. Neither changes what a reviewer must
  do; both only decide what ships.
- Reviewers' decisions are a lagging, noisy signal. A release that makes drafts subtly worse in
  a way reviewers do not notice will pass. Reviewers who rubber-stamp make every release look
  good. The gate is a floor, not proof of quality.
- Pooling reviews shows each clinic aggregate release rates that include other clinics'
  reviews. They are counts about the product, not about any clinic's patients, but a deployment
  should say so in its data-processing agreement.
- Not built: routing a share of drafts to a candidate release inside one clinic (a canary), an
  operator role that sees all clinics, and automatic rollback. The gate decides; a person or a
  pipeline acts.
- The demo's history (`lib/demo_data/history.rb`) is invented to exercise all three decisions.
  Its numbers show the mechanics, not how any model performs.
