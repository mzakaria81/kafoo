# ADR-0016 — What Kafoo remembers between conversations

**Status:** Proposed — **four questions for the founder, listed at the foot. Nothing is built while
this reads Proposed.**
**Date:** 2026-08-13
**Decider:** Founder
**Depends on:** ADR-0015 (one conversation, not a questionnaire)

> This ADR exists in this state deliberately. Persistent memory is one of the three things CLAUDE.md
> says to stop and ask about — *a change would collect a new category of personal data* — and the
> right response to that trigger is a written proposal and a specific question, not an
> implementation with a note attached.

## Context

The founder asked for memory, in these words:

> The app should have a memory of the previous interactions with Cook/Customer and use them while
> replying — same as the long-term memory created by the chat agents such as ChatGPT.

The product reason is sound and it is stronger for Kafoo than for a general assistant. A Cook who
has published eleven Meals should not be asked, on the twelfth, what her kitchen is called, whether
she delivers, or what she usually charges. A Customer who said once that his daughter cannot eat
sesame should not have to say it again — and **should certainly not have to say it again at the
moment it matters.**

Today Kafoo remembers nothing. Every conversation starts from an empty room.

## What is actually being proposed

**A small set of short, plain-Arabic facts per person, written by the assistant, readable and
deletable by that person, retrieved into the next conversation.**

Not a transcript. Not raw audio (that stays forbidden — ADR-0013 conflict 1). Not an embedding of
everything ever said. Facts, in the words the person used:

```
«بتطبخ محشي ورق عنب كل خميس»
«المطبخ بيفتح من ١١ لـ ٧»
«بتحب السعر يبقى رقم صحيح، مش بكسور»
```

Mechanically: one table, owner-scoped, RLS from the same migration that creates it, `pgvector` for
retrieval — the extension and the HNSW pattern already exist for Meal search (ADR-0011), so this
adds no new infrastructure. Retrieval is recency plus similarity to what is being discussed, capped
at a small number of facts per turn.

## The three rules that make this acceptable, and they are the whole proposal

Memory without these is surveillance with a friendly voice.

**1. Memory is visible, in the same channel it was collected.** «إيه اللي انت فاكره عني؟» is a
supported question with a spoken answer, on every screen, always. A Cook who cannot read cannot be
handed a settings page and told the memory is transparent. **If she cannot hear it, it is not
visible.**

**2. Forgetting is one sentence and it is immediate.** «انسى ده» removes the fact. «انسى كل حاجة»
removes all of them, behind the same confirmation gate as any other irreversible action. No
support ticket, no menu three levels deep, no soft delete that keeps the row.

**3. Health-adjacent facts are not stored without being asked for.** Allergies and dietary
restrictions are the most useful thing memory could hold and the most sensitive. `business-rules.md`
already binds: *stored only with explicit consent, never used for advertising or ranking outside the
Customer's own session, never shared with Cooks beyond what a specific Order requires.* Under this
proposal the assistant **asks before remembering one** — «أفتكر إن بنتك ماتقدرش تاكل سمسم، عشان
مانسألكش تاني؟» — and a «لأ» means it is used for this Order and dropped.

## The rule this collides with, and the exemption being requested

`.claude/rules/business-rules.md`: *"Every AI-derived field written to the database requires an
explicit human approval step in the flow."*

A memory is written by the assistant, from its own reading of a conversation. It is AI-derived. Under
the rule as written, every remembered fact needs its own approval, which in practice means the
assistant interrupting a Cook forty times an hour to ask permission to remember — the exact
questionnaire ADR-0015 just deleted, wearing a different hat.

**So this ADR requests a narrow, second exemption, of the same shape ADR-0011 granted to embeddings**
— and it is narrower in one way and wider in another, which is the honest part:

- **Narrower:** an embedding is 768 numbers shown to nobody. A memory is a sentence in Arabic, which
  a person could disagree with. So unlike an embedding it must be *inspectable* — hence rule 1.
- **Wider:** an embedding is derived from a Meal the Cook already published. A memory can be derived
  from anything said in passing. That is a real expansion of what the assistant writes unasked, and
  it is what makes rules 2 and 3 conditions rather than niceties.

The exemption's boundary, if granted:

> **A memory may be written without a gate. A memory may never become a field on a Meal, an Order,
> a Review or a Kitchen Profile without the normal approval step.** Memory informs what the
> assistant *says*. It does not fill in a form on the person's behalf. If a remembered price
> appears on a Meal, the Cook confirmed it aloud in this conversation like any other price.

## What this costs

**A new category of personal data, and the first one Kafoo holds that nobody typed on purpose.**
Everything stored today was answered into a question. This is inferred from talk. The privacy
questions in `business-rules.md` — why do we need it, how long do we keep it, who can read it, can
we avoid collecting it — have answers for the first, third and fourth, and **not for the second.
Retention is question 2 below.**

**A wrong memory is worse than no memory**, because it is confidently reused. The mitigation is
rules 1 and 2 and nothing else; there is no clever fix.

**Prompt injection now has a persistence path.** Anything a person says can reach a later
conversation. Memory must be treated as untrusted input on the way back in — quoted as data, never
as instructions — exactly as Meal descriptions already are.

**It is not free to run.** Extracting facts is a model call per conversation, and retrieval adds an
embedding call per turn. Small against the cost of the conversation itself (ADR-0017), and worth
stating.

## Options considered

| Option | Why not |
|---|---|
| No memory | Honest, cheap, and the product stays worse every conversation. The founder has asked for it, and the repeat-question problem is real |
| Remember everything, transcript-style | Largest privacy exposure, worst retrieval quality, and it would hold raw conversation content between two people. Rejected outright |
| Facts, but hidden — no way to hear or delete them | The cheapest to build and the one that ends the product. A Cook who discovers Kafoo remembered something she cannot see or remove has learned something about Kafoo that no feature recovers |
| Facts, visible, deletable, consent-gated for health data | **Proposed.** |
| Per-conversation memory only (never crosses sessions) | Solves the in-flow repetition ADR-0015 already covers, and none of what the founder asked for |

## The four questions this needs answered before anything is built

1. **Is the no-gate exemption granted?** The assistant writes memories without asking, bounded as
   above. Yes or no; a "yes with conditions" needs the conditions written into this file.
2. **How long is a memory kept?** Options with real consequences: forever until deleted (most
   useful, largest exposure); expire after ~12 months untouched (a stale kitchen fact stops being
   quoted); expire with the dormancy window ADR-0007 already defines for a phone credential
   (**the recommendation — Kafoo already has this concept and one retention rule is easier to keep
   honest than two**).
3. **Do Customers get memory in the MVP, or Cooks only?** Cooks only is smaller, safer, and matches
   the one journey the trial is testing. Customer memory is where the food-preference and allergy
   data lives, which is the sensitive half. **Recommendation: Cooks only for the five-Cook test.**
4. **Does a Cook's memory ever inform what a *Customer* is shown?** Today: no, and the
   recommendation is to keep it no. Memory serves the conversation of the person it belongs to, and
   nothing else. Saying so now costs nothing; discovering later that it leaked into ranking costs
   the product.

## Notes for Claude Code

**Do not implement against this ADR while it reads Proposed.** No table, no migration, no
extraction prompt, no retrieval. If asked to build memory, say that ADR-0016 is unresolved and that
the four questions above are the blocking ones.
