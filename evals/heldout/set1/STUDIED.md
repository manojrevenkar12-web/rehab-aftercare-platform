# set1: studied after its first run

The first run is `reports/evals/heldout-set1.json` and is not rewritten. Written blind from
`evals/WRITING_CASES.md`, it showed that keyword rules do not survive messages as patients
write them:

- **Emergency flags found: 10 of 24.** The rules missed:
  - dialect ("Ziehe in dr Bruscht");
  - paraphrase ("ich red so verwaschen und der Mundwinkel hängt", "nicht mehr aufwache");
  - word order the patterns did not expect ("kriege nachts kaum Luft").
- **28% of harmless messages escalated.** The rules cannot tell when an event happened or to whom:
  - a past event ("2019 Herzinfarkt mit Brustschmerzen");
  - someone else's ("mein Mann ist gestürzt");
  - fear without the event, and questionnaire-style denials ("Sturz? Nein").
  - They also took a measured 36.9 °C as fever.
- **Pseudonymisation: 4 of 48 mentions survived**: a transliterated name (Joerg Woehrle for Jörg
  Wöhrle), dates with hyphens or a two-digit year after a month name, a phone number with dots.

Reading these failures made set1 a regression set (`STATUS`). The rules and pseudonymiser were
then changed (see the commit after this file), and a new held-out set, set2, was written blind
by someone who had seen neither the rules nor set1.
