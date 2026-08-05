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

## Settled alongside this: the Arabic word for Cook is الطباخ

Two words were in use — the ARB strings said **الطباخ**, the prompts said **الكوك**. Founder
decision, 2026-08-04: **الطباخ**. The strings are already correct; `prompts/meal-analysis.md` is
not, and changing prompt wording is a semantic change, so it bumps `version` and forces a
re-evaluation. That is the same replay T088 already needs for the register fix, so the two are done
together and the corpus is replayed once rather than twice.
