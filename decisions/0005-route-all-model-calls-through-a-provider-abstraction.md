# ADR-0005 — Route all model calls through a provider abstraction

**Status:** Accepted
**Date:** 2026-07-26
**Decider:** Founder

> Written retroactively. This decision was already binding — `CLAUDE.md`, the constitution
> (Principle V), and `.claude/rules/ai.md` all cite ADR-0005 — but the record itself was never
> committed. This file states the decision those rules were enforcing.

## Context

Kafoo is AI-first: meal analysis, calorie and allergen estimation, ingredient extraction,
cuisine suggestion, description drafting, translation, search ranking, and conversation all run
through a language model. The AI is not a feature bolted on the side; it is most of the product
surface.

Facts that forced the decision:

- Model vendors change faster than this product will. Pricing, rate limits, tool-call formats,
  and response shapes have all moved repeatedly within single quarters.
- Kafoo's workload is dialect-sensitive. Egyptian Arabic quality varies sharply between models
  in ways that are not predictable from benchmarks, so the ability to switch on evidence is a
  requirement, not a nicety.
- Cost and latency profiles differ per task. Extraction and classification want a fast tier;
  a subtle estimation wants a stronger one. Binding to one vendor binds both tiers at once.
- A voice round-trip budget of 2 seconds makes provider latency a product constraint.

## Options considered

| Option | Cost | Risk | Reversibility |
|---|---|---|---|
| Call vendor SDKs directly from feature code | Lowest upfront | Vendor change becomes a repo-wide refactor touching Flutter and Edge Functions; dialect quality locked to one vendor | Very low — every call site must change |
| Thin per-call wrappers, no shared interface | Low | Drifts into inconsistent shapes; each wrapper leaks its vendor's quirks; no single place to add caching, tiering, or evals | Low |
| One `AiProvider` interface in `packages/ai/`, vendor adapters behind it | Real upfront design cost; adapters must absorb quirks | Abstraction can leak if not tested; over-abstraction risk if the interface guesses at future needs | High — swapping is a config change |
| Route through a third-party gateway (OpenRouter and similar) | Adds a vendor and a margin; another party sees every prompt | Availability and privacy now depend on a middleman; still needs an internal interface anyway | Medium |

## Decision

Every model call goes through the `AiProvider` interface in `packages/ai/lib/provider/`. Feature
code and Flutter code depend on that interface and never import a vendor SDK. Vendor-specific
behaviour — token limits, tool-call formats, response shapes, retry semantics — is absorbed
inside the adapter. Swapping OpenAI → Anthropic → Gemini is a configuration change, not a
refactor.

The claim is tested rather than asserted: `packages/ai/test/` runs the same golden cases against
a stub adapter, so an abstraction that has quietly leaked fails the suite.

## Consequences

**Accepted costs.** An interface must be designed and maintained ahead of knowing every future
need. Each new provider costs adapter work before it can be trialled. Provider-specific features
are either modelled in the interface or unavailable, so some vendor-only capability will
occasionally be out of reach until the interface grows to fit it. Every prompt change carries an
eval obligation.

**What this forecloses.** Direct use of a vendor's convenience SDK, and any vendor feature that
cannot be expressed through the interface, until the interface is extended. Reopening means
extending `AiProvider` and updating every adapter — deliberately more expensive than adding a
call site, because a leak here is what the ADR exists to prevent.

**Revisit trigger.** Reopen when either holds:

1. A vendor capability that would materially improve Egyptian Arabic quality cannot be expressed
   through the interface after one honest attempt to extend it.
2. Adapter maintenance exceeds roughly a day per quarter across all supported vendors, which
   would mean the interface is tracking vendor churn rather than insulating from it.

## Notes for Claude Code

All model calls go through `AiProvider`. Never import an OpenAI, Anthropic, or Gemini SDK
outside `packages/ai/lib/provider/`. If a provider quirk reaches a caller, the abstraction has
failed — fix the adapter, do not work around it at the call site. Every new AI behaviour ships
at least one golden case in `packages/ai/test/`.
