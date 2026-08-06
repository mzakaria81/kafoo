---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always
---

# Verification Before Completion

## Overview

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verification command in this message, you cannot claim it passes.

## The Gate Function

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
5. ONLY THEN: Make the claim

Skip any step = lying, not verifying
```

## The Gate Behind The Gate

The Gate Function above assumes the command you run is a real check, aimed at the real target.
Both assumptions fail silently and routinely. These three questions are the ones that catch it.

### 1. Did the check actually run, and could it have failed?

A check that cannot fail is not a check. Green from a check that never executed, never found its
subject, or never had a failing path is indistinguishable from green from a working one.

- **Never let a gate be the non-final element of a pipeline.** A pipeline's exit status is its
  last command's, so `verify.sh | tail -5 && commit` commits even when `verify.sh` did not exist.
  Run it bare, or set `pipefail` / check `${PIPESTATUS[0]}` and print the status you assert on.
- **Skip-on-empty must never report success.** Any check whose discovery step can return nothing
  must distinguish "checked, found nothing wrong" from "found nothing to check". Prefer filesystem
  discovery over version-control discovery for anything validating work in progress — enumerating
  tracked files makes uncommitted work invisible, and the gate still answers, in the affirmative.
- **A newly written check is not evidence until it has been observed failing.** Break the thing it
  guards, run it, see red, restore. This applies with *more* force to a check copied from a working
  neighbour: copying its shape copies its unstated preconditions, and pattern-recognition is the
  strongest available source of false confidence.
- **A guarded step's contents are unverified until the guard has opened.** Ask of any `if:`-gated
  configuration: has this ever run? Resolve pinned versions against the registry, not by reading
  them for plausibility.
- **Ask what the check compares against, and whether that thing can be wrong in the same direction
  as the artefact.** Two derived copies agreeing proves consistency, never completeness — parity
  between translation files is perfect when a key is missing from both. Completeness needs a check
  against whatever creates the demand: the call sites, the schema, the interface.
- **A check whose failure output is implausible is announcing a bug in itself.** "All 11 keys are
  missing" is a signal, and it exists only if someone reads the output rather than the exit code.

### 2. Am I pointed at the right thing?

- **Credentials answer "may I", never "should this".** Before the first state-changing call against
  any external system, make one read-only call returning something a human would recognise —
  resource names, a project title, a row count — and compare it to what the task expects. A
  successful authentication against the wrong system looks exactly like success against the right
  one. Where the environment supplies the target rather than the task naming it, treat the target
  as unverified by default.
- **Existence, health and name are the cheapest properties to satisfy and the least informative.**
  When confirming a requested resource exists, check what creates it, what destroys it, and what it
  costs while it exists — the attributes that define its kind and lifecycle, not its presence.
- **Proof does not survive a rewrite.** Evidence attaches to the exact artefact that produced it.
  Before shipping a reimplementation of something already proven, execute the shipped file itself.
  The difference is rarely in the logic; it is in defaults neither version states — headers,
  timeouts, encodings, working directory.
- **One real call beats any amount of documentation.** Docs describe the service the provider
  intends to offer; a call describes the one your credential can reach. Type checks, unit tests and
  the provider's own discovery endpoints are all blind to the gap, and the gap runs systematically
  in the direction of "this looked fine and does not work". Record the measured result next to the
  configuration it justifies.
- **Distinguish *documented* from *observed*, and make the distinction survive into the artefact.**
  A dated measurement line, or an explicit "documented, not yet observed here". The two kinds of
  sentence are written identically, so unmeasured claims otherwise age into apparent fact.
- **Any lookup that answers "empty" instead of "no such thing" converts a naming mistake into
  valid-looking data.** Build-time constants, unset environment variables, config keys. Assert
  non-empty where the value is essential; the language will not.
- **A platform feature is adopted for one capability and arrives with several.** When enabling one,
  enumerate what it now does beyond the reason it was enabled, and check each against what your
  pipeline already does. For anything with a single authoritative state — a schema, a deploy target
  — two writers is worse than either alone. Resolve to one owner and record which.

### 3. What am I not claiming carefully enough?

- **A negative finding carries its search space as an inseparable qualifier.** "Not on PATH and not
  a subcommand" — not "does not exist". Before asserting a tool, package, API or file is absent,
  enumerate the channels it could arrive through and check the ones that apply; if any remain
  unchecked, say where you looked and ask. Adding corroborating detail to a wrong negative makes it
  worse, not better: it converts a checkable "I looked here" into an unearned "therefore it is
  nowhere", and the more coherent the story the harder it is to correct.
- **Verification is not automatically side-effect-free.** Before fetching a detail record from an
  infrastructure API, consider whether the response embeds credentials, and prefer the narrowest
  endpoint that answers the question. A read that returns secrets has published them into your
  transcript; treat it as a leak requiring rotation, not as an authorised read.
- **Marking a claim unverified is a debt, not a discharge.** Keep a short list of what is
  outstanding; when the blocking condition clears, measure and write the result back into the same
  files that carried the guess. Where the verification window is transient — an ephemeral
  environment, a live incident — protect it deliberately, because the default workflow will close it.
- **A verification worth writing down is usually a verification worth automating.** Prose in a
  runbook runs only when someone reads that paragraph. If the check is a single command with a
  deterministic pass/fail, it belongs in the gate; keep the prose as explanation.
- **A permission a test asks for is a design signal.** When a test needs a capability the suite does
  not have — filesystem, network, clock, environment — check whether a static check over the source
  tree expresses the same property first. Structural questions ("does this code ever mention X")
  are build-gate assertions wearing a test's clothing, and the gate version needs no permission and
  covers every file rather than the one the test could reach.
- **A documented fix creates the impression of a solved class of problem while solving an
  instance** — and the better the write-up, the stronger the impression. When you fix a
  verification defect, grep the whole verification layer for siblings and record the sweep, not the
  fix, as the thing you did.

## Common Failures

| Claim | Requires | Not Sufficient |
|-------|----------|----------------|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passes once |
| Agent completed | VCS diff shows changes | Agent reports "success" |
| Requirements met | Line-by-line checklist | Tests passing |
| New check works | Seen red on a deliberate break | Green on the current tree |
| Gate examined my work | Its output names the new files | Overall "ok" |
| Right system targeted | Read-only call returning a recognisable name | Credentials authenticated |
| Integration works | One real call, result recorded | Docs, config, green unit tests |
| X does not exist | Named the namespaces searched | "I checked and it's not there" |
| Behaviour is covered | Suite goes red when the behaviour is removed | A passing test named after it |

## Red Flags - STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!", etc.)
- About to commit/push/PR without verification
- Trusting agent success reports
- Relying on partial verification
- Thinking "just this once"
- Tired and wanting work over
- **ANY wording implying success without having run verification**

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter ≠ compiler |
| "Agent said success" | Verify independently |
| "I'm tired" | Exhaustion ≠ excuse |
| "Partial check is enough" | Partial proves nothing |
| "Different words so rule doesn't apply" | Spirit over letter |

## Key Patterns

**Tests:**
```
✅ [Run test command] [See: 34/34 pass] "All tests pass"
❌ "Should pass now" / "Looks correct"
```

**Regression tests (TDD Red-Green):**
```
✅ Write → Run (pass) → Revert fix → Run (MUST FAIL) → Restore → Run (pass)
❌ "I've written a regression test" (without red-green verification)
```

**Build:**
```
✅ [Run build] [See: exit 0] "Build passes"
❌ "Linter passed" (linter doesn't check compilation)
```

**Requirements:**
```
✅ Re-read plan → Create checklist → Verify each → Report gaps or completion
❌ "Tests pass, phase complete"
```

**Agent delegation:**
```
✅ Agent reports success → Check VCS diff → Verify changes → Report actual state
❌ Trust agent report
```

## When To Apply

**ALWAYS before:**
- ANY variation of success/completion claims
- ANY expression of satisfaction
- ANY positive statement about work state
- Committing, PR creation, task completion
- Moving to next task
- Delegating to agents

**Rule applies to:**
- Exact phrases
- Paraphrases and synonyms
- Implications of success
- ANY communication suggesting completion/correctness
