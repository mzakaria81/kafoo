# ADR-NNNN — Short imperative title

**Status:** Proposed | Accepted | Superseded by ADR-NNNN
**Date:** YYYY-MM-DD
**Decider:** Founder

## Context

What forced a decision. The constraint, the pressure, the thing that broke. Facts and numbers, not
narrative.

## Options considered

| Option | Cost | Risk | Reversibility |
|---|---|---|---|

At least two real options. If there was only ever one, this is not a decision and does not need an
ADR.

## Decision

What we are doing. One paragraph, present tense.

## Consequences

**Accepted costs.** What this makes harder or more expensive. If this section is empty, the analysis
was not honest — every decision costs something.

**What this forecloses.** Options no longer available, and what it would take to reopen them.

**Revisit trigger.** The specific observable condition that should make us reopen this — a number, a
scale threshold, a date. Not "if it becomes a problem."

## Notes for Claude Code

The one-line rule an implementer needs. Example: "All model calls go through `AiProvider`. Never
import a vendor SDK outside `packages/ai/lib/provider/`."
