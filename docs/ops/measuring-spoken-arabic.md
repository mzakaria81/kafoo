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
