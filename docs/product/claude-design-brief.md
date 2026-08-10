# Brief for Claude Design

**Written**: 2026-08-09. **For**: the founder, to paste into [claude.ai/design](https://claude.ai/design).

Kafoo has 27 mobile presentation files and 5 web pages, and no visual language holding them
together. `packages/ui/lib/theme/tokens.dart` is 48 lines: a spacing scale, a tap-target minimum,
and five colors. **There is no typography at all** — no font, no scale, no line-heights — which for
an Arabic-first product is the largest single gap in the repository.

This file exists so that gap is closed by a decision somebody made and can point at, rather than by
whatever Material defaults happened to render.

## How to use it

Four prompts, in order, in one Claude Design project. **Do not paste them all at once.** Anthropic's
own guidance and every practitioner write-up agree on the same shape: rough description first, then
refine conversationally, and break complex work into sequential prompts rather than one long one.
A single prompt carrying all four stages produces a plausible kit that answers none of them well.

Between each prompt, look at what came back and react in plain language — "warmer", "that reads as
a restaurant, not a home", "the Arabic is too small". Reacting is the part only the founder can do.

## Before prompt 1 — what to upload

Claude Design builds its design system by reading what you give it, and its documented best practice
is that **real examples beat abstract specification**: a finished page tells it more about a brand's
feel than a palette does. Kafoo has no finished design, so supply feel from elsewhere:

1. **Point it at the GitHub repository** (`mzakaria81/kafoo`). It reads a codebase directly, and
   it will pick up the existing tokens, the ARB strings, and the RTL conventions.
2. **8–12 photographs of real Egyptian home cooking** — the food, and the kitchens it is made in.
   Not stock photography of restaurants. This is the single most useful upload; it is how "warm and
   homemade" stops being a word and becomes something to match.
3. **Two or three apps you like the feel of, and one you do not**, as screenshots. Say which is
   which. Contrast carries more information than approval alone.

## Prompt 1 — foundations

> I'm building Kafoo, an Egyptian marketplace where home cooks sell food to customers nearby. It is
> a Flutter mobile app plus a small Next.js website. I am the founder, not a designer.
>
> I want you to establish the visual foundations only — not screens yet.
>
> **The single most important constraint: Egyptian Arabic is the default language, not a
> translation.** Every preview you produce must be in Arabic, right-to-left, using real Egyptian
> conversational phrasing — never Lorem Ipsum, never English, never Modern Standard Arabic. If you
> also want to show an English version, show it second.
>
> **Feel**: warm, homemade, trustworthy. A neighbour's kitchen, not a restaurant chain and not a
> Silicon Valley startup. The people using this are ordinary Egyptians on mid-range Android phones,
> often in bright daylight.
>
> Give me:
>
> 1. **A colour palette.** We currently use `#C2410C` as primary, `#FFFBF7` as surface, `#1C1917`
>    for text, `#B91C1C` for errors. Treat that as a starting point you may replace — tell me if
>    you would, and why. Every pair must meet WCAG AA, checked for a phone screen in sunlight.
> 2. **An Arabic type scale.** This is the decision I most need. Recommend one font and justify it
>    against the alternatives — Cairo, Tajawal, IBM Plex Sans Arabic, Almarai and Noto Sans Arabic
>    are the candidates I know of. Give sizes, weights and line-heights, and remember that Arabic
>    needs more line-height than Latin at the same size. Show the scale set in real Egyptian Arabic.
> 3. **Spacing.** We already use 4 / 8 / 16 / 24 / 32. Keep it unless you have a reason.
>
> Show all three as one page I can look at. Explain each choice in one sentence — I need to
> understand the trade-off, not the technique.

## Prompt 2 — components

Only after the foundations are settled.

> Now build the core components on those foundations. Six, no more:
>
> **Button** (primary, secondary, destructive; normal, pressed, disabled, loading) · **Text input**
> (empty, filled, focused, error, with helper text) · **Meal card** — a photo, a name, a price in
> Egyptian pounds, the cook's name · **Chip** for filters like cuisine and dietary tags ·
> **Bottom sheet** · **Empty state**.
>
> Constraints, all non-negotiable:
>
> - Every component previewed in Arabic, right-to-left, with real Egyptian text.
> - **Minimum 48×48dp tap target on anything interactive.** Show me the target bounds.
> - Must survive 200% text scaling without clipping. Show one component at 200%.
> - Any food photograph in these mockups is a **placeholder that will never ship**. Mark it visibly
>   as a placeholder. Do not generate photorealistic food images — Kafoo's rules forbid
>   AI-generated food photography, and a mockup that looks shippable is how one leaks into
>   production.
> - Use these words exactly: **Cook**, **Customer**, **Meal**, **Kitchen Profile**, **Order**,
>   **Review**. Never chef, vendor, restaurant, dish, product, listing, buyer or user.

## Prompt 3 — one real screen, as a test

> Now assemble one real screen from those components: the Cook's Meal list. A Cook opens Kafoo and
> sees the Meals they have published, each with its status — draft, published, unavailable,
> archived — and a way to add a new one.
>
> Show it in three states: full of Meals, empty (a Cook who has published nothing yet), and failed
> to load. Arabic, right-to-left.
>
> This is a test of the system, not a new design. If a component doesn't fit, tell me what's missing
> rather than inventing a one-off.

## Prompt 4 — the handoff

> Package this as a DESIGN.md I can commit to my repository, with these sections: visual theme and
> atmosphere, colour palette with semantic roles, typography rules, component styling with all
> states, layout and spacing principles, elevation, do's and don'ts, responsive and touch-target
> behaviour, and a short prompt guide for future work.
>
> Write the rationale beside each rule, not just the value. The next person to read it will be a
> coding agent with none of this conversation.
>
> Then produce the Claude Code handoff bundle.

## What not to ask it for

**Do not ask it to design the conversational flows** — meal publishing and kitchen-profile setup.
Those are Kafoo's core interaction and they are already built, deliberately, as conversations rather
than forms. The documented weakness of this tool is that it produces work that looks right and is
domain-naive; a conversational flow redrawn as a beautiful form is exactly that failure, and it
would break a rule in `CLAUDE.md` that exists on purpose.

**Do not ask it for all 27 screens.** Components plus one proving screen is the job. Screens are
cheap once the system exists and expensive to redo when it changes.

## What happens to the output

Claude Design produces **HTML and CSS**. `apps/web/` can consume that almost directly. The Flutter
app cannot — the design system arrives there as specification, and `packages/ui` gets written in
Dart from it, with the golden tests `.claude/rules/dart.md` already requires. That translation is
mechanical and roughly a day; it is not a reason to avoid the tool, but it is a real step and
nobody should be surprised by it.

## Sources

Anthropic's [Claude Design announcement](https://www.anthropic.com/news/claude-design-anthropic-labs)
and [design-system setup guide](https://support.claude.com/en/articles/14604397-set-up-your-design-system-in-claude-design);
Anthropic's [prompt engineering best practices](https://claude.com/blog/best-practices-for-prompt-engineering);
Victor Dibia's [practitioner review](https://newsletter.victordibia.com/p/how-good-is-anthropics-claude-design);
the [DESIGN.md format](https://github.com/VoltAgent/awesome-claude-design).
