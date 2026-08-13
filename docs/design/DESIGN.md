# Kafoo — Design Foundations

Kafoo is an Egyptian marketplace where home Cooks sell Meals to Customers nearby. Flutter mobile app + Next.js web. Voice-first.

This document is the source of truth for visual decisions. Every rule has its reason beside it, because a rule without a reason gets broken the first time it is inconvenient.

**Read this first — three constraints that override everything else:**

1. **Egyptian Arabic is the source language, not a translation.** Every string is authored in Egyptian conversational Arabic (`ar-EG`) first. RTL is the default layout direction; LTR is the mirrored case. Never Modern Standard Arabic — MSA reads like a government form, and Kafoo is a neighbour's kitchen. Never Lorem Ipsum in any mock or test fixture: fake text hides the fact that Arabic runs ~15% taller and wraps differently than Latin.
2. **The interface is read in direct sunlight on a mid-range Android phone.** Every contrast decision assumes a washed-out screen at 300–400 nits behind a fingerprinted panel. This is why there are no light greys, no thin weights, and no shadow-only affordances.
3. **The interface is spoken before it is seen.** Kafoo is voice-first: the assistant speaks, the user speaks back, and the screen is the *receipt* of that exchange — never the primary teaching surface. Cooks may not read comfortably, so large type comes only from a closed word set recognised by shape, and numerals carry the real information. **Section 10 is not optional reading** — a component without a spoken line is unfinished.
4. **No AI-generated food photography, ever.** Real photos are shot with the Cook in her Kitchen. In any mock, prototype, or placeholder state, an image slot must be an obviously-unshippable placeholder (see *Placeholders* below). A mock that looks shippable is how a fake photo leaks into production.

## Vocabulary — non-negotiable

Use these words exactly, in code identifiers, UI strings, comments, and commit messages.

| Use | Arabic | Never use |
|---|---|---|
| Cook | الطباخة / الطباخ | chef, vendor, seller, partner |
| Customer | العميل | user, buyer, consumer |
| Meal | الأكلة | dish, product, item, SKU |
| Message | الرسالة | chat, DM, thread |
| Kitchen Profile | صفحة المطبخ | restaurant, store, shop, listing |
| Order | الطلب | cart, checkout, transaction |
| Review | التقييم | rating, feedback, stars |

Why: these words decide what the product feels like. "Vendor" and "listing" turn a woman cooking in Maadi into inventory. The vocabulary is load-bearing, not cosmetic.

---

## 1. Visual theme and atmosphere

**The feeling: a neighbour's kitchen.** Warm, hand-made, plainly trustworthy. Not a restaurant chain (no glossy black, no gold, no appetite-engineered red), not a Silicon Valley startup (no gradients, no glassmorphism, no purple, no illustrated blobs).

How that translates into mechanics:

- **Warm neutrals everywhere, never pure white or pure black.** The surface is `#FFFBF7`, text is `#1C1917`. Pure `#FFFFFF` next to terracotta reads clinical, and pure black is a hole in the page. The warm cast also cuts glare slightly outdoors.
- **Borders carry structure, not shadows.** A 1px warm border (`#E7DED3`) is visible in sunlight; a soft shadow is not. Shadows are decoration; borders are information.
- **Generous line-height and roomy tap targets over density.** A Cook checks Orders with flour on her hands; a Customer scrolls one-handed on a bus. Fitting one more row on screen is never worth a mis-tap.
- **Trust comes from the person, not the polish.** The Cook's name and face sit high in any Meal presentation — above or over the photo, not buried below the price.
- **Voice is a first-class state with its own colour.** Everything else in the palette is warm; listening/speaking states are the one cool colour in the system, so "I'm hearing you" can never be confused with "buy this."
- **Copy is spoken, not written.** "معلش، الطلب مانفعش يتبعت" — an apology a person would actually say. Not "خطأ في العملية".

---

## 2. Colour palette

All ratios below are measured against the surface `#FFFBF7` unless stated. **Every text pair is WCAG AA (4.5:1) or better; interactive fills are AA against both the surface and their own label.** Sunlight compresses perceived contrast, so AA is the floor, not the goal — where a token could have been lighter, it was darkened instead.

| Token | Hex | Role | Contrast | Why this value |
|---|---|---|---|---|
| `primary` | `#C2410C` | Primary actions, active filter chips, brand accent | 5.1:1 on surface · 5.2:1 vs white label | Terracotta and red pepper. Warm, unmistakably Egyptian, and reads as "home" rather than "chain." Retained from the founder's original palette — it was already right. |
| `primary-deep` | `#9A3412` | Coloured *text*, links, secondary button labels, pressed primary fill | 7.2:1 | `primary` is fine as a large fill but thin Arabic strokes at 14–16px sit too light against the surface. Text needs a darker step. |
| `primary-tint` | `#FFF7ED` | Secondary button fill, empty-state medallion, informational panels | — | A wash, not a colour. Lets a secondary action feel connected to primary without competing with it. |
| `primary-border` | `#F0C9A8` | Secondary button and tint-panel borders | — | Defines the edge of a tinted surface, which would otherwise dissolve into the background outdoors. |
| `surface` | `#FFFBF7` | App background, cards | base | White warmed by one step. Reduces glare and stops the terracotta looking synthetic. |
| `surface-raised` | `#FFFFFF` | Rows and panels sitting *on* the surface | — | Pure white is used only as a lift against the warm surface — never as the page background. |
| `surface-sunken` | `#FAF5F0` | Table headers, draft-state fills, subtle wells | — | One step darker than the surface for zones that recede. |
| `text` | `#1C1917` | Primary text | 17.1:1 | Near-black with a brown cast, so it doesn't cut against the warmth. |
| `text-muted` | `#57534E` | Secondary text, metadata, helper text | 7.5:1 | Deliberately dark for a "muted" token. Anything lighter (the usual `#78716C`+ greys) becomes unreadable in sunlight. |
| `text-subtle` | `#78716C` | Non-essential annotation only — never a price, label, or instruction | 4.8:1 | Passes AA but only just; treat as the last legible step and never put required information here. |
| `text-disabled` | `#A8A29E` | Disabled control labels | 2.9:1 | **Intentionally sub-AA.** Failing contrast is the signal that the control is inert. Never use for readable content. |
| `voice` | `#0F766E` | Listening / speaking / transcribing states, tap-target debug bounds | 5.4:1 · 5.5:1 vs white label | Blue-teal, the only cool colour in the system. Reserving a hue for voice means the mic state is identifiable before any word is read. |
| `voice-deep` | `#115E59` | Text on `voice-tint`, assistant speech, «محفوظ» glance word | 8.9:1 | `voice` is a fill colour; assistant speech set as text needs the darker step, same relationship as `primary` → `primary-deep`. |
| `voice-tint` | `#F0FDFA` | Voice panels, assistant speech backgrounds, hear-again buttons | — | Pairs with `voice-deep` at AAA. Human message bubbles must never use this — teal means the machine is talking. |
| `error` | `#9F1239` | Destructive actions, validation failures, offline | 7.9:1 | **Replaces the original `#B91C1C`.** That red sat in the same hue family as `#C2410C`; in sunlight the two washed out to the same colour and a normal button became indistinguishable from an error. Crimson/wine separates cleanly by hue, not just by lightness, and gains 1.6 ratio points. |
| `error-tint` | `#FEF2F2` | Error field fills, destructive button rest state | — | |
| `error-border` | `#F3B8C4` | Error field and destructive button borders | — | |
| `success` | `#15803D` | Order confirmed, Meal published | 4.9:1 | The darkest green that still reads as green. Lighter leaf greens drop below 4.5:1 on a warm surface. |
| `success-tint` | `#F0FDF4` | Success panels, published-status badges | — | |
| `warning` | `#9A3412` *(borrowed)* | "Unavailable today", paused Meals | 7.2:1 | **Known gap.** The palette has no dedicated warning hue; deep terracotta currently stands in and reads as "paused," not "wrong." If paused states spread beyond the Meal list, promote this to its own token — a real amber would need to be very dark (`#92400E`-ish) to pass AA on a warm surface. |
| `border` | `#E7DED3` | Default dividers and card edges | decorative | Warm hairline. Use this instead of a shadow wherever structure must survive sunlight. |
| `border-strong` | `#D6CCC0` | Input borders at rest, drag handles | decorative | Inputs need a heavier edge than cards — an empty field must be visibly a field. |

### Semantic mapping (implement as named tokens, not hex literals)

- **Action:** primary = `primary` fill / white label. Secondary = `primary-tint` fill / `primary-deep` label / `primary-border`. Destructive = `error-tint` fill / `error` label / `error-border`, filling solid `error` only while pressed.
- **Status:** published → `success` on `success-tint`; draft → `text-muted` on `surface-sunken` with a **dashed** border; unavailable → `warning` on `primary-tint`; archived → `text-subtle` on `surface-raised`.
- **Feedback:** error → `error`; confirmation → `success`; listening → `voice`.
- **Never** use `error` for a normal emphasis, and never use `primary` for a warning. One hue, one meaning.

### Dark mode

Not defined yet. Deliberate: the primary usage context is bright daylight, and a dark theme built without that testing would be guesswork. If it is added, `primary` must lighten (roughly `#FB923C`) because terracotta on dark fails AA as a text colour.

---

## 3. Typography

**Font: IBM Plex Sans Arabic.** Self-hosted (see *Loading*).

> **What actually shipped, 2026-08-10: four weights — 400, 500, 600, 700.** Not 300–700. The 300 and
> lighter faces are below the weight floor this same section sets for Arabic body text, because thin
> strokes vanish outdoors — so bundling them would have shipped weights the rules forbid using.

Why it wins, and what it beat:

- **IBM Plex Sans Arabic — chosen.** Drawn for screens first: large dots (nuqaṭ), open counters in ع/ه/م, and sīn teeth that don't flatten at small sizes. Five real weights drawn (four bundled), so hierarchy comes from weight rather than from size — which matters when the smallest usable size is already 13px. Clean without being cold.
- **Cairo — strong runner-up, defensible.** Egyptians see it daily, so it reads as familiar, and familiarity buys trust faster than beauty does. Rejected only because its 300/400 weights thin out in sunlight. If it is ever adopted, use 600+ exclusively.
- **Tajawal — rejected.** Geometric and corporate; reads like a telecom bill, not a kitchen.
- **Almarai — rejected.** Warm and likeable, but only four weights with no 500/600, so hierarchy would have to be built from size alone.
- **Noto Sans Arabic — fallback only.** Universally available, no personality. Keep it in the font stack as the fallback so a failed webfont degrades legibly.

Stack: `'IBM Plex Sans Arabic', 'Noto Sans Arabic', system-ui, sans-serif`.

### The line-height rule (the single most important typographic decision)

**Arabic runs at ~0.15 more line-height than Latin at the same size.** Arabic stacks marks above and below the baseline — hamza, shadda, sukun, and the descenders of ج/ح/ع — and at Latin leading these collide between lines. So body text is **16/1.75 in Arabic, 16/1.6 in Latin**. Do not "normalise" the two: a shared value either wastes space in Latin or breaks Arabic.

Also: never apply `letter-spacing` to Arabic. Arabic is cursive; positive tracking severs the joins and produces broken-looking words. Tracking is allowed on Latin eyebrow/label text only (`0.06em` max).

### Scale

| Role | Size | Weight | Line-height | Use | Rationale |
|---|---|---|---|---|---|
| Display | 40px | 700 | 1.35 | Welcome / onboarding only | Tight leading is safe because it is one or two lines and never sits in a paragraph. |
| Screen title | 32px | 700 | 1.4 | First line of a screen | |
| Section | 24px | 600 | 1.45 | "أقرب المطابخ ليك", sheet titles | 600 not 700 — at 24px, bold Arabic starts to close its counters. |
| Meal name | 20px | 600 | 1.5 | Card and row titles | |
| Body large | 18px | 400 | 1.75 | Voice assistant replies, primary buttons | Voice output is read at arm's length or glanced at while cooking. |
| Body | 16px | 400 | 1.75 | **Default for everything** | Also the minimum for any input field — smaller triggers iOS zoom-on-focus and is hard to proof-read in sun. |
| Body small | 14px | 400 | 1.7 | Metadata under a title | |
| Label | 14px | 600 | 1.4 | Buttons, tabs, field labels | Weight carries the emphasis so the size can stay small. |
| Caption | 13px | 400 | 1.6 | **Floor.** Legal, annotation | Never a price, never a button, never an instruction. If information matters, it is ≥14px. |
| **Glance word** | 20px (row) / 32px (verdict) | 700 | 1.4 | Status from the closed set in 10.4 | Recognised by shape, not read. Fixed size per context so the silhouette is learnable. |
| **Numeral** | 34px (row) / 48–64px (verdict) | 700 | 1.2–1.25 | Price, count, time | The largest type in the system: numbers are read by nearly everyone, words are not. |

Rules: never below 13px. Never weight <400 for Arabic body text (thin strokes vanish outdoors). Prices are always ≥18px/700 — the number is the decision the Customer is making. Use Arabic-Indic numerals (١٢٠) in Arabic UI for prices, counts, and distances; keep Western numerals (`01012345678`) with `dir="ltr"` for phone numbers, OTP codes, and IDs, since those are entered on a Latin numeric keypad and copy-pasted.

### Loading

**Flutter (`apps/mobile`) — what shipped.** Four full TTF faces bundled in the app under
`assets/fonts`, declared in `pubspec.yaml`, 968 KB raw and about 415 KB compressed in the APK. No
`swap`, no `preload`, no subsetting: none of those concepts exist in a bundled app, the font is
present at first frame, and there is no round-trip to be slow. The `google_fonts` package was
rejected deliberately — it downloads at first render, which on an Egyptian mobile network is a blank
screen followed by every line reflowing.

**Web (`apps/web`) — not done, and one trap to avoid.** `apps/web/app/globals.css` is still on
`system-ui` with a Latin-metric fallback stack, which is the exact reflow the line-height rule above
exists to prevent. When it is addressed: self-host the woff2 subset (Arabic + Latin, weights
400/500/600/700) with `font-display: swap` and a `preload` on the 400 and 600 faces, and keep the
fallback stack Arabic-first.

> **A subset is a Modified Version under the SIL Open Font License, and the OFL then forbids the
> Reserved Font Name.** A subset served as "IBM Plex Sans Arabic" would be the only licence problem
> Kafoo has. Rename it — `Kafoo Arabic`, or anything without "Plex".

---

## 4. Spacing and layout

**Scale: 4 / 8 / 12 / 16 / 24 / 32 / 48.** The founder's original 4/8/16/24/32 kept; 12 and 48 added.

| Step | Use | Why it exists |
|---|---|---|
| 4 | A line and the line immediately under it (title → subtitle) | Sub-4 spacing is invisible; sub-pixel tuning is not a design decision. |
| 8 | Icon and its word, badge and its title | The tightest grouping that still reads as two things. |
| 12 | **Added.** Between elements inside one row (thumbnail ↔ text ↔ action); between chips | The gap that was missing. 8 makes a Meal row look cramped, 16 makes it fall apart into pieces. This is now the most-used value after 16. |
| 16 | Card padding, gap between cards, form field gaps | Default. When unsure, 16. |
| 24 | Screen gutters on mobile, section padding inside cards | Full-width mobile content sits 24 from each edge — 16 feels like the text is falling off the phone. |
| 32 | Between two unrelated groups on one screen | |
| 48 | **Added.** Between major sections; also the minimum tap target | One number doing two jobs on purpose: the rhythm of the page and the size of a finger are the same unit, so vertical spacing never accidentally shrinks a target. |

Layout principles:

- **Flex/grid with `gap`, never margins on siblings.** Gap survives reorder, insertion, and deletion; margin chains don't.
- **Logical properties only** (`padding-inline-start`, `margin-inline-end`, `inset-inline-start`). Never `left`/`right`. RTL is the default direction and a hardcoded `left` is a bug that only shows up in the mirrored build. In Flutter: `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`.
- **Content max-width on web: 720px for prose, 1120px for a page.** Arabic at 16px becomes hard to track past ~80 characters per line.
- **Card radius 24px, row/panel 16px, control 12px, pill 999px.** Radius decreases as the element gets smaller and more functional — a 24px radius on a 48px button eats its own corners.
- **One screen, one primary action.** If two things look primary, neither is.

---

## 5. Elevation

Four levels. Elevation is expressed by **border and background first, shadow second** — a shadow is nearly invisible on a cheap panel in sunlight, so nothing may depend on it alone.

| Level | Treatment | Use |
|---|---|---|
| 0 — flat | `surface`, no border | Page background |
| 1 — bordered | `surface-raised` + 1px `border` | Cards, Meal rows, panels. **The default.** Structure without shadow. |
| 2 — lifted | `surface-raised` + 1px `border` + `0 1px 3px rgba(28,25,23,0.06)` | A card that must read as pickable-up (a featured Meal) |
| 3 — floating | `surface` + `0 8px 24px rgba(28,25,23,0.12)` + scrim `rgba(28,25,23,0.55)` behind | Bottom sheets, dialogs |

Shadow colour is always the text brown at low alpha, never neutral grey or black — a grey shadow on a warm surface goes visibly cold. Never more than one level-3 surface at a time; a sheet on a sheet means the flow is wrong.

---

## 6. Components and every state

Six components, plus the voice components in 10.2 and the messaging components in 10.12 — those are equally binding, not extras. Anything not on these lists does not exist yet: say so rather than inventing it locally.

**Every component is undefined until its spoken line is written.** A visual spec with no Egyptian-Arabic line for the assistant to say is half a component (10.1).

### 6.1 Button

Shared: `border-radius 12px`, `padding 16px 24px`, `min-height 48px` (56px when it is the screen's single committing action), label 16/600 (18/600 for a full-width committing action), `width: 100%` in a bottom bar or sheet. Padding — not a fixed height — determines size, so the button grows with scaled text instead of clipping it.

| Variant | Rest | Pressed | Disabled | Loading |
|---|---|---|---|---|
| **Primary** | `primary` fill, white label | `primary-deep` fill, `scale(0.98)` | `#F0E9E1` fill, `text-disabled` label | `primary` fill + 18px spinner (2.5px ring, white top, 0.7s linear) + changed label ("بيتبعت...") |
| **Secondary** | `primary-tint` fill, `primary-deep` label, 1.5px `primary-border` | `#FDE7D3` fill, `primary` border | `surface-raised` fill, `border` border, `text-disabled` label | tint fill + spinner in `primary-deep` |
| **Destructive** | `error-tint` fill, `error` label, 1.5px `error-border` | solid `error` fill, white label | `surface-raised`, `border`, `text-disabled` | tint fill + spinner in `error` |

Rationale: destructive rests as an outline and only fills solid while pressed, so an irreversible action can't be hit by muscle memory — but it still confirms with full colour under the finger. Disabled states state the *reason* in the label ("المطبخ مقفول دلوقتي", "الطلب خرج، مش ينفع يتلغي") rather than greying out silently; a disabled button with no explanation is a dead end. Loading replaces the label with an Egyptian-Arabic present continuous and keeps the button's footprint identical to avoid layout shift.

### 6.2 Text input

**Demoted by the voice decision (10.7).** Typing Arabic on a phone keyboard is the hardest thing this product asks of a Cook. The input is a deliberate choice the user makes, never the consequence of the assistant failing to understand. It keeps full spec because it must work perfectly when chosen.

Shared: `min-height 48px`, `padding 14px 16px`, `border-radius 12px`, `border 1.5px`, text 16/1.5 (16px minimum prevents mobile zoom-on-focus), label above at 14/600, helper text below at 13/1.6.

| State | Treatment |
|---|---|
| Empty | `border-strong` border, `text-subtle` placeholder |
| Filled | `#A8A29E` border |
| Focused | `primary` border + `0 0 0 3px rgba(194,65,12,0.18)` ring, label turns `primary-deep` |
| Error | `error` border, `error-tint` fill, label and message in `error` |
| Disabled | `surface-sunken` fill, `border` border, `text-disabled` text |

Rules: **helper text is always present and always occupies its row**, so an error message replaces it instead of pushing the form down — a jumping form makes people lose their place mid-entry. Error messages say what to do, with the number ("الرقم ناقص رقمين. لازم ١١ رقم."), never "Invalid input". Numeric and Latin-only fields (phone, OTP, address numerals) get `dir="ltr"` + `text-align: left` inside the RTL layout; the field is still labelled and positioned RTL. Focus ring is a 3px halo, not an outline-only change — a colour-only shift is invisible in sunlight. Multi-line fields use body line-height 1.75 and `resize: vertical` on web.

### 6.3 Meal card

Two sizes, one component.

**Card (Customer browsing, 340px):** placeholder photo 180px tall, top-radius 24px; the **Cook's identity chip overlays the bottom-inline-end of the photo** — 32px avatar + name 14/600 on `rgba(255,251,247,0.95)` pill. Body padding 16: Meal name 20/600, meta 14/1.7 `text-muted`, Review score in `primary-deep` 600, then a row with price (24/700 + "جنيه" at 15/500 `text-muted`) and the primary button. Sold-out state: `rgba(28,25,23,0.45)` scrim over the photo + centred pill, button becomes disabled "نبّهني بكرة", card at 0.85 opacity.

Why the Cook sits *on* the photo: trust in Kafoo comes from the person. Below the price, her name becomes a footnote to a transaction.

**Row (Cook's own Meal list, full width):** 72×72 placeholder thumb (radius 14), 12px gap, name 17/600 + status badge inline, meta 14/1.7, price 18/700, and a 48×48 `···` action button opening the bottom sheet. `surface-raised` + 1px `border`, radius 16. Unavailable and archived rows render at 0.6 opacity — present but clearly not selling.

The price/button row **wraps** rather than shrinking: at 200% text scale it stacks, and the button takes `flex: 1 1 auto`. Verified at 200% with no clipping.

### 6.4 Filter chip

Pill, `padding 10px 16px`, `min-height 40px` visual, label 15/600, `white-space: nowrap`. Unselected: `surface-raised` + 1.5px `border-strong`, `text` label. Selected: `primary` fill, white label. Removable: selected + `×` glyph. Unavailable: dashed `border`, `text-disabled`, states why ("حلويات — مفيش دلوقتي"). "Clear all" is plain `primary-deep` text, never a chip — it is not a filter.

**The chip is 40px visually but carries a 48px hit area** (padding on the wrapper, or a Flutter `MaterialTapTargetSize.padded` equivalent). A row of 48px-tall chips looks like a row of buttons and dominates a screen it should merely qualify; the finger gets 48 anyway. Chips scroll horizontally in one line, never wrap to a second row on mobile — a wrapping filter bar reflows the list every time a filter changes.

### 6.5 Bottom sheet

Radius 26px top, scrim `rgba(28,25,23,0.55)`, 44×4 drag handle centred with 24 below it, content padding inline 24 / bottom 24, title 24/600, `max-height: 90vh` with internal scroll.

Rules: the handle is always present because the first thing anyone does is try to drag it down. Something behind the sheet must stay visible — if it fills the screen, people don't know it can be dismissed. The **committing action sits at the bottom**, within thumb reach, with the summary above it, so a Customer reading fast sees the total before the button. Cancel is plain `text-muted` text, not a coloured button: retreat must be easy but must not compete. Actions are inline-start aligned (`text-align: right` in RTL) when the sheet is a menu. When text scales, the sheet body scrolls and the bottom action stays pinned.

### 6.6 Empty state

Centred column, gap 16, 72px medallion (dashed `primary-border` on `primary-tint`; `error-border` on `error-tint` for failures), title 20/600, body 16/1.75 `text-muted`, then one primary action and at most one secondary.

Rules: **reason → expectation → one action.** "مفيش مطابخ فاتحة جمبك دلوقتي / الطباخين بيفتحوا من حوالي ١١ الصبح / نبّهني أول ما يفتح." No large illustrations (they are decoration where an answer is needed, and they are the first thing to look wrong on a mid-range screen), no apologies, no dead ends. Failure states must say what is preserved ("اللي قولته محفوظ", "دي آخر نسخة محفوظة من ٩:٤٠ الصبح") — a Cook on a dropped connection needs to know her work survived. Where cached data exists, show it at 0.45 opacity below the failure message rather than showing nothing.

### Known gaps — not yet in the system

A coding agent hitting one of these should **stop and ask**, not improvise:

1. **Status badge** — needed by the Cook's Meal list; currently drawn as a smaller, non-interactive chip. It must not be visually identical to a filter chip, or Cooks will tap "مسودة" expecting it to change. Promote to component 7.
2. **Loading / skeleton state** — no defined treatment for the gap between screen open and data arrival. On Egyptian networks this is a state people live in. Needed: a hairline skeleton at the Meal-row footprint.
3. **App bar / top bar** — used ad hoc on the Meal list (title 24/600 + count 13/1.6 + 40px avatar, 1px bottom border). Needs formalising.
4. **Floating vs pinned add action** — the Meal list pins the primary button in a bottom bar rather than floating it, because a FAB covers the last row and, in RTL, sits under the right hand where the thumb already occludes. If a FAB is wanted, that is a new decision.
5. **Warning colour** — see the palette note.
6. **Toast / snackbar, tab bar, date & time pickers, rating input** — undefined.

### Placeholders

Any image slot in a mock or unshipped state renders as: `repeating-linear-gradient(45deg, #F0E9E1 0 10px, #FAF5F0 10px 20px)` + 1.5px dashed `#C7B9A8` + a dashed `error`-coloured label reading "مكان صورة مؤقت — مش هينزل في النسخة النهائية". It must be impossible to mistake for a photograph, at a glance, at thumbnail size. **Do not generate, source, or synthesise food imagery under any circumstances** — including "temporary" images to make a demo look better. Real photography is shot with the Cook.

---

## 7. Touch targets, scaling, and responsive behaviour

- **The talk button is 88dp**, the confirmation «أيوة» is 72dp, and settings switches are 76×48dp. The most important control on a screen is never merely compliant — it is unmissable by thumb without looking.
- **48×48dp minimum on everything else interactive**, including icon buttons, avatars that navigate, and chips. Where an element is visually smaller, the target is expanded around it. Reason: 48dp ≈ 9mm ≈ an adult fingertip, and Kafoo is used standing up, walking, one-handed, with wet hands.
- **8dp minimum between adjacent targets.**
- **Bottom 96dp is thumb territory.** The primary action lives there. Destructive actions never do.
- **Must survive 200% text scale with no clipping.** Verified on the Meal card. Achieved by: padding-based sizing (never fixed heights on text containers), `min-height` instead of `height`, wrapping rows (`flex-wrap`) so a price/button pair stacks instead of squeezing, `text-wrap: pretty` on headings, scrollable sheets with pinned actions, and no single-line truncation on a Meal name — a Cook must be able to read her own Meal's full name.
- **Never truncate a price, a total, or a Cook's name.** Wrap instead.
- **Breakpoints (Next.js site):** <600 single column, 24 gutters; 600–1023 two columns; ≥1024 three columns capped at 1120 page width, prose at 720.
- **Test matrix:** 360×640 (the real floor for mid-range Android), 390×844, 200% text scale, and dropped-connection. If it holds at 360 wide with 200% text, it holds everywhere.
- **Motion:** 150–250ms, `ease-out` for entering, `ease-in` for leaving; spinner 0.7s linear. Respect `prefers-reduced-motion` — replace movement with an opacity change. Nothing bounces or springs; a kitchen is calm.

---

## 8. Do's and don'ts

**Do**

- Author every string in Egyptian Arabic first, and read it aloud — if a person wouldn't say it, rewrite it.
- Use logical/directional properties so RTL and LTR come from one layout.
- Reach for `border` before `box-shadow` when the boundary carries meaning.
- Give disabled and error states a human reason.
- Keep the Cook's identity high in any Meal presentation.
- Let containers grow with their content.
- Use `voice` teal exclusively for voice states.
- Say "this component doesn't exist yet" instead of designing a one-off.
- Write the spoken Egyptian-Arabic line for every state, at the same time as the visual.
- Read a message back verbatim before sending it to another person (10.12).
- Keep assistant speech (teal) and human messages (white / terracotta bubbles) in separate colour families.

**Don't**

- Don't use MSA, machine-translated Arabic, or Lorem Ipsum — not even in tests.
- Don't apply `letter-spacing` to Arabic.
- Don't use Latin line-heights on Arabic text.
- Don't hardcode `left`/`right`, or mirror by flipping a whole canvas.
- Don't put required information in `text-subtle` or any grey lighter than `text-muted`.
- Don't use `error` red for emphasis, or `primary` for warnings.
- Don't generate or source food photography. Ever.
- Don't add gradients, glassmorphism, purple, neon, or illustrated mascots.
- Don't set text below 13px, or below 14px for anything that matters.
- Don't rely on hover — the primary platform has no pointer.
- Don't nest bottom sheets, or stack two primary actions on one screen.
- Don't let a filter chip and a status badge look alike.
- Don't set large Arabic text that isn't in the closed glance-word set (10.4).
- Don't rewrite, tidy, or formalise a person's dictated words — transcribe them (10.12.1).
- Don't let the assistant speak in a Cook's name; it is a pen, not a spokesperson.
- Don't animate a listening indicator from anything other than the real microphone level.
- Don't let silence confirm, send, or publish anything.
- Don't shrink a tap target to fit a layout; change the layout.

---

## 9. Prompt guide for future work

Paste the relevant block when asking an agent to build on this system.

**Standing context (include in every request):**

> Kafoo — Egyptian marketplace where home Cooks sell Meals to Customers nearby. **Voice-first: the assistant speaks, the user speaks back, the screen is the receipt.** Follow `DESIGN.md` exactly, including section 10 on voice; it is the source of truth. Every component needs a spoken line in Egyptian Arabic, a haptic, and a tap fallback — a component without a spoken line is unfinished. Assume Cooks may not read comfortably: large text comes only from the closed glance-word set (10.4), and numerals carry the real information. Egyptian conversational Arabic (`ar-EG`), RTL default — author copy in Arabic, never translate from English, never MSA, never Lorem Ipsum. Vocabulary is fixed: Cook, Customer, Meal, Kitchen Profile, Order, Review — never chef, vendor, restaurant, dish, product, listing, buyer, user. Use the named tokens from DESIGN.md, not hex literals. 48dp minimum tap targets. Must hold at 360px wide and 200% text scale. Designed for direct sunlight on mid-range Android. No AI-generated food imagery — image slots use the DESIGN.md placeholder treatment.

**Building a new screen:**

> Build <screen> voice-first per DESIGN.md section 10 — say what the assistant speaks on arrival and what the screen confirms. Use only the six components in §6 plus the voice states in 10.2. If something is missing, stop and list what's missing instead of inventing it. Show the full, empty, and failed-to-load states. All copy in Egyptian Arabic. Name the exact tokens and spacing steps you used.

**Adding a component:**

> Propose <component> as an addition to DESIGN.md §6. Define every state (rest, pressed, disabled, loading, error where applicable), reuse existing tokens and the 4/8/12/16/24/32/48 scale, and give the rationale for each choice. Show it in Egyptian Arabic RTL alongside two existing components so I can check it belongs. Flag any new token it needs.

**Reviewing an implementation:**

> Audit this against DESIGN.md. Report: contrast failures (AA, on `#FFFBF7`), tap targets under 48dp, clipping at 200% text scale, hardcoded left/right, letter-spacing on Arabic, Latin line-heights on Arabic, banned vocabulary, text below 14px carrying real information, and any hex literal that should be a token. List findings with file and line; don't fix silently.

**Writing copy:**

> Write this in Egyptian conversational Arabic, the way a neighbour would say it out loud — warm, short, no formality, no MSA. Errors apologise like a person and say what to do next. Empty states give the reason, what to expect, and one action. Never blame the Customer or the Cook.

---

## 10. Voice-first system

This section supersedes any earlier assumption that the screen is the primary surface. Reference: `Kafoo Voice Foundations.dc.html` and `Kafoo Cook Meal List v2 Voice.dc.html`.

### 10.1 The five principles

1. **The screen confirms; it does not teach.** Everything visible was spoken first. A screen that presents information the user has not heard has failed the person most likely to be harmed by that.
2. **The assistant replies in its own words — there is no transcript.** It says what it understood ("تمام، محشي بمية وعشرين") rather than showing verbatim ASR text. A paraphrase exposes a misunderstanding immediately; small verbatim text hides it, and cannot be read by the person who needs it most.
3. **Reversible actions happen without asking; irreversible ones need a spoken yes.** Search, filter, navigation, and draft-writing execute immediately and are announced aloud. Publishing a Meal, confirming or cancelling an Order, and changing the price of a published Meal are read back and wait for «أيوة».
4. **Every state reaches the user three ways: visual, spoken, haptic.** A kitchen is noisy, a street is bright, a phone may be face-down. Any one channel alone must be sufficient.
5. **Tap is a complete alternative, not a degraded one.** Everything doable by voice is doable by tap. People stop talking on buses, around other people, and when tired.

### 10.2 Voice states — all nine are components

Each state defines **four** things: visual treatment, the spoken line in Egyptian Arabic, the haptic, and the tap fallback. A state missing its spoken line is not implemented.

| State | Visual | Spoken | Haptic |
|---|---|---|---|
| Idle / invitation | 88px teal orb, mic glyph, one-line hint | «أنا معاك. دوسي واتكلمي.» once on arrival | none |
| Listening | expanding rings + 5 amplitude bars **driven by real input level** | silence | one short pulse at start |
| Thinking | 3 blinking dots in the orb, visible within 400ms | silence; after 2s «لسه معاك، ثانية.» | none |
| Speaking | light ring around orb + the spoken sentence shown large | reply in Egyptian Arabic, max 3 sentences | two short pulses before speaking |
| Didn't catch | orb turns deep terracotta `#9A3412` | «معلش، مافهمتش. قوليها تاني؟» — once | one long pulse |
| Correcting | only the changed value animates and enlarges | repeats the new value aloud, always | two short pulses |
| Interrupted | speech stops mid-sentence, returns to listening, no message | none | one short pulse |
| Offline / queued | dashed teal outline orb + queued-audio marker | «مفيش نت. كلامك محفوظ وهيتبعت أول ما النت يرجع.» | one long pulse |
| Too noisy | all bars high and static | «الدوشة عالية — قرّبي الموبايل من بوقك وقولي تاني.» | one long pulse |

Amplitude bars must reflect the actual microphone level. A fake animation that moves while the mic is muted or broken destroys trust in every other state.

### 10.3 The talk button

- **88px diameter**, bottom centre, 24 from the bottom edge, ≥24 clear space all round, and **no other control inside that radius**. Larger than the 48dp minimum because it is found by thumb without looking, sometimes with wet hands. Bottom *centre*, not inline-end: it is not part of the reading order, and hand preference varies.
- **Hold to talk; a single tap locks recording** for long descriptions. No always-listening mode — kitchens are shared spaces, and an open mic frightens people, reasonably.
- A brief release (<300ms) does not end recording; it continues one more second, because thumbs slip.
- **Acknowledge within 150ms** (haptic + orb growth) even when recognition takes seconds. Half a second of silence reads as "the button didn't work," so the user taps again and cuts off their own speech. Thinking state appears before 400ms. There is never a silent, still moment.

### 10.4 Glance words — the closed set

Because reading cannot be assumed, **large Arabic text is a closed vocabulary of nine words**, each always at the same size, weight, colour, and position, so it is recognised by silhouette rather than read:

منشورة (`success`) · مسودة (`text-muted`, dashed) · مش متاحة (`warning`) · أرشيف (`text-subtle`) · طلب جديد (`voice`) · وصل (`success`) · اتلغى (`error`) · محفوظ (`voice-deep`, dashed) · مفيش نت (`error`)

Rules: **20px/700 in a list row, 32px/700 as a screen verdict.** Colour must carry the same meaning as the word, redundantly — if the word is not read, the colour alone must land. **Never introduce a tenth large word without adding it here**; an unrecognised shape is worse than no word.

### 10.5 Numerals are the largest thing on any screen

Numbers are read by nearly everyone, including people who don't read words comfortably. So **price, count, and time take the largest type in the system — 34px/700 in a row, 48–64px/700 as a verdict** — in Arabic-Indic numerals, never abbreviated (no "١.٢ ألف"). A Meal name drops to 14px `text-muted`: present, spoken aloud on tap, but **never the only thing distinguishing two options.**

> If the only difference between two choices is set in small text, the screen has failed.

### 10.6 The confirmation gate

For any irreversible action the assistant reads the whole thing back, then waits.

- Visual: large numeral + one glance word + the spoken sentence shown in full.
- Two targets: **«أيوة» at 72px min-height, solid `success`**; **«لأ» at 56px, outline only.** Green is larger because it is the common case; both are unmissable.
- **Silence never confirms.** No timeout accepts. The question repeats once after 8 seconds, then waits indefinitely.
- After execution: announce it («تمام، الأكلة منشورة») and keep an undo visible for two minutes — even for nominally irreversible actions.
- Voice and tap both answer the gate, always, at the same time.

### 10.7 Recognition failure ladder

Egyptian Arabic recognition will fail on names and household words. Descend exactly three rungs, never loop:

1. **Ask again, once** — «معلش، مافهمتش. قوليها تاني؟» A third identical prompt makes the app feel stupid.
2. **Ask a narrower question** — «الأكلة اسمها محشي ورق عنب؟ قولي أيوة أو لأ.» Two-word answers are recognised far more reliably than open speech.
3. **Fall back to tap, unprompted** — «خلاص، هوريكي الاختيارات وانتي دوسي على اللي عايزاه.» Options as photos + large numerals + glance words. **Never ask her to type.** Typing Arabic on a phone keyboard is the hardest thing this product could ask of a Cook; it stays available as a choice and is never a consequence of failure.

**Never blame the speaker.** «معلش، مافهمتش» is allowed. "Your speech was unclear" or "Please speak more clearly" is forbidden — the failure belongs to the app.

### 10.8 Always-on speech, and privacy

- The app **reads itself aloud by default**, because speech is the primary channel, not an accessibility add-on. It says so on first launch.
- **A mute control is on every screen**: 48dp, top inline-end, speaker-with-slash, and it **persists until reversed** — never silently re-enabled.
- **Money and addresses are spoken at reduced volume**, routed to the earpiece when one is connected. Homes are shared; income is private.
- **Recording is always visibly indicated.** No silent listening, not even for a wake word.

### 10.9 What this changed in the earlier foundations

| Area | Before | Now |
|---|---|---|
| Voice | one teal token | nine defined states, each with visual + spoken + haptic + fallback |
| Status word | 13px badge | 20–32px glance word from a closed set |
| Price | 18–24px | 34px in rows, 48–64px as a verdict |
| Largest target | 48dp button | 88dp talk button; 72dp «أيوة» |
| Text input | core component | last-resort fallback, never a consequence of failure |
| Component definition | visual states only | **undefined until its spoken line is written** |

### 10.10 Decided since

- **Assistant voice gender is a user setting** (10.11).
- **All Cook ↔ Customer communication is text, dictated through the assistant** (10.12). No audio messages exist in the product, so "telling the assistant's voice from a Cook's voice note" is moot — there are no voice notes.
- **Reviews and complaints follow the same dictated-text path** (10.12.6).

### 10.11 The assistant's voice — settings

The assistant has **two voices, male and female, both Cairene Egyptian Arabic.** Each account chooses its own — Cooks and Customers alike — and the choice is asked aloud on first launch.

- Stored per device, **persists until changed, never switches on its own.**
- Settings also expose **speech rate** (بالراحة / عادي / سريع) — older Cooks and Customers are a core audience, and a fixed rate excludes people at both ends.
- Settings toggles, all on by default: read incoming messages aloud, speak money at reduced volume, show the recording indicator. The recording indicator toggle exists but cannot be turned off — it is shown as a locked-on state, because silent listening is never acceptable.
- Voice selection cards use the primary token when selected (2px `primary` border on `primary-tint`, name in `primary-deep` at 20px/700) with a **48dp "اسمعيه" preview button** — nobody should have to commit to a voice they haven't heard.

Still undecided: age and register beyond gender. That is a casting decision, not a design-token one.

### 10.12 Cook ↔ Customer messaging is text, dictated

**All communication between a Cook and a Customer is text.** Neither party ever receives an audio message. The assistant is the scribe: it transcribes speech to text and reads incoming text aloud.

This creates the system's **one exception to "no transcript" (10.1.2):**

> **A message is read back verbatim before it is sent.** Everywhere else the assistant paraphrases what it understood. Here the exact words are what another human will receive, so the sender hears them literally and answers «أيوة» before anything leaves. Silence never sends.

The send gate offers three responses, not two: **أيوة، ابعتيها** (72dp, solid `success`), **أعيد الكلام** (re-dictate from scratch), and **أزوّد كلمة** (append). Two options force a person to discard a good sentence over one missing word.

Rules:

1. **The assistant transcribes; it does not improve.** Egyptian phrasing is preserved exactly. Never rewritten into MSA, never made "more polite," never shortened. A Cook who says «تحبي أبعته مع ابني» must not arrive sounding like a company.
2. **The message is attributed to the person, not to Kafoo.** The assistant is a pen, not a spokesperson. If a Customer perceives Kafoo as the one talking, the neighbourly relationship the product depends on is gone.
3. **Incoming messages are read aloud automatically** when the thread opens, prefixed with the sender's name and a short pause: «سامية بتقولك...». Every incoming message keeps a 48dp «اسمعيها تاني» button.
4. **The assistant's voice and quoted human speech must be distinguishable** — the assistant always names the sender first and pauses before quoting. Visually: assistant speech sits on `voice-tint` teal panels; human messages are bubbles in `surface-raised` (incoming) and `primary-tint` (outgoing). Two different colour families, never mixed.
5. **Bubble shape carries the direction without reading**: incoming = white, inline-start, corner notched at the bottom inline-start; outgoing = `primary-tint`, inline-end, notched at the bottom inline-end.
6. **Reviews follow the same path.** A Customer speaks, the assistant writes, the Cook hears it. The Customer also hears their own Review verbatim before it posts — so a harsh sentence said quickly stays a decision rather than a slip.
7. **Typing is always available** on both sides and is never a consequence of the assistant failing to understand.

**Glance-word set grows to eleven:** اتبعت (`voice-deep`) and اتقرت (`success`) join the closed set from 10.4, at 20px/700 in a message footer. Delivery state must be legible without reading small text — a Cook needs to know her words arrived. The state is also spoken when it changes.

### 10.13 Still open

- **How a Cook hears a bad Review.** Reading a harsh sentence verbatim to a woman standing in her own kitchen needs a decision: read it straight, or lead with the shape of it («فيه تقييم تلات نجوم على المحشي، تحبي تسمعيه؟») and let her choose when. **Recommendation: the second** — consent before criticism, same volume of information, better moment. Founder call.
- **Assistant voice casting** — age and register (see 10.11).
- **Whether a Customer's Order placement is spoken-confirmed** like a Cook's publish action.

---

## 11. The conversation screen

Added 2026-08-13 by ADR-0015. §10 describes how the app speaks; this section describes the one
screen it speaks *on*.

**The design bundle does not cover this and did not claim to.** Its Cook Meal List is a list — a
receipt of Meals that already exist — and it is still correct for that job. What it has no drawing
of is the surface where a Meal comes into being through talking, because when the bundle was made
that surface was four screens of questions. This section is the addition, and it is built almost
entirely from parts §6 and §10 already define. **One component is genuinely new: the receipt panel
(11.3).**

### 11.1 The rule the screen exists to express

> **One journey, one screen, one conversation.** Publishing a Meal is one screen. Onboarding a Cook
> is one screen. Nothing advances because a question was answered.

What this deletes: the dish question, the description question, the photo question, the price
question, the two fallback questions, the estimates list and the summary — seven surfaces replaced
by one.

### 11.2 Layout, top to bottom

The screen has exactly three zones and never more.

| Zone | Content | Treatment |
|---|---|---|
| **Top** | Screen title 24/600, mute control 48dp top inline-end (§10.8) | 1px `border` bottom, `surface` |
| **Middle** | The exchange, newest at the bottom, scrolled | `surface`; assistant speech on `voice-tint` panels, radius 16, `voice-deep` text at 18/1.75 — never a bubble, never mixed with the message-bubble family from §10.12.4 |
| **Bottom** | The receipt panel (11.3), then the talk button (§10.3) | Receipt on `surface-raised` + 1px `border`, radius 16; talk button 88dp, bottom centre, 24 from the edge, nothing else within its radius |

The middle zone is not a transcript. It shows **what the assistant said**, in the assistant's own
words, because §10.1.2 forbids showing recognised text back. What the person said appears only as
the effect it had — a value arriving in the receipt panel.

Bottom 96dp stays thumb territory (§7): receipt panel and talk button only. No destructive action
is ever placed there.

### 11.3 The receipt panel — new component

**What is known so far, and nothing else.** It is the screen keeping its promise to be a receipt
while the conversation is still happening.

- One row per fact the journey needs. Rows appear filled; **a fact not yet given shows its row with
  a dashed `border-strong` outline and nothing in it** — visible as an absence, at a glance, without
  reading.
- **Numerals carry the value** (§10.5): price at 34px/700 Arabic-Indic. Words are `text-muted` at
  14/1.7 and are never the only difference between two rows.
- Status uses the closed glance-word set (§10.4) and adds nothing to it. A draft in progress reads
  «مسودة», `text-muted` on `surface-sunken`, dashed border.
- **A value the assistant estimated is marked and stays marked** until the Cook confirms or corrects
  it — this is the visual half of the approval step, and it must never look identical to a value she
  spoke. Estimated rows carry the `primary-tint` fill and the `primary-border`; spoken values sit on
  `surface-raised`.
- **Every row is tappable and every row is correctable by voice.** Tapping a row is the tap
  alternative to saying «لأ، السعر مية وخمسين» and reaches the same place.
- When a value changes, **only that row animates and enlarges**, and the assistant repeats the new
  value aloud — the *correcting* state from §10.2, unchanged.

Panel height is capped and the panel scrolls internally. It never grows past a third of the screen:
the conversation is the screen, and the receipt is the margin note.

### 11.4 States

Reuse, do not invent. The nine voice states of §10.2 all apply here and are the screen's primary
state machine. Four screen-level states sit above them:

| State | Treatment | Spoken |
|---|---|---|
| Arriving, nothing said yet | Empty receipt panel, all rows dashed; talk button idle | The invitation from §10.2, once |
| In conversation | As 11.2 | Per turn, max three sentences (§10.2) |
| Waiting on the network | Skeleton at the assistant-panel footprint (the gap §6 flags as undefined — **this is where it gets used**); talk button stays live | Silence, then «لسه معاك، ثانية.» after 2s |
| Ready to publish | Receipt panel complete, no dashed rows; the confirmation gate of §10.6 takes the bottom zone | The whole thing read back, then waits |

**The gate is not a screen and never becomes one.** It replaces the bottom zone in place, with the
talk button still answering it. §10.6 is unchanged: «أيوة» 72dp solid `success`, «لأ» 56dp outline,
silence never confirms, no timeout resolves it, undo visible for two minutes after.

### 11.5 What must not happen on this screen

- **No progress indicator, no step counter, no "3 of 5".** There are no steps. A progress bar would
  reintroduce the wizard as decoration.
- **No transcript of the person's speech**, ever, except the verbatim read-back a Message gets
  (§10.12).
- **No twelfth glance word.** If the conversation reaches a state the set cannot name, that is a
  decision to take, not a word to coin.
- **No new large Arabic text** outside the closed set and the numerals.
- **The assistant never fills a row from its own suggestion.** Advice is spoken; only what the person
  says lands in the receipt (ADR-0015 rule 5).

### 11.6 The tap path is the same screen

§10.1.5 requires tap to be complete rather than degraded, and this screen satisfies it without a
second design: every receipt row is tappable, tapping opens the bottom sheet of §6.5 with that fact's
options, and the confirmation gate answers to a finger exactly as it answers to a voice. **Typing
stays available and is never a consequence of the assistant failing to understand** — the failure
ladder of §10.7 still descends exactly three rungs and still ends at tapping, not typing.

---

**Reference files:** `Kafoo Foundations.dc.html` (palette, type scale, spacing), `Kafoo Components.dc.html` (six components, all states, tap-target and 200%-scale proofs), `Kafoo Cook Meal List.dc.html` (assembled screen, three states — **tap-first, superseded**), `Kafoo Voice Foundations.dc.html` (nine voice states, talk button, glance words, confirmation gate, failure ladder), `Kafoo Cook Meal List v2 Voice.dc.html` (the same screen rebuilt voice-first — **use this one**), `Kafoo Voice Messaging.dc.html` (voice settings, dictation, the verbatim send gate, and both sides of a Cook ↔ Customer thread). These are **design references in HTML**, not production code — recreate them in the target codebase's own patterns.
