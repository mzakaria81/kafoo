# Phase 0 research: E0 Foundation

Findings that changed the plan. Each is recorded because it cost time to discover and would cost
the same again.

## 1. Melos 7+ requires a Dart pub workspace, not `melos.yaml`

**Decision**: Declare the workspace in the root `pubspec.yaml` under `workspace:`, carry the
melos scripts in a `melos:` section of that same file, and mark every member package
`resolution: workspace`. Delete `melos.yaml`.

**Rationale**: CI activates melos 8.2.2, which failed with *"Your current directory does not
appear to be within a Melos workspace"* despite a valid-looking `melos.yaml` at the root. Melos 7
moved to Dart pub workspaces; a `melos.yaml` with no root `pubspec.yaml` declaring `workspace:`
is not a workspace at all. Confirmed against the melos getting-started documentation before
changing anything.

**Alternatives considered**: Pinning melos to 6.x would have kept `melos.yaml` working, but pins
the project to a superseded layout and forfeits the single shared lockfile that pub workspaces
give. Rejected as trading a real benefit for a deferred migration.

## 2. Skip-guards must key on something durable

**Decision**: The gate's Dart steps activate on the `workspace:` key in the root `pubspec.yaml`.

**Rationale**: They originally keyed on `melos.yaml` existing. Deleting that file as part of
finding 1 would have silently reverted `analyze` and `test` to skipping — the exact failure mode
E0 exists to end, reintroduced by the fix for a different problem. The guard now keys on the
thing that defines a workspace rather than on one possible spelling of it.

**Alternatives considered**: Removing the guards entirely once the workspace exists. Rejected
because a fresh clone before `melos bootstrap` would then fail confusingly rather than skipping
honestly, and FR-004 requires the gate to report truthfully when it has nothing to check.

## 3. The Dart formatter changed in 3.7

**Decision**: Keep constructs short and unambiguous — single-line test descriptions, no long
argument lists that force a wrapping decision — and drop the `require_trailing_commas` lint.

**Rationale**: Dart 3.7 introduced "tall style" formatting, which wraps long argument lists
differently from the previous formatter. The authoring environment had no Dart SDK, so
`dart format --set-exit-if-changed` could not be run before pushing. Code that is short enough
not to wrap formats identically under both styles, which removes the risk rather than guessing
at it. `require_trailing_commas` interacts awkwardly with tall style and was removed rather than
fought.

**Alternatives considered**: Guessing at tall-style output. Rejected — a wrong guess fails CI on
every file at once. Weakening the format check to non-fatal was also rejected: it would make the
gate lie about formatting, which is worse than a red build.

**Outcome**: The prediction was wrong in a useful direction. When the toolchain was later
installed locally, `dart format` and `analyze --fatal-infos` both passed unchanged.

## 4. `hashFiles()` at job level evaluates before checkout

**Decision**: Guard release steps at step level, after the checkout, using an explicit detection
step that writes to `$GITHUB_OUTPUT`.

**Rationale**: A job-level `if: hashFiles('apps/mobile/pubspec.yaml') != ''` is evaluated against
an empty workspace, because nothing has been checked out when job-level conditions run. It
therefore always yields `''` and skips the job silently on every run — a guard that looks correct
and disables the thing it guards. Found by the `trust-reviewer` agent, not by testing.

**Alternatives considered**: Dropping the guard entirely. Rejected because `apps/mobile` has no
platform projects yet, so an unguarded build would fail rather than skip, and a red deploy on
every merge trains people to ignore it.

## 5. The Android project does not exist

**Decision**: Detect `apps/mobile/android/` and report its absence in the job summary rather than
failing.

**Rationale**: The workspace scaffold created `lib/` and `test/` by hand. `flutter create
--platforms=android,ios .` was never run, so there is no Gradle project to build. Until it is,
`flutter build appbundle` cannot succeed no matter how the pipeline is configured. Saying so
plainly beats a red build whose cause is not obvious from the log.

**Alternatives considered**: Generating the platform projects as part of E0. Deferred — it adds
several hundred generated files and a signing configuration, and belongs with the work that
first needs to install the app on a device.

## 6. Signing material placement

**Decision**: The keystore stays in `$RUNNER_TEMP`, outside the working tree. Only
`key.properties` is written into `apps/mobile/android/`, where Gradle resolves it via
`rootProject.file()`.

**Rationale**: The first attempt passed the path in an environment variable, which neither
Flutter nor Gradle reads — the build would have silently produced an unsigned bundle while the
summary reported success, because that summary derived "signed" from secret presence rather than
from the artifact. Both halves were wrong in the same direction: claiming a property without
checking it.

**Alternatives considered**: Committing a signing config with placeholder values. Rejected —
credentials adjacent to committed files is how they eventually get committed.
