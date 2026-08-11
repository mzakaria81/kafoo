# Design

The visual and voice foundations for Kafoo, as delivered by the design handoff on 2026-08-11.

| File | What it is |
|---|---|
| `DESIGN.md` | **Source of truth.** Palette with reasoning, type scale, spacing, elevation, the six components with every state, and §10, the voice system. Read §10; it is not optional. |
| `handoff-README.md` | The designer's implementation notes — what each reference file shows, the state machine, the accessibility floor, and the list of known gaps. |
| `reference/*.dc.html` | Design references in HTML. Prototypes of intended look and behaviour. **Not production code — do not port them.** Open them in a browser; the tap-target, sunlight and state-cycling toggles are worth using. |
| `reference/screenshots/` | Static previews, for orientation only. `DESIGN.md` and the HTML are authoritative. |

## Where it lives in code

`DESIGN.md` describes values; these are the files that hold them. A value that
appears in a widget or a stylesheet instead of one of these is drift.

| Layer | File |
|---|---|
| Colour, spacing, radius, elevation, motion | `packages/ui/lib/theme/tokens.dart` |
| Type scale and the Arabic line-height rule | `packages/ui/lib/theme/typography.dart` |
| The assembled Flutter `ThemeData` | `packages/ui/lib/theme/theme.dart` |
| The same tokens for the web surface | `apps/web/app/globals.css` |

The contrast, line-height and tap-target claims are checked by
`packages/ui/test/contrast_test.dart`, `typography_test.dart` and
`tokens_test.dart` — computed, not asserted in a comment, so a token nudged
"just a shade lighter" fails the gate rather than shipping.

## Where the code deliberately differs from DESIGN.md

Two places, both documented at the point of difference rather than only here.

1. **Input borders.** `DESIGN.md` §6.2 gives a control's border as
   `border-strong`, which measures 1.54:1 against the surface. WCAG 1.4.11 asks
   3:1 of the boundary of a control, and the web surface had already fixed
   exactly this bug on the search box. No border token in the palette reaches
   3:1, so `KafooColors.borderInput` borrows `text-subtle` (4.66:1) until
   there is a design decision. Same treatment as the borrowed `warning` colour.
2. **The stated contrast ratios.** Every figure in the `DESIGN.md` palette table
   runs about two percent high, and `voice-deep` is given as 8.9:1 where it
   measures 7.36:1. Nothing turns a pass into a fail, so no value was changed —
   but the tests assert the AA threshold rather than the documented number.

## The six components

All six of `DESIGN.md` §6 exist in `packages/ui/lib/widgets/`, plus two the
other six depend on.

| Widget | Notes |
|---|---|
| `KafooButton` | Three variants. Loading keeps the footprint identical; destructive fills solid only while pressed; a disabled button states its reason in its own label. |
| `KafooTextField` | Helper row always reserved, so an error does not shift the form. `latinNumerals` flips one field left-to-right inside a right-to-left form. |
| `MealCard` | The Customer's card. The Cook's name sits *on* the photo. |
| `KafooMealRow` | The Cook's row — the voice-first shape, see below. |
| `KafooFilterChip` / `KafooFilterBar` | 40dp visual, 48dp target, one scrolling line that never wraps. |
| `KafooSheet` | Pinned committing action, scrolling body, capped at 90% height. |
| `KafooEmptyState` | Reason → expectation → one action, plus the failure form that says what survived. |
| `KafooPhotoPlaceholder` | The unshippable image slot. A trust rule, not a styling choice. |
| `KafooGlanceWord` | The closed set of eleven words, as an enum, so a twelfth cannot be added by accident. |

**The Cook's Meal row follows §10, not §6.3.** The two sections of `DESIGN.md`
describe it differently: §6.3 leads with the Meal name at 17px and a small
status badge, §10 makes the price the largest element and replaces the badge
with a glance word. §10 supersedes, and the handoff marks the tap-first screen
as replaced. The widget's doc comment records which was followed, so the
earlier section does not get "restored" as a fix.

**Every widget takes its strings from the caller.** This package cannot reach
the app's ARB files, so labels, semantics and the placeholder warning are
parameters — and the required ones are the rules a caller is not allowed to
skip.

## What is not built yet

**The voice half of every component.** `DESIGN.md` §6 is explicit: "Every
component is undefined until its spoken line is written." These six have their
visual states, their haptic-free tap fallbacks and their screen-reader labels;
none has an assistant line, because Kafoo has no text-to-speech service yet —
`voice_input.dart` is speech-*to*-text only. By the design's own definition
these are half-finished, and building the speaking side is the next piece of
work, not a polish item.

§10's nine voice states, the talk button, the confirmation gate and the
messaging surface do not exist yet either.

`DESIGN.md`'s own "Known gaps" list — loading/skeleton, status badge versus
glance word, the app bar, the warning colour, assistant voice casting, how a
Cook hears a bad Review, and toast/tab bar/pickers/rating input/dark mode — are
**stop-and-ask items, not gaps to improvise around.**

The font is also missing: IBM Plex Sans Arabic is named in the theme but is not
self-hosted in this repository, so the platform default renders instead. It
needs a woff2/ttf subset (Arabic + Latin, weights 400/500/600/700) declared
under `flutter: fonts:` and preloaded on the web surface.
