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

## Sequencing — decided by the founder, 2026-08-10

1. **EV, the voice layer, over E2's Meal conversation.** It already has a `VoiceButton` and asks one
   question at a time, so it is the smallest real surface that exercises all nine states.
2. **E4 Orders, specified voice-first.** The first epic that is voice-first by birth.
3. **EM Messaging**, which Orders will want anyway — a Customer asking "is it spicy?" is the obvious
   next thing once an Order exists.

Reviews stay where they were. They depend on completed Orders and inherit the dictated-text path from
EM rather than needing their own.

**ADR-0009 is deliberately NOT answered first, and the founder chose that knowing the cost.** The
alternative was to spike how voice reaches the model and learn whether 150 ms is achievable before
building. Building first proves the states against working code; the risk accepted is that if
ADR-0009 later picks an architecture this layer cannot sit on, the layer is rebuilt.

**So the two latency budgets are targets, not gates.** A state that acknowledges in 900 ms still
ships, and is reported as missing its budget — the same treatment discovery's 1112 ms got. What is
never acceptable at any latency is a silent, still moment.

## What is still unproven, and what to measure first

**The real-time path.** `docs/ops/spike-gemini-live.md` records the Gemini Live ephemeral-token flow
failing on 2026-08-06; ADR-0009 is open. This is now a known risk being carried rather than a blocker
being cleared.

**Offline transcription, and this is the first thing to measure.** The offline queue holds text, which
means the phone must transcribe without a network. Kafoo delegates to Android `SpeechRecognizer` and
iOS `SFSpeechRecognizer`, which normally reach the network, and `ar-EG` is already known to be missing
from many Egyptian handsets. **Run `docs/ops/measuring-transcription.md` on a real Egyptian phone
before building the offline state** — it needs a person with a handset, and it decides whether that
state can exist at all.

**Five glance words name Order and Message states that do not exist.** They arrive with their feature,
never before it. A glance word for a state the app cannot reach is a promise nothing keeps.
