# Operations: Reha-Zentrum Spreebogen (demo)

Generated 2026-11-21T16:32:51+01:00 by `bin/rails ops:report`, over the last 14 days. Do not edit by hand.

## Releases (reviews pooled over all clinics)

| Workflow | Baseline → candidate | Reviews | Rejected | Rejected or edited | 95% interval of the change | Decision |
|---|---|---:|---:|---:|---|---|
| check_in_reply | check-in-reply/2 · simulated-1 → check-in-reply/3 · simulated-1 | 180 / 170 | 6.1% → 3.5% | 36.1% → 21.2% | -7.5 to +2.2 pts; -24.0 to -5.5 pts | **pass** |
| closing_report | closing-report/1 · simulated-1 → closing-report/2 · simulated-1 | 70 / 24 | 7.1% → 4.2% | 47.1% → 33.3% | -12.2 to +13.6 pts; -33.0 to +9.1 pts | **wait** |
| plan_change | plan-change/2 · simulated-1 → plan-change/2 · simulated-1-mini | 90 / 60 | 7.8% → 25.0% | 27.8% → 55.0% | +5.4 to +30.1 pts; +11.2 to +41.7 pts | **block** |

## Check-ins

18 of 21 due check-ins (85.7%) were answered within 24 h; median 5.3 h, slowest tenth 18.1 h. 4 open, 1 past the promise.

## Model calls

| Workflow | Prompt | Calls | Failed | p50 | p95 | Tokens in / out | Cost (placeholder rates) |
|---|---|---:|---:|---:|---:|---:|---:|
| check_in_reply | check-in-reply/3 | 23 | 1 | 2.9 s | 4.6 s | ≈19812 / 5325 | €0.0179 |
| check_in_screen | check-in-screen/1 | 24 | 0 | 0.9 s | 1.8 s | ≈12084 / 1327 | €0.0080 |
| closing_report | closing-report/2 | 2 | 0 | 0.0 s | 0.0 s | ≈547 / 216 | €0.0006 |

## Alerts

- **critical** 86% of due check-ins were answered within 24 h (target 95%)
- **critical** plan change: plan-change/2 · simulated-1-mini is worse than plan-change/2 · simulated-1 — rejected rose from 7.8% to 25.0% (95% interval of the rise +5.4 points to +30.1 points)
- **warning** 1 check-in waiting longer than 24 h
