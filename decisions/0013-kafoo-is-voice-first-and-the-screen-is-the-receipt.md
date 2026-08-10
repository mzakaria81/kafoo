# ADR-0013 — Kafoo is voice-first, and the screen is the receipt

**Status:** Accepted
**Date:** 2026-08-10
**Decider:** Founder
**Supersedes in part:** the tap-first assumption behind E1–E3. Not an ADR, which is why it was never
written down and could be changed by working on a design for an afternoon.

## Context

Kafoo has always said "voice-first". Until today that meant **a voice input control on a form**:
`VoiceButton` sits inside the Meal conversation, transcription fills a text field, and every screen
Kafoo has built reads top-to-bottom as something to look at. The constitution's Principle IV is
titled "Conversation First" and every rule under it is about *not building forms* — it says nothing
about the app speaking.

On 2026-08-10 the founder worked through a design exercise and reached a different position, and it
is a genuine change rather than a restatement:

> **The AI assistant speaks. The user speaks back. The screen is the receipt of that exchange.**

The distinction that forces the change is **who reads**. A tap-first product assumes the Cook reads
the screen and speaks as a shortcut. A voice-first product assumes she may not read comfortably at
all — so anything the screen alone conveys is invisible to the person the product exists for. Every
consequence below follows from that single assumption.

The design bundle recording this is `docs/design/` (see "What this decision points at").

## Decision

**Voice is the primary surface. The screen confirms what was spoken; it never introduces
information the user has not heard.**

Five rules follow, and they are binding:

1. **A component is unfinished until its spoken Egyptian-Arabic line is written.** Visual states
   alone no longer constitute a component. This is the rule with the widest blast radius: it
   changes what "done" means for every widget in `packages/ui/` and every screen in `apps/mobile/`.
2. **The assistant paraphrases; it does not show a transcript.** It says what it understood
   («تمام، محشي بمية وعشرين») rather than displaying recognised text. A paraphrase exposes a
   misunderstanding immediately; small verbatim text hides it from exactly the person who cannot
   read it. **One exception, in rule 5.**
3. **Reversible actions execute and are announced. Irreversible ones are read back and wait for a
   spoken «أيوة». Silence never confirms** — no timeout resolves a gate, ever.
4. **Every state reaches the user three ways — visual, spoken, haptic — and any one alone
   suffices.** A kitchen is noisy, a street is bright, a phone may be face-down.
5. **All Cook ↔ Customer communication is text, dictated through the assistant.** No audio message
   exists in the product in either direction. The assistant transcribes speech to text and reads
   incoming text aloud, and **a message is read back verbatim before sending** — those exact words
   are what another person receives, so the sender hears them literally and answers «أيوة».

**Tap remains a complete alternative, never a degraded one**, and typing is never a *consequence* of
the assistant failing to understand. The recognition ladder descends exactly three rungs — ask
again once, ask a narrower yes/no, fall back to tapping photos and numerals — and never blames the
speaker.

Two typographic rules carry the "may not read" assumption into the layout, and they are design
decisions rather than preferences:

- **Glance words are a closed set** of eleven Arabic words that may appear large, each fixed in
  size, weight, colour and position so it is recognised by shape rather than read. Adding a twelfth
  requires adding it to the set first — an unrecognised shape is worse than no word.
- **Numerals are the largest type in the system** — 34px in a row, 48–64px as a verdict, Arabic-Indic,
  never abbreviated. Numbers are read by nearly everyone. A Meal name drops to 14px and is spoken on
  tap, so it is never the only thing distinguishing two options.

## What this costs, and it is not small

**Every screen already built is now provisionally wrong.** Not broken — none of it has to be
deleted — but 27 presentation files were written against the assumption the screen teaches, and
none of them has a spoken line. They become tap fallbacks, which the decision says must be
complete rather than degraded, so they keep their value. What they do not yet have is the voice
layer above them.

**The technical foundation is not proven.** `docs/ops/spike-gemini-live.md` records that the
ephemeral-token flow for the Gemini Live API did not work when tested on 2026-08-06, and ADR-0009
is still undecided as a result. A conversational surface with a 150 ms acknowledgement budget needs
a real-time path that Kafoo does not currently have. **This decision is about product direction and
does not pretend the plumbing exists.**

**Messaging is a new domain.** It is not in any epic, has no entity, no table and no policies, and
it introduces message content between two named people — a new category of personal data. It is
scoped by this ADR and specified by a separate one.

## Three conflicts with existing binding rules

These are recorded rather than resolved, because two of them are the founder's to decide and the
third needs precision before anyone writes code against it.

### 1. Offline queued audio persists raw audio — blocked pending an ADR

The offline state says «كلامك محفوظ وهيتبعت أول ما النت يرجع» and shows a queued-audio card. That
stores raw audio on the device until the network returns.

The constitution is explicit: *"Voice recordings are transcribed and discarded. Raw audio MUST NOT
be persisted without an ADR."* This ADR does not grant that — a queue is a different question from
a philosophy, and it deserves its own decision covering how long audio is held, where, whether it
survives a force-quit, and what deletes it.

**Until that ADR exists, the offline-queued state must queue the transcript, not the audio**, or the
state is not built. Transcribing on-device before queueing satisfies both the design's promise to
the Cook and the constitution, and is the likely answer — but it is a decision, not an assumption.

### 2. "Draft-writing executes immediately" needs narrowing

Principle II is non-negotiable: *"Every AI-derived field written to the database MUST pass through
an explicit human approval step in the flow."*

The design lists draft-writing among the reversible actions that happen without asking. Read
loosely that contradicts Principle II. Read precisely it does not, and the precise reading is the
one that binds here:

> **A draft may be written without a gate when it holds what the Cook said.** An AI-derived field
> inside that draft — calories, allergens, inferred cuisine or category — still requires the
> approval step E2 already implements. Speaking a sentence is the Cook authoring; the model
> estimating a calorie count is not.

Principle II is unchanged. The design does not overrule it, and if a future flow has the assistant
writing an estimate straight to a row, that flow is wrong.

### 3. Glance words that name things Kafoo has not built

Four of the eleven glance words — «طلب جديد», «وصل», «اتلغى» — are Order states, and «اتبعت» /
«اتقرت» are message delivery states. Orders are E4 and do not exist; messaging does not exist. The
set is correct as a *destination*, and the words for unbuilt features must not appear in a build
before the feature does. A glance word for a state the app cannot reach is a promise to a Cook that
nothing keeps.

The design bundle also disagrees with itself here: §10.4 says "nine words" and lists nine, §10.12
says the set grows to eleven, and the README lists eleven. **Eleven is the intended number**; the
§10.4 heading was not updated. Recorded so nobody reconciles it the other way.

## Options considered

| Option | Why not |
|---|---|
| Keep tap-first, treat voice as an input mode | It is what Kafoo has been doing, and it assumes the Cook reads. The founder's judgement is that this assumption is wrong about the actual user, and a marketplace that excludes cooks who read uncomfortably has excluded much of its supply side |
| Voice-first for the Cook only, tap-first for the Customer | Tempting — the Cook is the one with flour on her hands — but it splits the design system in two and the Customer arriving by WhatsApp link is often the same person. Rejected as two products |
| Adopt voice-first now, build it after Orders (E4) | This is close to what happens in practice, and it is a sequencing question rather than an alternative. Recorded in "Consequences" instead |

## Consequences

**Accepted costs.**

- `packages/ui/` grows a voice layer, and its definition of a finished component changes. The
  design system work is no longer "colour, type, spacing" — it is those plus nine voice states.
- Two Cairene Egyptian voices must be sourced, male and female, selectable per account. Casting is
  open. This is a real procurement item with a real cost, not a token.
- The 150 ms acknowledgement and 400 ms thinking-state budgets join the performance budgets. They
  are tighter and more specific than the existing "voice response round-trip < 2s", which stays.
- Text input is demoted from a core component to a last-resort fallback. It is not removed.

**What does not change.** Principle I (user trust), Principle II (AI suggests, humans approve),
Principle III (security), Principle V (provider independence), Principle VI (canonical vocabulary),
every RLS rule, and the trust rules in `.claude/rules/business-rules.md`. **A voice-first product
is not a product with weaker guarantees**, and the confirmation gate makes several of them stronger
— reading an irreversible action back aloud is a better approval step than a tap on a dialog.

**Sequencing, which is a founder decision and is not settled here.** The voice system is specified
against screens that largely do not exist: Orders are E4, Reviews later, messaging new. The cheapest
honest path is to build the voice layer over what E2 and E3 already shipped — the Cook's Meal list
and Customer discovery — and let Orders arrive already voice-first, rather than building Orders
tap-first and retrofitting. That ordering is a proposal, not part of this decision.

## What this decision points at

The design bundle lives in `docs/design/`. `DESIGN.md` §10 is the voice specification and is the
source of truth for values; the HTML files are design references and must not be shipped or ported.

**The tap-first Cook Meal List in that bundle is superseded** by the voice version and is kept only
to show what changed. `docs/product/claude-design-brief.md` — the brief that produced the first
bundle — is superseded by this ADR and says so.
