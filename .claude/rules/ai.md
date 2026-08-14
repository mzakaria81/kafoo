---
paths:
  - "packages/ai/**"
  - "prompts/**"
  - "supabase/functions/**"
---

# AI layer

## Provider independence (ADR-0005, as amended 2026-08-02)

Every model call goes through `AiProvider` in `packages/ai/lib/provider/`. Feature code never
imports an OpenAI, Anthropic, or Gemini SDK — it depends on the interface.

**The vendor call happens in an Edge Function, not in Dart.** A provider key compiled into the
Flutter app is extractable by anyone who downloads it, and rotating it does not reach handsets
already installed. So `packages/ai/lib/provider/` holds the interface, the stub, and an adapter that
calls Kafoo's own function — and **no vendor SDK, ever**. Vendor quirks are absorbed in the Edge
Function's provider registry.

This has a second effect worth more than the first: the function that talks to the model holds no
service-role key and has no write path, so the AI Assistant is *structurally* unable to write.

**One exception exists and it is narrower than this sentence suggests — read ADR-0011.**
`embed-meal` holds a write credential because storing a Meal's vector needs one, and an embedding is
the single AI-derived value the approval rule cannot sensibly cover: it is not a claim, it is shown
to nobody, and there is no human judgement to apply to 768 numbers.
`scripts/check-ai-write-boundary.py` permits that one function and asserts it writes exactly
`meals.embedding`, touches only `meals`, and never inserts, deletes or calls an RPC. Every other
function keeps the blanket ban. **Adding a column to that list is an ADR, not an edit.**

**Switching providers is one environment variable, with no code diff at all.** Prompts declare
`model_tier`, never a model name; the registry maps tier → model per provider. A model id belongs in
exactly two places — the registry's default table and an env var. `scripts/verify.sh` fails the gate
if one appears anywhere else, and that check was mutation-tested on 2026-08-02.

Test the claim rather than asserting it: `packages/ai/test/` runs the same golden cases against a
stub adapter.

**Active configuration: Gemini by default** — an unset `AI_PROVIDER` resolves to `gemini`, fast tier
`gemini-3.1-flash-lite`, key in `GEMINI_API_KEY`. `AI_PROVIDER=anthropic` switches to Claude Haiku
4.5 and nothing else changes. A *wrong* value throws rather than falling back.

**Pick models by measuring them, not by reading pricing pages.** Every default here was first
written from documentation and every one was wrong: `gemini-2.5-flash` is listed by the provider's
own ListModels endpoint and refuses new accounts; `gemini-3.5-flash` returns invalid JSON;
`gemini-3.6-flash` burns 600–900 "thinking" tokens on an extraction task and takes 4–8 seconds
against a 2-second budget. The model that works takes 645 ms. One real call found all of it.

## Prompt files

Prompts live in `prompts/*.md`, version-controlled, one file per task. Never inline a multi-line
prompt in Dart or TypeScript.

**An Edge Function cannot read them at runtime.** `prompts/` sits at the repository root and is not
part of a deployed function bundle, so `scripts/generate-prompts.ts` compiles the markdown into
`supabase/functions/_shared/prompts.ts`, which is committed and imported. Edit the markdown and
re-run the generator — never the generated file. `./scripts/verify.sh` compares the two and fails
on drift, because a prompt edit that was not regenerated is a deploy quietly serving the old words.

Each file carries frontmatter:

```yaml
---
id: meal-analysis
version: 3
model_tier: fast | reasoning
last_evaluated: 2026-07-21
---
```

Bump `version` on any semantic change and record the eval result. A prompt change without a
re-evaluation is an untested deploy.

Prompts use canonical business vocabulary: "Analyze this Meal", "Estimate calories", "Suggest
Cuisine". Never "product", "food item", "listing".

## Conversation design

**Rewritten 2026-08-13 by ADR-0015.** The rule here used to read "one question at a time", which was
aimed at interviews and is what built one: four fixed questions, one per screen, in order. What
follows replaces it.

**One conversation, not a questionnaire.** A journey is one open exchange, not a sequence of steps.
Information is collected inside the conversation and never demanded by it. If a flow can be drawn as
"question → answer → next question", redesign it.

**Kafoo owns what is required; the model owns what is said.** Kafoo hands the model the facts still
missing and the model decides whether to ask for one, ask for two, answer something else first, or
stay quiet while the person keeps talking. **The model never decides what a Meal requires, and Kafoo
never dictates the order of the asking.**

**A person may steer, and the assistant follows.** «إيه اللي تنفع أطبخه بكرة؟» in the middle of
publishing is a normal turn. Answer it, then say out loud what is being returned to.

**Never ask what was already said** — in this conversation, or an earlier one once ADR-0016 is
decided. A Cook saying "عملت كشري" already implies Egyptian cuisine, main course, and a known
ingredient set. Asking for those is a bug.

**Advice never becomes a stored fact.** A suggestion the assistant made must not arrive in the
database as though the person said it. If they act on it, the value comes from what *they* then say.

**Explain assumptions.** When the AI fills in a field, it says why: «حطيت المطبخ مصري لأن فيه ملوخية
ورز». Silent inference destroys trust.

**Human approves.** The AI produces a draft. The user confirms or edits. There is no path where the
AI's output reaches the database unreviewed. In a fluent conversation the approval step is a sentence
the assistant speaks rather than a screen — **it is the same step and it is not optional.**

**Everything anyone says is untrusted input, for as long as they keep talking.** A conversational
surface is a prompt-injection surface. Nothing a person says may change what the assistant is
permitted to do.

## Language

The conversational register is Egyptian Arabic, not Modern Standard Arabic. Prompts must instruct
the model explicitly on dialect, and evals must include Egyptian slang, transliterated English
(`برجر`, `بانيه`), and mixed-script input.

Semantic search is cross-language by design: `كشري` matches Koshary/Koshari/Kushari, `chicken`
matches `فراخ`. This is an embedding property — verify it in evals rather than assuming it.

## Structured output

When the model must return data, demand strict JSON and validate it against a schema before use.
Never regex a model response. On a parse failure, retry once with the error appended, then fail
loudly — do not silently substitute a default.

## Cost and latency

Every call declares a `model_tier`. Extraction and classification use the fast tier. Reserve the
reasoning tier for genuinely hard tasks and say why in a comment.

Voice round-trip budget is 2 seconds. Streaming is required for any user-facing conversational
response — a 4-second silent wait is a broken feature even if the answer is perfect.

Cache aggressively: embeddings, nutrition estimates for identical Meal text, translations.

## Evals

Every prompt has golden cases in `packages/ai/test/goldens/` with real Egyptian Arabic input.
Minimum coverage per prompt: three typical cases, two dialect/slang cases, one adversarial case
(prompt injection through user-supplied Meal text), one empty/garbage input.

Treat user-supplied Meal descriptions as untrusted. A Cook can write anything into a description
field, including instructions aimed at the model.
