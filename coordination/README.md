# Coordination

Two or more Claude Code sessions work on Kafoo at once. This directory is how they avoid building
the same thing twice.

**They did, on 2026-08-05.** Two sessions each built the Cook's Meal list. One had merged it to
`main` twenty-six minutes before the other proposed it, and nothing said so — the second session
had asked the founder to approve design decisions that were already made and merged. The cost was
small and the failure mode is not: **both sessions believed they owned the work, and there was no
point at which either could have found out.**

## Roles

**One session is the coordinator. Every other session is a worker.** The coordinator is whichever
session the founder is talking to about planning; it is a role, not an identity, because sessions
run in containers that are destroyed after a period of inactivity. The founder is the only durable
participant.

**The coordinator alone** creates, splits, merges, prioritises, cancels and assigns work packages,
and is the only one that moves a package to `ASSIGNED`. It owns `coordination/`, `specs/*/tasks.md`
and `decisions/`.

**A worker never chooses its own work.** It owns its assigned package end to end — design, backend,
frontend, database, tests, documentation, verification — and updates the status of that package
only. It does not touch planning files.

## Work packages

A package is a complete unit of work, not a task. `coordination/packages/WP-###.json`, **one file
per package** — a single shared file would mean every status update by every worker rewrites the
same lines, which is a conflict point built into the thing meant to prevent conflicts. A conflicted
JSON file is also invalid, so every tool reading it breaks until a human intervenes.

State lives in the JSON. **Reasoning lives in markdown** — `specs/*/tasks.md` carries why a check
could not fail, what a mutation proved, which policy does which half of a rule. That prose is read
by the founder and would not survive being flattened into JSON string fields.

### Fields

| Field | Meaning |
|---|---|
| `id` | `WP-###`. Must match the filename. |
| `title`, `objective` | What and why, in a sentence each. |
| `tasks` | The `T###` numbers in `specs/*/tasks.md` this package delivers. |
| `acceptance_criteria` | How anyone tells it is done, without asking the author. |
| `dependencies` | Package ids that must be `COMPLETED` first. |
| `scope.files` | What this package expects to touch. |
| `scope.shared_files` | What it touches that another package also might. Declared honestly. |
| `execution_mode` | `PARALLEL` or `EXCLUSIVE`. |
| `status` | The lifecycle below. |
| `owner` | Exactly one, or `null` when `NOT_STARTED`. |
| `priority` | Lower is sooner. |
| `spend_envelope_usd` | What this package may spend on delegated dispatches. |
| `suggested_model` | From the `opencode-go/` allowlist. The prefix is the billing boundary. |
| `branch`, `pr` | So the coordinator can see state without asking. |
| `blocked_reason` | Required when `BLOCKED`. A blocker nobody wrote down is not one. |
| `updated_at` | Touched on every status change. Also how a dead worker is detected. |

### Lifecycle

```
NOT_STARTED → ASSIGNED → IN_PROGRESS → READY_FOR_REVIEW → COMPLETED
                              ↓
                           BLOCKED
```

**The two ends belong to the coordinator; the middle belongs to the worker.** `ASSIGNED` is the
coordinator's move, and so is `COMPLETED`. Everything between them — `IN_PROGRESS`, `BLOCKED`,
`READY_FOR_REVIEW` — is the owning worker's.

A worker moves its package to `READY_FOR_REVIEW` when its PR is open and green, and stops there.
It does not mark its own work complete, for the same reason this repository delegates
implementation in the first place: **the author of a change is the worst available reviewer of it.**
There are two practical reasons on top of the principle. `COMPLETED` means the work is in `main`,
which a worker often cannot know — the merge may be waiting on the founder. And by the time it
merges the worker's container may be gone, so a status that only it may set would never be set at
all.

The coordinator flips `COMPLETED` after the merge, and clears `owner` in the same edit: a finished
package holds no worker, and a name left on one makes it look busy to the next session that reads
this directory.

### A worker's PR stays the worker's until it merges

**Conflicts, red CI and review comments on an open PR belong to the worker that opened it, not to
the coordinator.** The coordinator's only move on someone else's PR is to merge it, or to say why
it is not being merged.

This is not obvious and it cost duplicated work on 2026-08-05. WP-002's PR went un-mergeable when
WP-003 merged ahead of it. worker-b saw its own PR go red and started resolving. The coordinator saw
a production-blocking fix sitting unmergeable and started resolving. Both were right on their own
terms; neither could see the other. The collision surfaced only when the coordinator's push was
rejected as non-fast-forward — **git refusing the push was the entire notification mechanism**, and
had the coordinator pushed first it would have overwritten a live worker's branch instead.

The exception is a worker that is gone. Containers are destroyed on inactivity, so this is the
normal end of a session rather than an edge case: if the package is unowned, or `IN_PROGRESS` past
the staleness warning the validator prints, the coordinator may take the branch over. Say so in the
package before touching it, for the same reason the claim is pushed before the work starts.

**Do not read a "merged" from anyone but the repository.** The same day, a report that WP-002 had
merged arrived while its PR was still open — which is what sent the coordinator to the branch in the
first place. Check the PR state before acting on a claim about it, including a claim from the
founder; the cost of checking is one API call and the cost of not checking is two sessions editing
one branch.

### Execution mode

`PARALLEL` is the default. `EXCLUSIVE` means nothing else runs while it is active — used for
changes that touch files every other package touches. `WP-007` is the worked example: it rewrites
both ARB files and about 56 call sites, and it changes `verify.sh`, which every other package
depends on to know whether it passed.

**Exclusivity solves file contention, not resource contention.** Two parallel packages still share
the OpenCode spend caps, which is what the envelope is for.

## The limit worth stating plainly

**File-disjoint packages are not achievable in this repository, and pretending otherwise hides
collisions rather than removing them.** Measured across everything committed since 1 August, the
hotspots are `app_ar.arb` and `app_en.arb` with their three generated files, the spend ledger, the
observation log, `verify.sh`, and the pgTAP suites — where two workers adding cases both edit the
same `plan(N)` line.

So packages declare `shared_files` and the coordinator serialises the ones that genuinely collide.
The spend ledger and the calibration file are handled differently: `.gitattributes` gives them a
union merge, because their only operation is "add a line".

## What the gate enforces

`scripts/validate-coordination.py`, run by `./scripts/verify.sh`. It refuses duplicate ids, a
filename disagreeing with its id, an active package with no owner, a `NOT_STARTED` package that has
one, `BLOCKED` with no reason, two active `EXCLUSIVE` packages, anything running beside an active
`EXCLUSIVE`, a dependency that does not exist, a cycle, a model outside the `opencode-go/`
allowlist, and a missing spend envelope.

It **warns** rather than fails when a package has sat `IN_PROGRESS` for six hours: the worker has
probably died with its container, and only the coordinator may reclaim it. Failing there would
block every unrelated commit until someone tidied up.

Every one of those rules was mutation-tested when it was written — broken on purpose, watched to go
red, and put back.
