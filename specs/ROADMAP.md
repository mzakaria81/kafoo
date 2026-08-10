# Epics after voice-first

**Written**: 2026-08-10, the day ADR-0013 landed. **Owner**: the founder decides sequencing; this
file records what the decision does to the plan, not what the plan should now be.

Read ADR-0013 first. The one-line version: the assistant speaks, the person speaks back, and the
screen is the receipt of that exchange rather than the place information first appears.

## Where the epics stand

| Epic | State | What voice-first does to it |
|---|---|---|
| **E0** Foundation | Built | Nothing. Gate, CI, tooling — no user-facing surface. |
| **E1** Identity & Kitchen Profile | Built | Screens become the tap path. No spoken lines yet. |
| **E2** Meal publishing | Built | Same. The Meal conversation is the closest thing Kafoo has to voice-first already, and is the cheapest place to prove the voice layer. |
| **E3** Customer discovery | Built | Same. Search by phrase is already a spoken-shaped interaction wearing a text field. |
| **E4** Orders | **Not specified** | **Specify voice-first from the start.** See below — this is the decision that saves the most work. |
| **EV** Voice system | **New, not specified** | The nine states, talk button, confirmation gate, failure ladder, glance words. Everything else now depends on it. |
| **EM** Messaging | **New, not specified** | Cook ↔ Customer text, dictated. New entity, new table, new personal-data category. |

## The three things this changes about planning

**1. E4 must be specified voice-first, and that is the highest-value consequence here.** Orders are
the next epic and they do not exist yet. Building them tap-first and retrofitting voice would repeat
across an entire epic the work E1–E3 now need. Specifying them voice-first costs nothing extra today
and saves the retrofit. **If one thing in this file gets acted on, make it this.**

**2. The voice system is a dependency, not a feature.** Nine states, a talk button, a confirmation
gate and a failure ladder are infrastructure that every other epic consumes. It cannot be the last
thing built, and it cannot be built per-screen without producing nine slightly different versions of
each state.

**3. Messaging is genuinely new work, not a variation on something built.** It needs an entity, a
table, RLS policies, and answers to the privacy questions — message content between two named people
is a new category of personal data. It also carries the system's one exception to "no transcript":
a message is read back verbatim before sending.

## What blocks the voice system today

**The real-time path is unproven.** `docs/ops/spike-gemini-live.md` records the Gemini Live
ephemeral-token flow failing on 2026-08-06, and ADR-0009 — where the voice conversation talks to the
model — is still undecided as a result. A 150 ms acknowledgement budget needs an architecture Kafoo
does not have.

**This is the gating question for the whole direction and it should be answered before EV is
specified**, not during. A voice-first product whose voice path cannot meet its own latency budget
is a plan, not a product.

**Two smaller blocks**, both recorded in ADR-0013 and in `.claude/rules/business-rules.md`:

- The offline-queued state persists raw audio, which the constitution forbids without an ADR. Queue
  the transcript instead, or decide it properly.
- Five glance words name Order and Message states that do not exist. They arrive with their feature,
  not before it.

## Sequencing — a proposal, not a decision

The founder's call. What I would do, and why:

1. **Answer ADR-0009** — how voice reaches the model. Everything else is speculative until this is
   settled, and it is a spike rather than an epic.
2. **EV over E2's Meal conversation**, which already has a `VoiceButton` and a question-at-a-time
   flow. It is the smallest real surface that exercises all nine states, so the voice system gets
   proven against working code instead of a new epic's unknowns.
3. **E4 Orders, specified voice-first.** The first epic that is voice-first by birth.
4. **EM Messaging**, which Orders will want anyway — a Customer asking "is it spicy?" is the
   obvious next thing after an Order exists.

Reviews stay where they were. They depend on completed Orders, and they inherit the dictated-text
path from EM rather than needing their own.
