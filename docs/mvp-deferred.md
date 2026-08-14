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
| 9 | 2026-08-13 | ~~The Meal wizard keeps running~~ · ~~the Kitchen Profile is still five questions~~ — **both done, 2026-08-14.** The Kitchen Profile is one open conversation with its own prompt (`prompts/kitchen-conversation.md`) and controller, and the read-back gate in front of creating it | `apps/mobile/lib/features/kitchen_profile/` | — | — |
| 10 | 2026-08-13 | The conversation prompt has **no golden cases and has never been replayed against a model** | `prompts/conversation.md`, `packages/ai/test/goldens/` | The register, the refusal to invent facts and the injection resistance are asserted in prose and tested nowhere. The first real Cook is the first test | Before the five-Cook test, or the first time a turn reaches a live model |
| 11 | 2026-08-13 | ~~Ordering in `meal_step.dart`~~ · ~~`conversation_step.dart`~~ — **both gone, 2026-08-14.** `kitchen_facts.dart` replaces the sequence with an unordered set of missing facts, the same shape `meal_facts.dart` already had | `packages/domain/kitchen_facts.dart` | — | — |
| 12 | 2026-08-13 | ~~The publish gate is still a button~~ — **done 2026-08-14.** Publishing now opens the read-back gate of DESIGN.md §10.6: the Meal and its price are said aloud in full, «أيوة، انشرها» is 72dp and solid, «لأ، استنى» is 56dp outline, and no timeout answers it. The gate screen moved out of `my_meals_row_sheet.dart` into `features/conversation/presentation/read_back_gate.dart` so there is one implementation rather than one per caller | `apps/mobile/lib/features/meal/presentation/meal_receipt.dart` | — | — |
| 13 | 2026-08-13 | The talk button's amplitude bars do not move | `apps/mobile/lib/features/meal/presentation/meal_conversation.dart` | The orb reports a constant zero because `VoiceInput` exposes no level. Honest, and it means the listening state is visually static | When the voice transport of ADR-0017 lands, which provides a real level |

| 14 | 2026-08-13 | The assistant's spoken reply is played chunk-by-chunk as tiny WAV clips | `apps/mobile/lib/features/conversation/data/pcm_player.dart` | The agent streams raw samples with no container and nothing in Flutter's audio stack takes them. Each chunk becomes its own clip, so long replies can sound clipped at the seams. A real streaming sink is a platform channel per operating system | A Cook says the voice sounds broken |
| 15 | 2026-08-13 | The live conversation's model runs on the provider's account, not Kafoo's key | ElevenLabs agent config | ADR-0017 chose to keep Kafoo's own model behind the agent so the provider swap stays one environment variable. The custom-model endpoint is not written, so the agent currently runs the provider's. **Provider independence for the conversation is suspended, not decided away** | The custom-model Edge Function lands, or the founder accepts the lock-in explicitly |
| 16 | 2026-08-13 | **The whole voice path is untested on a real handset** | `agent_conversation.dart`, `agent-session` | The microphone stream, the socket, the ping/pong and the playback have never run outside a container. The signed-URL mint is the one part proven, by a real call | The first APK reaches a phone |

| 17 | 2026-08-13 | The hosted agent-management MCP server is declared but not signed in | `.mcp.json` | It authenticates with a browser sign-in, which a container cannot complete. Until the founder approves it in his own client, agents are managed by API calls in a session rather than by asking | Founder opens the project locally and approves the connector |

| 18 | 2026-08-14 | The Meal list's orb starts a NEW Meal instead of answering «عايزة تعملي إيه؟» | `apps/mobile/lib/features/meal/presentation/my_meals_screen.dart` | The design package has this orb taking a spoken command against the list — "شيلي المحشي من المنيو" changing a status. That needs an intent step through `packages/ai/` which does not exist, so the orb narrows to the one journey MVP mode asks for. A Cook who speaks a command to her list gets a new Meal conversation instead of the change she asked for | List-level intent lands, or a Cook in the five-Cook test speaks a command to the list |
| 19 | 2026-08-14 | The account sheet replaces a home menu, and only three entries were moved into it | `apps/mobile/lib/home.dart` | Everything the menu carried still exists. But the sheet is a tap-only surface with no spoken line, so it is deferral 6 in a new place — a Cook who does not read comfortably cannot be told what is in it | Any screen a Cook reaches in the five-Cook test |

| 20 | 2026-08-14 | The Kitchen Profile prompt has **no golden cases and has never been replayed against a model** | `prompts/kitchen-conversation.md` | Same shape as row 10 and the same cost: the register, the refusal to guess the form of address, and the injection resistance are asserted in prose and tested nowhere. The rule that matters most here is the one about never inferring how to address her from her name | Before the five-Cook test, or the first time a turn reaches a live model |

_Rows 1–8 were taken at the cut. Add new rows above this line, newest last, with the date and the commit._
