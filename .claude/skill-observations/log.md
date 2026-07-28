# Skill observation log

Maintained by the `task-observer` skill. Observations are appended to the **end** of this
file, never mid-file, always in the form `### Observation NNN:` with `**Status:** OPEN` as the
first field.

**Status key:** OPEN = not yet actioned | ACTIONED (YYYY-MM-DD) = skill updated/created |
DECLINED (YYYY-MM-DD) = decided not to pursue. Resolved statuses always carry their date.

> **This file only survives if it is committed and pushed.** Kafoo development runs in
> ephemeral containers; an uncommitted log is destroyed when the session ends. See the "Skill
> activation" section of `CLAUDE.md`.

---

## 2026-07-28

### Observation 1: A gate can pass because it checked nothing

**Status:** OPEN
**Date:** 2026-07-28
**Session context:** Building E0 — CI, then the Dart workspace
**Skill:** New skill candidate: writing-verification-gates
**Type:** open-source
**Phase/Area:** Gate and check authoring

**Issue:** `scripts/verify.sh` reported PASS while five of its seven checks were skipping — no
Dart workspace, no ARB files, no migrations. The output said `ok` for each. It read as a healthy
project and was in fact a project where almost nothing was inspected. The same shape recurred
twice more in one session: the Android job's guard silently disabled the job it guarded, and the
signature check reported "verified" for a debug-signed bundle.

**Suggested improvement:** A check must distinguish *passed* from *had nothing to check*, in its
own output, every time. Three variants of the same bug appeared in one session, which suggests
this is a category rather than an incident.

**Principle:** A verification that cannot fail is not a verification. When adding a check, ask
what it prints when its subject is absent — if that is indistinguishable from success, the check
is decorative.

---

### Observation 2: Guards keyed to the wrong artifact revert silently

**Status:** OPEN
**Date:** 2026-07-28
**Session context:** Migrating from `melos.yaml` to a Dart pub workspace
**Skill:** New skill candidate: writing-verification-gates
**Type:** open-source
**Phase/Area:** Refactoring around conditional logic

**Issue:** The gate's Dart steps activated on `melos.yaml` existing. Melos 7+ requires a pub
workspace instead, so fixing CI meant deleting `melos.yaml` — which would have silently returned
`analyze` and `test` to skipping. The fix for one problem would have reintroduced the exact
problem the work existed to solve, invisibly, while CI stayed green.

**Suggested improvement:** When a conditional keys on a file, prefer the thing that *defines* the
condition over one spelling of it. Here: the `workspace:` key, not the filename that used to
carry it.

**Principle:** When deleting a file, grep for it first. A conditional that references it will
change behaviour rather than break, and behaviour changes do not announce themselves.

---

### Observation 3: Reviewing your own work catches a class of bug that reading does not

**Status:** OPEN
**Date:** 2026-07-28
**Session context:** Writing the deploy pipeline, then reviewing it with `trust-reviewer`
**Skill:** trust-reviewer, release-engineer
**Type:** internal
**Phase/Area:** Review dispatch

**Issue:** I wrote `deploy.yml` and believed it correct. Dispatching `trust-reviewer` against it
found three defects: a job-level guard that skipped the job on every run, signing material handed
over in a variable nothing reads, and an unpinned CLI running with a production token. It also
found the release checklist covered two of the four product-fatal trust rules. None were visible
to me on re-reading, because I re-read what I intended rather than what I wrote.

**Suggested improvement:** Dispatch a domain reviewer against non-trivial work in its domain
before committing, especially work whose failure is silent. The cost is one agent invocation.

**Principle:** An author re-reading their own work checks it against their intent. A reviewer
checks it against reality. These find different bugs, and the second kind are the ones that ship.

---

### Observation 4: Building the artifact found two bugs that no amount of reading would

**Status:** OPEN
**Date:** 2026-07-28
**Session context:** Generating platform projects, then building a real release bundle
**Skill:** release-engineer
**Type:** open-source
**Phase/Area:** Verification of build and release configuration

**Issue:** After the pipeline was written, reviewed, and corrected, actually running
`flutter build appbundle` surfaced two more problems: R8 failed outright on Play Core references
introduced by enabling minification, and the signature check I had *just written as a fix* gave a
false positive — a debug-signed bundle contains a signature block, so "a signature exists"
reported `verified` for an unpublishable artifact.

The second is notable: I had criticised the original check for asserting a property without
verifying it, then wrote a replacement that did the same thing one level deeper.

**Suggested improvement:** For any pipeline that produces an artifact, run it once end to end
before considering it correct. Inspect the artifact's actual properties, not the presence of
things that usually accompany them.

**Principle:** Verifying a proxy for the property is not verifying the property. "Has a signature
block" is not "is signed with the right key"; "secrets are set" is not "signing happened".

---

### Observation 5: Documents cited by active rules may not exist

**Status:** OPEN
**Date:** 2026-07-28
**Session context:** Analysing E0 scope
**Skill:** New skill candidate: governance-integrity-check
**Type:** open-source
**Phase/Area:** Project onboarding and rule authoring

**Issue:** `CLAUDE.md`, the constitution, and the business rules all named `docs/vision/glossary.md`,
`docs/product/domain-model.md`, and ADR-0005 as sources of truth. None existed. Definition of Done
item 6 required updating a file that had never been written. The rules had been enforceable-looking
and unenforceable for the project's entire history, and nothing surfaced it.

**Suggested improvement:** A mechanical check that every path referenced by a rules file resolves.
Tracked as T030 in `specs/001-e0-foundation/tasks.md`.

**Principle:** A rule that points at a missing document is worse than no rule: it reads as
governance and provides none. Check references resolve before trusting the rule that made them.
