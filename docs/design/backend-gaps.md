# What the designed screens need that the backend cannot do yet

The Cook's Meal List is built to the shape the design handoff specifies, including
the controls nothing can serve yet. Those render exactly as designed and
**disabled, with the reason in their own label** — the same rule the design
applies to every other inert control. Hiding them would have made the screen
look finished and quietly lost the list below.

This is that list. Each entry says what a person sees today, what is missing
behind it, and what it costs to close.

**Nothing here blocks the screen from shipping.** Everything a Cook can already
do — see her Meals, take one off the menu, put it back, retire it, carry on a
draft, delete a draft, edit — works, and is covered by tests.

---

## 1. The assistant has no voice

**What a Cook sees.** The talk button, 88dp at the bottom of the screen, drawn
exactly as designed and greyed out. Its label reads «الكلام لسه مش شغال — ضيفي
بإيدك دلوقتي». The «اسمعي الأكلة دي» button on each row and the «اسمعها تاني»
button on the spoken banner are drawn and inert for the same reason.

**What is missing.** A text-to-speech engine. `SpeechOutput` is the seam every
spoken line goes through; the only implementation is `UnvoicedSpeechOutput`,
which is named for its emptiness.

**What it costs.** This is a founder decision, not an engineering one. An
on-device engine is free, ships immediately, and sounds like a machine reading
a form. A cloud Egyptian voice sounds like a person and is billed per sentence —
and since the app reads itself aloud by default, that bill grows with usage.
`DESIGN.md` §10.13 leaves the voice casting open for the same reason.

**Blocks:** every spoken line in the product, which by the design's own
definition means every component is unfinished until this lands.

## 2. Nothing listens on this screen

**What a Cook sees.** The same disabled talk button.

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
reassurance «اللي قولتيه محفوظ وهيتبعت أول ما النت يرجع», and a retry.

**What is missing.** Two halves of the designed state:

- **The cached Meal list** the design shows underneath at 0.45 opacity, under
  "آخر نسخة محفوظة · ٩:٤٠ الصبح". Nothing stores the last good list, so there
  is nothing to show and no timestamp to show it under. `MyMealsFailed` already
  takes both and is passed neither.
- **The queued-audio card** with «محفوظ» and its animated bars. Nothing queues
  anything, because nothing records anything.

**The reassurance is currently a promise the app cannot keep.** It says what
was said is saved. Until there is a queue, nothing was said and nothing is
saved. It is correct copy for the designed system and premature for this one.

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

**What a Cook sees.** «عندك ٥ أكلة، منهم ٢ منشورة. عايزة تعملي إيه؟»

**What the design says.** «عندك خمس أكلات، اتنين منشورين» — numbers spelled out,
because the line is *spoken* and a voice does not read digits.

**What is missing.** An Arabic number-to-words function, with the agreement
rules Arabic needs for counted nouns. Written text keeps the Arabic-Indic
digits; only the spoken line needs words.

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

## 8. The loading state is not from the design

**What a Cook sees.** A plain spinner.

**What is missing.** `DESIGN.md` lists the loading state as undefined and tells
an implementer to stop and ask rather than invent one — and notes that on
Egyptian networks this is a state people live in. The design asks for a hairline
skeleton at the Meal-row footprint.

**This is a design gap, not a backend one.** It needs a decision before it can
be built.

## 9. Two status vocabularies exist

**What a Cook sees.** «منشورة» on the Meal list; «على المنيو» on other screens.

**Why.** The glance word is a fixed shape from a closed set of eleven, recognised
without reading. The older `myMealsStatus*` strings are descriptive sentences
used in body text. Both are correct in their place, but a Cook meets two words
for one thing.

**Recommendation:** keep the glance word wherever the status is a label, and
reword the descriptive strings to contain it — "منشورة على المنيو" rather than a
second name. Small, and a vocabulary decision rather than a code one.

## 10. The mute control does nothing yet

**What a Cook sees.** The 48dp speaker button, top inline-end of the Meal list,
which the design requires on every screen.

**What is missing.** It is not yet connected to `UnvoicedSpeechOutput`, because
there is nothing to mute. The preference itself is real and persists across
launches — that part is built and tested.
