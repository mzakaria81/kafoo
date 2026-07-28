# Quickstart: verifying a change

This is User Story 1's acceptance test, made runnable. If any step needs a person, US1 has
regressed.

## Prerequisites

Nothing but this repository and a network connection. In a Codespace, `.devcontainer/` installs
everything on create — skip to Verify.

## Setup

```bash
git clone https://github.com/mzakaria81/kafoo.git && cd kafoo

# Flutter brings Dart. Any recent stable channel works; the SDK constraint is ^3.6.0.
git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$HOME/sdk/flutter"
export PATH="$HOME/sdk/flutter/bin:$HOME/.pub-cache/bin:$PATH"

dart pub global activate melos
melos bootstrap
```

`melos bootstrap` resolves all four packages against one lockfile. It also writes IntelliJ
project files, which are git-ignored.

## Verify

```bash
./scripts/verify.sh
```

This is the **only** definition of passing. It runs identically here and in CI — there is no
second, looser standard for local work.

Expected on a clean tree:

```text
── format              ok
── analyze             ok
── tests               ok
── codegen drift       no package uses build_runner yet — skipping
── rls coverage        ok
── no synthetic content ok
── vocabulary          ok
── localization parity ok

PASS
```

**Exit code is the contract**: `0` means pass, non-zero means do not open a pull request. That
exit code is the only interface E0 exposes.

A step that prints *"skipping"* is reporting honestly that it had nothing to inspect. That is
FR-004: emptiness must never be mistaken for correctness. `codegen drift` skips legitimately —
no package depends on `build_runner` yet.

## Prove the gate actually bites

A gate nobody has seen fail is a gate nobody should trust. Each of these should fail, and each
should be reverted afterwards:

```bash
# Canonical vocabulary (Principle VI)
echo '// a vendor comment' >> packages/domain/lib/result.dart
./scripts/verify.sh    # expect: FAILED: vocabulary

# Arabic-first localization (Principle IV) — add an en key with no ar counterpart
# expect: FAILED: localization parity

# RLS in the same migration (Principle III)
printf 'CREATE TABLE demo (id uuid PRIMARY KEY);\n' > supabase/migrations/00000000000000_demo.sql
./scripts/verify.sh    # expect: FAILED: rls coverage
rm supabase/migrations/00000000000000_demo.sql
```

The vocabulary check caught `vendor` in this project's own source during E0. The comments were
changed; the check was not.

## Run a single test

Preferred over the full suite while iterating:

```bash
flutter test apps/mobile/test/app_test.dart
dart test packages/domain/test/result_test.dart
```

## What you cannot do yet

- **Run the app on a device.** `apps/mobile` has no `android/` or `ios/` project;
  `flutter create --platforms=android,ios .` has not been run.
- **Start the database.** `supabase start` needs Docker and there are no migrations to apply.
- **Produce a release.** The deploy workflow detects the missing Android project and says so in
  its job summary rather than failing.

Each of these is US2 or E1 work, tracked in the spec's Delivery Status.
