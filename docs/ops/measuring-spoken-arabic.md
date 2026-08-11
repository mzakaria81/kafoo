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

**It does not need an API key and must never be run with one pasted anywhere.** The vendor's own web
studio is the instrument. A key belongs in `.env` and in the deployment secret store, and nowhere
else, ever.

## What you need

- A free account on the text-to-speech service being evaluated. At the time of writing that means
  ElevenLabs' **Creative** tier (the studio), **not** its Agents product — see
  `decisions/` for why an assistant that composes its own words is the wrong shape for Kafoo.
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
