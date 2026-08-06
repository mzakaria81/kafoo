# ADR-0010 — Address a Cook in their own grammatical form

**Status:** Accepted
**Date:** 2026-08-04
**Decider:** Founder

## Context

Every Cook-facing string in Kafoo addresses the Cook as a man. This was never decided; E1 was written
that way and E2 copied it for consistency. The founder's position is that most Cooks will be women,
which makes the current copy wrong for the majority of the people the product exists to serve.

Arabic conjugates the second person. There is no neutral form of *كمّل* the way there is of
"Continue". A woman reading *مش قادر توصل لرقمك؟* is being addressed as a man, in a product whose
first principle is trust and whose register is deliberately conversational rather than institutional.

**56 of 94 Arabic strings are affected. 38 are already correct for everyone.** Written Arabic without
diacritics spells the past tense and the possessive suffix identically for both — *طبخت إيه؟*,
*مطبخك اسمه إيه؟*, *ده اللي قلته* need no change at all. What breaks is imperatives and the present
tense: *كمّل* → *كمّلي*, *بتشتغل* → *بتشتغلي*, *جرب تاني* → *جربي تاني*.

Two of the 56 are a different problem. *الطباخ مقدرش ياخد الطلب* and the AI estimate notice are shown
to a **Customer** and describe a **Cook**, so they need the Cook's stored form, not the reader's.

The cost grows with every epic. E2 alone has 47 tasks left, most of which add strings.

## Options considered

| Option | Cost | Risk | Reversibility |
|---|---|---|---|
| Rewrite all copy to avoid second-person verbs | ~56 strings, no schema, no new data | Kills the product voice — Egyptian imperatives are hard to avoid and the result reads like signage, not a person | Easy |
| Store gender on the Cook | ~56 strings + migration + a question | Collects a demographic field the feature does not need, which `business-rules.md` forbids collecting "just in case" | Hard — deleting a collected field is not the same as never collecting it |
| Store **form of address**, asked in the conversation | ~56 strings + migration + a fifth question in E1's conversation | Lengthens onboarding by one question | Moderate |
| Default feminine, changeable in settings | ~56 strings + migration, no new question | Men are addressed wrongly until they find a setting they have no reason to look for | Easy |

## Decision

We store a **form of address**, not a gender. The feature needs to know which verb ending to use; it
does not need to know anyone's gender, and the narrower field cannot later be repurposed for ranking
or advertising. It is asked as a question in the Kitchen Profile conversation, so a Cook is addressed
correctly from their first sentence rather than discovering a settings toggle later.

Mechanically: ICU `select` in both ARB files, the stored preference supplied through a Riverpod
provider, and one column on the Cook's row.

**This lands after E2 ships, not now.** E2's remaining tasks will add perhaps thirty more strings that
then need converting too, and that is accepted rather than overlooked — the alternative is pausing
Meal Publishing mid-flight and finishing it in a half-converted app.

`prompts/meal-analysis.md` is instructed never to address the Cook in the second person. That keeps
model output gender-free by construction, so no preference is passed to the model and no prompt needs
re-evaluating when this changes.

## Consequences

**Accepted costs.** The Kitchen Profile conversation grows from four questions to five, against a
product rule that treats every added question as a failure to infer. This one cannot be inferred: a
name does not reliably carry it, and guessing wrong is worse than asking. Around 56 call sites become
function calls, and every widget rendering Cook-facing copy needs the preference in scope. English
entries carry an ICU `select` with identical branches on both sides purely because the generator
requires matching placeholders across locales — noise in a file no Egyptian Cook will ever read.

A Cook's form of address becomes visible to Customers through the two third-person strings. That is a
deliberate exposure, not a leak, and it is why the field is a form of address rather than a gender.

Between E2 shipping and this landing, the app addresses every Cook as a man, and we know it.

**What this forecloses.** Nothing structurally. A later move to fuller gender data would be a new
decision with its own privacy answer, and this ADR is not a step toward one.

**What the parity gate will not catch.** `./scripts/verify.sh` compares ARB key presence between
locales, not placeholders or `select` branches. A string converted in Arabic and missed in English,
or a `select` missing its `other` branch, passes the gate and fails at generation or at runtime. The
sweep must extend the check, not rely on it.

> Done first, in T093: `scripts/check-l10n-parity.py` now compares placeholder sets, select
> presence and branch names in both directions, and refuses a select with no `other` branch. It was
> built and mutation-tested **before** any string was converted, so the conversion could not ship
> unchecked.

## What landing it actually cost, 2026-08-06

The estimates above were made against E2's ARB file. E2 nearly doubled it before this landed, so
the numbers are recorded here rather than left to read as though they had held.

**86 keys, not ~56**, out of 183. The per-key verdicts are in
`docs/ops/wp007-string-classification.md`: 83 switch on the reader (`addressForm`), 4 describe a
Cook to somebody else (`cookForm`), 22 are second-person but spelled identically for both forms in
undiacritized Egyptian, and 70 address nobody. **97 call sites** in `lib/`, plus 106 in tests.

**The preference reaches widgets through an `InheritedWidget`, not a Riverpod provider.** The app
has no `ProviderScope` above the Navigator — E1 deliberately shipped without a state-management
package and E2 added Riverpod only inside the Meal feature — so a provider would have meant either
adding a root scope or converting every plain `StatelessWidget` in the tree to a consumer. Both are
larger edits than the feature, and neither buys anything: the value is read, never written, by the
widgets that need it. `AddressFormScope` is declared in `apps/mobile/lib/l10n/address_form.dart`
and installed by `MaterialApp.builder`, which is above the Navigator — a scope inside `home` would
be invisible to every pushed route, which is all of them.

**Absent from the tree it answers `other`.** A screen shown outside the signed-in surface, and
every widget test that does not care, renders masculine rather than crashing for want of a scope.
That is the same rule as an unset stored value, applied one level out.

## Settled 2026-08-06: Customers are addressed as men, for now

Four Customer-facing strings address the **Customer** in the second person — `orderRejected`,
`publicMealAllergensUnknown`, and their neighbours — while Kafoo stores a form of address for Cooks
only. Giving Customers one would collect a new category of personal data from a new and much larger
population, which is the founder's call and not an implementation detail.

**Founder decision, 2026-08-06: Customers stay masculine for now.** So in those strings the
Customer-directed verbs (`جرب`, `اطلب`, `اسأل`) sit *outside* any `select` and the Cook-describing
clause switches on `cookForm`. Each carries an ARB `description` saying so, because the next person
to read one of these strings will otherwise see a half-converted sentence and assume it was missed.

This is a deferral, not a conclusion: it costs nothing to revisit, and revisiting it means asking
Customers a question and answering the four privacy questions for a new field — not editing these
strings again.

## Settled alongside this: the Arabic word for Cook is الطباخ

Two words were in use — the ARB strings said **الطباخ**, the prompts said **الكوك**. Founder
decision, 2026-08-04: **الطباخ**. The strings are already correct; `prompts/meal-analysis.md` is
not, and changing prompt wording is a semantic change, so it bumps `version` and forces a
re-evaluation. That is the same replay T088 already needs for the register fix, so the two are done
together and the corpus is replayed once rather than twice.
