---
paths:
  - "apps/**/*.dart"
  - "packages/**/*.dart"
---

# Dart & Flutter

## State management

Riverpod with code generation (`@riverpod`). Not Bloc, not Provider, not setState for anything
beyond local widget state. Run `dart run build_runner build --delete-conflicting-outputs` after
touching an annotated class.

Providers are declared next to the feature they serve, not in a global `providers.dart`.

**There is no `ProviderScope` above the Navigator, and that is why `AddressFormScope` is an
`InheritedWidget`.** E1 shipped without a state-management package; E2 added Riverpod inside the
Meal feature only. A value every screen reads and none writes — the Cook's form of address — would
otherwise have meant a root scope plus converting every plain widget in the tree to a consumer, for
nothing Riverpod does better. It is the documented exception, reasoned in ADR-0010, not a second
pattern to copy. Anything with state, async, or a dependency to override is still Riverpod.

## Layering

```
apps/mobile/lib/features/<feature>/
├── presentation/    widgets + screens. No business logic, no Supabase.
├── application/     providers, controllers. Orchestration only.
└── data/            repository impls. The only layer that touches Supabase.
```

`packages/domain/` holds entities and pure business logic. It has zero Flutter and zero Supabase
imports. If you need either one there, the boundary is being violated — say so rather than adding
the import.

## Errors

No `throw Exception('...')` for expected failures. Use the `Result<T, AppError>` type in
`packages/domain/lib/result.dart`. Exceptions are for programmer error only.

Every user-facing error message is localized and actionable. "Something went wrong" is not
acceptable copy.

## Async

Never `async` in `build()`. Never swallow an error in a `catch` block without either logging it or
returning a `Result.failure`.

## Widgets

- `const` constructors wherever possible
- Prefer composition over long widget files. Over ~150 lines, split it.
- No hardcoded colors, spacing, or text styles — use tokens from `packages/ui/lib/theme/`
- Every screen must render correctly under RTL. Use `EdgeInsetsDirectional`, not `EdgeInsets`, and
  `start`/`end`, never `left`/`right`

## Localization

Strings live in ARB files. `ar` (Egyptian Arabic) is the source locale; `en` is the translation.
Write the Arabic entry first — if you cannot write it, flag the string for founder review rather
than shipping an English-only key.

Do not use Modern Standard Arabic phrasing. The register is conversational Egyptian: how someone in
Cairo actually speaks, not how a news anchor reads.

Numbers, dates, and currency use `intl` with the active locale. Never string-concatenate a price.

## Accessibility

Every interactive widget has a semantic label. Tap targets ≥48dp. Test at 200% text scale — layout
must not clip. Respect `MediaQuery.disableAnimations`.

## Tests

Widget tests for anything with conditional rendering. Golden tests for the design system components
in `packages/ui/`. A test that only asserts "widget exists" is not a test.
