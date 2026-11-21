# Repeatable tasks

## Ship a new prompt version

1. Change the prompt and bump `PROMPT_VERSION` in `app/domain/ai/workflows/<workflow>.rb`.
2. `bin/rails evals:run && bin/rails evals:gate`: the checks must still hold every injected
   mistake and hold no faithful draft.
3. Deploy. Drafts now carry the new version, and the release gate starts counting its reviews.
4. Watch the *Operations* page or run `bin/rails ai:release_gate[<kind>]`. Roll back on **block**;
   keep waiting on **wait**.

## Try a different model

Set `AI_MODEL` (and the endpoint) for one clinic's deployment first, and add its rates to
`config/ai/costs.yml` (the view warns about a model without a rate). The model name is part of
the release, so the gate compares it with the current model on the same prompt.

## Add an alert

Add the threshold to `config/ops.yml`, the rule to `Ops::Snapshot::Alerts`, and a request spec
in `spec/requests/ops_spec.rb`.

## Record a held-out first run

See `AGENTS.md`, "Held-out sets". A first run is never rewritten.

## Refresh the screenshots

`bin/rails db:seed`, start the server and `bin/jobs`, then `cd web && npm run screenshots`.
CI takes the operations screenshots from the booted image and uploads them as an artifact.
