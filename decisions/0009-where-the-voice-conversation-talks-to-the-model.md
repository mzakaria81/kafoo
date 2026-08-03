# ADR-0009 — Where the voice conversation talks to the model

**Status:** Proposed — **not decided.** Nothing here binds an implementer yet. The ephemeral-token
spike below is what turns this into Accepted or Rejected.
**Date:** 2026-08-02
**Decider:** Founder

> Written at the founder's request to hold a proposal still while it is evaluated, rather than to
> record a choice already made. The status line is the whole point: a plausible architecture with
> no decision attached is exactly the kind of thing that gets implemented by accident because it
> was written down somewhere.

## Context

The proposal is a **thin client** for the voice conversation. Today every model call goes through
Kafoo's own Edge Function (ADR-0005 Amendment 1). The proposal is that the Flutter app opens a
session with the Gemini Live API directly: audio out from the phone, audio back to the phone, and
Kafoo's backend never in the loop.

The application keeps state, business rules, validation and persistence. The model gets language
and nothing else.

**Two parts of the proposal are already true and are not in question.**

- **"The AI is responsible for conversation; the application is responsible for state, business
  rules, validation and persistence"** is Constitution Principle II and the AI Assistant section of
  `.claude/rules/business-rules.md`. Adopting it costs nothing because it already binds.
- **The conversation is a finite-state machine owned by Kafoo, not the model.** Already built:
  `packages/domain/lib/conversation_step.dart` holds the Kitchen Profile sequence and
  `packages/domain/lib/meal_step.dart` holds the Meal one, both as domain rules with an explicit
  note that the sequence is not a property of any screen.

What is genuinely at stake is narrower than the proposal looks: **where the connection to the model
is opened, and therefore who holds the credential.**

Facts that force the decision:

- **A credential in a shipped binary cannot be rotated.** ADR-0005 Amendment 1 was written yesterday
  for this exact reason. Revoking a leaked key breaks every installed app that has not updated; not
  revoking it leaves it valid in the wild. This is the fact the proposal, as drawn, reverses.
- **Latency is already inside budget and is not the motivation.** Measured 2026-08-02 against the
  live key: `gemini-3.1-flash-lite` returns a full structured analysis in 645 ms–1.27 s, and 23
  further calls the same day ran 0.83–1.18 s. The voice budget is 2 s. Whatever Live is worth, it is
  not worth latency Kafoo already has.
- **Speech-to-text is the unmeasured risk, and Live removes it.** T083 records that on-device
  Egyptian Arabic transcription has never been tested. If the phone mishears `بانيه`, no downstream
  model quality recovers it. Gemini Live takes audio natively — no separate transcription step, and
  dialect handled inside the model. **This is the strongest argument for the proposal and it is not
  the one the proposal makes.**
- **The cost of a minute of Live audio is unknown.** Not estimated here on purpose. Every model
  default in this project written from documentation was wrong, and one real call found all of it.
  The per-Meal cost question from T076 is also still open.
- **Ephemeral tokens are believed to exist for this case and have not been tested.** The pattern —
  a backend mints a short-lived, single-session token and the client connects with that — is what
  would let the audio path stay direct while the long-lived key stays server-side. Treat that
  sentence as a hypothesis. It is the hinge of the whole decision and nobody has called the API.

## Options considered

| Option | Cost | Risk | Reversibility |
|---|---|---|---|
| **A. Status quo** — every model call through the Edge Function | None; already built and shipping | Speech-to-text stays on the phone, unmeasured, and is the likeliest place a voice-first product fails in Egyptian Arabic. Two round trips on a voice turn | High |
| **B. Thin client, key in the app** — Flutter opens the Live session with a compiled-in credential | Lowest to build | **Disqualifying.** Anyone who downloads the app extracts the key; rotation never reaches installed handsets. Reverses ADR-0005 Amendment 1 on the day after it was written | Low — a leaked key stays leaked |
| **C. Thin client, ephemeral tokens** — a Kafoo endpoint mints a short-lived token; Flutter opens the session with that | A new endpoint, a token lifecycle, and a client that handles expiry mid-conversation. Ends provider independence for the voice path | Depends entirely on the spike. If ephemeral tokens do not work as believed, this collapses into B and must not be built | Medium — the seam survives, the vendor choice does not |
| **D. Split by task** — Live for the voice conversation (C's mechanics), Edge Function for structured extraction and anything touching a photo | Two paths to keep in step, and a second validator in Dart mirroring `_shared/ai/schema.ts` | Two definitions of one schema is two places for it to drift. Mitigable by generating both from one source, as `prompts.ts` already is | Medium |

Option B is listed because it is what the proposal's diagram actually describes, and it needs to be
on the record as rejected rather than quietly not chosen.

## Decision

**Deferred.** No implementation proceeds against this ADR while its status is Proposed.

The decision this ADR expects to record, if the spike succeeds, is **D**: the voice conversation
opens a Gemini Live session directly from the app using a short-lived token minted by Kafoo, while
structured extraction — anything with a photo, anything whose output is validated against a schema
before a Cook sees it — stays behind the Edge Function. Kafoo owns the finite-state machine
throughout; the model is told which slot to fill next and answers in Egyptian Arabic, and it never
decides what data is required or when a conversation is complete.

If the spike fails, the decision is **A**, and the transcription risk in T083 is addressed some
other way.

**E2 does not wait for this.** E2's model call is one structured extraction with a photo. Live's
advantages are native audio and open-ended dialogue, and Kafoo's own finite-state machine
deliberately removes the second one. Nothing in E2 should be rebuilt on this proposal.

## Consequences

**Accepted costs.** A token-minting endpoint and its lifecycle, including what happens when a token
expires mid-sentence. A second validator in Dart mirroring the TypeScript one, generated from a
single schema source or it will drift. Audio cost per conversation becomes a recurring line nobody
has yet measured.

**What Principle V costs, stated plainly.** Constitution Principle V — Provider Independence — is
marked NON-NEGOTIABLE, and this proposal negotiates it for the voice path.

The mechanism that makes provider switching one environment variable is the `AiProvider` interface,
the Edge Function's provider registry, and the golden cases that run the same inputs against a stub.
**None of that reaches a WebSocket the app opens itself.** There is no Gemini Live equivalent at
Anthropic or OpenAI with the same shape, so there is no adapter to write and nothing to switch to.
Concretely, taking this means:

- The voice conversation is bound to one vendor. Not "harder to move" — bound. Moving means
  rebuilding the conversation against a different API, and shipping an app release to do it.
- The dialect bake-off ADR-0005 exists to enable becomes impossible for voice. Kafoo would no longer
  be able to answer "does another model speak better Egyptian Arabic to our Cooks?" by changing a
  variable, which is the specific capability Principle V was written to protect.
- A vendor pricing change on audio has no mitigation except a rewrite.
- `scripts/verify.sh`'s model-config-seam check does not cover a vendor session opened from Dart,
  so the guardrail that has been enforcing Principle V would silently stop applying to the largest
  surface in the product.

That may be the right trade. Voice is Principle IV and dialect quality is what makes or breaks
Kafoo, and an abstraction that costs the product its best voice experience is an abstraction serving
itself. But it is a trade, it is being made against a NON-NEGOTIABLE, and taking it requires
amending Principle V explicitly rather than letting it lapse by implementation.

**What this forecloses.** Nothing yet — that is what Proposed means. Accepting D would foreclose
provider independence for voice, reopenable only by rebuilding the conversation.

**Revisit trigger.** A throwaway spike, before E3, answering three questions in this order. Any
"no" stops it.

1. **Does the ephemeral-token flow exist and work?** Mint a short-lived token server-side, open a
   Live session from a client using only that token, and confirm no long-lived credential is
   present on the client. If the answer is no, this ADR is Rejected and the decision is A. Nothing
   else in the spike matters until this is answered, and it must be answered by a real call, not a
   documentation page.
2. **Does it hear Egyptian Arabic?** The same corpus as the `meal-analysis` golden cases — including
   `برجر` and `بانيه` — spoken aloud rather than typed. Compare against on-device transcription
   (T083). If Live is not materially better at the thing it is being adopted for, the case
   collapses.
3. **What does a conversation cost?** Measured, on a real session of realistic length, and put to
   the founder alongside T076's still-open per-Meal figure.

Throw the spike code away, as T084 already says. It exists to answer questions, not to become the
implementation.

## Notes for Claude Code

**This ADR decides nothing. Do not implement against it.** While the status line reads Proposed,
ADR-0005 Amendment 1 stands unamended: every model call goes through `AiProvider`, the vendor call
happens inside an Edge Function, and no vendor SDK or vendor credential may appear in Flutter or in
`packages/`. A change that puts a model API key on a handset is wrong today regardless of what this
file proposes for tomorrow.

If asked to build the voice conversation on Gemini Live, say that this ADR is unresolved and that
the ephemeral-token spike is the blocking question.
