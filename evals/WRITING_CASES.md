# Writing held-out evaluation cases

Held-out sets measure the red-flag rules and the pseudonymiser on messages their author never saw.
Whoever writes a set must not read `config/ai/red_flags.yml`, `app/domain/ai/`, `evals/dev/` or
any earlier held-out set. Write from this page only. Everything must be invented: no real people,
no real phone numbers or addresses (use `.example` e-mail domains).

Put a new set in `evals/heldout/<set>/` with two files. Its first run is recorded once with
`bin/rails evals:heldout[<set>]` and never rewritten. If anyone studies its failures to change the
rules, write `regression` into `evals/heldout/<set>/STATUS`: it is then a dev set, and a new
held-out set is needed.

## red_flags.yml

Messages a patient in German rehabilitation aftercare might send to their therapist through an
app, after a training session, in German or English, as people actually write: short, colloquial,
sometimes with typos, dialect, missing punctuation, several topics in one message.

```yaml
cases:
  - { id: h-001, message: "…", expected: [fall] }
  - { id: h-002, message: "…", pain_score: 8, previous_pain_score: 5, expected: [severe_pain] }
```

`pain_score` (0-10, this check-in) and `previous_pain_score` (the one before) are optional.
`expected` lists the flags a careful clinician would want raised:

| Flag | Raise it when the patient reports |
|---|---|
| `chest_pain` | chest pain, pressure or tightness in the chest |
| `breathlessness` | shortness of breath, not getting enough air (beyond normal exertion) |
| `neurological` | numbness, paralysis or sudden weakness in a limb or the face, speech problems |
| `self_harm` | thoughts of suicide, of not wanting to live, or of harming themselves |
| `fall` | that they fell (a fall that happened, not fear of falling) |
| `wound_or_fever` | fever, or a wound or scar that is red, swollen, oozing or has pus |
| `severe_pain` | a pain score of 8 or more |
| `pain_jump` | a pain score at least 3 above the previous one (and below 8) |

Include harmless messages too (about half), and in particular ones that look close to a flag:
denials ("no chest pain"), fear without the event ("afraid of falling"), past events that are
over, exertion that is normal ("out of breath after the stairs, as expected"? decide and label
it as a clinician would). Write at least 80 cases, mixing German and English.

## pseudonymization.yml

Messages in which the patient (or someone writing for them) mentions the patient's identity.

```yaml
cases:
  - id: p-001
    identity: { full_name: "…", birth_date: 1961-05-02, insurance_number: "…", phone: "…", email: "…@….example" }
    text: "…"
    mentions: ["…"]      # every piece of identity as it appears in the text, which must not survive
    keep: ["…"]          # clinical words in the text that must survive
```

`insurance_number` is a German pension insurance number: 2 digits, 6 digits (the birth date as
DDMMYY), one capital letter, 2 digits, 1 digit, e.g. `12 020561 S 01 7` (written with or without
spaces). Vary how identity is written: first name only, surname only, initials with surname,
possessive forms ("Müllers Knie"), double names, umlauts, dates in different formats, phone
numbers with different separators, identity inside an e-mail signature. Write at least 20 cases.
