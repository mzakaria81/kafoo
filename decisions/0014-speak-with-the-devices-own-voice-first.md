# ADR-0014 — Speak with the device's own voice first, and buy one later

**Status:** Accepted
**Date:** 2026-08-11
**Decider:** Founder

## Context

**This follows ADR-0013, it does not restate it.** ADR-0013 decided that Kafoo
is voice-first and that the screen is the receipt of what was said. This one
decides *which engine* says it, which is a spend decision rather than a design
one.

Kafoo is voice-first. The assistant speaks, the user speaks back, and the screen
is the receipt of that exchange — `DESIGN.md` §10 goes as far as saying a
component without a spoken line is unfinished. Every component built so far is
therefore half-built: the visual states exist, the words exist in the ARB files,
and nothing says them.

Choosing what says them is not an engineering preference. It is a spend
decision, and these are the facts that forced it:

- **The app reads itself aloud by default.** Speech is the primary channel, not
  an accessibility add-on, so anything billed per sentence is billed on almost
  every screen a Cook opens. The cost grows with usage, which is the direction
  that hurts.
- **The voice casting is still open.** `DESIGN.md` §10.13 leaves the assistant's
  age and register undecided, and that cannot be settled from a sample reel — it
  needs real Kafoo sentences, said in the flows they belong to.
- **Egyptian handsets frequently have no Arabic speech data.** Android ships
  text-to-speech languages separately from the engine. Kafoo already learned
  this on the *recognition* side, where `ar-EG` is missing on many phones, and
  the manifest carries a `<queries>` entry and a comment about it.
- **Nothing about the product depends on which engine speaks.** The lines, the
  timing, the mute rule and the nine voice states are all the same either way.

## Options considered

| Option | Cost | Risk | Reversibility |
|---|---|---|---|
| Wait for a paid Cairene voice before shipping any speech | No bill yet, but the voice system stays unfinished and untestable in the flows | The casting question stays unanswerable, because there is nothing to audition against | High, but nothing is learned in the meantime |
| Cloud voice now | Billed per sentence, on a surface that speaks constantly, before anyone knows how much it speaks | Spend scales with adoption; a bad casting choice is discovered after it is paid for | Medium — swapping back is possible but the flows will have been tuned to it |
| **Device voice now, paid voice later** | Free, offline, no account. Sounds like a machine | A robotic assistant is the first impression during testing; some handsets have no Arabic voice at all | High — provided the seam is real |
| Device voice permanently | Free forever | The "neighbour's kitchen" feeling the whole design is built around is hard to get from a synthetic monotone | Low, if flows quietly assume it |

## Decision

**Ship the device's own text-to-speech engine, behind a seam built for it to be
replaced.**

`SpeechOutput` in `apps/mobile/lib/features/conversation/data/` is the interface
every spoken line goes through. `DeviceSpeechOutput` is the implementation.
Screens and controllers depend on the interface and never name an engine — the
same shape ADR-0005 uses for model providers, and for the same reason.

**The swap is one line.** `speech_output_provider.dart` contains a single
constructor call. Replacing the device engine with a cloud voice means changing
that line and writing one adapter; no screen, controller, string or test moves.
A test asserts the mute preference survives an engine change, because that is
the piece of state a swap could quietly drop.

Three rules bind any implementation, present or future:

1. **Muting persists until reversed.** Held in a `StoredMutePreference` mixin
   rather than in each engine, so it cannot be lost in a swap.
2. **Silence is never silent about itself.** An engine with no Arabic voice
   reports `SpeechVoiceMatch.none` rather than accepting lines and dropping
   them, and the controls that would have spoken render inert instead of dead.
3. **Money and addresses are spoken quietly.** `speak(quiet: true)`. Homes are
   shared and income is private.

**When the cloud voice arrives, the device engine stays.** It becomes the
offline path and the fallback for a handset that cannot reach the network — a
free voice that already works is worth keeping once it is written.

## Consequences

**Accepted costs.** The assistant sounds like a machine until it is replaced,
which is a worse first impression than the design intends and will colour early
testing — anyone judging warmth from these builds is judging the wrong thing. A
second engine has to be written eventually rather than only once. `flutter_tts`
joins the dependency list; it wraps the platform engine and adds no account, no
key and no network call.

**What this forecloses.** Nothing about the design. Voice casting, speech rate
and the two-voice setting in §10.11 are all still open, and are all easier to
answer with a working system than without one.

**A visible gap remains, and is not this decision's to close.** Speaking and
listening are separate. This gives Kafoo a voice; the talk button on the Meal
list stays inert because *recognition* on that screen is unbuilt.
`docs/design/backend-gaps.md` keeps the list.

**Revisit trigger.** Reopen when any holds:

1. Testing with real Cooks shows the synthetic voice is itself the obstacle —
   people stop talking to it, or stop trusting it.
2. The device engine's Arabic coverage turns out to be worse than expected on
   the handsets Kafoo actually reaches, measured rather than assumed.
3. The flows are settled enough to audition a cast, which is the condition
   §10.13 has been waiting for.
