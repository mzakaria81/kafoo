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

### Observation 19: A verification step that lives only in prose is re-done by hand or not at all

**Status:** OPEN
**Date:** 2026-08-01
**Session context:** Checking environment variables and Supabase branching capability for Kafoo,
after a prior session had run against an unrelated project's credentials.
**Skill:** verification-before-completion
**Type:** open-source
**Phase/Area:** Turning a one-off verification into a repeatable gate

**Issue:** `docs/HANDOFF.md` and `docs/ops/verifying-e1.md` both instruct the reader to curl the
provider's project list and confirm the configured ref names the right project. The check is
correct and it caught a real error. But it is prose in two documents, so it runs only when a human
or agent happens to read that paragraph before touching a deployed resource. The project's actual
gate (`scripts/verify.sh`) checks committed credentials, RLS coverage and ARB parity — it does not
check that the credentials in the environment point at this project. The identity of the target
system is exactly the class of error the gate exists to catch, and it is the one thing left to
memory.

**Suggested improvement:** In `verification-before-completion`, add a rule: when a session
discovers a verification worth writing down, ask whether it can be expressed as an assertion in
the project's existing gate rather than a paragraph in a document. Prose verification steps decay
into optional reading; an assertion in the gate runs whether or not anyone remembers it. A useful
discriminator: if the check is a single command with a deterministic pass/fail, it belongs in the
gate, not in a runbook.

**Principle:** A verification recorded as prose is a suggestion; the same verification expressed as
an assertion in the build gate is a guarantee. When documenting a check, ask what it would take to
execute it automatically — and prefer that, even if the prose stays as explanation.

### Observation 20: Renaming environment variables degrades silently, because an unset credential reads as empty rather than as an error

**Status:** OPEN
**Date:** 2026-08-01
**Session context:** Auditing which environment variables this session actually has against the
names the repository and its documentation reference.
**Skill:** New skill candidate: environment-contract-check
**Type:** open-source
**Phase/Area:** Session start / environment readiness

**Issue:** The environment supplies suffixed names (`SUPABASE_PROJECT_REF_DEV`, `SUPABASE_URL_DEV`,
`SUPABASE_SERVICE_ROLE_KEY_DEV`, `SUPABASE_DB_PASSWORD_DEV`). Scripts, runbooks and test files
across the repository reference the unsuffixed names (`SUPABASE_PROJECT_REF`, `SUPABASE_URL`,
`SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_DB_PASSWORD`). Only `.mcp.json` was updated to the suffixed
form. Nothing fails loudly: shell parameter expansion of an unset variable yields an empty string,
so a script does not stop — it runs against an empty ref or an empty URL and produces a confusing
downstream failure, or worse, silently no-ops. The same shape produced the previous session's
wrong-project incident from the other direction: the variables were set, just set to another
product's values.

**Suggested improvement:** A small skill (or a section in an existing environment skill) that, at
session start, derives the set of environment variable names the repository actually references
(grep the tracked files), compares it against what is set, and reports three buckets: referenced
and set; referenced but unset; set but referenced nowhere. Each bucket is actionable and none of
them is visible today without deliberately going looking.

**Principle:** An environment variable has no schema, so a rename is not a breaking change — it is
a silent one. Any project that depends on named credentials needs an explicit contract between the
names the code reads and the names the environment provides, checked at start rather than
discovered at failure.

### Observation 21: Credentials outlive the task that needed them, and a shared environment has nowhere to put them but plain sight

**Status:** OPEN
**Date:** 2026-08-01
**Session context:** Enumerating environment variables while checking Supabase access.
**Skill:** New skill candidate: environment-contract-check
**Type:** open-source
**Phase/Area:** Credential hygiene in ephemeral/shared environments

**Issue:** The environment carries a live third-party API key for a service the repository does not
reference anywhere — a leftover from unrelated work in the same account. Its variable name is also
inconsistently cased against the vendor's convention, which means even code that wanted it would
likely miss it. The project's own documentation already records that this class of environment has
no secrets store and that anyone who can use it can read the values, and already carries an
outstanding instruction to rotate a different key for exactly this reason. So the risk is
understood; what is missing is the sweep that finds the next one.

**Suggested improvement:** Pair the "set but referenced nowhere" bucket from Observation 20 with an
explicit recommendation: an unreferenced credential in a shared environment is not inert, it is
exposure with no compensating benefit. Recommend removal or rotation rather than merely listing it.

**Principle:** In an environment with no secrets store, a credential's blast radius is set by who
can open a shell, not by what the code uses. Unreferenced credentials are therefore pure liability
— enumerate them deliberately, because nothing else will ever surface them.

### Observation 22: A pinned dependency version inside a conditionally-skipped step is never validated by anything

**Status:** OPEN
**Date:** 2026-08-01
**Session context:** Installing the Supabase CLI into the shared toolchain script and pinning it to
the version CI uses.
**Skill:** verification-before-completion
**Type:** open-source
**Phase/Area:** Trusting configuration that has never executed

**Issue:** The deploy workflow pinned a CLI version that was never published — only `.0` and `.1` of
that minor exist, and the pin named `.2`. The step could only ever have failed. It survived review
and months of green builds because its `if:` guard skips the whole step when the deployment secrets
are absent, and they always were. So the pin looked like the *most* carefully considered line in the
file — it even carried a comment explaining why pinning mattered — while being the one line nothing
had ever executed. It was caught only because a separate task needed the same tool locally and tried
to install that exact version.

**Suggested improvement:** Add to `verification-before-completion` a rule for conditionally-executed
configuration: a guarded step's contents are unverified until the guard has actually opened.
Reviewing such a step means asking "has this ever run?" — and where the answer is no, resolving the
pin out-of-band (a registry query, a dry-run install) rather than reading it for plausibility. A
version string is a claim about an external registry; only the registry can confirm it.

**Principle:** Green CI proves the steps that ran. A conditionally-skipped step accumulates the
appearance of validation without any, and the more deliberate its comments look, the more trust it
attracts. Ask of any guarded step: has the guard ever been true?

### Observation 23: A comment asserting an invariant is not the invariant, and reads as evidence that it holds

**Status:** OPEN
**Date:** 2026-08-01
**Session context:** Discovering the Supabase CLI was installed by only one of two environment
setup scripts.
**Skill:** New skill candidate: environment-contract-check
**Type:** open-source
**Phase/Area:** Shared setup across multiple environments

**Issue:** A toolchain script opened with "Single source of truth for the toolchain — called by BOTH
environment setups so they cannot drift apart," and listed what it installs. One tool was missing
from it and was installed separately by only one of the two callers, so one environment silently
lacked it. The header made the drift harder to see, not easier: anyone checking whether the two
environments agreed would read that paragraph and conclude the question was already settled. A
runbook compounded it by telling the reader to run the *other* script, so the gap only surfaced for
someone who ran neither and looked for the tool directly.

**Suggested improvement:** When a file claims to be the single source of truth for a set, the claim
should be checkable rather than asserted — enumerate the set in one place and have the consumers
read it, or add an assertion that fails when a consumer installs something the shared script does
not. Where that is too heavy, at minimum treat "this comment says it cannot drift" as an unverified
claim during review, and check the callers.

**Principle:** Documentation of an invariant is not enforcement of it, and it is worse than silence
when wrong — it converts the reader's question into a false answer. Prefer invariants that fail
loudly over invariants that are described accurately.

### Observation 24: A safety hardening can break the thing it protects, so check the callers before revoking

**Status:** OPEN
**Date:** 2026-08-01
**Session context:** Restricting a test-harness helper before it began running on internet-facing
ephemeral databases.
**Skill:** rls-reviewer
**Type:** open-source
**Phase/Area:** Privilege tightening on test/support code

**Issue:** A test harness installed four helper functions, one of which wrote directly to the auth
table. Once that harness started being installed on deployed-but-disposable environments, the
obvious move was to revoke access to the whole helper schema from the untrusted roles. That would
have broken every authorization suite in the project. The suites deliberately *become* the
untrusted role and then call a helper to switch back — so the role-switching helpers must remain
callable by exactly the roles the revoke was aimed at. Only the writing helper is called while
still privileged, and only it can be locked down. The correct hardening was one function, not the
schema, and the difference was visible only by reading the call ordering in the suites.

**Suggested improvement:** In `rls-reviewer`, add a check for privilege-tightening changes: before
revoking on a schema or a group of objects, enumerate the callers and the *role each caller holds at
the moment of the call*. Test and support code routinely runs as the low-privilege role on purpose,
so it is the most likely thing a broad revoke breaks — and the breakage lands on the tests, which is
the worst place for it, because a suite that cannot run looks like a suite that has nothing to say.

**Principle:** A revoke is only as good as the caller inventory behind it. Tightening privileges is a
change to an interface, and the callers to check are not the ones the object was written for but the
ones that reach it while deliberately holding reduced privilege.

### Observation 25: Configuration that mirrors an external system drifts silently, because only the external system knows the truth

**Status:** OPEN
**Date:** 2026-08-01
**Session context:** Preparing ephemeral database branches; comparing local stack configuration
against the deployed project.
**Skill:** New skill candidate: environment-contract-check
**Type:** open-source
**Phase/Area:** Local/deployed parity

**Issue:** The local stack pinned a major version of the database engine two releases behind what
the deployed project actually ran. Every migration in the repository had therefore been authored and
tested against one engine and was destined to be applied to another. Nothing reported this: the
local stack starts happily on the pinned version, the deployed project runs whatever it runs, and no
check compares them because the authoritative value lives outside the repository. It surfaced only
because an unrelated task queried the provider's API for something else and the two numbers happened
to be visible side by side.

**Suggested improvement:** Extend the environment-contract idea beyond credentials to *versions*:
any value in local configuration that names a version, region or tier of a hosted dependency is a
mirror of a remote fact and should be verified against the remote, not read for plausibility. Where
the provider has an API, the check is one request and belongs in the gate.

**Principle:** A configuration value that duplicates a fact owned by an external system is stale by
default — it can only be confirmed by asking that system. Treat every such value as a cached copy
with no invalidation, and check it on a schedule rather than trusting the copy.

### Observation 26: Documenting an external system's behaviour from its documentation produces a confident claim with no evidence behind it

**Status:** OPEN
**Date:** 2026-08-02
**Session context:** Preparing ephemeral database branches, then measuring the first branch that
actually existed.
**Skill:** verification-before-completion
**Type:** open-source
**Phase/Area:** Writing documentation ahead of the thing it documents

**Issue:** A change was prepared for a hosted feature that could not be exercised yet — the feature
was configured but never firing. The accompanying documentation stated what the platform would do,
in the platform's own terms, and a safety measure was added on the strength of it. When an instance
finally existed and was queried directly, half the claim was false: one of the two documented steps
had not happened, and the safety measure had therefore never executed. The claim had been repeated
across three files by then, each repetition making it look better established. Nothing had made the
uncertainty visible, because the sentence describing a vendor's documented behaviour and the
sentence describing an observed behaviour are written identically.

**Suggested improvement:** In `verification-before-completion`, distinguish *documented* from
*observed* when writing about an external system, and make the distinction survive into the
artefact — a dated measurement line, or an explicit "documented, not yet observed here" marker.
The failure is not believing the vendor; it is that the reader cannot tell which kind of statement
they are reading, so nobody knows which claims still need checking once the system is live.

**Principle:** A vendor's documentation describes the general case; your configuration is a specific
case, and only the running system knows which one you got. Write down which claims are measured and
when, so the unmeasured ones stay visibly unmeasured instead of aging into apparent fact.

### Observation 27: An artefact created with the right name can be the wrong thing, and the name suppresses the check

**Status:** OPEN
**Date:** 2026-08-02
**Session context:** Confirming that a requested piece of infrastructure had been created.
**Skill:** verification-before-completion
**Type:** open-source
**Phase/Area:** Confirming someone else's completed action

**Issue:** A user reported creating the agreed resource, and one had indeed appeared with the
expected name and a healthy status. Two attributes settled it as a different kind of object than the
one designed: it was not linked to the source-control branch that would create and destroy it, and
it was flagged short-lived while having nothing to be torn down with — so it carried the running
cost of a permanent resource and the lifetime guarantee of a temporary one. The surrounding
integration it was meant to activate was untouched and still inert. Confirming "it exists and is
healthy" would have been true and would have missed all of it.

**Suggested improvement:** When confirming that a requested resource exists, check the attributes
that define its *kind* and its *lifecycle*, not just its presence and health. Specifically: what
creates it, what destroys it, and what it costs while it exists. A resource matching the requested
name is the beginning of the check, not the end of it.

**Principle:** Existence, health and name are the cheapest properties to satisfy and the least
informative. The properties that determine whether a thing does its job are the ones describing how
it is created, how it ends, and what it costs in between.

### Observation 28: The failing system often states its own reason in a field nobody reads

**Status:** OPEN
**Date:** 2026-08-02
**Session context:** Diagnosing why an automated check had been reporting `skipped` across four
consecutive pull requests.
**Skill:** systematic-debugging
**Type:** open-source
**Phase/Area:** Reading the evidence already present before forming a hypothesis

**Issue:** An external service posted a status check that came back `skipped` on every pull request.
The status was read — the name, the conclusion, the link it pointed at — and two rounds of
hypotheses were built on those three fields and written into documentation as likely causes. Both
were wrong. The check object also carried a human-readable summary field, never fetched, containing
one sentence naming the exact disabled setting and where to re-enable it. The default listing of
checks does not display it; one additional request for the full object does. So four pull requests'
worth of "why is this skipping" had a published answer the entire time, and the cost of reading it
was one request.

**Suggested improvement:** In `systematic-debugging`, add an explicit step before hypothesis
formation: fetch the *full* record of the failing object, not the summary view the listing gave you.
Listings are designed for scanning many items and omit exactly the free-text fields — summary,
message, detail, annotations — where a service explains itself. The rule of thumb: if a status has a
human-readable field you have not read, you are not yet debugging, you are guessing.

**Principle:** Prefer the failing system's own account of the failure over any inference from its
observable behaviour. Machine-readable status tells you *that* something did not happen; the
free-text field next to it usually tells you *why*, and it is almost always one request away.

### Observation 29: Reading a resource can disclose its secrets, so the read is part of the blast radius

**Status:** OPEN
**Date:** 2026-08-02
**Session context:** Inspecting a newly created database branch to confirm it had been built
correctly.
**Skill:** verification-before-completion
**Type:** open-source
**Phase/Area:** Inspecting infrastructure that holds credentials

**Issue:** Confirming a resource was healthy meant fetching its detail record. That record embedded
the database password and the token-signing secret in plaintext, so a read-only verification step
copied live credentials into a durable transcript. Nothing warned that it would: the endpoint's
purpose is describing the resource, and the credentials arrive as ordinary fields alongside host and
port. A narrower endpoint answered the same question without them. The exposure was recoverable only
because the resource was disposable and could be destroyed.

**Suggested improvement:** Add a rule for inspection steps: before fetching a detail record from an
infrastructure API, consider whether the response is likely to embed credentials, and prefer the
narrowest endpoint that answers the question. Where a broad endpoint must be used, extract only the
needed fields rather than rendering the whole response. Treat an accidental disclosure as
requiring the same rotate-or-destroy response as any other leak, and say so — a read that was
technically authorised is still a disclosure.

**Principle:** Verification is not automatically side-effect-free. A read that returns secrets has
published them; the question is not whether the call was permitted but where the response now lives
and who can reach it.

### Observation 30: A local emulator that accepts what the real service rejects turns local testing into a source of false confidence

**Status:** OPEN
**Date:** 2026-08-02
**Session context:** The first ephemeral environment ever built for this project failed immediately
on a configuration file that had passed every local run.
**Skill:** test-driven-development
**Type:** open-source
**Phase/Area:** The limits of local verification

**Issue:** A configuration value had been written in a format the vendor's hosted API rejects
outright. The local emulator of that same service accepted it silently, so the error survived
authoring, code review, a full verification gate and three merged changes. The first deployed
environment to read the identical file failed on it within seconds. The failure was not subtle or
probabilistic — it was a flat 400 with a message naming the exact field and the exact rule — and it
was undetectable locally by construction, because the component that would have complained was the
one being emulated.

**Suggested improvement:** Add to `test-driven-development` a note on the boundary of local testing:
a local emulator verifies your code against *its* implementation of a service, not against the
service. Configuration and schema that the hosted product validates on ingest are the highest-risk
category, because the emulator is usually more permissive than the product. The remedy is not more
local tests; it is one cheap disposable instance of the real thing in the pipeline. Where that
exists, treat the first run of it as a review step in its own right.

**Principle:** An emulator's silence is evidence about the emulator. Anything the real service
validates and the emulator does not is invisible to every local test you will ever write, and no
amount of local rigour converts into confidence about it.

### Observation 31: When an experiment finally becomes possible, run it and record the result in the artefact that carried the guess

**Status:** OPEN
**Date:** 2026-08-02
**Session context:** A hypothesis written into three files became testable the moment the first
working ephemeral environment appeared.
**Skill:** verification-before-completion
**Type:** open-source
**Phase/Area:** Closing out explicitly-unverified claims

**Issue:** Work had shipped with two claims explicitly marked unverified — a behaviour assumed from
vendor documentation, and a safety statement that had never executed anywhere. Both were labelled
honestly, which was necessary but not sufficient: a labelled uncertainty still ages into apparent
fact once the label scrolls out of view. When the environment that could settle both finally
existed, deliberately holding it open long enough to measure — rather than merging on green — turned
both into observations, and revealed that the scoping decision behind the safety statement was
correct in a way that could not have been argued from the code alone.

**Suggested improvement:** In `verification-before-completion`, pair the practice of labelling
unverified claims with a closing step: keep a short list of what is outstanding, and when the
blocking condition clears, measure and write the result back into the same files that carried the
guess. Where the verification window is transient — an ephemeral environment, a live incident, a
one-off migration — protect it deliberately rather than letting the default workflow close it.

**Principle:** Marking a claim unverified is a debt, not a discharge. The debt is paid by measuring
and amending the original artefact, and the opportunity to do it is often a narrow window that the
normal workflow will destroy by default.

### Observation 32: A build-time constant lookup that defaults to empty turns a name mismatch into a shipped artefact

**Status:** OPEN
**Date:** 2026-08-02
**Session context:** Following up a user's remark that a credential already existed under a
different name than the code expected.
**Skill:** verification-before-completion
**Type:** open-source
**Phase/Area:** Values injected at build time

**Issue:** A compiled client read a credential from a build-time constant keyed by name. The runbook
that documented the build passed one name; the source read another. The language's constant lookup
returns an empty string for a name nobody supplied rather than failing, so the documented build
produced a binary containing an empty credential — no warning at build, no warning at start, and a
confusing authentication error much later. The variable in source was even *named* after the value
the runbook passed, so the two files read as agreeing while disagreeing on the only string that
mattered. Static analysis cannot catch it: both sides are individually valid, and the contract
between them exists only in prose.

**Suggested improvement:** Treat any build-time injected value as an untyped contract between the
build command and the source, and close it explicitly — assert non-empty at startup so a mismatch
fails immediately and names the flag to pass, rather than degrading into a runtime symptom. Where a
runbook documents the build command, the names in it are part of the source contract and should be
checked against the code whenever either changes. This is the same failure as an unset shell
variable expanding to empty, one step worse: the empty value is baked into an artefact that can ship.

**Principle:** Any lookup that answers "empty" instead of "no such thing" converts a naming mistake
into valid-looking data. Wherever such a lookup feeds something essential, add the check that turns
absence back into an error — the language will not.

### Observation 33: Triage an automated security finding by attempting the exploit, not by reading the rule that fired

**Status:** OPEN
**Date:** 2026-08-02
**Session context:** Running a hosted platform's security linter against a live project.
**Skill:** rls-reviewer
**Type:** open-source
**Phase/Area:** Triaging automated findings

**Issue:** A platform security linter returned three findings. Two named a privileged function as
callable by anonymous and signed-in users over the public API, quoting the exact URL. Both were
false: the function's return type makes direct invocation impossible, and a single request against
that URL returned an error rather than executing anything. The function also only *tightened*
security — it was the platform's own safety net for enabling row-level security on new tables — so
even a successful call had no adverse effect. The remaining finding was real, and confirming it
took one request that returned success where failure was expected. Reporting all three at face
value would have buried the one that mattered under two that did not, and reporting them as
dismissed without testing would have been a guess in the other direction.

**Suggested improvement:** Add a triage step to `rls-reviewer` for machine-generated findings: for
each one, construct the smallest request that would demonstrate the claimed access, run it, and
record the response alongside the finding. Static linters reason about grants and signatures; they
do not attempt the call, so they cannot distinguish "granted" from "reachable" from "harmful". Three
questions separate them — can it be invoked, does invoking it do anything, and does what it does
help an attacker.

**Principle:** A linter reports that a rule matched, not that a vulnerability exists. Confirmation
and dismissal both require attempting the thing described; whichever way the evidence falls, the
finding should carry the response that settled it.

### Observation 34: A privilege check that reads the grant but not the path to it reports access that does not exist

**Status:** OPEN
**Date:** 2026-08-02
**Session context:** Verifying that a deliberately narrow permission change had taken effect, then
discovering the verification itself was incomplete.
**Skill:** rls-reviewer
**Type:** open-source
**Phase/Area:** Verifying privilege changes

**Issue:** A change revoked one function's permissions while leaving three sibling functions
callable. Verification queried the per-function execute privilege, got exactly the intended pattern
— one denied, three granted — and the result was reported as confirmation. It was not: reaching a
function also requires usage on its containing namespace, and a freshly created namespace grants
that to nobody. Every one of the three "granted" functions raised permission denied on the first
real call. The per-object privilege was necessary and not sufficient, and the check that looked
most like proof examined only the half that was already true.

**Suggested improvement:** In `rls-reviewer`, require that a privilege claim be verified by
performing the operation as the role in question, not by querying the privilege catalogue. Access in
Postgres is a conjunction — schema usage, object privilege, row policy, and column grants must all
hold — and a catalogue query answers about one conjunct. Where an actual call is impractical, at
minimum enumerate the conjuncts and check each; a single `has_*_privilege` result is not an answer.

**Principle:** Permission is a path, not a property. Confirming one link and reporting the path as
open is the same error whichever link you happened to check — and it is most dangerous when the link
you checked returns exactly the answer you expected.

### Observation 35: When the tests cannot run, re-express their intent rather than editing them to pass

**Status:** OPEN
**Date:** 2026-08-02
**Session context:** The project's authorization suites turned out to be unrunnable for two
independent environmental reasons, in the middle of a request to run them.
**Skill:** test-driven-development
**Type:** open-source
**Phase/Area:** Blocked test suites

**Issue:** Suites written to prove that a non-owner is refused could not execute: the roles they
switch into lacked namespace access to the helpers, and could not read the identity table the suites
use to resolve fixtures. Both were fixable in ways that would have made the suites run — one by
granting a role read access to the identity table. That fix would have loosened the very database
the suites exist to check, producing green tests that proved less than nothing. The alternative
taken was to re-express the suites' intent as independent probes, executed as the same real roles,
leaving the suites untouched and the blocker documented with the pattern that would resolve it
properly.

**Suggested improvement:** Add to `test-driven-development` a rule for the blocked-suite case: when a
test cannot run, enumerate the candidate unblocking changes and reject any that alter the behaviour
under test. Loosening a permission, relaxing a constraint, or stubbing the boundary being verified
converts an unrunnable test into a misleading one, which is strictly worse. Prefer changing how the
test obtains its fixtures over changing what the system allows — and where the right fix is larger
than the current task, verify the behaviour by another route and record the blocker rather than
reaching for the change that makes red go away.

**Principle:** An unrunnable test is honest; a test made runnable by weakening its subject is not.
When those are the two options on offer, the correct move is a third one — verify the behaviour
independently and leave the blocker visible.

### Observation 36: Mutation-test a green suite, because passing does not establish that it could fail

**Status:** OPEN
**Date:** 2026-08-02
**Session context:** Repairing authorization suites that had never executed, then deciding whether
to trust them once they went green.
**Skill:** test-driven-development
**Type:** open-source
**Phase/Area:** Establishing that a passing test is load-bearing

**Issue:** A set of authorization suites was repaired until every assertion passed. Passing was not
evidence of much: these suites had never run, so no assertion had been observed distinguishing a
protected system from an unprotected one. Deliberately reintroducing the vulnerability each
assertion described settled it. Most turned red, which is what made the greens meaningful. One did
not: the assertion carrying a comment identifying it as *the critical one* stayed green with its
protection removed, because a second, unrelated rule happened to refuse the same operation. The
protection it advertised was redundant today and would become load-bearing under a planned change,
at which point the test guarding it would have gone on passing regardless.

**Suggested improvement:** Extend `test-driven-development` beyond red-before-green for new tests to
a mutation step for any suite that has never been observed failing — including inherited or repaired
suites, where the original red was never seen. For each assertion, remove the specific protection it
names and confirm that assertion turns red. Assertions that stay green are not necessarily wrong,
but they do not test what their name claims, and the discrepancy belongs next to them in a comment.

**Principle:** A test earns trust by discriminating, not by passing. Until you have seen an
assertion fail for the reason it exists, you know it runs — not that it guards anything.

### Observation 37: Validate the artefact you are shipping, not the equivalent one you developed with

**Status:** OPEN
**Date:** 2026-08-02
**Session context:** Promoting a working scratch script into a committed one used by continuous
integration.
**Skill:** verification-before-completion
**Type:** open-source
**Phase/Area:** Promoting prototypes to production

**Issue:** A helper was developed and proven against a live system, then rewritten into the
repository for automation to run. The rewrite was faithful in logic but changed one incidental
detail: the prototype shelled out to a common HTTP client, the committed version used the language's
standard library. The remote service's firewall rejects the standard library's default user agent
with a status that reads like an authentication failure. Every call failed. Nothing in the logic
differed, the prototype's evidence was real, and it transferred nothing — the difference lived
entirely in a default neither version stated. Running the committed file once caught it in seconds.

**Suggested improvement:** Add to `verification-before-completion` a promotion rule: evidence
attaches to the exact artefact that produced it, so a rewrite invalidates it. Before shipping a
reimplementation of something already proven, execute the shipped file itself against the same
target. Pay particular attention to details neither version names — default headers, timeouts,
encodings, working directory — because those are precisely what a faithful logical port silently
changes.

**Principle:** Proof does not survive a rewrite. When the thing you validated and the thing you ship
are two different files, only one of them has been tested, and it is not the one that matters.

### Observation 38: Enabling a platform feature can silently take over a responsibility your own pipeline still claims

**Status:** OPEN
**Date:** 2026-08-02
**Session context:** Investigating a failing deployment step after a merge, and finding the work had
been done anyway.
**Skill:** verification-before-completion
**Type:** open-source
**Phase/Area:** Adopting a managed platform feature

**Issue:** A hosted feature was switched on for one benefit — disposable environments per change
request. It also quietly assumed a second responsibility: applying schema changes to production on
merge. The existing pipeline still contained a step doing the same thing. Nobody chose to have two,
and for a while nobody could tell, because the pipeline's step had never run — it was gated on
credentials that were absent. When those credentials were finally supplied the step ran, failed on
an unrelated defect, and production received the change regardless. That failure is the only reason
the duplication surfaced; had the step succeeded, two systems would have been writing the same
schema with neither aware of the other, and the symptom would have been an occasional migration
applied twice or skipped.

**Suggested improvement:** When enabling a managed feature, enumerate what it now does *beyond* the
reason it was enabled, and check each against what the existing pipeline already does. Overlaps are
not additive — for anything with a single authoritative state, such as a schema or a deployment
target, two writers is worse than either alone. Resolve to exactly one owner and record which, since
the redundant one will otherwise look like prudent belt-and-braces to whoever next reads it.

**Principle:** A platform feature is adopted for one capability and arrives with several. The ones
nobody asked for are the dangerous ones, because nothing in the change request names them and no
review covers them — they are discovered by their side effects, usually later than you would like.

### Observation 39: A "watch the test fail first" rule needs a stated fallback when the environment cannot run the test

**Status:** OPEN
**Date:** 2026-08-02
**Session context:** Readiness assessment for E2 (Meal Publishing) before implementation starts
**Skill:** ship-check (and the Kafoo build-a-feature sequence in CLAUDE.md steps 5–6)
**Type:** open-source
**Phase/Area:** Authorization-test ordering / red-then-green verification

**Issue:** The workflow mandates writing an authorization test, running it, and confirming it FAILS
before the policy exists. The task list encodes this as local commands (`supabase test db`, then
`supabase db reset && supabase test db`). The session container has the Supabase CLI but no Docker
daemon, so neither command can run locally. The rule is unsatisfiable as written, and the two
failure modes are both bad: silently skip the red step and claim the ordering was honoured, or
stall. Neither is what the rule intends. A workable third path exists — push the tests alone,
watch the CI authorization job go red against a disposable preview database, then push the policy
and watch it go green — but it is not written down anywhere, and it changes commit sequencing
(two pushes on the PR, not one squashed commit).

**Suggested improvement:** In the ordering rule, state the environment it assumes and name the
remote fallback explicitly: if the local database cannot run, the red observation is made on the
pull request by pushing the failing tests in their own commit before the migration. Add the
sequencing consequence, because it contradicts the usual "one logical change per commit" habit.

**Principle:** A verification rule that names specific local commands silently assumes an
environment. When it can be satisfied remotely instead, write the fallback into the rule — an
unsatisfiable rule is not obeyed, it is skipped, and the skip is invisible in the artefact.

### Observation 40: A rule enforced at two layers needs one assertion per layer, or neither can be mutation-tested

**Status:** OPEN
**Date:** 2026-08-02
**Session context:** Writing the E2 authorization suites for the `meals` table
**Skill:** ship-check (definition-of-done / RLS verification), and the RLS review checklist
**Type:** open-source
**Phase/Area:** Authorization test design, mutation testing

**Issue:** The design deliberately enforced one invariant ("a row cannot change owner") twice — in
a row-level security policy and in a database trigger — with the rationale that policies defend
against a hostile client and constraints defend against the project's own code. Both layers are
correct. But the combination made either layer individually untestable: the trigger runs before
the policy is evaluated, so it answers first, and the single test asserting "the reassign is
refused" stays green when the policy is deliberately broken. The previous feature hit the same
shape from the other direction and left a written warning that its test did not detect what its
name claimed. Defence in depth silently converts into a test that cannot fail for the reason it
says it can.

**Suggested improvement:** Where a rule is deliberately enforced at more than one layer, require
an assertion per layer, each distinguished by the *mechanism* that answers (distinct error codes,
or temporarily disabling one layer inside the test transaction to isolate the other). Name the
mutation target explicitly in a comment on the isolating assertion — "break X and THIS assertion
must go red" — so a later reader can verify the suite rather than trusting it. Add a review
question: for each new invariant, how many layers enforce it, and is there an assertion that fails
when each one alone is removed?

**Principle:** Redundant enforcement is good for safety and bad for evidence. Layers mask each
other in a fixed order, so a single "the bad thing is refused" assertion measures only the
outermost layer and silently stops measuring the rest. Coverage must be counted per enforcement
layer, not per rule — and the mutation that should redden each assertion belongs in a comment next
to it, because a suite that has only ever been green looks identical to one that cannot fail.

### Observation 41: Quantify a deferred cost decision before deferring it to a human

**Status:** OPEN
**Date:** 2026-08-02
**Session context:** Pricing model providers for E2's blocked-on-a-decision task
**Skill:** ship-check / the stop-and-ask trigger list in the project instructions
**Type:** open-source
**Phase/Area:** Stop-and-ask triggers, decision deferral

**Issue:** A planning document correctly identified a choice as recurring spend and therefore a
human decision, and deferred it as a hard blocker on a whole phase of work. When the options were
actually priced, the spend turned out to be roughly half a cent per unit of activity — about a
dollar a month at the project's real scale. The category was right and the magnitude was never
checked, so a non-decision was escalated as a blocker, and the actual differentiators (output
quality in a specific dialect, and which vendor receives user photographs) were left unstated
underneath it. The decision-maker would have been asked to weigh a cost that does not matter while
the things that do matter went unnamed.

**Suggested improvement:** When a stop-and-ask trigger fires on cost, require an order-of-magnitude
estimate in the same breath as the escalation — even a rough one. If the number turns out to be
immaterial at the project's scale, say so and re-frame the question around whatever actually
differentiates the options. Escalate the real decision, not the category it fell into.

**Principle:** A trigger identifies a *kind* of decision, not its *weight*. Escalating on category
alone spends the decision-maker's attention on the label rather than the substance — and worse, it
can hide the real trade-off underneath a cost framing that turns out to be noise. Quantify before
escalating; the estimate is usually cheap and it decides whether the question is even worth asking.

### Observation 42: A gate that enumerates tracked files silently ignores uncommitted work — and still answers

**Status:** OPEN
**Date:** 2026-08-02
**Session context:** Adding an Edge Function unit-test step to the project's verification gate
**Skill:** verification-before-completion, and ship-check
**Type:** open-source
**Phase/Area:** Verification tooling, pre-commit gates

**Issue:** The project's gate script discovers what to check with the version-control tool's
"list tracked files" command, which every existing check used and which I copied. Ten new unit
tests were sitting on disk, unstaged. The gate printed "no unit tests yet — skipping" and then
"ok", and the overall result was a pass. Nothing was wrong and nothing was verified. The failure
is not that the check was skipped — it is that the gate *answered*, in the affirmative, about work
it had not looked at. Had I trusted it, I would have committed ten tests that had never run inside
the gate, and reported the gate as green with a straight face.

Noticed only because the count looked wrong. A skip line is easy to read past when nine other
lines say ok.

**Suggested improvement:** In verification guidance, add a specific check: after adding a step to
a gate, confirm it actually examined the new files rather than skipping them — the skip path and
the pass path print differently, and the difference must be read. More generally, prefer
filesystem discovery over version-control discovery for anything meant to validate work in
progress, and reserve tracked-file enumeration for checks about the repository's committed state
(such as scanning for committed credentials, where "untracked" genuinely means "not a problem").

**Principle:** A verification step that cannot find its subject should be loud, not silent. Any
gate whose discovery mechanism can return an empty set needs to distinguish "checked, found
nothing wrong" from "found nothing to check" — and the second must never be reported as success.
Skip-on-empty is the default shape of these scripts and it converts a missing check into a green
tick.

### Observation 43: Configuration read from documentation is a guess until one real call is made

**Status:** OPEN
**Date:** 2026-08-02
**Skill:** verification-before-completion
**Type:** open-source
**Phase/Area:** Integrating a third-party API

**Issue:** Built an integration against a third-party API and populated its configuration —
identifiers, defaults, tier mappings — from the provider's published documentation and pricing
pages. Unit tests passed, type checks passed, the whole gate was green. The first real call failed
immediately: the primary identifier was rejected as "no longer available to new users". Two more
followed. A second identifier returned malformed output despite the request constraining the
format; a third was correct but roughly ten times slower than needed, because it silently spent
most of its latency on internal reasoning for a task that did not need any. All three were
invisible to every check that did not actually call the service. The provider's own "list what
exists" endpoint still advertised the rejected identifier, so even querying the service
programmatically would not have caught it — only a real request did.

**Suggested improvement:** When integrating any external service, require one real call before the
work is considered done, and record the measured result next to the configuration it justifies.
Treat "the docs say X" as a hypothesis and the call as the test. Where a value has a performance
budget attached, measure it rather than assuming the documented tier meets it — and prefer the
cheapest, least capable option that passes, since heavier ones often add latency without adding
correctness on extraction-shaped work.

**Principle:** Documentation describes the service the provider intends to offer; a call describes
the one your credential can actually reach. The gap between them is invisible to type checks, unit
tests and even the provider's own discovery endpoints, and it is systematically in the direction of
"this looked fine and does not work". One real call is the cheapest test available and the only one
that closes that gap — make it before claiming an integration works, and write the number down so
the next person inherits evidence instead of a citation.
