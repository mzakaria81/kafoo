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
