# Handoff: Kafoo — Visual & Voice Foundations

## Overview

Kafoo is an Egyptian marketplace where home **Cooks** sell **Meals** to **Customers** nearby — a Flutter mobile app plus a Next.js website. It is **voice-first**: the AI assistant speaks, the user speaks back, and the screen is the receipt of that exchange.

This bundle contains the visual foundations (colour, typography, spacing), the voice system (nine states, talk button, confirmation gates), the six core components with every state, one assembled screen in three states, and the dictated-messaging flow.

**Read `DESIGN.md` first — all of it, including section 10 on voice.** It is the source of truth and carries the reasoning behind every value. This README describes what the HTML files show and how to implement them.

## About the design files

The `.dc.html` files are **design references created in HTML** — prototypes showing intended look and behaviour. They are **not production code to copy**.

Recreate them in the target codebase's existing environment:
- **Flutter** — widgets using the app's own patterns (`ThemeExtension` for tokens, `TextTheme` for the scale). Set `MaterialApp.locale` to `ar-EG`; let `Directionality` follow the locale and never hardcode `TextDirection`.
- **Next.js** — React components in the site's existing styling layer. `<html lang="ar-EG" dir="rtl">`.

If neither exists yet, pick the framework and implement there. Do not ship the HTML. The files use a small in-house component runtime (`support.js`, `<x-dc>`, `sc-for`) — ignore those mechanics entirely; what matters is the rendered result and the values in DESIGN.md.

## Fidelity

**High-fidelity.** Final colours, typography, spacing, radii, states, and Arabic copy. Every value is a decision, not a placeholder. The three explicit exceptions are flagged in DESIGN.md: the borrowed `warning` colour, the absence of dark mode, and the assistant's voice casting.

## Four non-negotiable constraints

1. **Egyptian Arabic (`ar-EG`) is the source language; RTL is the default direction.** All copy is authored in Egyptian conversational Arabic — never MSA, never machine translation, never Lorem Ipsum, including in tests and fixtures. English is a mirrored secondary locale only.
2. **Voice is the primary surface.** The assistant speaks first; the screen confirms what was heard. **A component without a spoken Egyptian-Arabic line is unfinished.** Assume Cooks may not read comfortably: large text comes only from the closed glance-word set, and numerals carry the real information.
3. **No AI-generated or stock food photography, ever** — not even temporarily to make a demo look better. Real photos are shot with the Cook in her Kitchen. Every image slot here is an intentionally unshippable placeholder (45° hatch + dashed border + red "temporary" label); reproduce that treatment for any unfilled slot.
4. **Fixed vocabulary** in code identifiers, UI strings, comments, and commits:

| Use | Arabic | Never |
|---|---|---|
| Cook | الطباخة / الطباخ | chef, vendor, seller, partner |
| Customer | العميل / العميلة | user, buyer, consumer |
| Meal | الأكلة | dish, product, item, SKU |
| Kitchen Profile | صفحة المطبخ | restaurant, store, shop, listing |
| Order | الطلب | cart, checkout, transaction |
| Review | التقييم | rating, feedback, stars |
| Message | الرسالة | chat, DM, thread |

## The voice system (implement this first)

Full spec in DESIGN.md §10. The shape of it:

- **Nine voice states**, each requiring four things: visual, spoken line, haptic, tap fallback — idle, listening, thinking, speaking, didn't-catch, correcting, interrupted, offline-queued, too-noisy.
- **Talk button:** 88dp, bottom centre, hold-to-talk with tap-to-lock. No always-listening. Acknowledge input within **150ms**; thinking state visible before **400ms**.
- **Agency:** reversible actions (search, filter, draft) execute immediately and are announced; irreversible ones (publish, Order, cancel, price change) are read back aloud and wait for «أيوة». **Silence never confirms.**
- **No transcript** — the assistant paraphrases what it understood. **One exception:** a message to another human is read back **verbatim** before sending, because those exact words are what the other person receives.
- **Failure ladder:** ask again once → ask a narrower yes/no question → fall back to tapping photos and numerals. Never ask her to type as a consequence. Never blame the speaker.
- **Always-on speech**, with a persistent 48dp mute control, money spoken quietly, and a **recording indicator that cannot be switched off**.
- **Glance words** — a closed set of eleven Arabic words that may appear large (على المنيو، مسودة، مش متاحة، أرشيف، طلب جديد، وصل، اتلغى، محفوظ، مفيش نت، اتبعت، اتقرت), each fixed in size, weight, colour and position so it is recognised by shape. Never introduce a twelfth without adding it to the set.
- **Numerals are the largest type in the system**: 34px in a row, 48–64px as a verdict, Arabic-Indic, never abbreviated.

### Messaging (DESIGN.md §10.12)

All Cook ↔ Customer communication is **text**; neither side ever receives audio. The assistant transcribes speech into text and reads incoming text aloud.

- **Transcribe, don't improve** — Egyptian phrasing preserved exactly, never formalised into MSA, never "made more polite."
- **Attribution is to the person, not to Kafoo.** The assistant is a pen, not a spokesperson.
- **Send gate has three options**: «أيوة، ابعتيها» (72dp, solid `success`), «أعيد الكلام», «أزوّد كلمة» — two options force people to discard a good sentence over one missing word.
- **Incoming messages auto-read** on thread open, prefixed with the sender's name and a pause; each keeps a 48dp "hear it again" button.
- **Delivery state** (اتبعت / اتقرت) appears **only on your own outgoing messages** at 20px/700; incoming messages show a timestamp.
- Reviews follow the same path — the Customer hears their own Review verbatim before it posts.

## Screens / views

### 1. Cook's Meal List — voice-first (`Kafoo Cook Meal List v2 Voice.dc.html`) — **the canonical screen**

Five panels: full, empty, failed-to-load, the publish confirmation gate, and recognition failure.

**Full state layout** (390×800 reference, `surface` background, vertical flex):
- Top bar `16px 20px 12px`: title "أكلاتي" 20/600; **48dp mute control** on the inline-end (`voice-tint` pill, 1.5px `#99E2DA`).
- **Spoken banner** — `voice-tint`, 1px `#99E2DA`, radius 16, padding 16, pulsing 20px teal dot + the line just spoken: «عندك خمس أكلات، اتنين منشورين. عايزة تعملي إيه؟» This is the screen's most important element: it is the receipt of the spoken greeting.
- **Meal rows**, gap 12: 80×80 placeholder thumb (radius 14), then glance word 20/700 in its status colour, price **34/700** + "جنيه" 15/600, Meal name **14/1.6 `text-muted`**, then a 48dp "hear this row" button (`voice-tint`) and a 48dp `···` button.
- **Bottom dock**: 88dp teal talk orb with an expanding ring, centred, "دوسي واتكلمي" 17/600 `voice-deep`, and a 48dp text link "أو ضيفي أكلة بإيدك" as the tap fallback.

**Empty state:** dark `#1C1917` panel, "احكيلي عن أكلة" 32/700, spoken invitation in a teal panel, a **120dp** talk orb, and "أو اكتبيها بإيدك" as an outline button — an invitation to speak, not a form.

**Failed state:** «مفيش نت» as a 20/700 glance word, reassurance first («اللي قولتيه محفوظ وهيتبعت أول ما النت يرجع»), a queued-audio card with «محفوظ» at 20/700 and animated bars, then cached rows at 0.45 opacity under "آخر نسخة محفوظة · ٩:٤٠ الصبح".

**Confirmation gate:** dark panel; the spoken read-back at 17/1.75 in `#CCFBF1`; a white card with placeholder photo, **56px** price, «تنشر؟» at 32/700 `success`; then «أيوة، انشريها» (72dp, solid `success`, 24/700) and «لأ، استنى» (56dp, outline). Footnote: silence confirms nothing.

**Recognition failure:** terracotta orb, narrowed yes/no question, then tappable photo+word options and «مشي حاجة من دول» — never a keyboard.

Exact Meal data, statuses and copy: see the file and the v1 README table (unchanged names/prices).

### 2. Voice foundations (`Kafoo Voice Foundations.dc.html`)

Reference sheet: the nine states (each with visual, spoken line, haptic, fallback), the talk button spec, the glance-word set at full size, the numeral rule, the confirmation gate, the three-rung failure ladder, privacy rules, and a table of what the voice work changed. **The orb is interactive — click it to cycle through the states.**

### 3. Messaging (`Kafoo Voice Messaging.dc.html`)

Five panels: voice settings; the Cook dictating; the verbatim send gate; the thread on the Cook's side; the same thread on the Customer's side.

**Settings:** two voice cards (صوت ست / صوت رجل), selected = 2px `primary` border on `primary-tint` with the name in `primary-deep` 20/700 and the glance word «مختار»; each has a 48dp "اسمعيه" preview. Speech rate segmented control (بالراحة / عادي / سريع). Three switches at **76×48dp** — read incoming aloud, speak money quietly, and the recording indicator, which renders **locked on** (no handler, `cursor: default`, 2px `voice-deep` border, lock glyph in the knob).

**Thread bubbles:** incoming = `surface-raised` + 1px `border`, inline-start, radius `16 16 16 4`; outgoing = `primary-tint` + 1px `primary-border`, inline-end, radius `16 16 4 16`. Sender label above at 13/600 `text-muted` («سامية بتقولك» / «انتي قولتي»). Assistant speech never uses these bubbles — it sits on teal panels.

### 4–5. Earlier references

`Kafoo Foundations.dc.html` — palette with contrast ratios, the five-font comparison, type scale, spacing, and a **sunlight preview toggle** that overlays a white wash so contrast can be judged as actually seen.

`Kafoo Components.dc.html` — the six components in every state, the terminology strip, a **tap-target toggle** drawing 48dp bounds, and the Meal card **at 200% text scale**.

`Kafoo Cook Meal List.dc.html` — the original tap-first assembly. **Superseded by v2**; kept only to show what changed and why.

## Interactions & behaviour

- **Buttons:** pressed = darker fill + `scale(0.98)`; loading = spinner (18px, 2.5px ring, 0.7s linear) + Arabic present-continuous label, footprint unchanged.
- **Filter chips:** single-select, live filtering, no reflow of the chip bar.
- **Bottom sheet:** drag-down, scrim tap, and an explicit dismiss action all close it.
- **Motion:** 150–250ms, `ease-out` in / `ease-in` out; orb ring 1.8–2.2s; amplitude bars 0.9–1s. Honour `prefers-reduced-motion` — the files already collapse animations under that query. Nothing springs or bounces.
- **No hover dependency**; web hover states are additive only.
- **Responsive:** <600 single column / 24 gutters; 600–1023 two columns; ≥1024 three columns, page capped 1120, prose 720.
- **200% text scale must not clip** — padding-based sizing, `min-height` not `height`, `flex-wrap` on price/action rows, `text-wrap: pretty` on headings, scrollable sheets with pinned actions, and no truncation of a Meal name, price, or Cook name.

## State management

```
mealListState  : loading | loaded | empty | error
voiceState     : idle | listening | thinking | speaking | notHeard
                 | correcting | interrupted | offlineQueued | tooNoisy
meals          : Meal[]  (id, name, priceEGP, status, meta, photoUrl?)
status         : published | draft | unavailable | archived
activeFilter   : all | published | draft | unavailable | archived
pendingGate    : { action, spokenReadback, payload } | null
messages       : Message[] (id, from, text, sentAt, deliveryState)
deliveryState  : sending | sent | read      // rendered only on outgoing
settings       : { assistantVoice: female|male, speechRate, readIncoming,
                   quietMoney, micIndicator: true /* locked */ }
connectivity   : online | offline
cache          : { meals: Meal[], fetchedAt }
```

Transitions: open → `loading` (skeleton still undefined — see gaps) → `loaded | empty | error`. On `error`, render cached rows at 0.45 opacity and speak the reassurance. Irreversible actions route through `pendingGate` and require an explicit yes by voice or tap; **no timeout may resolve a gate**. Dictated messages are held un-sent until the verbatim read-back is approved.

## Design tokens

Implement as named tokens (Flutter `ThemeExtension`, CSS custom properties, or Tailwind theme) — **never hex literals in component code.**

```
primary        #C2410C   primary-deep   #9A3412   primary-tint   #FFF7ED
primary-border #F0C9A8
surface        #FFFBF7   surface-raised #FFFFFF   surface-sunken #FAF5F0
text           #1C1917   text-muted     #57534E   text-subtle    #78716C
text-disabled  #A8A29E
voice          #0F766E   voice-deep     #115E59   voice-tint     #F0FDFA
voice-border   #99E2DA
error          #9F1239   error-tint     #FEF2F2   error-border   #F3B8C4
success        #15803D   success-tint   #F0FDF4
warning        #9A3412  (borrowed — see DESIGN.md §2)
border         #E7DED3   border-strong  #D6CCC0   disabled-fill  #F0E9E1
dark-surface   #1C1917   (voice panels)  quoted-text #CCFBF1
```

**Spacing:** 4 / 8 / 12 / 16 / 24 / 32 / 48.
**Radius:** control 12 · row/panel 16 · thumbnail 14 · card 24 · sheet 26 (top) · phone shell 32 · pill 999.
**Type** — `'IBM Plex Sans Arabic', 'Noto Sans Arabic', system-ui, sans-serif`, 300–700, self-hosted woff2, `font-display: swap`:

| Role | Size | Weight | Line-height (AR) | (LTR) |
|---|---|---|---|---|
| Display | 40 | 700 | 1.35 | 1.2 |
| Screen title | 32 | 700 | 1.4 | 1.25 |
| Section | 24 | 600 | 1.45 | 1.35 |
| Meal name | 20 | 600 | 1.5 | 1.35 |
| Body large | 18 | 400 | 1.75 | 1.6 |
| Body | 16 | 400 | 1.75 | 1.6 |
| Body small | 14 | 400 | 1.7 | 1.5 |
| Label | 14 | 600 | 1.4 | 1.4 |
| Caption | 13 | 400 | 1.6 | 1.5 |
| **Glance word** | 20 row / 32 verdict | 700 | 1.4 | — |
| **Numeral** | 34 row / 48–64 verdict | 700 | 1.2 | — |

Arabic line-heights run ~0.15 higher than Latin at the same size, because Arabic stacks marks above and below the baseline. **Do not unify them.** Never apply `letter-spacing` to Arabic.

**Shadows:** level 2 `0 1px 3px rgba(28,25,23,0.06)` · level 3 `0 8px 24px rgba(28,25,23,0.12)` · scrim `rgba(28,25,23,0.55)` · focus ring `0 0 0 3px rgba(194,65,12,0.18)` · talk-orb halo `0 0 0 10–12px rgba(15,118,110,0.15–0.18)`. Shadow colour is always the text brown at low alpha, never grey. Structure that carries meaning uses a border, not a shadow — shadows disappear in sunlight.

## Accessibility floor

- 88dp talk button, 72dp confirmation yes, 76×48dp switches, **48×48dp minimum everywhere else**; 8dp minimum between adjacent targets. Where the visual is smaller (40px chips, 40px avatar), expand the target around it — do not draw a compliant-looking box around a non-compliant target.
- All text pairs meet WCAG AA on `#FFFBF7`. `text-disabled` (2.9:1) is intentionally sub-AA to signal inertness; never use it for readable content.
- Never put required information in `text-subtle` or lighter, or below 14px.
- Focus is a 3px halo, not a colour-only change.
- Every state must be perceivable three ways — visual, spoken, haptic — with any one sufficient alone.
- Status and delivery words need accessible labels, not colour alone.
- Bottom 96dp is thumb territory: primary actions there, destructive actions never.

## Assets

**None ship in this bundle.** Every image slot is a placeholder by design; icons are simple shapes awaiting a real set.

To source: (a) the Kafoo logo/wordmark; (b) one icon library — verify glyphs read at 24px in sunlight; (c) IBM Plex Sans Arabic woff2 subsets for self-hosting; (d) the two assistant voices (Cairene Egyptian, male and female — casting still open); (e) real Cook and Meal photography shot in the Kitchen. **Never generate, synthesise, or use stock food imagery.**

## Known gaps — stop and ask, don't improvise

1. **Loading / skeleton state** — undefined, and on Egyptian networks it is a state people live in. Needed before shipping the Meal list.
2. **Status badge vs glance word** — the glance word supersedes the badge; reconcile before building more screens.
3. **App bar** — used ad hoc, not yet formalised.
4. **Warning colour** — deep terracotta is borrowed; no dedicated hue exists.
5. **Assistant voice casting** — age and register beyond gender.
6. **How a Cook hears a bad Review** — verbatim, or led by a summary with consent first (recommendation in DESIGN.md §10.13).
7. **Undefined entirely:** toast/snackbar, tab bar, date & time pickers, rating input, dark mode.

## Files

| File | Contents |
|---|---|
| `DESIGN.md` | **Source of truth** — theme, palette, typography, components, spacing, elevation, do's & don'ts, touch/responsive rules, §10 voice system, prompt guide |
| `Kafoo Voice Foundations.dc.html` | Nine voice states, talk button, glance words, confirmation gate, failure ladder, privacy |
| `Kafoo Cook Meal List v2 Voice.dc.html` | **Canonical screen** — full / empty / failed / gate / recognition-failure |
| `Kafoo Voice Messaging.dc.html` | Voice settings, dictation, verbatim send gate, both sides of a thread |
| `Kafoo Foundations.dc.html` | Palette with ratios, font comparison, type scale, spacing, sunlight toggle |
| `Kafoo Components.dc.html` | Six components, all states, 48dp proof, 200% text-scale proof |
| `Kafoo Cook Meal List.dc.html` | Original tap-first screen — **superseded**, kept for contrast |
| `support.js` | Runtime for the previews only — **not part of the design, do not port** |
| `screenshots/` | Static previews (orientation only; the HTML and DESIGN.md are authoritative): `01-foundations`, `02-components`, `02b-components-tap-targets`, `03-cook-meal-list` (superseded v1), `04-voice-foundations`, `05-cook-meal-list-v2-voice`, `06-voice-messaging` |

Open the `.dc.html` files directly in a browser. Toggles worth using: tap-target bounds (components, v2 screen, messaging), the sunlight wash (foundations), and the state-cycling orb (voice foundations).
