# ADR-0016 — What Kafoo remembers between conversations

**Status:** Accepted — the founder answered all four questions on 2026-08-13. The answers are
recorded in "The four questions, answered" at the foot, and **question 3 was answered against the
recommendation**, which widens the scope. Read that section before building.
**Date:** 2026-08-13
**Decider:** Founder
**Depends on:** ADR-0015 (one conversation, not a questionnaire)

> This ADR was written as a proposal and held there deliberately. Persistent memory is one of the
> three things CLAUDE.md says to stop and ask about — *a change would collect a new category of
> personal data* — and the right response to that trigger is a written proposal and a specific
> question, not an implementation with a note attached. The questions were asked and answered the
> same day.

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

## The four questions, answered — founder, 2026-08-13

**1. Is the no-gate exemption granted? — YES.** The assistant writes memories without asking each
time, bounded by the three rules above. The conditions are not decoration: **rules 1 and 2 are what
was granted, not what was recommended alongside it.** A build that stores memories a Cook cannot
hear on demand, or cannot delete with one sentence, has not implemented this decision — it has
implemented the exemption without the thing that made it acceptable.

**2. Retention — expires with the dormancy window (ADR-0007).** One retention rule for the whole
product. A memory belonging to a Person who has gone dormant expires with everything else that
Person's inactivity expires. No second clock, no per-memory expiry, no "twelve months untouched".

**3. Cooks *and* Customers — answered against the recommendation, and the scope is wider than the
question asked.** The founder's words:

> Both, and also save the customer preferences in terms of previously ordered Meals and accordingly
> recommend similar Meals.

Three consequences follow and each one is load-bearing:

- **The sensitive half is now in scope from day one.** Customer memory is where food preferences,
  and eventually allergies and dietary restrictions, live. Rule 3 above is therefore not a
  future refinement — **the consent question before storing a health-adjacent fact is required in
  the first version that ships to a Customer.** `business-rules.md` binds here and is unchanged.
- **Order history is not memory and must not be copied into it.** "Previously ordered Meals" is
  already a fact the database holds, in `orders`, owned jointly and protected by its own RLS. A
  recommendation reads it directly. **Duplicating it into a memory row would create a second copy
  of purchase history with a second set of policies to keep correct, and the second copy is the one
  that leaks.** Memory holds what a Customer *said* («مابحبش الحار»); the Orders table holds what he
  bought.
- **This part cannot be built yet, and that is a sequencing fact rather than an objection.** Orders
  are E4 and do not exist — there is no `orders` table, so there is no purchase history to
  recommend from. Customer memory of what a Customer *says* can be built now; recommendation from
  order history arrives with Orders.

**4. Does a Cook's memory inform what a Customer sees? — NO.** Memory serves the conversation of the
person it belongs to and nothing else. It never enters ranking, discovery, or another person's
screen. This is now a rule, not a default, and the RLS on the table must make it structurally true
rather than merely intended.

## What is now buildable, and what it must include

In this order:

1. One table, owner-scoped, **RLS enabled in the same migration**, with a test proving a non-owner
   reads zero rows. Non-negotiable and unchanged.
2. «إيه اللي انت فاكره عني؟» — spoken, on every screen, answering with the memories held.
3. «انسى ده» and «انسى كل حاجة» — the second behind the confirmation gate.
4. The consent question before any health-adjacent fact is stored, for Customers and Cooks alike.
5. Retrieval into the conversation, treating every retrieved memory as **untrusted data quoted to
   the model, never as instructions to it.**

Recommendation from Order history is deferred to E4 and reads `orders` directly. It is not a memory
feature and must not become one.
