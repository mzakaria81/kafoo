# EV — the voice system: plan

**Status:** awaiting founder approval. No code written.
**Epic:** EV in `specs/ROADMAP.md`, sequenced first by the founder on 2026-08-10.
**Depends on:** ADR-0013, `docs/design/DESIGN.md` §10, `docs/ops/measuring-spoken-arabic.md`.

## Why this exists at all

ADR-0013 made Kafoo voice-first on 2026-08-10 and **nothing in the repository speaks.**
`voice_input.dart` transcribes; there is no text-to-speech anywhere, no haptic vocabulary, and no
confirmation gate. Twenty-seven presentation files will each need a spoken line.

The roadmap already states the consequence: *"the voice system is a dependency, not a feature… it
cannot be built per-screen without producing nine slightly different versions of each state."* This
plan is how it becomes one place instead of twenty-seven.

## What the module is

**Not "a thing that speaks a sentence."** That is shallow — every screen would still have to remember
to also buzz the phone and also draw the state, which is the twenty-seven-copies problem with an extra
step in it.

The module owns a **state**. A screen says *"I am thinking"* or *"this Meal is published"*, and the
module produces all three channels at once: what is drawn, what is said, what is felt. §10.1's fourth
principle — every state reaches the user three ways, any one sufficient alone — becomes structurally
true rather than remembered, because there is no way to ask for one channel only.

Two things sit behind the same interface:

- **The nine voice states** (§10.2) — idle, listening, thinking, speaking, didn't-catch, correcting,
  interrupted, offline, too-noisy.
- **The confirmation gate** (§10.6) — read the action back in full, wait for «أيوة», repeat once
  after eight seconds, never let silence confirm, keep an undo for two minutes.

**The gate is the main reason to build this.** It is a trust rule from
`.claude/rules/business-rules.md`, and it belongs in one module with one test rather than in
twenty-seven `if` statements that each remember it slightly differently.

## Where the voice comes from

Three sources behind one seam. Three is what justifies the seam existing — one adapter would be
indirection.

| Source | Used for | Cost |
|---|---|---|
| **Bundled recordings** | Every fixed line. The default path. | Nothing at run time. Generated once. |
| **A live ElevenLabs call** | Only genuinely variable text — a Meal title, a price, a Message read aloud. | Per character. |
| **The phone's own voice** | Offline fallback for variable text only. | Nothing. |

Fixed lines are never fetched live. They are generated before the app ships, listened to, and
bundled — the same decision `apps/mobile/pubspec.yaml` already made about the Arabic font, and for the
same stated reason: on an Egyptian mobile connection a first-render download is a Cook watching the
screen fill in twice.

**Measured, not estimated:** the whole spoken vocabulary in both voices came to **997 characters** —
2.5% of one month's allowance on the $6 plan, spent again only when the wording changes. The fixed
lines are effectively free.

## The chosen voices, and what changing one costs

| Role | Voice | Id |
|---|---|---|
| Female — the voice most Cooks hear | Ghozlan — Soft Clear Conversational | `xPcC3nehhziQaOrIeAwv` |
| Male | Ahmad — Conversational AI Voice | `ihycSANIrpHfhWoaq1g3` |

**Changing a voice later must stay cheap, and that is a design constraint rather than a hope.** Two
rules make it so:

1. **Audio assets are named by the line, never by the voice.** `assets/spoken/<voice>/<lineKey>.mp3`.
   Swapping the female voice replaces one folder. No Dart changes, no ARB changes, no test changes.
2. **The two voice ids live in exactly one file** — the generator's configuration — and nowhere else.
   A voice id appearing in application code is a defect.

So the real cost of replacing Ghozlan is: about 500 characters of allowance, one script run, and **one
app release**. The engineering cost is near zero; the cost that is actually real is that the new voice
reaches a Cook only when she updates the app, and a voice people have grown used to changing under
them is a product decision rather than a technical one.

**A Cook switching between the male and female voice is free and instant**, because §10.11 requires
the choice per account, so both voices ship bundled either way.

**Asset budget: 2 MB for the bundled audio**, both voices together, at 48–64 kbps mono. Today's §10
specifies about thirty distinct lines, which lands near 1.2 MB. The font is 968 KB and was argued
over; this deserves the same scrutiny. If the vocabulary grows past the budget, that is a
conversation, not a silent APK increase.

## Where the spoken lines live

**In the ARB files, beside the visible strings**, paired by name: `mealPublished` for what the screen
shows, `spokenMealPublished` for what the assistant says. Arabic written first, as always.

This keeps `CLAUDE.md`'s no-hardcoded-strings rule intact instead of carving an exception for the
newest surface, and it makes the pairing checkable: the gate can refuse a component that registers a
state with no spoken line. It roughly doubles the string count, which is the price.

**The writing is now known to carry the pronunciation.** The line judged perfect Egyptian was
produced by a stock American voice — so the model reading Egyptian *text* is doing that work. What
decides whether a line is said correctly is how it is written, which is why every fixed line is heard
before it ships and why the gender trap below is a real defect class.

## First slice

Over **E2's Meal conversation**, as the founder sequenced it — it already asks one question at a time
and already has a `VoiceButton`, and publishing is the irreversible action, so this one flow exercises
the confirmation gate. A slice over search would be easier and would leave the gate shipping unproven.

**In:** the module and its interface; the nine states; the confirmation gate; bundled audio in both
voices; the generator; the haptic vocabulary; the ARB pairs for every line in §10.

**Out, deliberately:**

- **Messaging** (§10.12) — no entity, no table, no policies, and message content is a new category of
  personal data. Its own epic (EM).
- **The voice settings screen** (§10.11) — a screen, so it needs founder approval separately. The
  voice choice is stored and honoured; choosing it in the UI comes after.
- **Amplitude bars driven by the real microphone level** (§10.2) — §10 rightly says a fake animation
  that moves while the mic is broken destroys trust in every other state, and a real one cannot be
  verified without a handset.
- **Always-on read-aloud on every screen** — the module exists first; adopting it across the other
  twenty-six presentation files is separate, reviewable work.

## Tests, in the order the constitution requires

1. **The gate test first, and seen to fail.** Silence does not confirm; no timeout resolves it; the
   question repeats exactly once after eight seconds and then waits. This is the negative test that
   must fail before the gate exists.
2. **A state cannot be produced with a channel missing.** The type makes a silent state
   unconstructible, and a test proves the constructor rejects it.
3. **Every §10 state has a spoken ARB key in both locales**, asserted by the gate rather than by
   review.
4. **A journey test** — boot the app, walk the publish path by tapping and speaking, assert the gate
   was answered before the Meal changed status. `.claude/rules/dart.md` requires this for anything that
   moves a person between screens.
5. **Golden audio is not tested by machine.** Whether a line sounds Egyptian is a listening
   judgement, recorded in `docs/ops/measuring-spoken-arabic.md`. Do not write a test that pretends
   otherwise.

## Open, and not blocking

- **Four listening verdicts** on the generated lines. Only the gender line «نفسك في إيه؟» can produce
  a defect; the rest are wording quality. These change line *content*, not the architecture, so the
  module can be built while they are outstanding.
- **ADR-0009** — where the voice conversation reaches the model. Deliberately unanswered first, by the
  founder's decision. The seam is what makes that survivable: a different source behind the door, not
  twenty-seven edits.
- **§10.13** — how a Cook hears a bad Review, and whether a Customer's Order placement is
  spoken-confirmed. Founder calls, both outside this slice.
