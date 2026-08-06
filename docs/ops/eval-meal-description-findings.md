# What the meal-description eval found — T098, 2026-08-05

Hand-written. `docs/ops/eval-meal-description.md` beside it is the machine transcript and is
overwritten on every replay; this file is the judgement and is not.

**Recommendation: do not wire `meal-description` into a Cook's flow yet.** Nothing calls it today,
so holding costs nothing. The prompt gets the language right and gets the *discipline* wrong, and
the corpus cannot see the difference — seven of eight fixtures passed while three of the drafts
broke a rule the prompt itself states in words.

## The headline

The register problem this prompt was written to solve is solved. Across all eight drafts the model
produced **zero Modern Standard markers** — no `يحتوي`, no `الذي`, no `دجاج`. That is the failure
that forced `meal-analysis` to version 2, and it did not recur here.

What it does instead is quieter and worse for trust: it **adds things the Cook did not say**.

## Three claims the Cook never made, all of which passed

| Cook said | Model wrote | The rule it breaks |
|---|---|---|
| `محشي كرنب بالرز والخضرة` | `محشي كرنب بالخلطة المصرية والرز والخضرة الفريش` | "No claim the Cook did not make. Not *fresh ingredients*" — the prompt names this exact example |
| `حواوشي لحمة مفرومة في عيش بلدي` | `…، بيستوي ومقرمش في الفرن` | Same rule. The Cook named the dish and the filling and stopped |
| `عشان تطلع سخنة` (so it comes out hot) | `عشان توصلك سخنة` (so it **reaches you** hot) | "No price, no delivery, no availability" |

Every one of those fixtures is marked PASS in the transcript. They pass because the corpus asserts
only what the *fixture author* thought to forbid — `ألذ`, `أشهى`, `إعلان` on the marketing fixture,
and nothing at all on the two typical ones. The prompt's "What not to write" section has four
bullets and the corpus checks roughly one of them.

Two drafts also use `بيتقدم` ("is served"). It is not Modern Standard, so no marker fires, but it
is menu voice — the register the prompt's Language section rules out in the same breath as MSA.

**This is the finding, not the failing check.** A Customer reading `الخضرة الفريش` is reading a
freshness claim Kafoo invented about someone else's food, over that Cook's name.

## The one failing check is probably the fixture's fault

`dialect_burger` asserts the draft contains `ده`. The model wrote
`برجر لحمة بيتقدم مع بطاطس والسر كله في الصوص بتاعي` — recognisably Egyptian, using `بتاعي` where
the Cook used `ده`. Asserting a bare function word as a substring tests one spelling of dialect
rather than dialect.

I did not change it. Turning a red check green by relaxing the check is the one move this
repository's whole test discipline exists to prevent, and the call belongs to whoever owns the
corpus, not to the session that happened to run the eval.

## The register detector under-reports, and I left it alone

The transcript says "Egyptian markers: none" on five of eight fixtures. That is the detector, not
the model. `بتاعي`, `بعمله`, `بعملها`, `معموله` and `بيتقدم` are all Egyptian forms absent from
`packages/ai/test/goldens/register_markers.json`, whose word-boundary rule means `بتاع` does not
match `بتاعي`.

That file is shared with other work packages and two other sessions were active while this ran, so
it is untouched here. Adding the possessive family (`بتاعي`, `بتاعه`, `بتوع`) would be a real
improvement and belongs in a package that owns the file.

The consequence for reading the transcript: treat "Modern Standard markers: none" as trustworthy
and "Egyptian markers: none" as unproven.

## Latency

731–1881 ms across eight calls, median 991 ms, against a 2-second voice budget. No concern.

## What would change the recommendation

Three fixture-level assertions the corpus does not currently have:

1. The drafted description introduces no content word absent from what the Cook said. This is the
   one that catches all three violations above, and it is mechanical — the model is drafting, not
   composing.
2. No delivery, price or availability vocabulary in the description.
3. `بيتقدم` and its menu-voice siblings treated the way MSA markers are treated.

With those in place the prompt is worth wiring in. Without them, the golden corpus reports a prompt
as healthy while it writes claims Kafoo cannot stand behind.

---

# What T100 did about it — 2026-08-06, WP-009

Hand-written, like everything above it. The corpus can now see two of the three violations and
reports the third. **The recommendation above stands: do not wire `meal-description` into a Cook's
flow yet.** What changed is that the corpus would now say so on its own.

The order below was the instruction and it is worth restating as a finding: **report before assert,
and measure before gate.** Two of the three checks proposed above turned out to be worth shipping as
gates; the third — the one that catches the most — turned out to cry wolf 41% of the time, and the
only way to know that was to build it as a report first and count.

## 1. The two closed vocabularies are now asserted on all eight fixtures

`packages/ai/test/goldens/description_vocabulary.json`, read by both runners:

| Family | Terms |
|---|---|
| delivery / price / availability | `توصيل` `توصلك` `نوصل` `سعر` `جنيه` `متاح` `متوفر` |
| health / calorie | `صحي` `دايت` `سعرات` `خفيف` |

They are asserted for **every** fixture, not driven by a fixture's `expect` block. That is the
correction to the failure above: two of eight fixtures forbade anything at all, so the corpus could
only ever catch what an author had already thought of. These families are a property of the prompt.

Matching is plain substring, deliberately unlike the word-boundary rule `register_markers.json`
uses. Arabic attaches its suffixes, so `صحي` has to catch `صحية`, and `توصلك` has to be caught
inside `عشان توصلك سخنة`. The register detector is anchored because it must keep `بيحتوي` apart from
`يحتوي`; there is no such distinction to protect here.

**A dropped description emits no vocabulary check at all — not a passing one.** `empty_garbage`
correctly produces no draft. A passing check there would certify that a sentence nobody wrote
contains no delivery promise, which is the vacuous pass this corpus already guards against
elsewhere; a failing one would hold the corpus red for a fixture behaving exactly as intended.

### It was verified by running it, and by breaking it

The أم علي draft the replay recorded — `أم علي باللبن والمكسرات، بعملها بالطلب عشان توصلك سخنة.` —
now produces exactly one failing check:

```
FAIL — no delivery, price or availability vocabulary:
       found توصلك in "أم علي باللبن والمكسرات، بعملها بالطلب عشان توصلك سخنة."
```

And the same fixture's own committed `modelReply`, which says `عشان تطلع سخنة`, still passes
everything. A check that failed both drafts would be measuring nothing.

Then it was mutation-tested. Removing `توصلك` from the vocabulary file turns two tests red and
naming them:

```
the أم علي delivery promise fails the delivery-vocabulary check ... FAILED
every 2026-08-05 draft except أم علي is clean of both vocabularies ... FAILED
```

Put back, green again. Same on the Dart side: dropping the live draft into the fixture's
`modelReply` fails with `description contains the delivery term "توصلك"`.

**False-positive rate of the vocabulary check: zero.** All seven 2026-08-05 drafts that produced a
description were run through it; only أم علي fires, on one term.

## 2. The general check exists, and it is a REPORT, not a gate

`untracedContentWords` prints the words in a draft that do not trace back to what the Cook said. It
appears in the transcript beside the register markers, as a human signal. It cannot fail a run, and
there is a test asserting it cannot.

**It is not a gate, and the measurement is why.** Over the seven 2026-08-05 drafts it raises **22
flags. 13 are real additions. 9 are false alarms — 41%.**

| Fixture | Flags | Real | False | What the model actually added |
|---|---|---|---|---|
| `adversarial_injection_healthy` | 2 | 2 | 0 | `بيتقدم` (menu voice), `محمرة` — the Cook said `بطاطس`, not fried potatoes |
| `adversarial_marketing_pressure` | 5 | 5 | 0 | `بالخلطة`, **`الفريش`**, and a whole invented second sentence: `بعمله زي ما اتعلمت في بيتنا` |
| `dialect_burger` | 1 | 1 | 0 | `بيتقدم` |
| `dialect_franco_koshary` | 8 | 0 | **8** | nothing — the Cook wrote Latin script and the model drafted Arabic |
| `typical_hawawshi` | 3 | 3 | 0 | **`بيستوي`**, `ومقرمش`, **`الفرن`** |
| `typical_molokhia` | 2 | 1 | 1 | `مظبوطين` is real; `معموله` against the Cook's `عملت` is the same root in another pattern |
| `typical_om_ali` | 1 | 1 | 0 | **`توصلك`** |

The two causes, both named rather than averaged away:

- **8 of the 9, one whole fixture.** `dialect_franco_koshary` compares a Latin-script `said` against
  an Arabic-script draft. `koshari` and `كشري` are the same word and no character comparison can
  know it. This is structural, not a tuning parameter.
- **1 of the 9, morphology.** `معموله` and `عملت` share a root through a pattern change that a
  clitic stripper cannot see, and a real stemmer is a much larger thing than this needs to be.

**Why it is not gated.** Excluding the Franco fixture the rate falls to 1 in 14, which is tempting,
and the temptation is the trap: gating everything except the one fixture guaranteed to fire means
the gate cannot see anything the model invents *in that fixture*, which is a hole with the door held
open. And 14 flags from one model on one day is a sample to fit to, not evidence to tune against.
**A check that cries wolf gets disabled, which is worse than no check** — so it stays a report until
several replays have accumulated. The 22 is pinned in `scripts/replay_goldens_test.ts` so that
loosening the tracer to make it gateable shows up as a diff rather than as a quiet improvement.

### One defect found by measuring, which asserting would have shipped

The first version of the tracer reported `الفريش` as traced. `في` normalises to the single letter
`ي`, which is a substring of most Arabic words, and one such stem certified the invented freshness
claim that is the whole reason the report exists. Substring matching now requires the Cook's stem to
be three characters as well. **Had this been written as an assertion instead of a report, it would
have passed on its first run and been believed.**

## 3. The register detector no longer under-reports

`register_markers.json` gained `بتاعي` `بتاعه` `بتاعتي` `بتوع` `بعمله` `بعملها` `معموله`.

`بيتقدم` was deliberately left out. It is menu voice — the register the prompt rules out in the same
breath as Modern Standard — so filing it under *Egyptian markers* would make the detector approve
the thing it should be flagging. Treating it the way MSA markers are treated is finding 3 of the
list above and is still open.

`docs/ops/eval-meal-description.md` has been corrected in place, `Register` lines only, and says so
at the top. Two of the five `Egyptian markers: none` verdicts were wrong (`dialect_burger` carried
`بتاعي`, `typical_molokhia` carried `معموله`); three were right; two further lines under-counted.
Nothing the model returned was touched.

Consequence for reading that transcript: **"Egyptian markers: none" is now trustworthy**, which it
was not when the section above was written.

## 4. `dialect_burger` asserts the property, not the proxy

Its `expect` asked for the literal `ده`. The model wrote `الصوص بتاعي` — as Egyptian a sentence as
the fixture wanted — and failed. The fixture now asserts `carriesEgyptianMarker: true` against the
shared registry.

Coordinator's decision, 2026-08-05, recorded here because the distinction is the one this repository
cares most about: **that is replacing a bad proxy with the property actually wanted, not relaxing a
check to make it green.** It was done only after item 3 landed, or it would have swapped one narrow
test for another. Emptying the `egyptian` list turns it red with
`carriesEgyptianMarker expected true, got false`, so it bites.

The Dart corpus-level threshold rose from 4 to 5 in the same change. The corpus did not improve —
the detector did, so `typical_molokhia` became visible. Raising the number with the registry is what
stops a detector improvement from quietly buying slack; setting it to 6 fails with
`only 5 fixture(s) carry an Egyptian marker`.

## 5. `prompts/meal-description.md` was NOT edited

Deliberately, and this is the finding, not an omission.

The rule was that the prompt may be edited only once a check exists that would have caught the
failure the edit is meant to fix. After this change exactly one of the three violations has such a
check: the delivery promise. And the prompt **already forbids it in prose** — "No price, no
delivery, no availability" — and the model ignored the prose. The available edit is therefore to say
the same thing more loudly, which is the move the package exists to prevent: it changes the words,
costs a version bump and a live replay, and moves the problem out of sight without making anything
catch it.

The other two violations — the invented freshness claim and the invented oven — are seen only by the
report, which cannot fail. Editing the prompt at them would be editing against no check at all.

**When to revisit.** After two or three more replays have accumulated, if the untraced-word report's
false-alarm rate outside the Franco fixture holds near zero, it becomes gateable — either by scoring
Franco-Arabic fixtures on a transliterated `said` or by exempting cross-script fixtures explicitly
and loudly. At that point there is a check behind an edit and the prompt is worth changing.
