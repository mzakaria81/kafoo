# Measuring whether a voice service actually speaks Egyptian Arabic

The companion to `measuring-transcription.md`, and its mirror image. That runbook asks whether a
phone can **hear** an Egyptian Cook. This one asks whether a voice service can **speak** to her.

Both questions were unanswered when ADR-0013 made Kafoo voice-first on 2026-08-10. The design
commits to an assistant that talks, in two Cairene voices, and nothing in the repository had
established that any service can produce Cairene Arabic at all.

## Read this first: why this one is cheap

`measuring-transcription.md` needs a human holding an Egyptian handset, which is why it has never
been run. **This runbook needs a browser and half an hour.** A text-to-speech service is a web
product; you type a sentence and listen to it. There is no platform service to stand in for, no
device locale to resolve, nothing to fake.

So this should be run before any decision about paying for voices, and before the speaking module is
built — it is the cheapest unknown on the whole voice-first path.

**It can be run entirely in the vendor's web studio, with no key at all** — type a sentence, pick a
voice, listen. That is the version to reach for first, and it is the only version that works on a
free plan for the voices that matter (see the findings below).

It can also be driven from a key held in the session environment, which is how the first run
generated its clips. If you do that: **the key comes from the environment and is never written down**
— not into a script, not into a file, not into a commit, not pasted into a chat. `.env` and the
deployment secret store, nowhere else, ever.

## What was found on the first run, 2026-08-11

Run once against ElevenLabs with the founder's own key, on the **free** tier. Four findings, and the
first one changes what the free tier is good for.

**The free tier refuses library voices through the API.** Verbatim: *"Free users cannot use library
voices via the API. Please upgrade your subscription to use this voice."* The account's own voice
list holds 21 stock voices and **every one is American, British or Australian** — not one Arabic
voice among them. So on a free plan the API can only read Arabic in an English voice, which is
useless for judging accent.

**There are 25 Egyptian-accented voices, and they are all library voices.** Found by searching the
shared voice library for Arabic: 100 Arabic voices, 25 of them tagged Egyptian, in both genders.
Their sample recordings are free to fetch and need no plan at all, which is how the first listening
pass was assembled. Auditioning them costs nothing; **calling them from Kafoo costs a paid plan.**

**Voice cloning is off on free.** `can_use_instant_voice_cloning` and
`can_use_professional_voice_cloning` both return false, and the voice limit is 3. So recording a
Cairo voice actor — the fallback if none of the 25 passes — also needs a paid plan.

**`eleven_v3` supports Arabic and accepts written direction.** Square-bracket instructions in the
text (`[warmly]`, `[thoughtful]`) produce a performed line, which is the cheap way to get warmth into
a fixed sentence without a model improvising it.

Cost of the whole first run: **513 characters** of the 10,000 free monthly allowance, for 21
generated clips, plus 14 voice samples that cost nothing.

## What you need

- A free account on the text-to-speech service being evaluated. At the time of writing that means
  ElevenLabs' **Creative** tier (the studio), **not** its Agents product — see
  `decisions/` for why an assistant that composes its own words is the wrong shape for Kafoo.
  **Free is enough to audition and to test wording; it is not enough to call an Egyptian voice from
  code.** Read the findings above before assuming otherwise.
- **Headphones, and then a second pass on a phone speaker held at arm's length.** A Cook hears this
  from a phone propped against a bowl, not from studio monitors.
- Somebody who speaks Cairene. **This is the one requirement that cannot be substituted.** Every
  test below is a judgement about accent, and a non-Egyptian ear will pass a voice that an Egyptian
  ear rejects immediately. If the founder is not doing this himself, it needs a native Cairene
  listener.

## The corpus: the assistant's own sentences

`transcription-corpus.json` holds what a **Cook says**. This test needs what the **assistant says**,
so the corpus is different — it is drawn from `docs/design/DESIGN.md` §10, which is where every
spoken line in the product is specified.

Say each of these through the service, one at a time, in both a male and a female voice.

### Set 1 — the nine voice states (§10.2)

| Line | State |
|---|---|
| أنا معاك. دوسي واتكلمي. | Idle / invitation |
| لسه معاك، ثانية. | Thinking, after 2 s |
| معلش، مافهمتش. قوليها تاني؟ | Didn't catch |
| الدوشة عالية — قرّبي الموبايل من بوقك وقولي تاني. | Too noisy |

### Set 2 — the confirmation gate and the failure ladder (§10.6, §10.7)

| Line | Where |
|---|---|
| تمام، محشي بمية وعشرين | Paraphrase of what was understood |
| تمام، الأكلة منشورة | After an irreversible action executes |
| الأكلة اسمها محشي ورق عنب؟ قولي أيوة أو لأ. | Ladder rung 2, the narrow question |
| خلاص، هوريكي الاختيارات وانتي دوسي على اللي عايزاه. | Ladder rung 3, falling back to tap |
| أيوة | The gate's own answer word |
| لأ | The gate's other answer word |

### Set 3 — the glance words (§10.4, §10.12)

Spoken singly, because §10.4 says the state is announced when it changes and §10.12 extends the set
to eleven:

منشورة · مسودة · مش متاحة · أرشيف · طلب جديد · وصل · اتلغى · محفوظ · مفيش نت · اتبعت · اتقرت

### Set 4 — numerals, which are the largest type in the system (§10.5)

Written in Arabic-Indic digits, as they appear on screen:

| Written | Must be heard as |
|---|---|
| ١٢٠ جنيه | miyya w-ʿishrīn **g**ineh |
| ٣ نجوم | talat nugūm |
| ٤٥ دقيقة | khamsa w-arbaʿīn diqīqa |

### Set 5 — the traps

| Line | The trap |
|---|---|
| نفسك في إيه؟ | Written identically for a woman and a man. Pronounced *nafsik* to her, *nafsak* to him. See the note on this string in `app_localizations.dart`. |
| سامية بتقولك... | A person's name followed by a pause, per §10.12.3. Names are where speech services fail. |
| فيه تقييم تلات نجوم على المحشي، تحبي تسمعيه؟ | §10.13's proposed wording for a bad Review, still an open founder decision. Hearing it read aloud is part of deciding it. |

## What to listen for, in order of how much it decides

**1. The ج test, and it is the fastest single check in this document.** Cairene pronounces ج as a
hard **g**. «جنيه» is *gineh*, never *jineh*. If the service says *jineh*, the voice is not Egyptian
and no amount of tuning makes it so. One word, one second, most of the answer.

**2. ق and ث.** Cairene turns ق into a glottal stop and ث into t or s. «قوليها» is *ʾūlīha*, not
*qūlīhā*. «تلات» is *talāt*, not *thalāth*. A voice getting these wrong is reading Modern Standard
Arabic in an Arabic accent — the news-anchor register `CLAUDE.md` forbids in writing, arriving
through the speaker instead.

**3. Egyptian negation.** «مافهمتش» and «مش متاحة» do not exist in Modern Standard Arabic. A service
trained mainly on formal Arabic may mispronounce them, spell them out, or stumble. This matters more
than it looks: «معلش، مافهمتش» is the sentence a Cook hears every time recognition fails, which is
the moment she is already least confident.

**4. Gender.** Every line in Set 1 and 2 is written in the feminine, deliberately. Confirm the voice
keeps it. Then check «نفسك في إيه؟» specifically — if it comes out *nafsak*, the string needs vowel
marks added or rewording, and that finding applies to every unvowelled line in the product.

**5. Numerals.** Numbers are the largest thing on any Kafoo screen and the thing nearly everyone can
read. If the spoken number is Modern Standard while the screen shows Arabic-Indic digits, the two
channels disagree — and §10.1's whole premise is that either channel alone must be sufficient.

**6. Pace and warmth, last.** A voice can pass every test above and still sound like a call centre.
§10.11 says both voices are Cairene and the register beyond gender is an open casting decision. This
is where that decision gets made, by ear.

## Reading the result

**The ج result decides whether this route is viable at all.** Hard g in «جنيه» in at least one
available voice, and the route is open. Consistent *jineh* across every voice offered, and the
service cannot serve Kafoo whatever else it does well — record a Cairene voice actor instead, or
accept the phone's own voice and drop the casting from §10.11.

**Score Sets 1–3 as pass / stumble / wrong**, the same three-way judgement `transcription-corpus.json`
uses, and write down what you actually heard rather than a verdict. «مافهمتش» read as four separate
letters is a different problem from «مافهمتش» read in Gulf Arabic, and the fixes are different.

**A stumble on a fixed line is not a blocker, and this is the important asymmetry.** Every sentence
in Sets 1–3 is a fixed string that will be generated once before the app ships, listened to, and
bundled. Anything that comes out wrong can be fixed by adding vowel marks or rewording, and the fix
is verified by ear before release. **Only Sets 4 and 5 carry real risk**, because a price, a Meal
title and a Customer's message are generated live on somebody's phone, where nobody is listening.

**If Voice Design was used rather than a cloned voice, say so in the result.** A voice generated from
a written description costs nothing and needs no voice actor; a cloned one needs a paid tier, a
recording session and a signed permission. Which of the two passed changes what the decision costs.

## Before anything is bundled

Two questions to answer from the vendor's terms, not from this document:

1. **Does the tier permit shipping generated audio inside a commercial app?** Pre-generating the
   fixed lines and bundling them is redistribution. Free tiers commonly forbid it or require credit.
2. **Does it permit cloning a voice, and on what evidence of consent?** Reproducing a real person's
   voice needs their explicit written permission, and the vendor will require you to confirm you hold
   it. That release is a document Kafoo has to keep.

Neither is an engineering question, and both block shipping rather than testing.

## The Egyptian shortlist, 2026-08-11

Fourteen of the 25, dropping every voice described as a news presenter, a salesperson, or
"authoritative" / "commanding" — §10 asks for a neighbour, not a broadcast. Six are marked as the
warm conversational ones. Ids are stable and can be pasted straight into the vendor's studio.

**The Cook's voice is the one to choose first.** ADR-0010 exists because a Cook is addressed as a
woman, so the female voice is what most users hear most of the time.

| Voice | Gender | Described as | Id | Shortlisted |
|---|---|---|---|---|
| Fatima — Expressive Egyptian | female | pleasant | `I3u6waC588j43py1kDN2` | ★ |
| Ghozlan — Soft Clear Conversational | female | husky | `xPcC3nehhziQaOrIeAwv` | ★ |
| Heba — Soothing and Gracious | female | casual | `JHdGl5PsEzushIzzVSd1` | ★ |
| Sawsan — Dignified and Warm | female | raspy | `mS4cERRqrNy5Kmlx8Udf` | |
| Ghozlan — Professional Support Agent | female | pleasant | `kQ2VDreF7XEea8InkZmA` | |
| Nadia — Sweet and Melodic | female | upbeat | `80le32Uz2DfWFo4Foz0p` | |
| Farida — Lively and Radiant | female | cute | `6aXW46RTUz6Y2lkBGQ1a` | |
| Fatima — Smooth Audiobook Narrator | female | pleasant | `vWDp3PLsTWjIhBxxUKh9` | |
| Mr. Momen — Warm, Mature, Calm | male | confident | `x6fvBLXv9YxzoVJQ0wp6` | ★ |
| Hany — Calm & Friendly | male | calm | `1hEuyycI7VQwusZo3Qbe` | ★ |
| Ashraf — Warm and Genial | male | casual | `QfMIySsRuJWjZPZCnDQp` | ★ |
| Ahmad — Conversational AI Voice | male | confident | `ihycSANIrpHfhWoaq1g3` | |
| Tarek — Pleasant and Professional | male | casual | `ckGEQg6YnSVooU5uDRsF` | |
| Samy — Storyteller | male | calm | `HB30Rk1hky9f5uvxWktR` | |

The eleven not listed: five described as news, sales, authoritative or commanding; the rest were
duplicates of a shortlisted speaker or described in terms §10 has no use for.

## Re-running this

The generator lives nowhere in the repository on purpose — it is a throwaway script, and a committed
one would invite somebody to run it in CI against a paid key. Rebuild it from this document: read the
corpus above, POST each line to the vendor's text-to-speech endpoint, and write the clips somewhere
outside the repository.

Two rules for whoever does:

- **The key comes from the environment and is never written down.** Not into a file, not into a
  script, not into a commit, not into a chat. `.env` and the deployment secret store, nowhere else.
- **Audio never enters the repository from a test run.** Generated clips are throwaway. The only
  audio that should ever be committed is the reviewed, final, bundled set — and that is a separate
  decision with the vendor's redistribution terms attached to it.

## Founder's choice, 2026-08-11

| Role | Voice | Id |
|---|---|---|
| The assistant's female voice — the one most Cooks hear | Ghozlan — Soft Clear Conversational | `xPcC3nehhziQaOrIeAwv` |
| The assistant's male voice | Ahmad — Conversational AI Voice | `ihycSANIrpHfhWoaq1g3` |

Chosen by ear from the fourteen samples, which is the only way this decision can be made. §10.11's
two-voice setting now has both of its values.

**The pronunciation finding is separate from the voice choice, and it is the more surprising one.**
«مية وعشرين جنيه» was judged *perfect Egyptian* — hard **g** in «جنيه», Egyptian numeral — and that
clip was generated with **Sarah, a stock American voice**, on `eleven_multilingual_v2`. So the
Egyptian pronunciation came from the model reading Egyptian text, not from an Egyptian voice.

Two consequences, and the second is the one to hold on to:

- **A paid plan buys timbre and warmth, not correctness.** It is still worth buying — a Cook should
  not hear an American-sounding woman — but the reason is not that the free path mispronounces
  Egyptian.
- **The pronunciation risk moves from the voice to the text.** If the model is doing this work, then
  what decides whether a line is said correctly is how the line is *written* — which is exactly why
  the gender trap below matters, and why the fixed lines must be listened to before they ship.

Not yet verified in the chosen voices. The free tier cannot call a library voice from code, so the
lines in "the corpus" above were all read by the stock voice. Re-run them in Ghozlan and Ahmad before
anything is bundled — in the vendor's studio at no cost, or from code once the plan allows it.

## Second run, in the chosen voices, 2026-08-11

Starter plan confirmed by the API, and **the Egyptian library voices answer from code** — verified by
calling Ghozlan directly. Three numbers worth recording because they differ from the pricing page:

| Fact | Value |
|---|---|
| Monthly character allowance | **40,000**, not the 30,000 the pricing page advertised |
| Instant voice cloning | on |
| Professional voice cloning | off — that is the Creator tier |
| Voices the account may hold | 10 |

Second run: 42 clips, every §10 line in both chosen voices, plus a four-way comparison of the same
sentence on `eleven_multilingual_v2` and `eleven_v3` with and without written direction.
**997 characters of 40,000.**

That number is the one to carry into the cost argument. The entire spoken vocabulary of the product,
in both voices, is roughly a thousand characters — **2.5% of one month's allowance**, spent again only
when the wording changes. Whatever the running cost of Kafoo's voice turns out to be, it is not the
fixed lines.

### Still outstanding

Four listening verdicts, and only a Cairene ear can give them:

1. **«نفسك في إيه؟»** — *nafsik* to a woman, or *nafsak* to a man? The only one of the four that
   carries a defect. If it is wrong, the fix is vowel marks or rewording, and the same risk applies to
   every unvowelled line in the product.
2. **«معلش، مافهمتش. قوليها تاني؟»** — does «مافهمتش» arrive as one natural word? A Cook hears this
   sentence every time recognition fails.
3. **The eleven glance words** — all whole, especially «مش متاحة» and «اتلغى».
4. **«٣ نجوم» and «٤٥ دقيقة»** — Arabic-Indic digits read as Egyptian numbers.

Plus two judgements that are preferences rather than defects: whether written-in warmth
(`[warmly]`, `[thoughtful]`) is close enough to a conversational assistant's feel, and whether `eleven_v3`
is worth its unpredictability for lines that are heard before they ship.

## How long the provider takes, 2026-08-12

**The audition measured how the voices sound and what they cost. Nobody measured how long they
take, and that omission is what stopped the paid voice ever playing.**

`HostedSpeechOutput` waited 1000 ms for audio and then fell back to the device's own engine. The
figure was never a measurement — it was arithmetic backwards from the 2-second voice budget, and it
assumed a synthesis faster than ElevenLabs has ever delivered here.

Three calls the founder triggered from the Cook's Meal list on the demo project, read from
`function_edge_logs`:

| Time (UTC) | Result | Function execution |
|---|---|---|
| 10:42 | 200, audio returned | **2612 ms** — cold start |
| 10:45 | 200, audio returned | **1064 ms** |
| 10:49 | 200, audio returned | **1070 ms** |

Every call succeeded. The app discarded every one. The figure above is the Edge Function's own wall
time, so what the handset waits is that plus its round trip to Supabase — the real client-side
figure is worse than the table, not better.

Two consequences, and the second is the one that costs money:

- **The paid voice had a 0% chance of ever being heard.** The fastest call was 6% over the limit.
- **Nothing ever cached, so it never recovered.** `_audioFor` stores audio only on a *successful*
  fetch, so every sentence started the same losing race forever — and ElevenLabs bills on generation,
  not on delivery. Kafoo paid for every sentence and heard none of them.

**The founder raised the wait to 3000 ms on 2026-08-12**, having been shown that the extra wait
lands only on the failure path: a fetch that succeeds still speaks at about 1.1 s, inside the
2-second budget and unchanged. `worstCaseBeforeAnyVoice` is now 3900 ms and the test that guards it
was raised in the same commit, with the reason written into it.

**What is still unmeasured:** the round trip from an actual Egyptian handset on an actual mobile
connection, which is the only figure that describes what a Cook experiences. Three samples from one
morning is a floor, not a distribution — and the cold start at 2612 ms is the one to watch, because
it lands on the *first* sentence after the app opens, which is the sentence heard most.

## What Kafoo now owns outright, 2026-08-12

**The 997-character figure above was an argument about cost. It is now a fact about the app.**

`scripts/generate-voice-clips.ts` buys every Kafoo sentence that has no variable in it, in both
voices, and writes the mp3s into `apps/mobile/assets/voice/`. They ship inside the APK. **72 clips,
2,496 characters, 3.5 MB, bought once** — and free from then on for every Cook there will ever be,
however many that turns out to be.

Before this, all of them were re-bought on every launch. The in-memory cache died with the process,
so «تمام، شلتها من المنيو» — five words that have never changed and never will — was billed again
every time a Cook opened Kafoo.

**36 of the 37 sentences Kafoo says are bundled.** The one that is not is the Meal-list greeting,
because it carries the Cook's own Meal counts. Pre-rendering every version of it was measured and
refused: a Cook with twenty Meals has 231 possible count pairs, which across two grammars and two
voices is 924 clips and roughly 45,000 characters — **more than a whole month's allowance for one
sentence.** It is bought at runtime and kept on disk instead, so it costs a Cook one purchase when
her menu changes rather than one per launch.

**Splicing it from stored fragments was considered and rejected.** «عندك» + a number + «أكلة، منهم»
would collapse that 45,000 to about 1,140 characters, and the founder was right about the
arithmetic. Two things stopped it. Each clip is synthesised as a complete utterance with its own
falling intonation, so five of them stitched together is an airport announcement — the flat cadence
this product left the device voice to escape. And Arabic changes the noun with the number, so the
fragments are not fixed either: «أكلة واحدة», «أكلتين», «تلات أكلات», «٢٠ أكلة». If splicing is ever
worth it — and at a thousand Cooks it will be — **the sentence has to be rewritten for it**, with one
join at a natural pause and the number last. Retrofitted onto this sentence it will sound wrong.

Two things the gate now refuses, because neither has a symptom anyone would notice:

- **A spoken string edited without regenerating.** `./scripts/verify.sh` runs the generator's
  `--check`, which needs no key and no network. Without it, the clip is simply never found — the
  hash of the new wording matches nothing — and Kafoo pays for that sentence forever while the old
  file sits unused in the app.
- **A sentence the app builds differing from the one that was bought**, by so much as a trailing
  space. `apps/mobile/test/voice_clip_store_test.dart` calls the real localization getters, the ones
  the screens call, and asks whether each result is a clip Kafoo owns. That is also the only
  cross-check that the Dart and TypeScript SHA-1 agree.

### Still outstanding, and it is a Cairene ear again

The Meal-list greeting now counts in Arabic instead of saying «عندك 3 أكلة» for every number. Two
listening verdicts on it, and neither can be settled from here:

1. **«3 أكلات»** — does the provider read it «تلات أكلات», or «تلاتة أكلات»? The second is wrong.
2. **«عندك أكلة واحدة، منهم واحدة على المنيو»** — grammatical, but is it what a Cairene would say to
   a Cook with exactly one Meal? It is the sentence a Cook hears on her very first day.
