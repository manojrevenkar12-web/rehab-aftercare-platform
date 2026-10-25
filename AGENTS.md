# Working on this repository

## Fast feedback

- `bundle exec rspec` runs in about 10 s. It needs PostgreSQL via `DATABASE_URL`, or
  `TEST_DATABASE_URL`, or a local `rehab_aftercare_test` database.
- `bin/rails evals:run && bin/rails evals:gate`: the dev evaluation and its thresholds
  (`config/evals.yml`).
- `cd web && npm run typecheck && npm run lint && npm test`

## Invariants

Each one has a spec or a CI step.

- **Models draft, people decide.** No model output changes data until a permitted person
  approves it. A held draft cannot be approved unedited, and edits are checked again
  (`spec/domain/workflows_spec.rb`, `spec/requests/care_flow_spec.rb`).
- **Nothing identifying reaches a model.** Text goes through `Ai::Pseudonymizer`, and
  `Ai::Client` refuses any request that still contains identity (`care_flow_spec`: "never lets
  identity reach the model").
- **The model screen only adds red flags.** Each added flag needs a quote from the message. The
  `screen_guarantees` suite is gated at 0 violations.
- **Health text never goes to logs** (`config/initializers/filter_parameter_logging.rb`).
- **Authorisation is the matrix.** Change `spec/policies/authorization_matrix.yml` together with
  a policy, never the policy alone.
- **The audit trail is append-only and hash-chained** (a database trigger; `spec/models/audit_event_spec.rb`).
- **Thresholds, DRV rules, rates, patterns and SLAs live in `config/`, not in code.**

## Held-out sets

- Never change the rules or the pseudonymiser to pass `evals/heldout/<set>` before its first
  run is recorded.
- A first run (`reports/evals/heldout-<set>.*`) is never rewritten. CI checks each one has a
  single commit.
- If you study a set's failures, write `regression` into `evals/heldout/<set>/STATUS`. Then have
  someone who has not seen the code write a new set from `evals/WRITING_CASES.md` only.
- set1 is a regression set. set2 is held out, and its first model-screen run is still to be
  recorded.

## Data

Everything is invented. E-mail domains end in `.example`. No real people, phone numbers or
addresses.
