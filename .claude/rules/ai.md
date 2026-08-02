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

**One question at a time.** No interviews, no questionnaires. If a flow asks a second question
before the user has answered the first, redesign it.

**Never ask what can be inferred.** A Cook saying "عملت كشري" already implies Egyptian cuisine, main
course, and a known ingredient set. Asking for those is a bug.

**Explain assumptions.** When the AI fills in a field, the UI shows why: "I set the cuisine to
Egyptian because this contains molokhia and rice." Silent inference destroys trust.

**Human approves.** The AI produces a draft. The user confirms or edits. There is no path where the
AI's output reaches the database unreviewed.

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
