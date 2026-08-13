# ADR-0017 — How the live conversation reaches a model

**Status:** Accepted in direction, **blocked on one spike before any code.** The direction is
decided; question 1 below can still send it to the fallback.
**Date:** 2026-08-13
**Decider:** Founder
**Supersedes:** ADR-0009, which asked this question about Gemini Live and could not answer it. That
file stays as the record of the spike that failed.
**Required by:** ADR-0015

## Context

ADR-0015 needs a conversation. What Kafoo has is a walkie-talkie.

**What is built today, precisely:**

- **Hearing** — `voice_input.dart` delegates to Android `SpeechRecognizer` and iOS
  `SFSpeechRecognizer`. Platform services, not libraries Kafoo controls.
  `docs/ops/measuring-transcription.md` records that **`ar-EG` is missing on many Egyptian
  handsets.** This is the largest known hole in the product and it has been known for a week.
- **Thinking** — `packages/ai/` → the `discover` / analysis Edge Functions → Gemini. WP-010 measured
  description-finished to first estimate at **2177 ms against a 2000 ms budget, 8 of 12 runs over.**
- **Speaking** — `supabase/functions/speak/index.ts` posts the whole sentence to ElevenLabs
  (`eleven_multilingual_v2`, mp3), gets the whole file back, plays it. 36 fixed sentences were bought
  once by `scripts/generate-voice-clips.ts` and ship inside the app; a few account-specific lines are
  bought at runtime and cached by hash in `voice_clip_store.dart`.

That design is good, and it is good *for a wizard*. Three things break the moment ADR-0015 lands:

1. **The clip cache stops paying.** It works because a wizard says the same 36 sentences to everyone,
   forever, free. In an open conversation nearly every sentence is new, so the cache hit rate falls
   toward zero and every reply is bought. **The economics invert.** The bundled clips stay worth
   keeping for the fixed lines they cover — they play in milliseconds with no signal — but they stop
   being the strategy.
2. **Whole-file audio cannot hold a conversation.** The reply is synthesised, downloaded and then
   played, so the first sound arrives after the last word is generated. Add the 2177 ms model call
   and a Cook waits several seconds after every sentence. People stop talking.
3. **There is no barge-in.** A person who interrupts is not heard, because nothing is listening while
   the assistant speaks. ADR-0013 lists *interrupted* as one of the nine voice states, and it is the
   one state the current architecture cannot produce.

The founder has removed the budget constraint for this phase:

> I know this would require a much bigger subscription than the monthly $6. But I'm still in a very
> early phase and there are no real Cooks/Customers, so we can consume this subscription as we wish.

That changes what is worth evaluating. It does not change the security rules, and this ADR does not
propose changing them.

## Options considered

| Option | What it gets | What it costs |
|---|---|---|
| **A. Keep the pipeline as-is** | Nothing new. Already built, already paid for | Fails all three problems above. Not a candidate; listed as the baseline |
| **B. Upgrade the pipeline** — server speech-to-text, streaming speech-out, our Edge Function still holds the model | Fixes the `ar-EG` hole on every handset. First audio in a few hundred ms instead of seconds. **Keeps ADR-0005 exactly as written** | Turn-taking, silence detection, interruption and echo handling are all ours to build. That is the hard, unglamorous half of a voice interface and it is weeks, not days |
| **C. A hosted voice agent** — one socket that does hearing, turn-taking, speaking and interruption, with **our own model plugged into it** and our own Edge Functions as its tools | Everything in B, plus the hard half, plus barge-in, for roughly the integration effort of B alone | The conversation loop belongs to a vendor. If they change pricing or break the dialect, the mitigation is a rewrite of the loop — though not of the model, the prompts, or the data |
| **D. A hosted voice agent with the vendor's model too** | Fastest of all to stand up | **Rejected.** It puts an opaque model where Kafoo's prompts, its Egyptian register, its provider swap and its dialect bake-off live. ADR-0005 exists precisely to keep this answerable: "does another model speak better Egyptian to our Cooks?" |

## Decision

**Take C, on ElevenLabs, with Kafoo's own model behind it. Fall back to B if the spike says C cannot
be had on those terms.**

Concretely, and this is the whole architecture:

- **The phone opens one session to the voice agent** and streams microphone audio up and speech
  audio down. The agent handles hearing, when a turn ends, speaking, and being interrupted.
- **The credential never reaches the phone.** A Kafoo Edge Function mints a short-lived signed URL
  per session; the app connects with that and holds no vendor key. **This is the same hinge ADR-0009
  turned on, and it must be tested the same way — by a real call, before anything is built.** ADR-0005
  Amendment 1 is not being amended: a provider key in a shipped binary is still a published key.
- **The language model stays Kafoo's**, reached through the agent's custom-model endpoint pointing at
  a Kafoo Edge Function. Prompts stay in `prompts/`. `model_tier` stays. The provider registry stays.
  Switching model vendors stays one environment variable.
- **Every action the assistant can take is a Kafoo function, and it is the same function a tap
  reaches.** Nothing gets a second, looser write path because it arrived by voice. The publish gate
  is still a read-back and still waits for «أيوة».
- **Speech-to-text moves off the handset**, which is the single biggest quality win available and
  closes the `ar-EG` hole documented in `measuring-transcription.md`.
- **The bundled clips stay** for the fixed sentences and for the offline state. They are already
  bought, they are free forever, and they play with no signal.

**`supabase/functions/speak/index.ts` keeps its whole design and gains a second caller.** The
role-never-an-id rule, the 400-character cap, the never-log-the-sentence rule and the immutable cache
header were all written for reasons the new path does not weaken. Nothing about them is superseded.

### The rules this is checked against, and how it passes

- **AI never writes without approval.** Unchanged and structurally intact: the agent has no database
  credential, and every write it can reach is a Kafoo function that applies the same rules a tap does.
- **Provider independence (ADR-0005).** Preserved for the model, which is what the principle protects.
  **Given up for the audio path**, and that is a real cost stated plainly: hearing and speaking become
  vendor-bound, and `scripts/verify.sh`'s model-seam check does not see a socket the app opens. ADR-0009
  argued this trade was only worth making knowingly. It is being made knowingly.
- **Raw audio is transcribed and discarded.** Audio now leaves the phone to be transcribed, which is a
  change in *where* and not in *whether*. **Vendor retention settings must be confirmed and written
  down in the spike** — a provider that keeps audio by default would put Kafoo in breach of its own
  rule without a line of Kafoo code being wrong.
- **Offline.** Unchanged and no better: ADR-0013 conflict 1 already settled that where on-device
  transcription fails, the app says so plainly and offers tap or typing rather than promising
  «كلامك محفوظ» over words nobody captured. Moving speech-to-text to a server makes offline strictly
  worse, and the honest state was already designed for it.

## What was verified on the vendor's own pages, 2026-08-13

The founder accepted vendor lock-in on ElevenLabs the same day. These are read from ElevenLabs'
public documentation and pricing pages, and **read is not measured** — the spike still runs. What
changes is that three of the four architectural assumptions above are now documented rather than
hoped for.

| Assumption | Verified | Where |
|---|---|---|
| The phone connects with a short-lived credential minted by Kafoo, never a key | **Yes.** A server requests a *signed URL* with the API key and hands it to the client, which opens the socket with it. "Never expose your ElevenLabs API key client-side." Valid **15 minutes to start** a conversation; the conversation itself may run longer | Agents → customization → authentication |
| Kafoo's own model can be the agent's brain | **Yes, over a standard interface.** The agent calls a URL implementing OpenAI's `/v1/chat/completions` or `/v1/responses`, streaming Server-Sent Events with `Content-Type: text/event-stream`. That is an Edge Function Kafoo writes, in front of whatever provider `AI_PROVIDER` names — **ADR-0005 survives intact and the provider swap stays one environment variable** | Agents → customization → LLM → custom LLM |
| Audio retention is controllable | **Yes** — retention policies for conversations and audio are a documented setting. The exact values Kafoo sets are a spike deliverable, not an assumption | Agents → overview |
| It hears Egyptian Arabic well | **Not verified and not verifiable from a page.** Arabic is supported at the model level; **there is no dialect or locale selector — the setting is "Arabic", not "Egyptian Arabic"** | — |

**The dialect gap is the real risk and it splits in two.** Speaking is the settled half: this
repository measured on 2026-08-11 that Egyptian pronunciation comes from the model reading *Egyptian
text*, not from a dialect setting, and that is why `speak` already sounds Cairene. **Hearing is the
unmeasured half** — whether their speech-to-text transcribes «بانيه» and «برجر» from a Cook's mouth
is exactly what spike question 2 exists to find out, and no documentation page can answer it.

One useful find alongside the pricing: ElevenLabs runs a **startup grant — 12 months free and 33M
characters** for building a real-time agent into a new product. Worth applying for in parallel;
it does not change the architecture and may remove the bill for the whole trial.

## Latency — what a voice agent fixes, and what it does not

Asked directly by the founder: does putting the agent inside the tool eliminate the delay?

**No. It removes most of it, and the part that remains is the part Kafoo chose to keep.**

Today the four steps run one after another and nothing overlaps: the phone recognises the speech,
then the model is called (2177 ms measured, WP-010), then the whole audio file is synthesised, then
it downloads, then it plays. Roughly **three to five seconds of silence** after a Cook stops talking,
and no way to interrupt.

A voice agent changes the shape rather than the speed of any one part. Hearing runs *while* she is
still speaking. The reply is spoken *as it is generated*, first words out before the last words
exist. And she can cut in. Published figures for these platforms cluster around **one to one and a
half seconds** from end of speech to first sound.

**Kafoo will not hit that figure as drawn, and the reason is a choice made two sections above.**
Those numbers assume the vendor's own model inside their own network. This decision keeps Kafoo's
model, reached over the public internet from an Edge Function, because provider independence is
worth more than the difference. Realistically that adds several hundred milliseconds — **expect
roughly one and a half to two and a half seconds, unmeasured, on an Egyptian mobile network.**

**The vendor has anticipated this exact case.** Their custom-model documentation describes *buffer
words*: the endpoint returns a short opener ending in an ellipsis and a space, which the agent starts
speaking while the real answer is still being written. That is a real mitigation for a slower
model behind a fast voice, and it is the difference between a pause and a person thinking aloud.
Use it — and never let it say anything that could be false if the answer turns out differently.

Three things matter more than the number:

- **Streaming makes the wait feel shorter than it is.** A reply that begins in 600 ms and takes four
  seconds to finish feels faster than one that arrives whole after two seconds of silence. What
  people experience is time-to-first-sound, not time-to-complete.
- **ADR-0013's 150 ms rule still does the heavy lifting** — the haptic and the growing orb the
  instant she stops. Silence is what reads as broken, not delay.
- **Barge-in matters more than milliseconds.** Being able to interrupt is most of what separates a
  conversation from a walkie-talkie, and no amount of speed substitutes for it.

**So the honest answer is: much better, not solved, and the residual delay is the price of keeping
the model swappable.** If the measured figure comes back bad enough to hurt, the option that buys it
back is D — the vendor's model — and that is a trade to put to the founder with a number attached,
not one to make quietly.

## Money

The founder has lifted the constraint for this phase, so the figure that matters is not "is it
affordable now" but **"what does it cost per Meal when there are Cooks"** — because that number is a
business input and it is currently unknown.

Read from ElevenLabs' public Agents pricing page on 2026-08-13. **Conversation minutes, not
characters** — a different unit from the `speak` bill Kafoo pays today.

| Tier | Monthly | Minutes included | Concurrent calls |
|---|---|---|---|
| Free | $0 | 15 | 4 |
| Starter | $6 | 75 | 6 |
| **Creator** | **$22** (first month $11) | **275** | 10 |
| Pro | $99 | 1,238 | 20 |
| Scale | $299 | 3,738 | 30 |
| Business | $990 | 12,375 | 40 |

Overage is **$0.08 per minute**, **$0.16 burst**, and a text message is $0.003.

**Take Creator, $22.** 275 minutes is about four and a half hours of talking. Five Cooks at twenty
minutes each is roughly a hundred minutes, so the trial fits inside the allowance with room to
develop against it, and ten concurrent calls is far past anything this phase produces. Pro buys
capacity for a product that does not have users yet.

**The number that is still unknown is the one that matters later: cost per published Meal.** At
$0.08 a minute, a Meal that takes four minutes to talk into being costs about 32 cents in voice
alone, before the model. That is a fine number for five Cooks and a serious number for five hundred,
and it is a business input the founder should have measured rather than estimated. The spike reports
it.

**The tier table above is read, not measured, and this repository has been wrong every time it
trusted a page over a call** — `.claude/rules/ai.md` lists four model defaults that were all wrong on
the first real request. Confirm the live figures at purchase.

## The spike, before any implementation

Three questions, in order. **Any "no" stops it and the answer is B.**

1. **Can a session be opened from the app with a short-lived credential minted by Kafoo, with no
   vendor key on the handset?** **Documented as yes** — signed URLs, minted server-side, 15 minutes
   to start. Still a real call and not a documentation page: ADR-0009 died on a mint endpoint that
   returned a plausible token which no socket would accept. Mint one, open one, confirm nothing
   long-lived reaches the client.
2. **Does Kafoo's own model plug in as the agent's language model, and does the whole loop still
   speak Egyptian Arabic?** The `meal-analysis` golden cases — including `برجر` and `بانيه` — spoken
   aloud rather than typed, both directions. If the register degrades, the fluency is not worth it.
3. **What does it retain, what does it cost, and how long does a turn actually take?** Vendor
   audio-retention settings, written down. Measured cost for one realistic conversation and the
   projected per-Meal figure. And **end of speech to first sound, measured on an Egyptian mobile
   connection with Kafoo's own model in the loop** — the number the latency section above refuses to
   guess. All three to the founder before a subscription is upgraded.

Throw the spike code away. It exists to answer questions, not to become the implementation.

## Consequences

- **`voice_input.dart` becomes a fallback rather than the path.** On-device recognition stays for
  offline and for the tap-and-dictate case, and stops being how the conversation hears.
- **`hosted_speech_output.dart` keeps its job for announcements and glance words** and stops being
  how the assistant converses.
- **The 150 ms acknowledgement and 400 ms thinking budgets from ADR-0013 become reachable**, which
  they were not before. They stay measurements rather than gates, exactly as ADR-0013 decided.
- **A new operational dependency with a monthly bill**, whose failure mode is the product going
  silent. The bundled clips and the device voice remain the degraded path, so silence is never the
  outcome.
- **If the spike fails, ADR-0015 still stands** and is built on B. It is slower to reach and it is
  the same product.
