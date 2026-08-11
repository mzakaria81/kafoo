# EV — the voice system: what is built, and what the paid voice adds

**Rewritten 2026-08-11, against `main` at `3bfa2b4`** (#459, "Read the assistant's answer instead of
stringifying the stream it arrives on").

**This document previously planned a module that already existed.** It was written from a branch cut
at `ea3f14e`, and #457 and #459 merged the voice layer while it was being written. The rule that
would have caught it now lives in `coordination/README.md` under "Pull `main` before you plan". What
follows is the honest version: what is on `main`, what this branch actually contributes, and what is
still open.

## Built and merged — do not rebuild

| Thing | Where |
|---|---|
| The nine voice states, each with its haptic | `packages/domain/lib/voice.dart` |
| `assistantIsSpeaking` / `microphoneIsLive`, so the recogniser never hears the assistant | same |
| The confirmation gate — silence never confirms, one reprompt, no method that resolves by time | same |
| The recognition failure ladder, three rungs, cannot loop or climb back | same |
| Talk-button timings — the 150 ms acknowledgement and the 400 ms thinking state | same |
| The undo window, two minutes | same |
| Eleven glance words as a closed enum, with colour and a dashed flag | `packages/ui/lib/widgets/glance_word.dart` |
| The gate as a widget | `packages/ui/lib/widgets/confirmation_gate.dart` |
| Glance-word type styles, 20 px in a row and 32 px as a verdict | `packages/ui/lib/theme/typography.dart` |
| The assistant's voice behind a seam, with the device's own voice as the first adapter | `apps/mobile/lib/features/conversation/data/speech_output.dart` |
| The spoken Arabic lines, in both locale files | `apps/mobile/lib/l10n/app_{ar,en}.arb` |

`main`'s gate is **safer in shape** than the one this branch wrote and deleted: it has no method that
resolves by the passage of time at all, where the deleted version had an `onSilenceElapsed` that was
correct but existed. Its offline line is also already honest — it says what is and is not kept rather
than promising «محفوظ» over words nobody captured.

## What this branch contributes

**ADR-0014 is the decision this branch serves**, and it was taken the same day: speak with the
device's own voice first, and buy one later. It names two things a device voice cannot settle — the
casting question, which "cannot be settled from a sample reel — it needs real Kafoo sentences, said in
the flows they belong to", and whether a paid voice is worth its bill on a surface that speaks
constantly.

**That follow-on is this work.** It is the second adapter the seam was built for, and it answers both
of ADR-0014's open questions with measurements rather than estimates.

- **`docs/ops/measuring-spoken-arabic.md`** — the runbook for whether a service speaks Egyptian at
  all. The mirror of `measuring-transcription.md`, and unlike it needs no handset, which makes it the
  cheapest unknown on the voice-first path.
- **Two runs against ElevenLabs**, recorded rather than summarised: what a free tier refuses, the 25
  Egyptian voices in the shared library, a fourteen-voice shortlist, and the plan tiers compared.
- **The voices, chosen by ear by the founder**: **Ghozlan — Soft Clear Conversational**
  (`xPcC3nehhziQaOrIeAwv`) and **Ahmad — Conversational AI Voice** (`ihycSANIrpHfhWoaq1g3`).
- **The finding that changes the cost argument:** Egyptian pronunciation comes from the model reading
  Egyptian text, not from an Egyptian voice — the line judged perfect Egyptian was generated with a
  stock American voice. **A paid plan buys timbre and warmth, not correctness.** The risk moves to how
  a line is *written*, which is why every fixed line must be heard before it ships.
- **997 characters** for the entire spoken vocabulary in both voices — 2.5% of one month's allowance
  on the $6 Starter plan, spent again only when the wording changes. **The fixed lines are effectively
  free**, which is what justifies generating them before the app ships rather than fetching them live.

## The paid adapter: what building it means

Not a new module. A second adapter behind the seam that already exists in `speech_output.dart`.

| Source | Used for | Cost |
|---|---|---|
| **Bundled recordings** | Every fixed line. The default. | Nothing at run time. |
| **A live ElevenLabs call** | Only variable text — a Meal title, a price, a Message read aloud. | Per character. |
| **The device's own voice** | Offline fallback for variable text. Already built. | Nothing. |

Fixed lines are never fetched live, for the reason `pubspec.yaml` already gives about the Arabic font:
on an Egyptian mobile connection a first-render download is a Cook watching the screen fill in twice.

**Two constraints keep a later voice change cheap, and they are constraints rather than hopes:**

1. **Audio assets are named by the line, never by the voice** — `assets/spoken/<voice>/<lineKey>.mp3`.
   Swapping a voice replaces one folder. No Dart, no ARB, no test changes.
2. **The two voice ids live in exactly one file** — the generator's configuration. A voice id in
   application code is a defect.

Replacing Ghozlan then costs about 500 characters, one script run and one app release. The cost that
remains is a product one rather than an engineering one: a voice people have grown used to changes
under them, so it is better done before many Cooks are using Kafoo than after.

**Asset budget: 2 MB across both voices**, at 48–64 kbps mono. Today's §10 vocabulary lands near
1.2 MB. The Arabic font is 968 KB and was argued over properly; audio deserves the same scrutiny
rather than a silent APK increase.

## Two ideas from the deleted duplicate, kept here rather than lost

Neither is a defect in what `main` built. Both are modelling choices worth weighing if that file is
touched again — recorded so the thinking is not thrown away with the code.

- **Declared silence with a required reason.** `main` models silence implicitly, via
  `assistantIsSpeaking`. The deleted version made it a sealed type where a silent state had to carry a
  written reason, so *forgetting* a spoken line and *choosing* not to have one were different things
  and only the second compiled. The rule «a state missing its spoken line is not implemented» is
  §10.2's, and the type was one way to make it mechanical.
- **A gate test that fires a thousand reprompts.** `main` has one test named "silence never confirms",
  and given its gate has no time-based method the property largely holds by construction. The deleted
  suite exhausted it — and that mattered, because the deliberately-broken first implementation
  *passed* the single-silence test and was only caught by the thousandth. If a time-based method is
  ever added to that gate, this test shape is what should arrive with it.

## Still open

- **Four listening verdicts** on the generated lines. Only «نفسك في إيه؟» can produce a defect:
  written Arabic omits the vowel marks, so it is spelled identically for a woman and a man and a
  speech engine guesses masculine. The rest are wording quality. These change line content, not
  architecture.
- **The generator** that renders the fixed lines into bundled audio, and the commercial-licence and
  voice-cloning terms to confirm before any audio enters the app.
- **ADR-0009** — where the voice conversation reaches the model. Unanswered first by the founder's
  decision; the seam is what makes that survivable.
- **§10.13** — how a Cook hears a bad Review, and whether a Customer's Order placement is
  spoken-confirmed. Founder calls.
- **Messaging (EM)** — no entity, no table, and message content is a new category of personal data.
