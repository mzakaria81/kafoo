---
paths:
  - "packages/ai/**"
  - "prompts/**"
  - "supabase/functions/**"
---

# AI layer

## Provider independence (ADR-0005)

Every model call goes through `AiProvider` in `packages/ai/lib/provider/`. Feature code never
imports an OpenAI, Anthropic, or Gemini SDK — it depends on the interface.

Provider-specific quirks (token limits, tool-call formats, response shapes) are absorbed inside the
adapter. If a quirk leaks into a caller, the abstraction has failed and needs fixing, not
working around.

Switching providers must be a config change. Test this claim: `packages/ai/test/` runs the same
golden cases against a stub adapter.

## Prompt files

Prompts live in `prompts/*.md`, version-controlled, one file per task. Never inline a multi-line
prompt in Dart or TypeScript.

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
