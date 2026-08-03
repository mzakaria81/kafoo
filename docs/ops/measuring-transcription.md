# Measuring on-device Egyptian Arabic transcription

**T083.** The weakest link in a voice-first feature is probably not the model. It is whether the
phone hears `بانيه` in the first place, and until this runbook is executed nobody has checked.

## Read this first: what was found without a handset

Two things came out of reading the code on 2026-08-03, before any measurement.

**The `ar-EG` fallback is silent, and it is the expected path.**
`apps/mobile/lib/features/kitchen_profile/application/voice_input.dart` asks the engine for
`ar-EG`, and when the handset does not have it, falls back to *any* Arabic locale. The file's own
header comment says `ar-EG` is missing on many Egyptian handsets — so the fallback is the normal
case, not the exception. A Cook on a handset carrying only `ar-SA` has their Egyptian speech
transcribed by a Modern Standard or Gulf model. Nothing tells them, and nothing tells us.

**Production cannot answer this question either.** `ConversationStarted` and
`ConversationStepCompleted` record `input: voice | typed`, which says a microphone was used. They do
not record *which* Arabic served the request, so no amount of field data distinguishes "voice works"
from "voice works for the subset of Cooks whose phones have `ar-EG`".

That is why the first change made under T083 was instrumentation rather than measurement: the
resolved locale is now recorded, so this stops being a question that requires a person with a phone
and becomes one the field answers continuously.

**This runbook still has to be run by a human with a handset.** The session container has no
microphone, no Android or iOS runtime, and no device. `speech_to_text` delegates to Android
`SpeechRecognizer` and iOS `SFSpeechRecognizer`, both of which are platform services. There is no
way to fake this honestly, and a simulated result would be worse than no result.

## What you need

- A **real Android handset**, ideally one bought in Egypt with its original system locale, because
  the installed speech locales are what is being measured. An emulator tells you about Google's
  cloud recogniser, not about the phone in a Cook's hand.
- An **iPhone** as a second run, if reaching iOS Cooks matters at launch. iOS ships a different
  recogniser and the answer may differ.
- A quiet room first, then a **second pass with kitchen noise** — a running tap, a fan, a radio.
  Cooks are in kitchens. A number measured in silence is the optimistic bound, not the number.
- `docs/ops/transcription-corpus.json` — 26 utterances, deliberately chosen.

## Procedure

1. Build and install the app on the handset: `flutter build apk --release` in `apps/mobile`, or run
   it from the IDE. Open the Kitchen Profile conversation, which is the only screen with voice
   today.
2. **Record which locale actually resolved, before anything else.** With the instrumentation change
   in place this is emitted on `ConversationStarted`; read it from the analytics row or the debug
   log. If it is not `ar-EG`, that fact alone is most of the finding, and every number below is a
   measurement of the wrong model rather than of Egyptian recognition.
3. Speak each utterance from the corpus, one at a time, at a natural pace. Do not enunciate
   carefully — a Cook will not. Say it the way you would say it to a person.
4. Write down what came back, verbatim, including nothing-at-all.
5. Score each against the corpus's four outcomes: `exact`, `equivalent`, `msa_substituted`, `wrong`.
6. Repeat the whole corpus with kitchen noise in the background.

## Reading the result

**`msa_substituted` on the `msa_lexical` set is the number that decides this.** Above roughly 20%,
on-device recognition is not serving Egyptian Arabic regardless of how good the raw accuracy looks,
because the engine is systematically translating the Cook into a register they did not use.

**Weight the categories by what can be recovered.** A mangled sentence is survivable — the Cook sees
the transcript before it is accepted (FR-012) and can repeat themselves. A missing dish name is not:
the downstream model cannot recover a word it never received, and `بانيه` has no synonym to fall
back on. So a 90% sentence score with a 40% loanword failure is a failing result, not a passing one.

**Record the numbers in this file when you have them**, with the handset model, OS version, and
resolved locale beside them. An unrecorded measurement gets re-argued from memory in three months.

## What follows from a bad result

The fix is server-side transcription, and it is a smaller change than it sounds. The client already
holds a recorded utterance; sending audio to a model that transcribes it centrally removes the
handset's speech locale from the product entirely, and every Cook gets the same quality regardless
of what their phone shipped with. Privacy position is unchanged and already written down: voice
recordings are transcribed and discarded, and persisting raw audio needs an ADR.

**ADR-0009 is the other route and it removes this link altogether.** A Gemini Live session takes
audio natively, with no separate transcription step, which is the strongest argument in favour of
that proposal and one this measurement directly informs. Question 2 of the ADR-0009 spike is this
same corpus, spoken rather than typed. Run this runbook first: if on-device transcription turns out
to be fine, the case for the thin client weakens considerably, and that is worth knowing before
committing to a vendor for the whole voice surface.

## Results

Nothing recorded yet. This section exists so that the first person to run it has an obvious place
to put the answer rather than putting it in a chat message that scrolls away.

| Date | Handset | OS | Resolved locale | Quiet: msa_substituted | Noisy: msa_substituted | Loanword pass rate | Notes |
|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — | not yet run |
