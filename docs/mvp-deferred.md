# Deferred work — the MVP ledger

Every shortcut taken under MVP mode is written here, in the same commit that takes it. That rule is
in CLAUDE.md's definition of done and it is the only thing that makes "perfect it later" a plan
rather than a hope.

**Why this file exists.** MVP mode suspended process rules on 2026-08-13 so Kafoo could get one
voice journey in front of five real Cooks. Restoring the old rulebook takes one command —
`git checkout fab86d8 -- CLAUDE.md .claude/`. Bringing work built under the looser rules back up to
the old standard does not — that cost is real, and this list is what keeps it visible.

**How to write an entry.** What was skipped, where it lives, what breaks if it is never done, and
what would trigger doing it. One entry per shortcut. Do not batch them at the end of a sprint; the
reason for a shortcut is only accurately remembered on the day it is taken.

## Standing deferrals — taken at the cut, 2026-08-13

| # | Deferred | Where | Cost if never done | Trigger to do it |
|---|---|---|---|---|
| 1 | Journey tests per screen transition | `apps/mobile/test/journey_test.dart` | Five defects reached the founder's phone on 2026-08-10 this exact way, all in the step *between* screens, gate fully green | Any second journey beyond the voice publish flow |
| 2 | Widget tests for loading / data / error states | `apps/mobile/test/` | Broken states ship silently; only money, authorization and domain rules are still covered | Before real Customers, not real Cooks |
| 3 | `quickstart.md` per feature | `specs/*/quickstart.md` | Nobody but the author can verify a feature by hand | A second person joins, or a feature is handed over |
| 4 | Spec → plan → tasks pipeline | `specs/`, Spec Kit skills | Work is planned in conversation, so the reasoning is not durable | Trial ends and the strict mode returns |
| 5 | ~~A fast gate~~ — **not deferred, rejected** | `./scripts/verify.sh` | Nothing. Measured on 2026-08-13: a cut-down gate saved 29 seconds of 3m12s, because codegen, analyze, tests and the authorization suites are nearly all of the runtime and none of them can go. Not worth a second definition of "passing" | — |
| 6 | Voice fidelity on screens outside the publish journey | `packages/ui/`, `apps/mobile/` | A component without its spoken Egyptian Arabic line is invisible to a Cook who does not read comfortably — the person the product exists for | Any screen a Cook reaches in the five-Cook test |
| 7 | The Customer web surface | `apps/web/` | Paused, not deleted. No Customer-facing web presence, no link previews, no search indexing | Cooks retain, and Customers need somewhere to land |
| 8 | Accessibility, localization, conversation-design and release reviews as blocking steps | `.claude/agents/` | Findings become advisory input; a real accessibility or Arabic-register defect can now ship | Trial ends, or a finding turns out to have shipped |

## Entries taken during the trial

| # | Date | Deferred | Where | Cost if never done | Trigger to do it |
|---|---|---|---|---|---|
| 9 | 2026-08-13 | ~~The Meal wizard keeps running~~ — **done for the Meal**. The Kitchen Profile onboarding is still five questions | `apps/mobile/lib/features/kitchen_profile/` | Two shapes of the same journey exist at once. A Cook meets a conversation for her Meal and a wizard for her kitchen, ten minutes apart | The Meal conversation survives the five-Cook test |
| 10 | 2026-08-13 | The conversation prompt has **no golden cases and has never been replayed against a model** | `prompts/conversation.md`, `packages/ai/test/goldens/` | The register, the refusal to invent facts and the injection resistance are asserted in prose and tested nowhere. The first real Cook is the first test | Before the five-Cook test, or the first time a turn reaches a live model |
| 11 | 2026-08-13 | ~~Ordering in `meal_step.dart`~~ — **removed**. `conversation_step.dart` still holds the Kitchen Profile sequence | `packages/domain/conversation_step.dart` | The domain layer half-contradicts ADR-0015, and the domain layer is what a new session reads as truth | With the Kitchen Profile conversation |
| 12 | 2026-08-13 | The publish gate is still a button, not the read-back gate of DESIGN.md §10.6 | `apps/mobile/lib/features/meal/presentation/meal_receipt.dart` | The «أيوة» moment — the one place the design is most specific and the trust rule most load-bearing — is a plain confirm button. `KafooConfirmationGate` exists and is unused here | Before a real Cook publishes anything |
| 13 | 2026-08-13 | The talk button's amplitude bars do not move | `apps/mobile/lib/features/meal/presentation/meal_conversation.dart` | The orb reports a constant zero because `VoiceInput` exposes no level. Honest, and it means the listening state is visually static | When the voice transport of ADR-0017 lands, which provides a real level |

_Rows 1–8 were taken at the cut. Add new rows above this line, newest last, with the date and the commit._
