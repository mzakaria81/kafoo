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

### Observation 6: Verify a task's stated premise against external authority before designing to it

**Status:** OPEN
**Date:** 2026-07-30
**Session context:** Working T039 (release signing custody) in a repo whose spec, handoff doc, and ADR all asserted that losing either the Android upload key or the Apple distribution certificate is permanently unrecoverable.

**Skill:** brainstorming
**Type:** open-source
**Phase/Area:** Checklist step 1, "Explore project context"

**Issue:** The project's own documents encoded a factually wrong premise, repeated across three files, and the task was written to solve the problem as those documents framed it. Designing directly against that framing would have produced an elaborate custody scheme for two assets — one of which is routinely resettable by the platform vendor, and one of which is disposable by design — while leaving the single genuinely irreversible asset unnamed anywhere in the repo. Internal consistency across several documents read as corroboration when it was actually one unverified belief copied forward. Two short vendor-documentation checks overturned it.

**Suggested improvement:** In the "Explore project context" step, add: when a task's stated stakes rest on an external system's behaviour — a platform's recovery policy, an API's guarantees, a vendor's limits — verify that behaviour against the vendor's own documentation before designing. Repeated assertions across project files are not independent confirmation; they are usually one source copied. Where verification contradicts the project's documents, surface the correction as the first deliverable, since it may change what the task is.

**Principle:** Agreement among a project's internal documents is not evidence. When a design's stakes depend on an external system's behaviour, the external system is the authority — check it before designing, because a wrong premise produces a well-built solution to a problem that does not exist while hiding the one that does.

### Observation 7: Persistent session state must commit independently of a deliverable approval gate

**Status:** OPEN
**Date:** 2026-07-30
**Session context:** Designing release signing custody (T039). The brainstorming skill's HARD-GATE forbids writing the design document until the user approves the design, while the repository's stop hook requires a clean working tree and CLAUDE.md requires the observation log to be committed and pushed or it is lost when the ephemeral container is destroyed.

**Skill:** task-observer
**Type:** open-source
**Phase/Area:** "How to Log" / archival and persistence

**Issue:** Observations were appended to the log during a phase where the session's actual deliverable was deliberately unwritten, awaiting approval. This produced a working tree that was dirty solely because of skill bookkeeping. In an environment where uncommitted state does not survive the session, the log would have been lost at teardown while the approval gate was still open — and the loss would have looked like the gate working correctly. The two mechanisms are individually right and jointly produce a gap.

**Suggested improvement:** State that observation-log writes are session bookkeeping, not deliverables, and must be committed on their own — separately from, and without waiting on, any approval gate governing the session's actual output. Where the environment is ephemeral, treat the commit-and-push as part of the log write rather than as end-of-session cleanup, since an approval gate can hold the deliverable open past teardown.

**Principle:** An approval gate governs the deliverable, never the record of how the work was done. Bookkeeping that must outlive the session has to be durable the moment it is written — otherwise a correctly-held gate and a correctly-enforced clean-tree check combine to destroy it silently, and the destruction is indistinguishable from both mechanisms working.

### Observation 8: A numeric threshold in a project rule fires where a stylistic preference does not

**Status:** OPEN
**Date:** 2026-07-30
**Session context:** Writing the first feature specification for a project whose constitution states "never build a form where a conversation would work" and then adds a concrete trigger: "on reaching a fourth input field, STOP and propose a conversational flow."

**Skill:** speckit-specify
**Type:** open-source
**Phase/Area:** Spec generation — applying project governance to a drafted spec

**Issue:** The entity being specified carried five attributes, listed in the project's domain model as an ordinary field list. Nothing about drafting the specification would have surfaced a problem — five attributes on an entity reads as unremarkable, and the qualitative half of the rule ("prefer a conversation") is easy to nod at while writing a form anyway. What caught it was the countable half: four fields, and this had five. The count is checkable against a draft without judgement, so it fired. The resulting requirement changed the feature's shape substantially rather than its wording.

**Suggested improvement:** When a project supplies governance documents, extract any rule with a countable trigger (a field count, a file-length limit, a nesting depth, a dependency ceiling) and check the draft against those specifically before writing the quality checklist. Record the check and its result in the checklist so the reasoning survives. Qualitative principles should still be applied, but they cannot be verified the same way and should not be assumed satisfied merely because they were read.

**Principle:** Governance that states a number gets enforced; governance that states a taste gets agreed with and ignored. When applying project rules to a draft, find the countable triggers first and check them mechanically — they are the ones that catch a problem the drafting process itself made invisible.

### Observation 9: When a user proposes copying a known product, separate its mechanism from its risk posture

**Status:** OPEN
**Date:** 2026-07-30
**Session context:** Clarifying an identity model. Offered a choice between treating a phone number as the identity or as a credential attached to a separate identity; the user replied "what about doing it like whatsapp".

**Skill:** speckit-clarify
**Type:** open-source
**Phase/Area:** Sequential questioning loop — handling a reference-product answer

**Issue:** A reference product bundles two separable things: the mechanism a user can see, and the risk posture that mechanism is safe under. Checking the vendor's documentation showed the mechanism was already the recommended option — the product's change-of-number feature transfers an account between numbers, which is only possible if the number is not the account. So "do it like X" resolved the question rather than reopening it. But the same check showed the risk posture did not transfer at all: that product's valuable data is device-local, so a recycled number yields an empty account, while this project's equivalent data is server-side, permanent, and reputational. Answering only the visible half would have imported a relaxed stance on account takeover along with a sound data model, and the import would have been invisible because the user's stated intent was satisfied.

**Suggested improvement:** When a user answers a clarification question by naming a product to copy, resolve it in two parts before proceeding: (a) what does that product actually do internally, checked against its own documentation rather than its surface behaviour — often it already matches one of the offered options; and (b) what property of that product's architecture makes its approach safe, and does the project share it? Report both, and state explicitly which half transfers. Do not treat the reference as a single answer.

**Principle:** A reference product is two claims wearing one name: a mechanism and the conditions under which that mechanism is safe. Copying is only sound when both transfer, and the second is the one nobody checks — it lives in architecture the user cannot see, so an unexamined analogy silently imports a risk posture along with a design.

### Observation 10: Check a proposal against the proposer's own goals stated elsewhere in it

**Status:** OPEN
**Date:** 2026-07-30
**Session context:** A user sent two proposals in one message. The first asked to move a governed list out of a high-ceremony document into an ordinary one, so a governing document would "simply reference it". The second, several hundred words later, recommended keeping that same list in the high-ceremony document precisely so it would stay hard to change.

**Skill:** brainstorming
**Type:** open-source
**Phase/Area:** Evaluating a user proposal before implementing it

**Issue:** Each half was individually sound and well argued. Taken together they were in direct tension: the first would have removed the change-resistance that the second named as the reason the arrangement was worth having. Implementing the first as literally written would have satisfied the user's stated request while quietly destroying the property they asked for a page later, and it would have looked like compliance. The tension was only visible by holding both halves at once, which is exactly what a long proposal makes hard — the natural failure mode is to evaluate each section as it is read.

**Suggested improvement:** When a proposal arrives in multiple parts, evaluate the parts against each other before evaluating any of them against the codebase, and say plainly where they conflict. A conflict inside a proposal is not the proposer being careless — it usually marks the place where they hold two real goals and have not yet found the design that serves both. Naming it converts an implementation decision into a design question, which is where it belongs, and the synthesis is often better than either part.

**Principle:** A multi-part proposal is a set of constraints, not a sequence of instructions. Read it whole and check the parts against one another first: where they conflict is where the proposer's real design problem is, and implementing one part faithfully can silently destroy what another part was protecting.

### Observation 11: When correct behaviour coincides with achievable behaviour, record the coincidence

**Status:** OPEN
**Date:** 2026-07-30
**Session context:** Planning a feature whose requirement made one entity's visibility depend on a second entity that a later feature will create. The authorization policy expressing that rule could not be written, because it must reference a table that does not exist.

**Skill:** speckit-plan
**Type:** open-source
**Phase/Area:** Phase 1 design — deriving enforcement from requirements

**Issue:** The requirement could not be implemented as stated, but the behaviour it produces today — nothing is visible, because the thing visibility depends on does not exist — was identical to the deny-by-default posture already required. So the correct implementation was to write nothing, and the feature is correct by accident of ordering rather than by construction. That is a genuinely good outcome and a genuinely dangerous one: nothing in the code, the tests, or the schema marks the absence as deliberate, and the later feature that creates the missing entity will not discover it. The failure mode is silent in the worst way — the widened query returns zero rows rather than erroring, so it reads as "no data yet" rather than "the rule was never wired up".

**Suggested improvement:** In Phase 1, flag any requirement whose enforcement depends on an artifact a later phase creates. Where the current correct behaviour coincides with the currently achievable behaviour, say so explicitly in the design artifact the later phase will read, and write out the enforcement it must add — not as prose, but as the concrete thing to paste in. A deliberate absence and an oversight look identical in a codebase; only the record distinguishes them.

**Principle:** An absence that is correct today and wrong tomorrow is indistinguishable from an omission, because nothing in the artifact records intent. When a rule cannot yet be expressed and doing nothing happens to be right, the deliverable is not the silence — it is the note that says why the silence is there and what must replace it.

### Observation 12: A pipeline's exit status is the last command's, so piping a check into a pager silently disarms it

**Status:** OPEN
**Date:** 2026-07-30
**Session context:** Running a project's mandatory verification gate before committing, written as `./scripts/verify.sh 2>&1 | tail -5 && git add -A && git commit`. An earlier `cd` in the same persistent shell meant the script path no longer resolved.

**Skill:** verification-before-completion
**Type:** open-source
**Phase/Area:** Running verification commands before claiming completion

**Issue:** The gate never ran — the shell reported "No such file or directory" — but the commit and push proceeded anyway and reported success. A pipeline's exit status is that of its *last* command, so `tail` exited 0 and the `&&` chain continued as though the check had passed. The "No such file" line was one line inside a wall of expected output and read as noise. The commit was later verified sound, but that was luck: the process had produced a confident success claim backed by nothing, which is precisely the failure the gate exists to prevent. Two ordinary conveniences combined to cause it — piping long output through `tail` to save context, and a working directory persisting across calls in a way a single command does not reveal.

**Suggested improvement:** When running a verification command whose result gates a subsequent action, never let it be the non-final element of a pipeline. Either run it bare, or capture and assert its status explicitly (`set -o pipefail`, or check `${PIPESTATUS[0]}`) and print that status alongside the output. Where the shell's working directory persists between calls, use an absolute path or an explicit `cd` to the repository root in the same command rather than relying on where the previous one left off. Treat "the check produced output I recognise" as insufficient evidence that the check ran at all.

**Principle:** A verification step that cannot fail loudly is not a verification step. Truncating or paging a gate's output discards the one thing that makes it a gate — its exit status — and leaves a success claim resting on the appearance of having checked. Assert the status explicitly, or do not claim the check ran.

### Observation 13: Per-feature task IDs collide across features, so a cross-feature status document points at two different tasks

**Status:** OPEN
**Date:** 2026-07-31
**Session context:** Answering "what is still missing from Epic E1" by reading the feature's `tasks.md` alongside the project-wide handoff document.

**Skill:** speckit-tasks
**Type:** open-source
**Phase/Area:** Task ID assignment and cross-document referencing

**Issue:** Task IDs restart at T001 for every feature, so the second feature's list reuses every ID the first one used. The project-wide handoff document cites bare IDs ("T039 — decide where the upload keystore lives", "T030", "T043", "T044") that belong to the *earlier* feature's list, while the current feature's list has its own T039, T030 and T043 with entirely unrelated content. Nothing in either document marks which list a cited ID belongs to. A reader tracking open work resolves the reference against whichever list is open, and both resolutions look correct — the IDs exist in both, with plausible-sounding descriptions. The failure is silent and gets worse with every feature added.

**Suggested improvement:** Require any reference to a task from outside its own `tasks.md` to be qualified with its feature — `001-e0-foundation/T039`, or at minimum "E0 T039" — and say so in the tasks template so the convention exists before the second feature makes it necessary. Where a status document lists open work spanning features, group by feature rather than presenting one flat list of bare IDs.

**Principle:** An identifier that is only unique within its own document becomes ambiguous the moment anything else cites it, and ambiguity between two documents that both contain the ID resolves silently rather than erroring. Namespace the reference at the point of citation, not at the point of definition — the definition never sees the collision.

### Observation 14: When designing against an external system's timer, fix the direction of your proxy clock before arguing about its value

**Status:** OPEN
**Date:** 2026-07-31
**Session context:** Designing a policy that has to act before an external party (a mobile carrier) reassigns a resource, where the external party's own clock is unobservable.

**Skill:** brainstorming
**Type:** open-source
**Phase/Area:** Proposing approaches / presenting the design

**Issue:** The obvious design question was "what threshold?", and the conversation was heading straight at picking a number. The threshold turned out to be the easy half. The hard half was which clock the threshold runs on — the system could measure one thing (its own use) while the external party measured another (any use of the underlying line), and the two are not the same quantity. Naming the relationship between them settled the design: because using the product necessarily produces activity on the line, the product's measured dormancy is always greater than or equal to the real dormancy, so the policy fires early and never late. That inequality is what makes the design correct for *any* threshold under the bound, rather than correct for one lucky number. Had the first-drafted clock been used instead — last authentication rather than last activity — the same threshold would have produced constant false positives, because sessions deliberately outlive authentication. Same number, opposite outcome, and nothing in the threshold discussion would have surfaced it.

**Suggested improvement:** In the approaches step, when a design depends on acting before an external system does something on a schedule you cannot observe, require an explicit statement of the proxy: what you actually measure, what they actually measure, and which direction the inequality between them runs. State it before proposing any threshold value. Where the inequality runs the safe way, say so — it is the argument that the design is sound rather than tuned. Where it does not, or where it cannot be established, that is the finding, and no threshold value repairs it.

**Principle:** A threshold is only as good as the clock it runs on, and a proxy measurement is not the thing it proxies. Establish which way the error leans before choosing a value: a proxy that is guaranteed to err in the safe direction makes a whole range of values correct, while one that can err either way makes every value a guess, however carefully it was picked.

---

## 2026-07-31

### Observation 15: `flutter create --platforms=` replaces, not appends, the platform list in `.metadata`

**Status:** OPEN
**Date:** 2026-07-31
**Session context:** Adding web as a build target to a Flutter app that already had `android/` and `ios/`
**Skill:** release-engineer
**Type:** open-source
**Phase/Area:** Platform scaffolding generation

**Issue:** Running `flutter create --platforms=web .` in an existing app rewrote `.metadata`, replacing the android and ios `migration.platforms` entries with only web. It also dropped template `test/widget_test.dart` and `README.md` into the project — the widget test references a widget that does not exist in this codebase and would break the test suite. The command did not touch tracked source files, but it silently changed platform-tracking metadata in a way that would look intentional in a diff review.

**Suggested improvement:** After any `flutter create --platforms=` run on an existing project, review the full diff, not just the new directory: restore dropped platform entries in `.metadata` (the correct end state is root plus every platform the project actually has), and delete the template `test/widget_test.dart` / `README.md` where the repo has its own conventions.

**Principle:** A scaffolding generator assumes a fresh project. Running it on an existing one changes state beyond its "Wrote N files" summary — audit the diff for deletions and dropped entries, not just additions.

### Observation 16: Before assuming a package blocks a platform, check the version actually resolved

**Status:** OPEN
**Date:** 2026-07-31
**Session context:** Adding a web build target; the brief flagged `speech_to_text` as the expected blocker
**Skill:** New skill candidate: platform-gap-checking
**Type:** open-source
**Phase/Area:** Platform support assessment

**Issue:** The brief listed `speech_to_text` as the expected blocker for a web build, but the workspace had already resolved 7.4.0, which declares web support (federated `speech_to_text_web` using the browser SpeechRecognition API) and compiles cleanly. It also degrades to the app's existing typing fallback by itself: the web implementation's `locales()` returns an empty list before a listen session starts, so the app's "resolve an Arabic locale or mark recognition unavailable" logic turns the feature off on web with no code change.

**Suggested improvement:** Before building an isolation shim for a platform-gap risk, check the resolved dependency version's declared platforms and read its platform implementation. Conditional-import isolation is only warranted when the build or runtime actually breaks; a well-implemented plugin can be a non-event, and the existing fallback may already handle the gap.

**Principle:** Verify the real obstacle before building the workaround. A dependency that "may not support" a platform often does — the declared platform map and the runtime behaviour of the actual resolved version are the ground truth.

### Observation 17: A credential that works is not evidence you are pointed at the right system

**Status:** OPEN
**Date:** 2026-07-31
**Session context:** About to run a project's authorization test suite against its deployed database, using credentials already present in the session environment.

**Skill:** verification-before-completion
**Type:** open-source
**Phase/Area:** Verifying preconditions before acting on an external system

**Issue:** The environment held a complete, valid set of credentials for a deployed database — project reference, URL, database password, and a service-role key. Every one of them worked. They belonged to an entirely different application: a household-finance product sharing the same account, with twenty populated tables. The repository was correct, the branch was correct, the credentials authenticated successfully, and the target was wrong. The human had approved the action while believing the target was their own empty database, so the approval was real but rested on a false premise neither party had checked. A read-only listing of table names caught it in one query; the next command in the sequence would have created users in a live unrelated system, and an earlier step in the same plan — a database reset — would have dropped twenty tables. Authentication succeeding felt like confirmation of identity, and it is only confirmation of access.

**Suggested improvement:** Before the first state-changing call against any external system, make one read-only call that returns something a human would recognise — resource names, a project title, a row count — and compare it against what the task expects. Prefer an identifying query over a connectivity check: "can I connect" and "am I connected to the right thing" are different questions, and only the second one catches this. Where the environment supplies credentials rather than the task naming a target, treat the target as unverified by default.

**Principle:** Credentials answer "may I", never "should this". A successful authentication against the wrong system is indistinguishable from success against the right one, so identity of the target must be established by observation rather than inferred from the fact that access worked.

### Observation 18: A test that has never run may be unrunnable, not merely unexecuted

**Status:** OPEN
**Date:** 2026-07-31
**Session context:** Writing instructions for a human to execute a database authorization suite that had been written, reviewed and merged months earlier but never once executed.

**Skill:** test-driven-development
**Type:** open-source
**Phase/Area:** Tests written ahead of the code they test

**Issue:** The suite was written before the policies it tests, which is correct discipline, and then never run because the session that wrote it lacked the container runtime. It was documented as "never executed", and everyone — including me, when I wrote a step-by-step guide around running it — read that as "the tests are fine, nobody has pressed the button". They were not fine. They called four helper functions from a test-support library and a testing extension, and nothing in the repository installed either. The first statement would have failed on any machine. The project's own quality gate passed throughout, because no check covers whether a test suite can start. So an unrun suite had been sitting in the repository being counted as evidence, and the distance between "unexecuted" and "unrunnable" was never noticed because both look identical from the outside.

**Suggested improvement:** When tests are written before the thing they test, the deliverable is not the test file — it is a test file plus a demonstration that the harness starts. If the environment cannot run them yet, record specifically what was never verified: not "these have not run" but "these have never been observed to start, and their dependencies are uninstalled". Where a project has an automated gate, add the cheapest possible check that each suite can be invoked at all, separately from whether it passes. A suite that cannot start is a stronger failure than a suite that fails, and it is the one no gate reports.

**Principle:** "Not yet run" describes a schedule; "cannot run" describes a defect. They are recorded with the same words and carry opposite weight, so the gap between writing a test and first executing it must be closed by observing the harness start — otherwise a suite that was never viable accumulates the credibility of one that simply awaited its turn.
