# Data model: E0 Foundation

**E0 introduces no domain entities.** That is the finding, not an omission.

The canonical model — Customer, Cook, Kitchen Profile, Meal, Order, Review, Conversation, and
the AI Assistant's permitted and forbidden actions — lives in
[`docs/product/domain-model.md`](../../docs/product/domain-model.md), which E0 *wrote* but did
not implement. Definition of Done item 6 requires that file to change in the same commit as any
domain change; duplicating it here would create a second source of truth and guarantee drift.

## Why no entities

E0 delivers a workspace, a gate, written rules, and a release path. None of those store anything
about a Customer or a Cook. `supabase/migrations/` is empty, and deliberately so: the first
migration belongs with the first feature that needs a table, together with its RLS policies and
its negative test, per Constitution Principle III.

Creating a table now would mean an unowned table — one whose ownership rule exists on paper but
has never been exercised by a real query.

## Consequence for FR-008

FR-008 requires that information belonging to one person is unreadable by anyone else, enforced
independently of the application, with evidence that a non-owner receives nothing.

The **enforcement machinery** exists:

- `.claude/hooks/check-rls.sh` blocks a write that creates a table without enabling RLS in the
  same migration.
- `scripts/verify.sh` fails the gate on the same condition.
- `.claude/agents/rls-reviewer.md` carries the review checklist, including the `USING` +
  `WITH CHECK` pair that a missing `WITH CHECK` would let a Cook use to reassign a Meal.

The **evidence** does not, because there is nothing yet to be a non-owner of. FR-008 is marked
unproven in the spec's Delivery Status rather than assumed satisfied. The first migration in E1
is what converts it from machinery to evidence.

## Structures E0 does define

These are code-level types, not persisted entities. No table backs any of them.

| Type | Package | Purpose |
|---|---|---|
| `Result<T, E>` with `Success` / `Failure` | `domain` | Model expected failure so a caller cannot forget it. Exceptions stay for programmer error. |
| `AppError` | `domain` | Carries an ARB key rather than display text, so every message reaching a person is localized and actionable. |
| `AiRequest` / `AiResponse` / `ModelTier` | `ai` | The shape of a model call. `promptId` names a file in `prompts/`, never inline text. |
| `AiProvider` | `ai` | The single seam to any model provider (ADR-0005). |
| `KafooSpacing` / `KafooColors` | `ui` | Design tokens, including the 48dp tap-target floor accessibility review checks against. |
