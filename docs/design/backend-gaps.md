# What the designed screens need that the backend cannot do yet

The Cook's Meal List is built to the shape the design handoff specifies, including
the controls nothing can serve yet. Those render exactly as designed and
**disabled, with the reason in their own label** — the same rule the design
applies to every other inert control. Hiding them would have made the screen
look finished and quietly lost the list below.

This is that list. Each entry says what a person sees today, what is missing
behind it, and what it costs to close.

**Four of the twelve are closed.** 1, 8, 9 and 10 are done; the rest are listed
below with what each still needs.

**Nothing here blocks the screen from shipping.** Everything a Cook can already
do — see her Meals, take one off the menu, put it back, retire it, carry on a
draft, delete a draft, edit — works, and is covered by tests.

---

## 1. ~~The assistant has no voice~~ — CLOSED, with a caveat

**Closed 2026-08-11.** The device's own speech engine now reads the Meal list's
summary aloud on arrival, reads any row on request, and the mute control is
live and persists across launches. Money in a spoken row is said quietly, since
homes are shared and income is private. ADR-0014 has the reasoning and the plan
for replacing it.

**The caveat: it will be silent on some handsets.** Android ships Arabic speech
data separately from the engine, so plenty of Egyptian phones have no Arabic
voice installed at all. When that happens Kafoo reports it rather than dropping
lines quietly — the «اسمعها تاني» and «اسمعي الأكلة دي» controls render inert,
the same way they did before the engine landed. How often this actually happens
is unknown until Kafoo runs on real handsets, and it is worth measuring early.

**Still open:** the voice sounds like a machine. That is the accepted trade —
a paid Cairene voice replaces it once the flows are settled and there are real
sentences to audition, which is the condition `DESIGN.md` §10.13 has been
waiting on. Swapping is one line in `speech_output_provider.dart`.

## 2. Nothing listens on this screen

**Speaking and listening are two gaps, and only the first is closed.** The
assistant now talks; nothing on this screen hears an answer.

**What a Cook sees.** The talk button, 88dp at the bottom, drawn exactly as
designed and greyed out, its label reading «الكلام لسه مش شغال — ضيفي بإيدك
دلوقتي».

**What is missing.** Speech recognition is wired into the Meal *conversation*
(`voice_input.dart`) but not into the Meal list, and the list is where the
design expects «عايزة تعملي إيه؟» to be answered out loud. Connecting them needs
an intent step — turning "شيلي المحشي من المنيو" into a status change — which
is a model call through `packages/ai/`, not a wiring job.

**Also missing:** the live microphone level. The amplitude bars take a real
number and refuse a fake one, so they stay flat until something supplies it.

**Blocks:** the nine voice states ever appearing on this screen. Only `idle`
can be reached today.

## 3. No offline cache, so the failure state is thinner than designed

**What a Cook sees.** On a failed load: «مفيش نت» as a glance word, the
reassurance «أكلاتك كلها في أمان», and a retry.

**What is missing.** Two halves of the designed state:

- **The cached Meal list** the design shows underneath at 0.45 opacity, under
  "آخر نسخة محفوظة · ٩:٤٠ الصبح". Nothing stores the last good list, so there
  is nothing to show and no timestamp to show it under. `MyMealsFailed` already
  takes both and is passed neither.
- **The queued-audio card** with «محفوظ» and its animated bars. Nothing queues
  anything, because nothing records anything.

**What it costs.** A local store for the last list, plus an outbox for anything
spoken while offline. Neither is large; the outbox needs a decision about how
long a queued item survives.

## 4. No connectivity detection

**What a Cook sees.** The failure state appears only when a request actually
fails, which on a bad Egyptian connection can take a long timeout first.

**What is missing.** Anything watching the connection, so the app can move to
the offline state before a request has hung. The design treats offline as a
state the app is *in*, not an error it discovers.

## 5. The spoken summary uses digits where the design speaks words

**MOSTLY CLOSED ON 2026-08-12, and the part that closed it was not the part this
entry expected.**

Two things were wrong here, and one of them was this entry.

**The counted noun did not agree, and that was the real defect.** It said
«عندك ٥ أكلة» for every number, when Arabic changes the noun with the number:
«أكلة واحدة», «أكلتين», «تلات أكلات», «٢٠ أكلة». Fixed with an ICU plural, whose
CLDR bands line up with the grammar exactly, so no hand-written agreement rules
were needed after all.

**And the written line was in Latin digits**, not the Arabic-Indic ones this
entry showed. It was the only numeral on the screen still in the script a Cook
does not type. The banner now goes through `KafooNumerals.arabicIndic`.

**The number-to-words half is rejected rather than outstanding.** This entry
assumed a voice cannot read digits. It can: the provider reads «20» as «عشرين»
in correct Egyptian, heard on a handset on 2026-08-12. So Kafoo needs no Arabic
number-to-words function for speech, and the spoken string deliberately keeps
Latin digits while the written one shows Arabic-Indic — the same sentence in two
scripts, because they are read by different things.

**What is genuinely still open** is one listening verdict: whether the provider
says «تلات أكلات» or the wrong «تلاتة أكلات» for «3 أكلات», and whether «٢٠» in
Arabic-Indic is read as well as «20» is. Both are in
`docs/ops/measuring-spoken-arabic.md` and need a Cairene ear rather than a
function.

## 6. The publish gate has no route into it

**What exists.** `KafooConfirmationGate` is built and tested, including that
silence cannot resolve it.

**What is missing.** The Meal list has no publish action to put behind it.
Publishing happens today at the end of the Meal conversation, and moving a
draft to published from the list needs `MyMealsController` to call the
repository's `publish` — which enforces completeness in the database, so a
half-answered draft has to be refused with a sentence rather than a failure.

**Recommendation:** add it when the voice path lands. Publishing by tap from a
list, with a full-screen read-back gate in front of it, is a heavier gesture
than the flow needs; the gate exists for the spoken path.

## 7. The recognition-failure panel cannot be built yet

**What the design specifies.** A terracotta orb, a narrowed yes/no question,
then tappable options shown as photograph plus large numeral plus glance word,
and «مفيش حاجة من دول».

**What is missing.** Two things, and the second is the harder one:

- **Recognition** — see gap 2. Nothing can fail to understand yet.
- **Photographs.** The options are meant to be recognised by picture. Every
  Meal in Kafoo currently has no photo, so the panel would be a column of
  identical placeholders, which is worse than the list it replaces. Real
  photography is shot with the Cook; no generated or stock image may stand in.

The strings and the ladder logic exist (`RecognitionLadder`, tested), so the
panel is a rendering job once those two land.

## 8. ~~The loading state is not from the design~~ — CLOSED

**Closed 2026-08-11.** `DESIGN.md` listed this as undefined and told an
implementer to stop and ask; the founder answered "build it", to the design's
own hint — a hairline skeleton at the Meal-row footprint.

`KafooSkeletonList` draws three rows in the real row's shape: same raised
surface, same border, same radius, same 80px thumbnail, and each bar exactly as
tall as the line of type it stands in for, taken from the type scale rather than
typed in. A test compares its height against a real Meal row, because the whole
value of a skeleton is that the list does not jump when the data lands. The
largest bar sits where the price will be, since the price is the largest thing
in a real row.

It pulses, slowly, and stops completely when the platform's reduce-motion
setting is on. On Egyptian networks this state lasts long enough that a
motionless screen reads as a hung app, which is the moment people force-quit.

## 9. ~~Two status vocabularies exist~~ — CLOSED

**Closed 2026-08-11, by the founder, against the recommendation that was here.**
This file proposed keeping the glance word «منشورة». He chose «على المنيو» — the
words a Cook already uses about her own menu — and it is now the only name for
that status anywhere in the app.

The second key is gone rather than set to the same text: two keys holding one
sentence is how the two vocabularies appeared in the first place.
`myMealsStatusPublished` was deleted and everything reads `glancePublished`.

**The cost, stated because it is real.** «على المنيو» is three words where every
other glance word is one, and the glance set is meant to be recognised by
silhouette without reading. It is the longest member of that set and it wraps to
two lines at 200% text scale. That is a deliberate trade of a design property
for a familiar phrase, not an oversight.

## 10. ~~The mute control does nothing~~ — CLOSED

**Closed 2026-08-11.** It silences the assistant, stops a sentence already in
progress, and the answer survives the next launch. Pressing it mid-sentence had
to be immediate: anything slower means a Cook pressed it in a room with people
in it and the app kept talking.

**Still open:** the speech-rate control (بالراحة / عادي / سريع) and the two-voice
setting from `DESIGN.md` §10.11. Both need a settings screen, which is a new
screen and therefore a decision rather than an implementation.

## 11. Only one screen has a voice

**What a Cook hears.** The Meal list greets her, reads any Meal on request, and
announces every change. Every other screen is silent — including the Meal
conversation, which is the one screen whose entire premise is that the assistant
speaks first.

**Where it bites hardest.** She taps «كمّل الأكلة دي» on a half-finished Meal,
arrives at the conversation, and hears nothing. The row sheet deliberately says
nothing on that tap rather than announcing an arrival somewhere that then goes
quiet — a false impression of a working voice is worse than an honest silence.

**What it needs.** `assistantVoiceProvider` read in the conversation screens the
same way the Meal list reads it, and a spoken line for each question. The engine
and the seam are done; this is per-screen wiring, one screen at a time.

**Also inherited by whoever wires recognition here.** The Meal list now speaks
from six places. Nothing has yet proved the speaking and listening engines can
share a phone's audio without fighting over it, because no screen does both
today. The first one that does needs a real-device test before it ships.

## 12. One label still speaks to only one gender

**What a Cook sees.** The empty Meal list opens with «احكيلي عن أكلة» — "tell me
about a Meal." It is a feminine-only imperative, so a male Cook meets the wrong
grammar on the first screen he sees after signing up with no Meals.

**Why it is not fixed here.** Four labels on the same screen family had this
defect and were converted; this one was left because the masculine form of that
verb is not derivable by pattern-matching, and a confident guess produces
something that reads as slightly wrong to a native speaker and passes every
check in this repository. Three Arabic wording questions are queued for the
founder and this is one of them.

**What it needs.** A native Egyptian speaker's masculine wording, then the same
`addressForm` conversion the other four got — ten minutes once the word exists.

**Three more waiting on the same person.** «بوق» in the too-noisy line, which a
reviewer flagged four times as reading like mockery rather than blaming the
room. The delete-a-draft cancel button, which borrows the wording written for
retiring a Meal. And the confirmation gate's «لأ، استنى», which is masculine
only — deliberately, because it is the Cook speaking *to* the assistant and the
assistant is masculine in Arabic, but that reading wants a native speaker's
confirmation before the gate is wired to a screen where anyone reads it.
