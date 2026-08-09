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

### Observation 53: An eval that scores a different layer than production reports failures nobody can hit

**Status:** OPEN
**Date:** 2026-08-03
**Session context:** T086 — replaying the meal-analysis golden corpus against a live model
**Skill:** New skill candidate: evaluating-prompts-against-live-models
**Type:** open-source
**Phase/Area:** Scoring design

**Issue:** The first version of the replay harness scored the model's raw JSON reply. Three of eight
fixtures "failed". None of the three was a real defect. Two were the harness demanding exact array
membership where the model had been more specific than the fixture author (fixture said "meat", model
said "minced meat"). The third was the model filling two enum fields on garbage input — which the
production parser already drops, because it discards any field whose explanation is blank. Scoring the
raw reply both invented failures and hid the fact that a defence was working.

**Suggested improvement:** An eval must score the value at the same layer the user receives it. Where a
parser, validator or gate sits between the model and the screen, mirror it in the harness before
comparing — and report what it dropped, because a field the model filled and the parser discarded is
the most informative thing in the run.

**Principle:** Evaluate the output at the layer the user consumes it, not the layer the vendor emits
it. Any transform between the two is part of the system under test, and skipping it produces both
false failures and false confidence in the same run.

### Observation 54: A quality detector that can only report "clean" certifies what it cannot see

**Status:** OPEN
**Date:** 2026-08-03
**Session context:** Same — checking whether a model wrote Egyptian Arabic or Modern Standard
**Skill:** New skill candidate: evaluating-prompts-against-live-models
**Type:** open-source
**Phase/Area:** Automated quality signals

**Issue:** The register check was built from the vocabulary pairs the prompt itself names. It reported
all eight fixtures clean. Reading the output by hand showed the opposite: the model had matched every
named vocabulary item and then written the surrounding sentences in the wrong register entirely. The
detector was measuring the one dimension the model happened to get right, and its green result read as
a pass on the whole question.

**Suggested improvement:** Build the detector from failure modes observed in real output, not from the
instruction being tested — an instruction's own wording is what a model pattern-matches first, so it is
the least discriminating thing to check. Where feasible, count positive evidence as well as negative,
so "no violations found" and "no evidence of compliance" cannot render identically. Always print the
raw text alongside the verdict.

**Principle:** A one-sided detector cannot distinguish absence of violations from absence of signal.
When a check can only ever say "clean", its green result is an unfalsifiable claim, and it is more
dangerous than no check because it is read as a pass.

### Observation 56: A bug in an unreachable branch needs a test at the layer where it IS reachable

**Status:** OPEN
**Date:** 2026-08-04
**Session context:** Reviewing a delegated controller against a domain rule documented in a comment
**Skill:** New skill candidate: reviewing-delegated-implementations
**Type:** open-source
**Phase/Area:** Test coverage of not-yet-wired code paths

**Issue:** A controller recorded a value for an optional step without also marking the step
resolved. The sequencing function reads only the resolved flag, so the step would have re-asked
forever — the exact trap the domain module documented in its own comment. No UI test could catch it:
the interface cannot reach that branch until a later task wires it up, so every test passed with the
bug present and would have kept passing until the feature that triggers it shipped.

**Suggested improvement:** When review finds a defect in a branch the current interface cannot
reach, do not rely on the test suite that missed it. Add a test at the layer where the branch IS
reachable — usually a direct unit test against the component rather than through the surface — and
mutation-check it by reverting the fix and confirming the test goes red. A green suite over an
unreachable branch is the strongest possible false signal, because the branch will be reached later
by someone who trusts it.

**Principle:** Code that a test cannot reach today is code that ships untested to whoever wires it up
tomorrow. Test at the layer where the path is reachable, not the layer where the feature will
eventually live, and verify the test fails without the fix.

### Observation 59: A phased task list re-lists work an earlier phase already finished

**Status:** OPEN
**Date:** 2026-08-05
**Session context:** Kafoo E2, building the Customer's public Meal view (T062-T065, T048, T071-T074)
**Skill:** speckit-tasks
**Type:** open-source
**Phase/Area:** Task generation — cross-phase deduplication

**Issue:** Three of the eight tasks assigned to this session were already complete before it started.
T064 ("confirm a signed-out person reads a published Meal") and T065 ("assert a non-owner reads zero
drafts and zero unavailable Meals") were written as Phase 8 tasks, but the authorization test suite
written in Phase 2 already carries them verbatim as cases 5, 6, 2 and 3 — the suite's own comments
even quote the task wording ("The first use of the anon role in Kafoo"). T071 (a documentation task
in the Polish phase) had likewise been landed by an earlier commit. Nothing in the task file marked
any of them done, so an agent reading only the task list would have written duplicate assertions.

**Suggested improvement:** When tasks are generated per user story, add a deduplication pass that
checks whether a later-phase verification task is already satisfied by an artefact an earlier phase
produces — particularly test suites, which are commonly written up-front under test-first rules and
therefore land phases ahead of the story they verify. Where the overlap is intentional, say so in
the task text ("already covered by X — confirm it runs green") so the reader is told to verify
rather than to build.

**Principle:** In a test-first workflow, verification tasks migrate earlier than the phase they
belong to. A task list organised by user story will therefore re-ask for work its own earlier
phases already did, and the failure mode is duplicated tests rather than missing ones — which is
invisible to any gate.

### Observation 60: An accessibility sweep passes vacuously when the fixture has nothing to measure

**Status:** OPEN
**Date:** 2026-08-05
**Session context:** Kafoo E2, adding the Customer's public Meal view to the accessibility sweep (T074)
**Skill:** accessibility-reviewer
**Type:** open-source
**Phase/Area:** Tap-target and interactive-element checks

**Issue:** The repository's accessibility suite iterates a map of screens and asserts no tap target
is under 48dp. A delegated agent added the new screen to that map using the widget's simplest
constructor, which left the screen's only interactive control — an optional callback-gated link —
unrendered. Every assertion passed. The suite reported the screen as covered while measuring an
empty set, and nothing in the output distinguished "no target is too small" from "there are no
targets".

**Suggested improvement:** Add to the reviewer's checklist: a tap-target or interactive-element
assertion must first assert that at least one such element was found. Where a screen's controls are
behind optional constructor parameters, the fixture must supply them, and the reason belongs in a
comment beside the fixture — otherwise the next person simplifying the fixture silently removes the
coverage.

**Principle:** A "nothing is wrong" assertion over a collection is vacuously true when the
collection is empty. Any such check needs a companion non-emptiness assertion, or it degrades from
a test into a report of how the fixture was built.

### Observation 61: A multi-clause requirement can be half-covered by tasks with nothing flagging the rest

**Status:** OPEN
**Date:** 2026-08-05
**Session context:** Kafoo E2, building US4/US5/US7 (Meal availability, retirement, editing)
**Skill:** speckit-tasks
**Type:** open-source
**Phase/Area:** Requirement-to-task traceability

**Issue:** One requirement in the spec carries three clauses: a Cook must be able to (a) see every
draft, (b) delete any of them, and (c) resume a draft rather than starting again. Clauses (a) and
(b) each have a task. Clause (c) has no task anywhere in the epic — a full-text search for the verb
returns nothing. Because the requirement id is cited by the two tasks that do exist, every
traceability check passes: the requirement looks covered. It was found only by reading the
requirement's own text while writing an implementation brief, not by any check.

**Suggested improvement:** When generating tasks, split a requirement containing multiple MUST
clauses into its clauses first and map each clause to a task, rather than mapping the requirement id
as a unit. Where a clause is deliberately deferred, it needs a task that says so — a deferral with
no record is indistinguishable from an omission, and the citation of the requirement id by sibling
tasks actively hides it.

**Principle:** Coverage measured at the granularity of the requirement id is coarser than the
requirement. A multi-clause requirement cited by any task reads as satisfied, so the uncovered
clauses are invisible to exactly the check meant to find them.

### Observation 63: no observations (checkpoint)

**Status:** OPEN
**Date:** 2026-08-05
**Session context:** CookMeal half-draft list fix (implementer brief)
**Skill:** task-observer
**Type:** internal
**Phase/Area:** checkpoint

**Issue:** Mandatory checkpoint after multi-step implementation. Spec was complete and
unambiguous; no skill friction, corrections, or workflow gaps.

**Suggested improvement:** none

**Principle:** A clean brief that names types, tests, and forbidden files leaves little for
task-observer to harvest — that is success, not a missed observation.

### Observation 70: A re-evaluation is not a prompt change, and the checklist conflates them

**Status:** OPEN
**Date:** 2026-08-05
**Session context:** WP-003 — recording the first live eval of an existing prompt, changing only its
`last_evaluated` field
**Skill:** ship-check
**Type:** internal
**Phase/Area:** Section 4, "AI changes"

**Issue:** Section 4 reads "The prompt file's `version` was bumped **and** `last_evaluated`
updated" as a single conjoined item. The task was purely to measure an unchanged prompt, so only
`last_evaluated` legitimately moved. Read literally the checklist demands a version bump, which
would falsely signal to every later reader that the prompt's words changed — the opposite of what
the version field is for. The item cannot be honestly ticked or honestly failed.

**Suggested improvement:** Split the item in two: (a) if the prompt's text changed semantically,
`version` was bumped; (b) `last_evaluated` reflects the most recent eval, whether or not the text
changed. Note explicitly that a re-evaluation of unchanged text updates only the date.

**Principle:** A checklist item that conjoins two independently-true conditions with "and" cannot be
answered for the case where one applies and the other does not — and the failure mode is not a
blocked check but a reviewer performing the unnecessary half to make the line tick.
### Observation 71: A test stand-in that supplies what production lacks hides the gap it exists to catch

**Status:** OPEN
**Date:** 2026-08-05
**Session context:** WP-002 — measuring E2's two performance timings against the live Supabase project
**Skill:** New skill candidate: verifying-a-stand-in
**Type:** open-source
**Phase/Area:** Test harness design; the boundary between a local substitute and the real system

**Issue:** The local database harness bootstrapped its own environment with a blanket
`ALTER DEFAULT PRIVILEGES ... GRANT ALL ON TABLES`, justified by a comment asserting the hosted
platform grants those privileges by default. It does not, on this project. So the harness was
supplying a layer production did not have. Every authorization suite was green while the deployed
database refused every read and write from every application role with `42501 permission denied` —
the product was unusable in production and nothing in the test suite could say so. It was found only
by making a real call against the real deployment for an unrelated reason (a latency measurement),
not by any check that existed.

**Suggested improvement:** A harness that stands in for a real system should carry, per stand-in, a
recorded answer to "what evidence says the real system behaves this way, and when was it checked?"
A stand-in justified by an assumption rather than an observation is a defect generator: it can only
ever make the suite greener than reality. Two concrete practices: (1) every stand-in line names its
evidence and its date, and (2) at least one probe runs against the real system periodically, because
a stand-in cannot audit itself by construction.

**Principle:** A test double can only fail in one direction — toward false confidence. Anything a
double supplies that the real system does not is invisible to every test that uses it, so the
correctness of a double is never testable from inside the suite it serves. It must be established
by observing the real system, and that observation has a date on it.

### Observation 72: A latency measurement must gate on success, or failure reads as speed

**Status:** OPEN
**Date:** 2026-08-05
**Session context:** WP-002 — measuring publish and first-estimate latency against a real backend
**Skill:** New skill candidate: measuring-against-a-budget
**Type:** open-source
**Phase/Area:** Performance measurement harnesses; verdict computation

**Issue:** A harness timed a request, averaged the elapsed times, and compared the median to a
budget. Twelve consecutive runs failed with HTTP 502 — the service could not reach its provider at
all — and the report printed **"Verdict: PASS"**, because a request that fails fast is fast. The
failure was invisible in the summary: the per-run table carried the status code, but the headline
number, the median and the verdict were all computed over runs that returned nothing. The metric
improved monotonically as the feature became more broken.

**Suggested improvement:** A latency verdict must be computed only over runs that produced the
result being timed, and the count of successes must appear beside the number. Where zero runs
succeeded, print no number at all rather than a number from an empty or failed sample. Failures
should be summarised by status and cause next to the missing figure, since they are the finding.
Two related traps in the same harness: a cleanup check that read through a role holding no SELECT
treated its own failed request as "nothing left" and reported success; and a summary that inherited
its run count from the *requested* number of runs rather than the number actually completed.

**Principle:** Any metric where failure is cheap will be improved by failure. Latency, throughput
and cost all have this shape — the degenerate path is the fast path — so the success predicate is
part of the measurement, not a separate quality check applied afterwards. The same rule covers
verification steps: a check that cannot distinguish "I looked and found nothing" from "I could not
look" will report the reassuring one.

### Observation 80: A generated report that rewrites a whole document deletes the parts a partial run did not measure

**Status:** OPEN
**Date:** 2026-08-06
**Session context:** WP-010. Splitting a three-phase measurement script so one phase could be made unreachable, then running only two of the three.
**Skill:** New skill candidate: generated-report-integrity
**Type:** open-source
**Phase/Area:** Reporting from partial runs

**Issue:** The script regenerated its whole report file from the runs of the current invocation. Once
one phase was deliberately skipped, that phase's section printed "NOT MEASURED in this run" and the
rewrite deleted a real twelve-run measurement that had been taken earlier and was still valid. The
wording was true of the run and false of the project, and the deletion was silent — the document
would simply have stopped containing a number it once contained. The same coupling had already
claimed a hand-written analysis section, which no longer existed after the first regeneration.

Two distinct defects share one root: a full-file generator makes every unmeasured section an
active deletion, and it makes any hand-added prose survive exactly until the next run.

**Suggested improvement:** Where a generator owns a whole document, a skipped section must carry the
prior measurement forward with its provenance and date attached, rather than printing an
absence — and prose the document needs permanently has to be generated too, not appended by hand.
Distinguish "not measured in this run" from "not measured ever" explicitly; they read the same and
mean opposite things.

**Principle:** A generator that owns an entire document turns every gap in the current run into a
deletion of the record. Partial-run reporting must therefore carry provenance, not just results:
"measured elsewhere, on this date" is a fact worth keeping, and "not measured now" is not the same
claim as "unknown".

### Observation 81: Generated prose branched on a verdict, and the untested branch shipped wrong

**Status:** OPEN
**Date:** 2026-08-06
**Session context:** WP-010. The first time a measured latency exceeded its budget.
**Skill:** New skill candidate: generated-report-integrity
**Type:** open-source
**Phase/Area:** Verdict-dependent prose in generated output

**Issue:** A report line read "a median inside the budget does not mean every Cook is inside it, and
N of these would have waited longer" whenever any run exceeded the budget. It had only ever run when
the median passed. The first measurement that failed printed that sentence directly underneath a
verdict stating the median was over — the qualifier contradicted the row above it. Nothing was wrong
with the number; the explanation attached to it asserted the opposite of the finding, in the one
report anybody would read closely.

**Suggested improvement:** Treat conditional prose in a generated report as code with untested
branches. Any sentence whose correctness depends on a computed verdict needs its other branch
exercised before the output is trusted — a fixture with a failing value is enough, and cheaper than
discovering it in front of a reader who is deciding something.

**Principle:** Prose generated under one branch of a condition is untested code until the other
branch runs. The failure mode is not a crash but a confident sentence asserting the opposite of the
data beside it, which is worse than a blank.

### Observation 82: A recommendation inherited its scope from the repo instead of asking the user

**Status:** OPEN
**Date:** 2026-08-06
**Session context:** Starting a new epic. The agent read the project's decision records and handoff
document, inferred the scope of an upcoming surface from them, and recommended the cheapest
technology that satisfied that inferred scope. The user then produced an outside opinion which
disagreed — correctly — on the grounds that the user's actual intent was substantially larger than
what the documents implied.
**Skill:** brainstorming
**Type:** open-source
**Phase/Area:** "Proposing approaches" / "Ask clarifying questions"

**Issue:** The agent's clarifying questions established *which* surface was in scope but never
established *how much application* the user intended to build on it. The decision record described
a narrow justification (a shareable link with a preview), so the agent optimised for that
justification and recommended a minimal server-rendered option. The user's real plan was a full
second client application. The recommendation was not wrong for the scope the agent assumed; it was
wrong because the assumption was never surfaced, so the user had no way to see it and correct it.
An outside reviewer caught it in one reading, precisely because they were working from the user's
stated intent rather than from the project's documents.

**Suggested improvement:** In the "Proposing approaches" step, require that every recommendation
state the scope assumption it is optimised for, in one clause, adjacent to the recommendation
itself — "cheapest thing that satisfies X" rather than just "cheapest thing". Where the assumption
came from a document rather than from the user, say so. A recommendation whose scope premise is
invisible cannot be disagreed with on its premise; the user can only disagree with the conclusion,
which is the harder and rarer thing to do.

**Principle:** Project documents record the scope that *was* decided, not the scope the user now
intends. When a recommendation is scoped by documents rather than by something the user said in
this conversation, the scope assumption is the load-bearing part of the recommendation and must be
stated out loud alongside it. Otherwise the user reviews the answer without ever seeing the question
it answered.

### Observation 83: An error naming a resource state actually described a rate

**Status:** OPEN
**Date:** 2026-08-06
**Session context:** Measuring a third-party model's quality before committing a design to it. Part
way through a sweep of candidate configurations, the service began returning an error whose text
read "You exceeded your current quota, please check your plan and billing details."
**Skill:** systematic-debugging
**Type:** open-source
**Phase/Area:** Interpreting an error before acting on it

**Issue:** The message describes an exhausted allowance and points at billing. The actual condition
was a per-minute rate limit, and the sweep was issuing requests faster than the window allowed.
Taken literally, the message would have ended the measurement and retired a usable candidate on the
grounds that the account had run out — a conclusion in the direction that closes doors, drawn from a
message that was not lying so much as describing the wrong axis. What settled it was making a
single call by hand: it succeeded immediately, which is impossible if an allowance is exhausted and
expected if the limit is a rate. The retry logic had also been written with a backoff that topped
out well short of the window it needed to cross, so it converted a recoverable condition into a
reported failure.

**Suggested improvement:** Add a rule to the debugging skill: when a third-party error describes a
resource as exhausted, unavailable, missing or forbidden, issue ONE minimal call of the same kind
before accepting it. Success proves the resource exists and the constraint is about pace, ordering
or shape rather than supply. Where the code retries, check that the backoff can outlast the window
the service actually meters on — a backoff shorter than the limit's period reports quota failures
that waiting would have cleared.

**Principle:** An error message names a symptom in the vendor's vocabulary, not the condition in
yours. Before believing a negative that would end a line of work, call something you expect to
succeed. A message about supply may be a message about speed, and the two lead to opposite actions.

### Observation 84: A verdict was only auditable because the evidence was printed beside it

**Status:** OPEN
**Date:** 2026-08-06
**Session context:** A measurement script classified each configuration with a computed verdict —
whether two populations could be separated by a score. Two configurations printed the passing
verdict. Both were wrong.

**Skill:** verification-before-completion
**Type:** open-source
**Phase/Area:** How a check reports its result

**Issue:** The verdict was computed correctly from its inputs and was still meaningless: the
separation it certified was smaller than the noise in the measurement, derived from a single
example. Nothing about the word "separable" carries that. It was caught only because the same line
also printed the raw gap the verdict was computed from — a number small enough that the verdict
became obviously unsupportable the moment a human read it. Had the check printed only its verdict,
the design resting on it would have been built and the failure would have surfaced in front of
users, where a confident wrong answer is the specific failure the work existed to prevent.

**Suggested improvement:** Add a rule: any check that emits a categorical verdict — pass/fail,
separable/not, healthy/degraded — must emit the quantity it thresholded on, in the same line. Not in
a debug mode, not behind a flag. A verdict is a claim; the number beside it is what lets a reader
disagree. This costs one format string and is the difference between a check that can be audited and
one that can only be trusted.

**Principle:** A categorical verdict destroys the information needed to challenge it. Print the
evidence alongside the conclusion, always — otherwise the only way to discover that a check is
wrong is for the thing it was guarding to fail.

### Observation 85: Measuring before specifying invalidated a mechanism, not a parameter

**Status:** OPEN
**Date:** 2026-08-06
**Session context:** A design was approved and written up, with one assumption flagged as unmeasured
and a recommendation to measure it before building. The measurement was then run, ahead of writing
the specification.

**Skill:** brainstorming
**Type:** open-source
**Phase/Area:** "Present design" / the boundary between design and specification

**Issue:** The expectation was that measurement would tune the design — confirm a choice, settle a
size. What it actually did was remove a mechanism the design depended on: a trigger the design used
to decide when a component should act turned out to be undetectable in principle, not merely
imprecise. Both alternatives tested came out backwards. Had the specification been written first,
that mechanism would have been distributed through requirements and acceptance scenarios, and the
correction would have been a rewrite rather than an edit to two paragraphs. The measurement also
produced the opposite result on a related question — a capability the design had treated as risky
turned out to work better than the requirement asked for — which shifted where the remaining risk
sits.

**Suggested improvement:** In the design step, separate assumptions by what their failure would
cost: a parameter whose measurement changes a number, versus a mechanism whose measurement could
remove a step. Mechanism-level assumptions should be measured before the specification is written,
not merely flagged in it. The signal that an assumption is mechanism-level: the design contains a
sentence of the form "X happens only when Y", and nothing yet establishes that Y is observable.

**Principle:** Unmeasured assumptions are not equally risky. One sets a value; another holds up a
step. Measure the load-bearing ones before writing the document that spreads them across twenty
requirements, because the cost of being wrong scales with how far the assumption has already
propagated.

### Observation 86: The remediation pass introduced three of the four findings the next pass caught

**Status:** OPEN
**Date:** 2026-08-06
**Session context:** A cross-artifact consistency analysis produced ten findings. All ten were
fixed. Re-running the same analysis found four new issues, and three of them had been created by
the remediation itself.
**Skill:** speckit-analyze
**Type:** open-source
**Phase/Area:** Remediation, and the decision about whether to re-analyse

**Issue:** The fixes were written directly into the artifacts and were individually correct. What
they were not was *consistent with the rest of the document*: a new task specified a transformation
in one language while an existing task consumed it in another; new tasks inherited a parallel marker
from the tasks beside them without checking that the marker was true there either; and a fix
correctly moved one item earlier in the ordering while leaving an identical item, one phase over,
where it was. None of the three would have been found by re-reading the fix. All three were found by
re-running the whole analysis, which is only what happened because the user asked for it explicitly
rather than because anything in the workflow required it.

**Suggested improvement:** Make re-analysis the defined end of the remediation step rather than a
separate thing a user may or may not request — the analysis is cheap relative to the implementation
it gates, and a remediation pass is exactly the moment new inconsistency is introduced, because it
adds material to a document whose invariants were established without it. Where a fix moves or
reorders something, the check should specifically look for siblings of the moved item that were not
moved.

**Principle:** A fix is written against the finding, not against the document. The finding is local
and the invariants are global, so remediation is one of the most likely moments to create the class
of defect that was just removed. Re-run the whole check after fixing, not the part that failed.

### Observation 87: A number identical to one already recorded as false was about to be trusted

**Status:** OPEN
**Date:** 2026-08-06
**Session context:** Sizing budgets for delegated work. A reporting tool printed a remaining-headroom
figure and a verdict of "OK to proceed".
**Skill:** verification-before-completion
**Type:** open-source
**Phase/Area:** Trusting a tool's own report of its state

**Issue:** The figure printed was character-for-character the same as one recorded in the project's
handoff document as a known false reading — the tool had previously reported that exact headroom
while the underlying service refused work for being over the limit the tool said was clear. The
tool's own output also flagged that every calibration day for the relevant model was outside the
project's stated tolerance, which is the tool saying its correction has stopped holding. Both signals
were present in a single screen of output and neither is what the eye goes to; the eye goes to the
verdict line. It was caught only because the same string had been read earlier in the session in a
document describing checks that could not fail.

**Suggested improvement:** Where a project records known-false readings from its own tooling, the
check that reads that tooling should compare against them rather than leaving it to whoever
remembers. More generally: when a tool prints both a verdict and a caveat about its own accuracy,
the caveat outranks the verdict, and a report that says its correction has stopped holding is not
reporting a number — it is reporting that it cannot currently produce one.

**Principle:** A tool's verdict and a tool's confidence in itself are two different outputs, and the
second is the one that decides whether the first means anything. An unchanged number where movement
was expected is evidence of a stuck reading, not of a stable quantity.

### Observation 88: A verification command reported success while running nothing

**Status:** OPEN
**Date:** 2026-08-06
**Session context:** Committing a chunk of implementation. The project's rule is that its full check
script must be run before any work is declared done, and the commit command chained that run to the
commit with `&&`.
**Skill:** verification-before-completion
**Type:** open-source
**Phase/Area:** Running the verification step itself

**Issue:** An earlier command in the session had changed directory into a subpackage to run a
mutation check, and the shell's working directory persisted. The verification script was invoked by
a relative path, so it resolved to nothing. Because the invocation piped its output to a truncating
command, **the exit status belonged to the pipe's last stage rather than to the missing script** —
so the chain treated "file not found" as success and went on to commit and push. The command read
exactly like every other verified commit before it, and the failure left no trace in the commit
itself. Two genuine failures shipped: an unformatted file and a lint error. They were found only
because the next verification run happened to be issued from the repository root.

**Suggested improvement:** Two concrete rules for the skill. First, **invoke a verification script by
an absolute or repository-anchored path**, never a relative one, because working directory is
session state that earlier commands mutate. Second, **never pipe the verification command into
anything when its exit status is being relied on** — or capture the status explicitly rather than
inheriting the pipeline's. More generally, the assertion "I ran the check" should be supported by
the check's own exit status, observed, rather than by the fact that a command containing it was
issued.

**Principle:** A guard that reports success without running is worse than no guard, because it also
consumes the attention that would have noticed. When verification is chained to the action it
guards, make the exit status of the verification itself the thing that gates — not the exit status
of whatever the output was piped through.

### Observation 89: Two layers each enforcing a rule made the test for it unable to fail

**Status:** OPEN
**Date:** 2026-08-06
**Session context:** Implementing a screen with three states — loading, content, and a failure — and
a rule that a failure must not be presented as an empty result. A test asserted exactly that rule
and passed.
**Skill:** test-driven-development
**Type:** open-source
**Phase/Area:** Verifying that a passing test can fail

**Issue:** The rule was enforced in two places without either being written as a fallback for the
other: the view checked for the error case *before* asking the state object whether it was empty,
and the state object also excluded the error case from its own emptiness answer. Deleting the guard
inside the state object left every test green, because the view's ordering meant the mutated code
path was never reached. Reordering the view would have been masked the same way by the guard. So
the test named after the rule was passing on the strength of a different mechanism than the one it
described, and the only reason this surfaced was a deliberate mutation run out of habit rather than
because anything suggested a problem.

**Suggested improvement:** When a rule is enforced at more than one layer, each layer needs its own
assertion at its own level — an end-to-end test cannot distinguish "both defences work" from "one
defence works and hides the other". Add to the skill: after writing a test for a rule, delete the
implementation of that rule and confirm the test fails. If it does not, the test is describing a
mechanism it is not exercising, and the fix is a narrower test at the layer that was mutated, not a
better assertion at the outer one.

**Principle:** Defence in depth makes each individual defence unfalsifiable from the outside. Two
layers guarding one rule will each keep the other's tests green, so the number of places a rule is
enforced is also the number of separate assertions it needs. Mutate one layer at a time and require
something to go red at that layer.

### Observation 90: A guard tested an identity the caller's own context can rewrite

**Status:** OPEN
**Date:** 2026-08-07
**Session context:** Implementing a database-level guard meant to stop client code writing a
particular column. The guard tested the effective user name and refused when it was one of the
client-facing roles.
**Skill:** systematic-debugging
**Type:** open-source
**Phase/Area:** Choosing what a guard tests

**Issue:** The identity being tested is one the platform deliberately rewrites in certain call
frames — a privilege-elevating function replaces it with the function's owner. So the guard refused
a direct write and permitted the identical write when routed through any such function that
client-facing code could call. The codebase already contained functions of that kind against the
same table, so the route was live rather than theoretical. The guard was also a **blocklist**: it
named the identities to refuse rather than the ones to permit, so it failed open for anything not on
the list, which is the direction that matters. It was caught by a reviewer who executed the bypass
rather than reasoning about it.

**Suggested improvement:** Two rules. First, prefer an **allowlist** in any guard: name who may, and
refuse everyone else, so an identity nobody anticipated is refused rather than admitted. Second,
when a guard rests on an identity or a context value, ask explicitly **which layers can rewrite it**
before relying on it — and prefer a value the platform propagates without resetting, keeping the
weaker check as a fallback for callers that carry no such value at all. A test for a guard must
include the *indirect* route, not only the direct one; the direct route is the one the implementer
was already thinking about.

**Principle:** A guard is only as trustworthy as the stability of the thing it inspects. Before
resting a refusal on an identity, enumerate what can change that identity between the caller and the
guard — and write the assertion for the path that changes it, because the path that does not is the
one that will pass anyway.

### Observation 91: Every defect in the batch failed in the safe direction, which is why none had been noticed

**Status:** OPEN
**Date:** 2026-08-07
**Session context:** A review of one feature returned several independent defects in filtering and
text-normalisation logic. Reviewing them together revealed something the individual reports did not.
**Skill:** requesting-code-review
**Type:** open-source
**Phase/Area:** Deciding what to look for, and what a passing system proves

**Issue:** Four separate defects — an identity entry in a character mapping, a described-but-absent
trimming step, an empty collection treated differently from an absent one, and an unescaped
metacharacter in a pattern match — all produced the same *shape* of wrong answer: too few results.
None produced an error, a crash, or a visibly wrong item. In a system whose correct answer is "some
subset", under-returning is invisible: the user assumes the thing they wanted does not exist, and
the operator sees a working feature. Three of the four were in logic whose own comments named the
exact cases it failed on, and none of the four had an assertion. The system was fully green
throughout.

**Suggested improvement:** When requesting or planning a review of filtering, matching or
normalisation logic, ask specifically for **defects that fail closed** and say so — they are
systematically under-reported because they generate no signal. Concretely: for every filter, assert
a case that MUST be returned, not only cases that must be excluded; and where code carries a comment
naming the inputs it handles, turn each named input into an assertion, because a comment is where an
author records intent they did not test.

**Principle:** Defects that fail in the safe direction are the ones that survive longest, precisely
because nothing complains. Absence of a complaint is evidence about how a system fails, not about
whether it works — so a review of anything that narrows a result set should hunt for
over-narrowing first.

### Observation 93: Deduplicating a merged log by identifier drops what the identifier collided on

**Status:** OPEN
**Date:** 2026-08-07
**Session context:** Merging `main` into a branch that had archived 45 resolved entries out of the
observation log while a parallel session appended nine new ones to `main`.
**Skill:** task-observer
**Type:** open-source
**Phase/Area:** Log-write safety / the numbering discipline, and the merge case it does not cover

**Issue:** Both sessions independently allocated `### Observation 82`, exactly as the skill's
numbering discipline warns. The discipline's remedy assumes a shared file and a check-then-act-then-
verify sequence around an append; it says nothing about a version-control merge, where each side's
pre-write check was correct against the file it could see and the collision only exists afterwards.

The dangerous part was the resolution, not the collision. Reconciling the two logs by observation
number — "keep every entry main has that I do not" — treats the number as an identity, so the
incoming 82 was classified as already-held and silently dropped. The count still reconciled, because
one entry in and one entry out is invisible to a total. It surfaced only because the two titles were
read side by side and were plainly different observations.

**Suggested improvement:** Add a merge case to Log-write safety: when reconciling two divergent
copies of the log, match entries on their TITLE (or full body), never on their number, and expect
number collisions rather than treating them as impossible. State which side renumbers — the shared
branch keeps its numbering, the private branch moves, because other sessions may already have seen
the shared one. Record the renumbering inside the moved entry so its old identifier stays traceable.

**Principle:** A locally-allocated identifier is unique only within the copy that allocated it, so
after a merge it is no longer an identity and cannot be used for deduplication. Reconciling on it
deletes exactly the records that collided — and a count-based invariant cannot see the loss, because
a drop and a keep balance. Match on content, and let the identifier be the thing you repair.

### Observation 94: Watching a check fail proves it can fail, not that failing was right

**Status:** OPEN
**Date:** 2026-08-07
**Session context:** Adding a gate step asserting the environment's project ref matches the one the
repository records, immediately after writing the skill section that demands new checks be seen to fail.
**Skill:** verification-before-completion
**Type:** open-source
**Phase/Area:** "Did the check actually run, and could it have failed?" — the see-it-red rule

**Issue:** The new check was mutation-tested properly: six cases, each run, each output read. One row
was "no credentials set, CI=true → exit 1". That row was the bug. A build runner holds no project
ref, points at no deployed project, and therefore has no wrong project to be aimed at — the failure
the check exists to prevent cannot occur there. Demanding a target from a machine that has none
asserts a fact about the world rather than about the change, and it turned the gate red on every
run until another session fixed it.

The row was printed, read, and recorded as correct. The see-it-red discipline had been satisfied to
the letter and produced false confidence, because it answers "can this check fail?" and the question
that mattered was "should it fail HERE?". Reading a red as success is the specific trap: a check
being seen to fail is such a strong positive signal that the plausibility of the failure itself goes
unexamined.

Compounding it: the local environment had the variables set, so every local run passed. The
environment that would fail was the one never exercised outside the synthetic test — and the
synthetic test reproduced the failure faithfully and was misread.

**Suggested improvement:** Extend the see-it-red rule with a second question, asked of every red
observed: is this failure the one the check exists to produce, and is it correct in the environment
that produced it? Specifically, for any check gated on environment state, enumerate the environments
it will run in — developer machine, build runner, scheduled job, container with no credentials — and
state the intended verdict for each BEFORE running it, so the test compares against an expectation
rather than reporting behaviour to be rationalised. And treat "fails when a variable is absent" as
requiring a reason absence is an error, not as self-evidently correct.

**Principle:** Seeing a check go red establishes that it discriminates, not that it discriminates
correctly. The two are easy to conflate because red is the outcome the discipline teaches you to
want, and a wanted outcome is the least examined one. A check gated on environment state has a
different right answer per environment, so its verdict must be predicted per environment and then
compared — otherwise the mutation test faithfully demonstrates the defect and is read as proof of
its absence.

### Observation 95: A privacy requirement stated as a screen behaviour must be implemented as a single choke point, not a screen branch

**Status:** OPEN
**Date:** 2026-08-07
**Session context:** Kafoo WP-015 — building a search screen whose acceptance criterion was "with the consent switch off, ZERO words leave the device, verified by watching what leaves rather than by reading the code that decides."
**Skill:** New skill candidate: verifying-egress-constraints
**Type:** open-source
**Phase/Area:** Implementation and test design for privacy/consent gates

**Issue:** The requirement was phrased as something the interface does ("the search box is unavailable"), which invites an implementation where the screen checks consent before calling the network. That is a branch among several — a suggestion chip, a deep link, a retry button, a voice button, and a "choose another area" action are all separate entry points, and each one added later walks past a screen-level check. The founder's framing ("the consent gate and the search screen are the same piece of work, not two") named the trap precisely: the failure is not a wrong branch, it is a second door.

**Suggested improvement:** For any constraint of the form "X must never leave under condition C", implement one choke point that every path funnels through, and prove it by recording what crossed the boundary rather than by asserting the branch. Two concrete techniques worth documenting: (a) give the test double a list that records every value handed to the outside — not a call count, which cannot answer "what left"; (b) mutation-test the gate by deliberately routing the forbidden case to the network and confirming the test goes red. A test asserting "the refused branch was taken" passes just as happily against an implementation that takes the branch AND sends the data.

**Principle:** An egress constraint is a property of a boundary, not of a screen. Implement it at the single point every path must cross, and verify it by recording what crossed rather than by asserting which branch ran — a branch assertion and an egress assertion look identical in the passing case and differ only in the case that matters.

### Observation 96: An error message is an egress path, and it is the one nobody audits

**Status:** OPEN
**Date:** 2026-08-07
**Session context:** Kafoo WP-015 — the `discover` Edge Function returned `detail: String(error)` on a 503, while the same feature's requirements forbid the Customer's phrase reaching "the event, a log line, or an error carrying the request".
**Skill:** New skill candidate: verifying-egress-constraints
**Type:** open-source
**Phase/Area:** Reviewing data-handling code

**Issue:** The forbidden value never appeared in the function's own code near the error. It arrived through two hops: the vendor adapter interpolated the provider's HTTP response body into an exception message, and providers routinely quote the offending request back in that body. So a function that carefully never logs the input still hands it to the caller inside an error, and the code reads as though it does not.

**Suggested improvement:** When auditing where a sensitive value can go, treat every `String(error)`, `err.message`, stack trace and structured error payload as an egress path and trace it to the layer that CONSTRUCTS the message, not the layer that emits it. The test that catches it asserts on the whole serialised response containing the sensitive string, across each failure mode — not on the fields the author remembered to check.

**Principle:** Sensitive data leaves through errors more often than through logs, because an error message is assembled somewhere else and read as opaque at the point it is returned. Audit error construction at its source, and assert on the entire outgoing payload rather than on named fields.

### Observation 97: A generated-file gate makes a comment about the rule a violation of it

**Status:** OPEN
**Date:** 2026-08-07
**Session context:** Kafoo WP-015 — a project vocabulary check failed on a new ARB entry whose *description* said the string "names the AI Assistant by its canonical name — never bot, chatbot or model". The banned words appeared only as an explanation of the ban, and only in a generated Dart file compiled from the ARB.
**Skill:** task-observer (or a repo-conventions skill)
**Type:** open-source
**Phase/Area:** Working with generated artefacts and lint-style content gates

**Issue:** Documentation prose about a forbidden term is indistinguishable, to a substring scanner, from a use of the forbidden term — and the failure surfaced in a file the author never edited, which makes the error message point at the wrong place. Time was spent looking for a real vocabulary mistake before recognising it was the comment about the rule.

**Suggested improvement:** When a content gate scans generated output, expect prose *about* the rule to trip it, and phrase rule-explaining comments by reference rather than enumeration ("rather than any of the words the vocabulary check forbids"). More generally: when a check fails inside a generated file, resolve the finding to its SOURCE file before diagnosing it.

**Principle:** A scanner cannot distinguish mention from use. Comments that explain a prohibition should refer to it rather than quote it, and a finding in a generated file is a finding about its source.

### Observation 98: A widget test suite with no viewport and no text scale can pass over text rendered in the framework's own "this is broken" style

**Status:** OPEN
**Date:** 2026-08-07
**Session context:** Kafoo WP-015 — twenty-five passing widget tests covered six user-facing sentences that were rendering at 48-point monospace under a double yellow underline (Flutter's root `_errorTextStyle`), overflowing a phone-sized screen at ordinary text scale. Found by a review agent that rendered the screen at a real device size.
**Skill:** New skill candidate: widget-test-fidelity
**Type:** open-source
**Phase/Area:** Widget/UI test design

**Issue:** Two independent blind spots lined up. The finder API matches on text content and never inspects style, so every assertion passed. And the default test surface is a desktop-sized viewport at 1.0 text scale, which no phone has — so the overflow that would have made the defect obvious never occurred. A project rule requiring testing at 200% text scale had been in place for months and nothing enforced it, because enforcement would have meant a test that sets a viewport and nothing did.

The proximate cause is worth recording separately: an ambient-style lookup (`DefaultTextStyle.of(context)`) resolved from a `State`'s own context, which sits ABOVE the widget that installs the theme. The identical line elsewhere in the same codebase was correct because its context came from a builder at the insertion point. Right in one file, wrong in another, and only where the context comes from distinguishes them.

**Suggested improvement:** For any UI test suite, keep at least one test that (a) sets a realistic device viewport, (b) sets a large text scale, and (c) asserts on rendered properties — size, style, absence of overflow exceptions — rather than on content. Content assertions verify that the right words are present; they cannot verify that anyone can read them. When a framework provides a deliberately-alarming fallback style, assert against it directly: it is the cheapest possible canary.

**Principle:** A test that matches on content is blind to presentation, and a default test viewport is a device nobody owns. A UI suite needs at least one assertion about how something rendered, at a size and scale somebody will actually use, or "all tests pass" means only that the strings exist.

### Observation 99: A guard placed on an entrance is a guard the next entrance walks past — and its test can pass vacuously

**Status:** OPEN
**Date:** 2026-08-07
**Session context:** Kafoo WP-015 — a consent check was placed on the primary method, with a documented comment predicting exactly the failure that then occurred: a second method reached the network without passing it. The test that appeared to cover the second method returned early on an unset precondition and asserted nothing.
**Skill:** New skill candidate: verifying-egress-constraints
**Type:** open-source
**Phase/Area:** Guard placement and negative-test design

**Issue:** Two failures compounding. First, the guard was on an entrance rather than on the funnel every entrance already crossed — and the class documentation *stated the correct principle* while the code did not follow it, which is the most persuasive form of wrong, because reading the file leaves you convinced. Second, the negative test called the unguarded method on state where it returns immediately, so it exercised the early return rather than the guard. It read as coverage and was coverage of nothing.

**Suggested improvement:** When placing a guard, find the narrowest point that every path crosses and put it there — usually the private method the public ones delegate to, not the public ones. When writing a negative test for a guard, first establish the preconditions under which the guarded code would actually run, and confirm the test fails when the guard is removed. A negative test that has not been watched turning red is indistinguishable from one that is testing an early return.

**Principle:** Guard the funnel, not the entrances; entrances keep being added. And a negative test must be shown to fail for the reason it claims — an early return produces the same green as a working guard.

### Observation 100: No structure for evaluating an external repo or paper against Kafoo's constraints

**Status:** OPEN
**Renumbered:** was Observation 95 on branch `claude/kafoo-speech-to-speech-eval-np67r5`; moved to 100 on merge with `main`, which had independently issued 95 to a different observation
**Date:** 2026-08-07
**Session context:** Founder asked for an evaluation of an arXiv paper and the huggingface/speech-to-speech repo for use in Kafoo. The useful answer turned out to be structured entirely around project constraints the external source knows nothing about — language coverage (Egyptian Arabic), deployment shape (no always-on server), and product direction (the AI never speaks). Reaching that structure took a full architecture sweep of the repo that had to be done before the external source could be judged at all.
**Skill:** New skill candidate: evaluating-external-dependencies
**Type:** open-source
**Phase/Area:** Technology evaluation / build-vs-adopt decisions

**Issue:** "Is this library/paper useful for us?" is a recurring question with a repeatable shape, but there was no skill for it. The failure mode it invites is evaluating the artifact on its own terms — stars, benchmarks, feature list, license — and producing a verdict that reads as informed while never testing the artifact against the constraints that actually decide adoption. Here, the repo scored well on every generic axis (11.5k stars, Apache 2.0, production deployment, clean architecture) and was still disqualified three times over on project-specific grounds.

**Suggested improvement:** Create a skill that fixes the evaluation order: map the project's own constraints FIRST (a subagent sweep of ADRs, deployment topology, roadmap position and the relevant existing code), then judge the external artifact against those, then report. Include a disqualifier checklist that generalises: (1) does it cover our languages/locales/regions, checking DEFAULTS not just the "supported backends" list; (2) does it fit our deployment shape and what new infrastructure tier does it require, priced; (3) is it aimed at the product we are actually building, or an adjacent one; (4) maintenance signal — open-PR-to-commit ratio, not stars. Require the report to name the parts worth *reading* separately from the parts worth *adopting* — a source can be valuable as evidence for a decision already pending while being wrong as a dependency.

**Principle:** Evaluate an external artifact against the adopting project's constraints, never on its own terms. A dependency's quality is a property of the fit, not of the dependency — and the generic quality signals (popularity, license, benchmarks, architecture) are exactly the ones that survive a bad fit intact. Establish the constraints before reading the artifact, or the artifact will supply the evaluation criteria.

### Observation 101: A retired measurement stays alive in the files that quoted it

**Status:** OPEN
**Renumbered:** was Observation 96 on branch `claude/kafoo-speech-to-speech-eval-np67r5`; moved to 101 on merge with `main`, which had independently issued 96 to a different observation
**Date:** 2026-08-07
**Session context:** Architecture sweep of Kafoo's voice stack while evaluating an external speech pipeline. ADR-0009's spike addendum explicitly retires a 645 ms latency figure ("it should not be used again to dismiss a latency argument") after production measurement showed 2177 ms median against a 2000 ms budget. The retired figure is still stated as live fact in `.claude/rules/ai.md` and in ADR-0005 Amendment 1. Separately, `docs/ops/measuring-transcription.md` still points at a file path that moved during E2's T031.
**Skill:** ship-check (and any skill covering ADR authoring / documentation-drift enforcement)
**Type:** open-source
**Phase/Area:** Definition of done — "update whatever the change made stale"

**Issue:** The project rule is that documentation drift is part of the change, not follow-up work. It held for the file that *made* the correction — the ADR records the retirement carefully and even says the number must not be reused. It failed for the files that *quoted* the number, which are the ones a future reader is most likely to hit first. A superseded figure sitting in an always-loaded rules file is worse than an absent one: it is load-bearing for decisions and carries no signal that it has been retired.

**Suggested improvement:** When a change retires a specific measured value, a named constant, or a file path, add a step that greps the repository for that literal value or path and updates every occurrence in the same commit. Fold this into `/ship-check`: if the diff removes or supersedes a number or path that appears elsewhere in tracked files, fail the check until the other occurrences are reconciled or explicitly marked historical. Mechanically checkable — the value is a literal string.

**Principle:** Correcting a fact where it was decided does not correct it where it was quoted. Superseded figures propagate by copy, so retiring one is a repository-wide find-and-replace, not a single-file edit — and the copies are more dangerous than the original, because they carry the authority of the claim without the context of its retraction.

### Observation 102: Evaluating a repo against a stale checkout, because the pull rule is scoped to "proposing"

**Status:** OPEN
**Renumbered:** was Observation 97 on branch `claude/kafoo-speech-to-speech-eval-np67r5`; moved to 102 on merge with `main`, which had independently issued 97 to a different observation
**Date:** 2026-08-07
**Session context:** Founder asked for an evaluation of alibaba/open-code-review as a review tool for
Kafoo. The session read `.claude/agents/` and `scripts/verify.sh` to establish what the project
already does, and drew conclusions from a checkout one commit behind `main` — where `main` had just
merged the first observation review, which changed `verify.sh` (a new "supabase target" check, 23
steps) and rewrote the observation log. The founder had to interrupt with "you are seeing an old
review log."
**Skill:** task-observer (session start protocol), and CLAUDE.md's coordination section
**Type:** open-source
**Phase/Area:** Session start — establishing the baseline before analysis

**Issue:** CLAUDE.md states "The coordinator pulls `main` before proposing anything", and the whole
`coordination/` directory exists because a session once proposed work that was already merged. The
rule was not followed here, and the reason is instructive: the task did not look like *proposing*.
It looked like *evaluating an external tool* — the repository seemed to be background context, not
the subject. So the trigger word "proposing" did not fire, even though the entire answer was a
comparison against the current state of the repository and was therefore worthless if that state
was stale.

The failure is silent by construction. A stale checkout produces a confident, internally consistent
analysis; nothing in the tree announces that it is behind. Every number quoted — the count of gate
checks, the list of review agents, the size of the observation backlog — was wrong in a way only a
fetch could reveal.

**Suggested improvement:** Make the baseline check unconditional and mechanical at session start,
not conditional on the task's category: `git fetch origin main && git rev-list --count HEAD..origin/main`,
and state the result before any analysis that cites repository state. Widen the CLAUDE.md rule from
"before proposing anything" to "before citing the state of the repository for any purpose —
proposing, evaluating, reporting or answering", since the failure mode is identical in all four and
only the first is currently named.

**Principle:** A rule scoped by the *category* of work fails on tasks that do not self-identify as
that category. The predicate that actually matters here is not "am I proposing?" but "does my answer
depend on the current state of the repository?" — so scope the rule to the dependency, not to the
activity. Any analysis that quotes repository state is stale-able, and staleness is invisible from
inside the stale copy: it produces a coherent answer, not an error.

### Observation 103: Second instance of the external-dependency evaluation shape, one day apart

**Status:** OPEN
**Renumbered:** was Observation 98 on branch `claude/kafoo-speech-to-speech-eval-np67r5`; moved to 103 on merge with `main`, which had independently issued 98 to a different observation
**Date:** 2026-08-07
**Session context:** Evaluating `alibaba/open-code-review` for adoption — the second such request in
two days, after the huggingface/speech-to-speech evaluation that produced Observation 95 (logged as
92 on its branch). The useful answer had the same shape both times: establish the project's own
constraints first, then judge the artifact against them, and separate "worth reading" from "worth
adopting".
**Skill:** New skill candidate: evaluating-external-dependencies (strengthens Observation 95)
**Type:** open-source
**Phase/Area:** Technology evaluation — evidence for the candidate, not a new candidate

**Issue:** Observation 95 proposed the skill from a single instance, which is the weakest kind of
evidence and exactly what the "SIMPLIFYING" checklist warns about ("a rule from a single unvalidated
observation"). A second independent instance one day later, on a completely different artifact class
(a CLI review tool rather than a speech model), confirms the recurrence and the stability of the
structure. Both evaluations turned on constraints the artifact could not know: for the speech repo,
Egyptian Arabic and deployment shape; for the review tool, Dart-plus-SQL language coverage, a
test-first safety model the tool excludes by default, and an already-committed LLM spend ledger.

Two disqualifier axes appeared in this instance that Observation 95's proposed checklist does not
name: (a) what the tool *defaults to ignoring*, which for a review tool was test files — the exact
artifact Kafoo's safety model rests on; and (b) whether the tool's own optimisation target matches
ours, here a deliberate precision-over-recall trade-off that is correct for a large org drowning in
review noise and backwards for a solo founder who cannot read the diff.

**Suggested improvement:** Do not create a second candidate. Attach this to Observation 95 as
corroborating evidence, and add the two axes above to its disqualifier checklist: "what does it
exclude or ignore by default, and is that the thing we most need looked at?" and "what is it
optimised FOR, and does that objective match ours?" Both are questions about defaults and intent
rather than capability, and neither shows up in a feature list.

**Principle:** A tool's defaults and its optimisation target disqualify more adoptions than its
feature list does, because features are advertised and defaults are assumed. Ask what an artifact
ignores by default and what objective it was tuned against — a capable tool aimed at a different
objective is a worse fit than a weaker tool aimed at ours.

### Observation 104: A misattributed source name is an ambiguity that looks like a precise instruction

**Status:** OPEN
**Renumbered:** was Observation 99 on branch `claude/kafoo-speech-to-speech-eval-np67r5`; moved to 104 on merge with `main`, which had independently issued 99 to a different observation
**Date:** 2026-08-07
**Session context:** Founder asked to "borrow the benchmark from alibaba and tune it for our repo", following a session that evaluated an arXiv paper. There is no benchmark by Alibaba in that paper: Alibaba is Qwen, whose *models* the paper measures; the benchmark the paper *cites* is BenchForce, which is Salesforce's. A third candidate (VoiceBench) exists and is associated with Alibaba only because Qwen publishes scores against it. Three non-interchangeable artefacts, one confident-sounding request. The founder deferred the work when the three were laid out.
**Skill:** New skill candidate: evaluating-external-dependencies (same candidate as Observation 93) — or any skill covering how to act on a request that names a source
**Type:** open-source
**Phase/Area:** Interpreting a request that names an external artefact

**Issue:** A request naming a specific source reads as *more* precise than a vague one, so it invites going straight to work. Here the name was wrong in a way that was invisible without checking — "the benchmark from X" where X is the party whose product was *measured*, not the party who wrote the benchmark. Picking any one of the three and building it would have produced confident, well-executed, wrong work, and the error would only have surfaced after delivery. The cost of checking was two searches.

**Suggested improvement:** Add a rule: before acting on a request that names an external artefact (paper, benchmark, library, dataset) *and* an attribution, verify that the artefact and the attribution actually go together. Where a source was discussed earlier in the session, re-read what it said rather than relying on the conversational summary of it. If the name resolves to more than one plausible artefact, enumerate them with their differences and ask — do not rank-and-pick silently. Do all work that does not depend on the answer first, so the question costs the user a decision and not a stalled session.

**Principle:** Specificity is not accuracy. A request that names a source, a version, or an author sounds verified and is not — misattribution is the most common way a confident instruction points at the wrong thing, and it survives every check except looking. Confirm the referent exists as named before building on it, and when one name maps to several real artefacts, that is an ambiguity to surface rather than a preference to infer.

### Observation 105: PDF text extraction has no fallback path when the container's crypto stack is broken

**Status:** OPEN
**Renumbered:** was Observation 100 on branch `claude/kafoo-speech-to-speech-eval-np67r5`; moved to 105 on merge with `main`, which had independently issued 100 to a different observation
**Date:** 2026-08-07
**Session context:** Reading an arXiv paper (2603.05413) to evaluate a third-party repo for Kafoo. The Read tool's PDF path failed (`pdftoppm` missing), and both `pypdf` and `pdfminer.six` then failed at import because the container's system `cryptography` package panics (`No module named _cffi_backend` → pyo3 PanicException). Three attempts burned before a workaround landed: stubbing a fake `cryptography.hazmat.primitives.ciphers` package on PYTHONPATH so pypdf's optional encryption import resolves.
**Skill:** New skill candidate: reading-pdfs-in-constrained-containers (or a reference section in an existing research/reading skill)
**Type:** open-source
**Phase/Area:** Source ingestion / research reading

**Issue:** Reading a PDF from the web is a routine research step, but in an ephemeral cloud container the documented paths can all fail for unrelated environment reasons. There was no documented fallback ladder, so the agent rediscovered one by trial and error mid-task, spending several tool calls on environment repair rather than on the analysis the user asked for.

**Suggested improvement:** Document a short fallback ladder for PDF text extraction: (1) the harness Read tool; (2) `pdftotext` if poppler is present; (3) `pypdf` with a stubbed `cryptography.hazmat.primitives.ciphers` module on PYTHONPATH — pypdf imports it only for encrypted-PDF support and a three-class stub satisfies the import; (4) raw zlib stream decode as a last resort. Note that WebFetch on an arXiv PDF returns a *summary produced by a small model*, not the text — for a paper whose numbers matter, always extract the real text rather than trusting the fetched summary.

**Principle:** When a tool returns a *model-generated summary* of a source rather than the source itself, treat it as a lead, not as evidence. Any claim that will drive a recommendation must be traced back to the primary text. And for routine ingestion steps that can fail on environment grounds, carry a documented fallback ladder rather than improvising one under time pressure — the improvisation cost lands in the middle of analytical work, exactly where attention is most expensive.

### Observation 106: A filename convention that silently decides whether a test suite runs

**Status:** OPEN
**Date:** 2026-08-07
**Session context:** WP-016 (Kafoo E3). Adding a Deno test suite for a new Edge Function; discovered while choosing a filename that the project gate globbed `*_test.ts` and three existing `*.test.ts` suites had never run in CI — including the entire Edge Function suite of the previous work package, which contained the assertion that a Customer's search phrase never appears in a response.

**Skill:** New skill candidate: verification-gate-auditing (or an addition to `verification-before-completion`)
**Type:** open-source
**Phase/Area:** Verifying that a check actually covers what it claims

**Issue:** The gate reported "edge function tests: ok" while silently covering a subset of the test files present. Nothing was broken — the check ran, passed, and printed a success line. The discrepancy was one underscore versus one dot, invisible in every report the gate produced. It was found only because a new file had to be named and the glob was read while choosing the name. A privacy assertion had been decorative for days.

**Suggested improvement:** When adding to a verification suite, do not only run the new check — enumerate what the harness selects and diff it against what exists on disk. Add a step to verification workflows: "list the files the gate actually selected; compare against the files that exist; any file present but unselected is either a deliberate exclusion that must be documented in the check, or a hole." Where a naming convention genuinely carries meaning (pure unit suite versus one needing live infrastructure), the check must state the convention in a comment at the point of selection, so the next author picking a filename learns it from the code rather than by accident.

**Principle:** A passing check proves the checked set passed; it says nothing about whether the checked set is the intended set. Any selector — a glob, a directory list, a tag filter — is an unverified assumption sitting upstream of every assertion it feeds, and it fails silently by design because selecting nothing is indistinguishable from finding nothing wrong. Audit the selector, not just the result.

### Observation 107: A negative test that would have passed either way

**Status:** OPEN
**Date:** 2026-08-07
**Session context:** WP-017 (Kafoo E3). Wrote four database assertions for a normalisation fix, ran them green, then deliberately reverted the fix to confirm they went red. Three did. One stayed green — it had been written with a test value that the surrounding substring match already satisfied, so it was testing a different mechanism than the one it named.

**Skill:** `test-driven-development` (the "watch it fail" step) and `verification-before-completion`
**Type:** open-source
**Phase/Area:** Confirming a test fails before making it pass

**Issue:** "Seen to fail" was treated as a property of the suite rather than of each assertion. The suite as a whole went red when the fix was reverted, which reads as confirmation — but the redness came from three assertions, and the fourth was carried along by them. Had the fix been broken later in exactly the way that assertion was written to catch, it would have stayed green. The failure was in the fixture data, not the assertion logic, which is why reading it did not reveal it.

**Suggested improvement:** When reverting an implementation to confirm tests fail, record WHICH assertions went red, by name, and compare that list against the assertions the change was supposed to protect. Any assertion that stays green during the revert is either redundant or mis-written and must be fixed before proceeding. Write the per-assertion result into the test file as a comment, so the next reader can see which assertions have been demonstrated and which have only ever passed.

**Principle:** A suite going red does not demonstrate that every test in it can go red. Verify the fail step per assertion, not per run — an assertion that passes in both the broken and the fixed state is not a weak test, it is not a test of that behaviour at all, and it is indistinguishable from a strong one in every report either state produces.

### Observation 108: A safety check that forbids a word cannot read the test that forbids the same word

**Status:** OPEN
**Date:** 2026-08-07
**Session context:** WP-016 (Kafoo E3). A repository check greps functions that call a model for the names of write credentials. A new test asserting "this function names no write credential" failed that check — by naming the credentials in its assertion list.

**Skill:** New skill candidate: writing-checks-with-exemptions, or an addition to a testing-practices skill
**Type:** open-source
**Phase/Area:** Static checks and their exemptions

**Issue:** The obvious resolutions were both wrong. Weakening the check to skip test files puts a hole in it shaped like "unless it is a test", and test files are exactly where somebody would prototype the thing being forbidden. Rewriting the assertion to avoid the literal makes the test awkward. The project already had precedent for the same collision (a data file whose content is the list of forbidden words), resolved by exempting one named file rather than a directory.

**Suggested improvement:** When a static check collides with code whose purpose is to describe what the check forbids, prefer bending the describing code over widening the check — build the forbidden literal from parts, or name a single exempt file rather than a pattern. Record the reason at the point of the awkwardness, because otherwise it reads as obfuscation and the next author "cleans it up". Never exempt a category (tests, fixtures, examples): the exemption becomes the place the forbidden thing lives.

**Principle:** A check that forbids a token cannot distinguish mentioning from using, and the fix belongs on the mentioning side. Exemptions should be one named file with a stated reason, never a class of files — a categorical exemption is a permanent hole whose shape exactly matches what a motivated author would need.

### Observation 109: A status field only a dead actor may set is never set

**Status:** OPEN
**Date:** 2026-08-08
**Session context:** Closing out two coordination work packages whose code had merged to main a day earlier while both records still read READY_FOR_REVIEW with `pr: null`.
**Skill:** Project documentation — `coordination/README.md` lifecycle
**Type:** open-source
**Phase/Area:** Work-package lifecycle, the `pr` field

**Issue:** The lifecycle assigns `READY_FOR_REVIEW` to the worker and `COMPLETED` to the coordinator, and the `pr` field is described as "so the coordinator can see state without asking". But nothing writes `pr` at the moment the PR is opened. Both packages carried `pr: null` through open, review and merge, so the one field that would have let anyone check the merge from the record was the field the record never had. The workers were not negligent: containers are destroyed on inactivity, so by the time the number mattered the only session that knew it was gone. The record then looked identical to unfinished work, which is the exact failure the directory exists to prevent.

**Suggested improvement:** Require `pr` to be written in the same edit that moves a package to `READY_FOR_REVIEW` — the transition that means "my PR is open and green" is the moment the number exists and the worker is still alive. Where a validator exists, make `READY_FOR_REVIEW` with `pr: null` an error, the same way `BLOCKED` with no `blocked_reason` already is.

**Principle:** When a field's only writer is an actor that predictably disappears before the field matters, the field will be empty exactly when it is needed. Bind writing it to the last transition that actor is guaranteed to be present for, and let the schema check refuse the transition without it.

### Observation 110: A criterion that names an identifier is checkable by searching for the identifier

**Status:** OPEN
**Date:** 2026-08-08
**Session context:** Walking eleven acceptance criteria against merged code to decide whether a package was genuinely done.
**Skill:** verification-before-completion
**Type:** open-source
**Phase/Area:** Verifying acceptance criteria against a codebase

**Issue:** One criterion read "SC-002 and SC-003 verified by name". The feature it describes worked, was well tested, and had shipped — so reading the code invited the conclusion that the criterion held. It did not: neither identifier appeared in any test in the repository, and the only hits for that string belonged to a different, earlier specification that happened to reuse the number. The cheap check found in seconds what a careful read of the feature would have talked itself out of.

**Suggested improvement:** When a criterion names a stable identifier — a requirement id, a ticket number, an error code, a metric name — check it by searching the repository for that identifier before reading any implementation, and treat zero hits as unmet regardless of how good the feature looks. Then check the hits actually belong to the right document, because identifier schemes are reused across specifications.

**Principle:** An identifier named in a criterion is a grep-able assertion, and grep does not rationalise. Run the mechanical check first; reading the implementation first primes you to accept an outcome that resembles the requirement instead of the one that satisfies it.

### Observation 111: A landmark that exists before the thing you are timing measures nothing

**Status:** OPEN
**Date:** 2026-08-08
**Session context:** Measuring that an optional AI response never delays the results a user sees — timing from "request finished" to "results visible" under two conditions and asserting the two are equal.
**Skill:** test-driven-development
**Type:** open-source
**Phase/Area:** Writing a measurement, as opposed to an assertion

**Issue:** The measurement loop waited for a piece of content to appear on screen and counted iterations. The content chosen was already on screen — it belonged to the underlying list the feature renders over, not to the results being timed. So the loop exited on the first iteration under both conditions, reported two equal numbers, and passed. It would have reported the same two equal numbers against an implementation that never rendered a result at all. A second, subtler form appeared immediately after the fix: both runs shared one element tree, so the second run began timing with the first run's output still displayed, and the loop again exited immediately. Neither was visible from reading the test; both surfaced only when the implementation was deliberately broken.

**Suggested improvement:** Any test that waits for a condition and counts must first assert the condition is FALSE before the timed action begins. One line, and it converts a silently vacuous measurement into a loud one. When several timed runs share a test body, give each its own distinct landmark rather than assuming teardown between them — UI frameworks that reuse a widget or element tree will carry the previous run's state into the next.

**Principle:** A measurement is only valid if its start condition was verified to be unmet at the start. Timing to "X appears" when X was already there is not a slow measurement or an inaccurate one — it is no measurement, and it produces the exact numbers a passing result would.

### Observation 112: Two expressions of one rule are a rule that can half-change

**Status:** OPEN
**Date:** 2026-08-08
**Session context:** Mutation-testing a script that computes two acceptance thresholds from the same underlying predicate.
**Skill:** test-driven-development
**Type:** open-source
**Phase/Area:** Mutation testing, and what to do when a mutation survives

**Issue:** The rule "the target appears within the top five" was written twice — once in the expression counting hits, once in the expression computing the rate. Four deliberate mutations turned the self-check red as intended. A fifth, narrowing "top five" to "top one", SURVIVED: it edited one of the two copies, so the rate moved while the count did not, and no assertion compared them. The tempting response is to add an assertion covering the second copy. That leaves the duplication, so the next mutation in the other direction survives instead.

**Suggested improvement:** When a mutation survives, ask first whether the rule it touched exists in more than one place. If it does, collapse the copies into one named predicate and re-run the mutation — the fix is deduplication, not another assertion. Add the assertion too, but as a second layer. Record the surviving mutation next to the extracted predicate so a later author does not re-inline it for readability.

**Principle:** A surviving mutation is evidence about the code's structure as often as about the test's coverage. Duplicated logic is partially mutable: a change can hit one copy and leave the other, so no test that compares outputs can see a difference. Deduplicating turns a class of undetectable mutations into detectable ones, which no amount of extra assertions on the duplicated form will do.

### Observation 113: A task listed in a closed unit of work is a claim that it was delivered

**Status:** OPEN
**Date:** 2026-08-08
**Session context:** Closing a large work package whose acceptance criteria were all met, but whose task list included one task that was genuinely two halves — one delivered and merged, one that could not be done from the environment at all.
**Skill:** ship-check
**Type:** open-source
**Phase/Area:** Closing a unit of work when part of it cannot be finished

**Issue:** Three options presented themselves and two were wrong in ways that are easy to miss. Marking the package complete with the task still listed silently claims the undone half, because a task id inside a completed package is read as delivered by everyone downstream — including the tracker's own dependency graph. Holding the package open for the remaining half keeps an otherwise finished unit active, which in a system where active units block exclusive ones and carry an owner name means a dead worker appears to still be working. Duplicating the task id into a new package makes the same number mean "done" in one place and "not done" in another.

**Suggested improvement:** When closing a unit of work that carries an unfinished task, MOVE the task id to the new unit rather than leaving or copying it, and write on both sides what was delivered under the old id. The delivered half stays recorded as history in the closed unit's notes; the id itself — the thing tools and dependency graphs read — travels with the work that remains. Then check whether any other unit depended on the closed one for the moved task's outcome, and repoint that dependency, or the split silently unblocks work that is still blocked.

**Principle:** Identifiers carry status, prose carries history. A task number in a completed unit is a machine-readable assertion of completion no amount of surrounding explanation overrides, so the number must follow the unfinished work while the narrative of what was already delivered stays behind.

---

### Observation 114: A second surface inherits the rule, not the mechanism — and the mechanism is where the rule breaks

**Status:** OPEN
**Date:** 2026-08-08
**Session context:** Building discovery (browse, search, honesty layer, consent) on a Next.js web surface, mirroring an existing Flutter implementation of the same feature.
**Skill:** New skill candidate: porting-a-feature-to-a-second-surface
**Type:** open-source
**Phase/Area:** Implementation — reproducing an existing feature on a different platform

**Issue:** The rule "a user's search phrase is never recorded" was already implemented and well-tested on the first surface, where it meant "no log line, no cache keyed on the phrase, no analytics attribute". Ported literally to a web surface, every one of those checks would have passed while the phrase leaked through three mechanisms that do not exist on the first platform: a query string written into the server's request log, the browser's own history, and the `Referer` header sent to every third-party asset host on the page. A form control with a `name` attribute and no JavaScript would have produced all three silently. None of these are visible from reading the original implementation, because the original platform has no URLs.

**Suggested improvement:** When porting a feature, enumerate the rule's *threat surface on the new platform* before reproducing the *code*. For each invariant the feature carries, ask "what are the ways this could be violated here that do not exist there" — and write the test against the new mechanisms, not against the old ones. The ported test suite should contain at least one assertion that would have been meaningless on the original platform.

**Principle:** A ported invariant is only as strong as the threat model it was written against, and a threat model is platform-specific. Copying the guard without re-deriving what it guards against reproduces the letter of a rule onto a surface where the letter no longer covers the spirit.

---

### Observation 115: A conflation that was merely wrong becomes load-bearing when a second feature reads it

**Status:** OPEN
**Date:** 2026-08-08
**Session context:** Adding area-narrowing to a second surface, which required knowing which areas currently have inventory.
**Skill:** New skill candidate: porting-a-feature-to-a-second-surface
**Type:** open-source
**Phase/Area:** Implementation — building on existing read layers

**Issue:** An existing read function returned an empty list both when the query succeeded with no rows and when it failed. The user-facing consequence at the time was one wrong sentence on one page, and a correctly-worded error string sat unused in the localization files because no caller could distinguish the two cases. The new feature then needed exactly that distinction: when a user's chosen area has nothing in it, the product must name the areas that *do* have something — and a failed read looks identical to "nowhere has anything", which turns a network error into a false claim about the whole marketplace at the precise moment the user is being offered alternatives.

**Suggested improvement:** Before building on an existing read layer, check whether it collapses "empty" into "failed". If it does, fix the read layer rather than working around it in the new caller — and look for an unused error string or dead branch, which is often the fossil evidence that someone already knew the distinction was needed. Treat an unreferenced user-facing error message as a defect report, not as dead code to delete.

**Principle:** Conflating absence with failure is a latent bug whose blast radius grows with each new reader. The second consumer of a lossy signal is where the loss stops being cosmetic, so the cost of the original shortcut is paid by whoever arrives next.

---

### Observation 116: Test-runner capability sets the shape of the code under test, and it is worth checking first

**Status:** OPEN
**Date:** 2026-08-08
**Session context:** Writing behavioural tests for a TypeScript module in a project whose existing tests only read source files as text.
**Skill:** test-driven-development
**Type:** open-source
**Phase/Area:** Writing tests for compiled/transpiled languages

**Issue:** The project's existing test file for this area read its subject as a string and asserted with regexes, with a comment explaining that the modules were TypeScript and therefore could not be imported. That constraint had quietly expired — the installed runtime strips types natively — but the workaround had already shaped the tests into structural assertions that could not verify behaviour. The requirement being tested explicitly demanded behavioural verification ("verified by watching what leaves rather than by reading the code that decides"), which regex-over-source cannot do. Separately, once real imports worked, one ordinary language feature in the module under test was unsupported by the stripper and had to be written out longhand — a one-line cost that bought executable tests.

**Suggested improvement:** At the start of a testing task in a transpiled language, spend one command establishing what the runner can actually execute today, rather than inheriting the constraint encoded in the neighbouring test file. When a runtime limitation forces a small change to the code under test, make the change and record why in a comment at that spot — otherwise the next person "cleans it up" and silently breaks the ability to test.

**Principle:** Workarounds outlive the limitations that caused them, and a test-shape adopted under an expired constraint keeps testing the wrong thing. Verify the tool's current capability before accepting the previous author's compromise as a fact about the world.

---

### Observation 117: Verifying an acceptance criterion "by name" is a different act from reviewing the diff, and finds different things

**Status:** OPEN
**Date:** 2026-08-08
**Session context:** Completing a unit of work whose acceptance criteria included "verified field by field: what is visible on surface B is identical to what is visible on surface A".
**Skill:** verification-before-completion
**Type:** open-source
**Phase/Area:** Final verification, before declaring work done

**Issue:** The full automated gate passed, types checked, the build succeeded, and every test written for the change was green. Walking the acceptance criteria one at a time afterwards — specifically the one demanding a field-by-field comparison against the other surface — surfaced a real user-facing defect that none of that had touched, and that was not in the diff at all: a value rendered on three pre-existing pages was missing a unit that the reference surface displays. It had been wrong since that surface shipped. A diff review cannot find it, because the defect is in code the change does not modify; a test suite cannot find it, because no test knew to compare the two surfaces; and the criterion names it exactly.

**Suggested improvement:** Treat "check the acceptance criteria by name" as a distinct verification step with its own output, performed after the automated gate rather than assumed to be covered by it. For each criterion, state what was actually done to check it and what the result was — and when a criterion asks for a comparison against something outside the change, go and read that other thing rather than reasoning about it. A criterion that can only be satisfied by inspection is the one most likely to be marked done by assertion.

**Principle:** Automated gates verify the change; acceptance criteria verify the outcome, and the gap between them is where pre-existing defects in scope of the criterion survive indefinitely. A criterion phrased as a comparison is an instruction to look at both sides, not a claim to endorse.

---

### Observation 118: A closed-list authorization rule ages into a silent outage, and the swallow that makes it safe is what hides it

**Status:** OPEN
**Date:** 2026-08-08
**Session context:** Deciding which analytics could not be recovered later; discovered that an entire feature's measurement had never been recorded.
**Skill:** New skill candidate: porting-a-feature-to-a-second-surface
**Type:** open-source
**Phase/Area:** Authorization rules that outlive the world they were written for

**Issue:** An authorization policy enumerated the two operations an unauthenticated caller could perform, and was exactly right when written. A later feature was built on the premise of working without authentication, and emitted three operations that policy did not name. Every one was rejected by the database and discarded by the client's own error handling — which is correct on its own terms, because that subsystem must never interrupt the user. The result: the feature worked, every test passed, the full gate stayed green, and the authorization test suite continued asserting the *old* behaviour truthfully, while the feature recorded nothing at all for its primary case. It went unnoticed for the entire epic and was found only by someone asking a question about the data rather than about the code.

**Suggested improvement:** Two habits, both cheap. (1) When a feature's premise is "works without X", enumerate every subsystem that gates on X and check each one explicitly — the gate list is short and the failure is otherwise invisible. (2) When writing an authorization rule as a closed list, write the test as a statement of the *principle* the list encodes ("an anonymous caller may record what an anonymous caller can cause"), not of the list's current contents. A test that restates the enumeration cannot distinguish a correct list from a stale one.

**Principle:** An enumerated permission is a snapshot of what the system could do on the day it was written, and it silently narrows as the system grows. Where the consumer of that permission is also designed to fail silently — as measurement, logging and telemetry almost always are — the two correct decisions compose into an outage with no symptom. Look for that pairing deliberately: a closed list plus a swallowed error is a blind spot by construction, not by accident.

### Observation 119: speckit-taskstoissues has no concept of hierarchy, so it flattens the structure it is asked to mirror

**Status:** OPEN
**Date:** 2026-08-08
**Session context:** Founder asked for all four Kafoo epics and their 348 tasks in GitHub issues, with work packages as a second level wherever the project had started using them.
**Skill:** speckit-taskstoissues
**Type:** open-source
**Phase/Area:** Outline, steps 6–7 (issue creation)

**Issue:** The skill creates exactly one flat issue per `T###` task in a single feature's `tasks.md` and stops there. It has no notion of a parent issue for the feature itself, no use of GitHub's sub-issues API, and no way to express an intermediate grouping — so the epic → task and epic → package → task shape the request was about could not be produced by following it. It also assumes a single feature directory (`check-prerequisites.sh` returns one `FEATURE_DIR`), so "all epics" is outside what it can express. The task's real structure had to be built in a purpose-written script instead, and the skill contributed only its title convention (`T001: <description>`) and its deduplication idea.

**Suggested improvement:** Add an optional hierarchy mode: create a parent issue per feature from `spec.md`, link every task issue to it via `POST /repos/{owner}/{repo}/issues/{n}/sub_issues`, and allow one intermediate level supplied by the caller (a grouping file, a phase header, or a label). State the two GitHub limits that constrain the shape — 100 sub-issues per parent and 8 levels of nesting — because a per-epic task count above 100 silently changes the design. Note that a sub-issue takes exactly one parent, so a task claimed by two groups needs a declared tie-break rather than a second link.

**Principle:** A converter that flattens is only correct when the source has no structure. When the source encodes a hierarchy — phases, epics, work packages — a tool that emits a flat list discards the most useful thing it was given, and the loss is invisible because every individual record looks right.

---

### Observation 120: a per-item API workflow needs a stated crossover point where it becomes a script

**Status:** OPEN
**Date:** 2026-08-08
**Session context:** Same task. 348 tasks plus 4 epics plus 20 work packages meant ~945 content-creating GitHub requests: 372 creates, 368 sub-issue links, 205 closes.
**Skill:** speckit-taskstoissues
**Type:** open-source
**Phase/Area:** Outline, step 7, and Pre-Execution as a whole

**Issue:** The skill instructs the agent to create issues one at a time through MCP tool calls, and is careful about read-side pagination while saying nothing about the write side. At this repository's size that prescription is not merely slow, it does not fit: GitHub caps content-creating requests at roughly 500/hour and 80/minute and signals a breach with a 403 plus `Retry-After` rather than a 429, so the run must pace itself and survive multi-minute stalls. Several hundred sequential tool calls also consume the agent's context on tool results that carry no information the agent needs. Neither constraint is mentioned, so the default reading of the skill is a workflow that stalls partway with issues half-created and no record of where it stopped.

**Suggested improvement:** Add a scale note: below roughly 30 tasks, create issues via individual tool calls as written; above that, generate a resumable script and state the three properties it must have — pacing with permanent slowdown on a secondary-limit 403, a state file written before the next call so a re-run resumes instead of duplicating, and a dry-run that prints the plan and counts before anything is created. Deduplication by issue title (already in step 6) is the fallback when no state file exists, not a substitute for one.

**Principle:** Any workflow that repeats a write per item has a size at which per-item agent calls stop being the right mechanism, and the instruction should name that threshold rather than leave the agent to discover it by exhausting a rate limit. Partial completion of a bulk write is the expected case, so resumability belongs in the design, not in the recovery.

---

### Observation 121: a documented warning that an identifier is not unique needs a test, not a reader

**Status:** OPEN
**Date:** 2026-08-08
**Session context:** Backfilling 348 Kafoo tasks into GitHub issues. The run died partway with a 422 from the sub-issues API — "Sub issue may only have one parent" — because state was keyed on the bare `T###`.
**Skill:** speckit-taskstoissues
**Type:** open-source
**Phase/Area:** Outline, step 6 (deduplication) and step 7 (issue creation)

**Issue:** The project's own instructions state plainly that task numbering restarts per epic, so the same `T045` names three different tasks in three different `tasks.md` files. That warning was read before the code was written and the code still keyed on the bare id, because the warning was absorbed as background rather than turned into a constraint. The skill encourages this directly: its deduplication step matches issue titles against `\bT\d{3}\b` and treats a hit as "this task already has an issue", which is only sound when ids are unique across everything being converted. The failure was loud and cheap here — GitHub refused the second parent and the run stopped with nothing corrupted — but the same key collision in a tool without a uniqueness constraint at the far end would have silently attached one epic's issue to another epic's parent.

**Suggested improvement:** In step 6, qualify the identifier by its feature before matching, and state that a bare task id is only assumed unique within one `tasks.md`. Add an explicit precondition to the Outline: assert that ids are unique across the set being converted and stop with the collisions listed if not. Where a multi-feature conversion is in scope, the created issue title should carry the feature too, so a bare id never names two issues.

**Principle:** A warning in prose that an identifier is not unique protects nobody, because reading it and encoding it are different acts. Convert the warning into an assertion the tool runs, and let it fail on the collision it predicts — otherwise the design proceeds on the assumption the document exists to deny.

---

### Observation 122: never derive a record's category from a map built by claim order

**Status:** OPEN
**Date:** 2026-08-08
**Session context:** Same task. Deriving which epic each work package belonged to from the task-to-package ownership map filed one package under a default epic.
**Skill:** speckit-taskstoissues
**Type:** open-source
**Phase/Area:** Grouping / parent resolution

**Issue:** Two units of work claimed the same task id, and a task can have only one parent, so the ownership map was built with first-claimant-wins. One package's entire task list was a single task already claimed by a lower-numbered package, so it contributed no entry to that map at all — and because the package's epic was being read back out of the same map, it fell through to a hardcoded default and was filed under the wrong epic. The visible symptom was a count being off by one in two places; the cause was a category derived from a side effect of contention rather than from the record itself. Nothing in the output looked wrong, which is why it took a count comparison against an earlier run to notice.

**Suggested improvement:** Derive each grouping's parent from its own fields, in a separate pass, before any claim or deduplication runs — then let the claim pass consume that result. Never let a default silently absorb a record missing from a derived map: if a lookup misses, fail or log it rather than substituting a fallback value that will look plausible in the output.

**Principle:** Deduplication is lossy by design, so anything read back out of a deduplicated map inherits the arbitrariness of who won. Compute a record's own attributes from the record, and keep that pass independent of, and earlier than, any pass that resolves contention between records.

---

### Observation 123: a converter is a reader of last resort, and what it trips over belongs back in the source

**Status:** OPEN
**Date:** 2026-08-08
**Session context:** Converting 348 spec-kit tasks into GitHub issues surfaced two defects in the source files that had passed every review and every gate run: a task id recorded twice in one `tasks.md`, and a plan file whose checkboxes contradicted the status of the work packages delivering them.
**Skill:** speckit-taskstoissues
**Type:** open-source
**Phase/Area:** Outline — a validation pass before any issue is created

**Issue:** The skill converts and creates, and never inspects what it is reading. Both defects it walked into were invisible to human review precisely because nothing contradicted anything — the duplicated id was `[x]` in both copies with the same explanatory text, so no reader had a reason to look twice, and the miscount it caused had been quoted onward. A converter is the first thing to read every record in a file mechanically and compare them, so it is the cheapest place these defects will ever be found; discarding that signal and creating issues anyway propagates the defect into a second system, where it is then harder to see because two systems now agree.

**Suggested improvement:** Add a validation pass before creation that reports, without fixing: ids duplicated within a file, ids referenced by a grouping that do not exist in any task file, and checkbox state contradicting any status the project tracks separately. Report and stop, or report and continue behind a flag — but never silently normalise, because reconciling a plan file is a planning decision belonging to whoever owns it. Where the converter must handle a defect to proceed at all, it should say so in the created record rather than absorb it.

**Principle:** Any tool that reads every record in a source mechanically is a free consistency check on that source, and the findings belong upstream where the source can be fixed — not silently accommodated so the conversion can finish. Accommodating a defect quietly is worse than failing on it: it creates a second system that agrees with the first, and agreement between two copies of one mistake reads as corroboration.

---

### Observation 124: a rollup counts the children it has, not the ones you were thinking of

**Status:** OPEN
**Date:** 2026-08-08
**Session context:** After reconciling 113 of 126 tasks in an epic to done and closing every one of their issues, the epic's own progress indicator still read 0%.
**Skill:** speckit-taskstoissues
**Type:** open-source
**Phase/Area:** Hierarchy / parent-child modelling

**Issue:** Where an intermediate grouping level exists, the top-level parent's children are the groupings — not the leaf items. Closing 113 leaf issues moved every grouping to 100% and left the top level at 0%, because nothing had closed the grouping issues themselves. The number was not wrong; it was answering a different question from the one being read off it, and it looked like a bug in the closing pass. The fix was to close a grouping when the project's own status field says the grouping is finished — deliberately not when its children all happen to be closed, because a grouping can have every item delivered and still be open on decisions its owner has not taken, which was true of one grouping here.

**Suggested improvement:** When a hierarchy has three levels, state which level each parent's indicator counts, and close intermediate nodes from the source's own completion field rather than inferring completion from the children. Inferring it would silently overrule whoever owns that field. Verify the top-level indicator explicitly after any bulk close — a parent reading 0% while all its grandchildren are closed is the signature of this mistake.

**Principle:** A hierarchy's progress indicator aggregates its immediate children only, so in a three-level tree the top level tells you about the middle level and says nothing directly about the leaves. Never infer a parent's completion from its descendants when the source of truth has a field for it: all-children-done and owner-says-done are different claims, and the gap between them is usually where the real remaining work is recorded.

### Observation 125: A communication contract that describes a posture gets ignored; one that describes a shape gets followed

**Status:** OPEN
**Date:** 2026-08-09
**Session context:** The founder said he routinely pastes Claude's answers into ChatGPT and asks it to explain what they meant, then supplied a twelve-point specification of the answer format he needs. Kafoo's CLAUDE.md already carried a "Who you are talking to" section saying to lead with the decision, explain in consequence not mechanism, and spell out jargon — every one of those rules was correct and none of them changed the output enough to be usable.
**Skill:** New skill candidate: writing-for-a-non-developer-decision-maker
**Type:** open-source
**Phase/Area:** Project instruction files — the audience/communication section

**Issue:** The failing instructions were all posture statements: adverbs and dispositions ("lead with", "explain in terms of", "briefly"). They are unfalsifiable in a single response, so nothing ever reads as a violation and drift is invisible. The instructions the founder wrote himself were shapes: a bottom line capped at three sentences, four named labels (Problem / Recommendation / Information / Decision needed), a fixed four-beat order for technical decisions, a length ceiling, a mandatory closing line, and a self-check question. Each of those can be checked against a draft and found absent. The founder's own evidence — outsourcing translation to a second AI — was the only reason the gap was detectable at all; without it the original section looked fine.

**Suggested improvement:** When an instruction file governs how the agent writes rather than what it builds, express the requirement as structure the draft either has or lacks — a section order, a word count, a required closing line, a fixed vocabulary of labels, a yes/no check to run before sending. Reserve prose about tone for explaining why the structure exists. Where a rule is being rewritten because the old one failed, record that it failed and what the evidence was, so nobody restores the softer wording as a simplification.

**Principle:** A behavioural rule an agent cannot fail visibly is a rule it will not follow. Convert dispositions into artefacts: instead of "be clear", require a named section, a bounded length, or a check with a yes/no answer. The test of such a rule is whether a reader holding the output can point at the place it is missing — if they cannot, it is a preference, not an instruction, and it will decay into decoration.

### Observation 126: A guard that matches command text will block the prose describing the command

**Status:** OPEN
**Date:** 2026-08-09
**Session context:** Replacing a permission allowlist with a wide-open one plus a PreToolUse hook enforcing four hard blocks. The hook worked on the first try against 36 crafted cases, then blocked the commit that was trying to land it, because the commit message explained which commands the hook blocks.
**Skill:** New skill candidate: writing-tool-call-guards
**Type:** open-source
**Phase/Area:** Guard/hook authoring — pattern scope

**Issue:** A guard that inspects a shell command string cannot distinguish a command from a sentence about that command. The two are the same characters. Every realistic guard therefore has a false-positive class its author will not think to test, because the test cases they write are commands and the failures are prose: commit messages, echo, heredocs, documentation written with a redirect, a grep for the dangerous pattern itself. The failure surfaced here only because landing the guard required writing about it; a guard for something never discussed in commit messages would have shipped with the same defect latent, and each later false positive would look like an unrelated glitch. The fix is to strip what cannot name a target — heredoc bodies and quoted spans — before matching, which also narrows the guard honestly: a quoted path stops being caught, and that residual gap is worth stating rather than papering over.

**Suggested improvement:** When authoring a guard over command text, add prose cases to the allow half of the self-test from the start — a commit message naming the blocked command, an echo, a heredoc — not only the dangerous spellings. Strip heredoc bodies and quoted strings before matching. Where a guard's coverage is genuinely partial after that, record the residual gap next to the rule instead of implying the block is total.

**Principle:** A pattern that matches an action will also match a description of that action, and self-tests written by the guard's author cover the action only. Test the descriptions too. More generally: any filter over a representation, rather than over the thing represented, inherits every ambiguity of that representation — so decide explicitly which regions of the input can name a real target, and match only there.
