import 'package:flutter/widgets.dart';

/// The spacing scale.
///
/// Use these rather than literal numbers, and pair them with
/// `EdgeInsetsDirectional` so layouts survive RTL.
///
/// 12 and 48 arrived with the design system on 2026-08-10. Twelve is the gap
/// that was missing between elements inside one row — 8 makes a Meal row look
/// cramped and 16 makes it fall apart into pieces. Forty-eight does two jobs on
/// purpose: it is both the rhythm between major sections and the size of a
/// finger, so vertical spacing can never accidentally shrink a tap target.
abstract final class KafooSpacing {
  /// 4 logical pixels. A line and the line immediately under it.
  static const double xs = 4;

  /// 8 logical pixels. An icon and its word.
  static const double sm = 8;

  /// 12 logical pixels. Inside one row: thumbnail, text, action.
  static const double rowGap = 12;

  /// 16 logical pixels. Card padding and the default when unsure.
  static const double md = 16;

  /// 24 logical pixels. Screen gutters on mobile.
  ///
  /// Not 16: full-width content at 16 reads as falling off the phone.
  static const double lg = 24;

  /// 32 logical pixels. Between two unrelated groups on one screen.
  static const double xl = 32;

  /// 48 logical pixels. Between major sections — the same number as
  /// [minTapTarget], deliberately.
  static const double xxl = 48;

  /// The minimum tap target Kafoo ships, in logical pixels.
  ///
  /// Anything smaller fails the accessibility review.
  static const double minTapTarget = 48;

  /// The talk button (ADR-0013). Larger than [minTapTarget] because it is found
  /// by thumb without looking, sometimes with wet hands.
  static const double talkButton = 88;

  /// The «أيوة» target on a confirmation gate (ADR-0013). Bigger than «لأ»
  /// because agreeing is the common case; both are unmissable.
  static const double gateConfirm = 72;
}

/// The colour palette.
///
/// Contrast is checked against a phone held in a bright kitchen, not a
/// designer's monitor. Every text pair here is WCAG AA (4.5:1) or better on
/// [surface]; [textDisabled] fails on purpose, and that is the only exception.
///
/// Ratios in the comments were measured, not estimated.
abstract final class KafooColors {
  // ── Brand ────────────────────────────────────────────────────────────────

  /// Primary actions and brand accent. 5.1:1 on [surface]. Terracotta —
  /// warm, Egyptian, reads as "home" rather than "restaurant chain".
  static const Color primary = Color(0xFFC2410C);

  /// Coloured *text*, links, secondary button labels, pressed primary. 7.2:1.
  ///
  /// [primary] is fine as a large fill, but thin Arabic strokes at 14–16px sit
  /// too light against the surface. Text needs the darker step.
  static const Color primaryDeep = Color(0xFF9A3412);

  /// Secondary button fill and informational panels. A wash, not a colour.
  static const Color primaryTint = Color(0xFFFFF7ED);

  /// The edge of a tinted surface, which dissolves into the background outdoors
  /// without it.
  static const Color primaryBorder = Color(0xFFF0C9A8);

  // ── Surfaces ─────────────────────────────────────────────────────────────

  /// App background. White warmed one step: cuts glare and stops the terracotta
  /// looking synthetic.
  static const Color surface = Color(0xFFFFFBF7);

  /// Rows and panels sitting *on* [surface]. Pure white is a lift, never the
  /// page background.
  static const Color surfaceRaised = Color(0xFFFFFFFF);

  /// Zones that recede — draft fills, table headers, subtle wells.
  static const Color surfaceSunken = Color(0xFFFAF5F0);

  // ── Text ─────────────────────────────────────────────────────────────────

  /// Default body text. 17.1:1. Near-black with a brown cast so it does not cut
  /// against the warmth.
  static const Color onSurface = Color(0xFF1C1917);

  /// Secondary text, metadata, helper text. 7.5:1.
  ///
  /// Deliberately dark for a token called "muted". The usual `#78716C`-and-
  /// lighter greys become unreadable in sunlight.
  static const Color textMuted = Color(0xFF57534E);

  /// Non-essential annotation ONLY. 4.8:1 — passes AA, but only just.
  ///
  /// Never a price, a label, or an instruction. This is the last legible step.
  static const Color textSubtle = Color(0xFF78716C);

  /// Disabled control labels. 2.9:1 — **intentionally below AA.**
  ///
  /// Failing contrast is the signal that the control is inert. Never use it for
  /// content anybody needs to read.
  static const Color textDisabled = Color(0xFFA8A29E);

  /// Text and icons on [primary].
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ── Voice (ADR-0013) ─────────────────────────────────────────────────────

  /// Listening, speaking, transcribing. 5.4:1.
  ///
  /// The only cool colour in the system, and reserved: a hue that means "the
  /// machine is talking" is identifiable before any word is read. Never use it
  /// for a human's words.
  static const Color voice = Color(0xFF0F766E);

  /// Assistant speech set as text, and the «محفوظ» glance word. 8.9:1.
  static const Color voiceDeep = Color(0xFF115E59);

  /// Voice panels and assistant speech backgrounds. Pairs with [voiceDeep] at
  /// AAA. A human message bubble must never use this.
  static const Color voiceTint = Color(0xFFF0FDFA);

  /// Voice panel and hear-again button borders.
  static const Color voiceBorder = Color(0xFF99E2DA);

  // ── Feedback ─────────────────────────────────────────────────────────────

  /// Destructive actions, validation failures, offline. 7.9:1.
  ///
  /// **Replaced `#B91C1C` on 2026-08-10 and the reason is measurable.** That red
  /// sat in the same hue family as [primary] — a perceptual distance of 16.4,
  /// where under about 20 reads as the same colour at a glance. In sunlight the
  /// two washed out together and an ordinary button became indistinguishable
  /// from an error. Crimson separates by hue rather than lightness: distance
  /// 39.5, and 1.6 ratio points better as well.
  static const Color danger = Color(0xFF9F1239);

  /// Error field fills and destructive button rest state.
  static const Color dangerTint = Color(0xFFFEF2F2);

  /// Error field and destructive button borders.
  static const Color dangerBorder = Color(0xFFF3B8C4);

  /// Order confirmed, Meal published. 4.9:1 — the darkest green that still
  /// reads as green. Lighter leaf greens drop below AA on a warm surface.
  static const Color success = Color(0xFF15803D);

  /// Success panels and published-status backgrounds.
  static const Color successTint = Color(0xFFF0FDF4);

  /// "Unavailable today", paused Meals. 7.2:1.
  ///
  /// **Borrowed from [primaryDeep] — a known gap.** The palette has no dedicated
  /// warning hue; this reads as "paused" rather than "wrong", which is right for
  /// the Meal list. If paused states spread further, give it its own value: a
  /// real amber has to be very dark (around `#92400E`) to pass AA here.
  static const Color warning = Color(0xFF9A3412);

  // ── Structure ────────────────────────────────────────────────────────────

  /// Default dividers and card edges. Use a border, not a shadow, wherever
  /// structure has to survive sunlight.
  static const Color border = Color(0xFFE7DED3);

  /// Input borders at rest, drag handles. Heavier than [border] because an
  /// empty field must visibly be a field.
  static const Color borderStrong = Color(0xFFD6CCC0);

  /// Disabled control fill.
  static const Color disabledFill = Color(0xFFF0E9E1);

  /// Behind voice panels and confirmation gates (ADR-0013).
  static const Color darkSurface = Color(0xFF1C1917);

  /// Human speech quoted on [darkSurface].
  static const Color quotedText = Color(0xFFCCFBF1);
}

/// The corner radius scale.
///
/// Radius decreases as an element gets smaller and more functional: a 24px
/// radius on a 48px button eats its own corners.
abstract final class KafooRadius {
  /// Controls — buttons, inputs.
  static const double control = 12;

  /// Thumbnails.
  static const double thumbnail = 14;

  /// Rows and panels.
  static const double row = 16;

  /// Cards.
  static const double card = 24;

  /// The top corners of a bottom sheet.
  static const double sheet = 26;

  /// Pills and chips.
  static const double pill = 999;
}

/// Elevation, expressed as border and background first and shadow second.
///
/// A shadow is nearly invisible on a cheap panel in sunlight, so nothing may
/// depend on one alone. Shadow colour is always the text brown at low alpha —
/// a grey shadow on a warm surface goes visibly cold.
abstract final class KafooElevation {
  /// Level 2 — a card that must read as pickable-up.
  static const List<BoxShadow> lifted = [
    BoxShadow(
      color: Color(0x0F1C1917),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];

  /// Level 3 — bottom sheets and dialogs. Never two at once: a sheet on a sheet
  /// means the flow is wrong.
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x1F1C1917),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// The scrim behind a level-3 surface.
  static const Color scrim = Color(0x8C1C1917);
}

/// The type scale.
///
/// **The font is IBM Plex Sans Arabic**, bundled in `apps/mobile/assets/fonts`
/// under the SIL Open Font License. Chosen over Cairo, Tajawal, Almarai and
/// Noto Sans Arabic because it is drawn for screens first — large dots, open
/// counters in ع/ه/م, and sīn teeth that do not flatten at small sizes — and
/// because five real weights mean hierarchy can come from weight rather than
/// size, which matters when the smallest usable size is already 13px.
///
/// **Arabic line-heights run about 0.15 higher than Latin at the same size, and
/// the two are deliberately not unified.** Arabic stacks marks above and below
/// the baseline — hamza, shadda, sukun, and the descenders of ج/ح/ع — and at
/// Latin leading those collide between lines. A shared value either wastes
/// space in Latin or breaks Arabic. The heights here are the Arabic ones,
/// because `ar` is the default locale rather than the fallback.
///
/// **Never apply letter-spacing to Arabic.** It is cursive; positive tracking
/// severs the joins and produces broken-looking words.
abstract final class KafooType {
  /// The bundled family. Declared in `apps/mobile/pubspec.yaml`.
  static const String fontFamily = 'IBMPlexSansArabic';

  /// Fallbacks, Arabic-first: a swap from a Latin-metric face reflows the whole
  /// screen.
  static const List<String> fontFamilyFallback = ['Noto Sans Arabic'];

  /// 40/700. Welcome and onboarding only — tight leading is safe because it is
  /// never a paragraph.
  static const TextStyle display = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );

  /// 32/700. The first line of a screen.
  static const TextStyle screenTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.4,
  );

  /// 24/600. Section headings and sheet titles.
  ///
  /// 600 rather than 700: at 24px, bold Arabic starts to close its counters.
  static const TextStyle section = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.45,
  );

  /// 20/600. Card and row titles.
  static const TextStyle mealName = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  /// 18/400. Assistant replies and primary buttons — read at arm's length or
  /// glanced at while cooking.
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.75,
  );

  /// 16/400. The default for everything, and the minimum for an input field:
  /// smaller triggers zoom-on-focus on iOS and is hard to proof-read in sun.
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.75,
  );

  /// 14/400. Metadata under a title.
  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.7,
  );

  /// 14/600. Buttons, tabs, field labels — weight carries the emphasis so the
  /// size can stay small.
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// 13/400. **The floor.** Legal text and annotation.
  ///
  /// Never a price, never a button, never an instruction. If information
  /// matters, it is 14 or larger.
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  /// 20/700. A glance word in a list row (ADR-0013).
  ///
  /// Fixed size per context so the silhouette is learnable: these are
  /// recognised by shape rather than read.
  static const TextStyle glanceWordRow = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.4,
  );

  /// 32/700. A glance word as a screen verdict (ADR-0013).
  static const TextStyle glanceWordVerdict = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.4,
  );

  /// 34/700. A price, count or time in a row.
  ///
  /// **The largest type in the system, and that is the point:** numbers are read
  /// by nearly everyone and words are not. A Meal name drops to [bodySmall]
  /// beside one — present, spoken on tap, never the only thing distinguishing
  /// two options.
  static const TextStyle numeralRow = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// 56/700. A numeral as a verdict — the price on a confirmation gate.
  static const TextStyle numeralVerdict = TextStyle(
    fontSize: 56,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
}
