# 0001: One Rails application, one PostgreSQL database

## Status

Accepted, 2026-10-25.

## Context

The work is a chain of state changes that must not half-happen:

- an enrolment is approved;
- a unit is recorded and completes the programme;
- a check-in is escalated;
- a draft is approved and applied;
- a claim is assembled and submitted.

Each of these needs an audit event. Several also need background work: a model call, or a daily
deadline scan.

## Decision

- Rails in API mode, with PostgreSQL as the only store. Solid Queue's tables live in the same
  database (`db/migrate/20261025000001`). A job is therefore enqueued in the same transaction as
  the change that caused it, and is never enqueued for a change that rolled back.
- The schema is kept as SQL (`db/structure.sql`). Check constraints, partial indexes and the
  audit trigger are part of it, not hidden in Ruby.
- Concurrency is handled with row locks and `lock_version` on enrolments and claims. Every write
  from outside is idempotent: unit idempotency keys, one draft per input digest, one claim per
  enrolment.

## Consequences

- There is one thing to back up and one thing to reason about. Job throughput is bounded by
  PostgreSQL, which is far beyond what aftercare check-ins need.
- A separate queue (Sidekiq/Redis) would be needed only if model calls grew by orders of
  magnitude. The job classes would not change.
