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
