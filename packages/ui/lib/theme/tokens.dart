import 'package:flutter/widgets.dart';

/// The spacing scale.
///
/// Use these rather than literal numbers, and pair them with
/// `EdgeInsetsDirectional` so layouts survive RTL.
abstract final class KafooSpacing {
  /// 4 logical pixels. A line and the line immediately under it.
  static const double xs = 4;

  /// 8 logical pixels. An icon and its word; a badge and its title.
  static const double sm = 8;

  /// 12 logical pixels. Between elements inside one row — thumbnail, text,
  /// action — and between chips.
  ///
  /// The step the original scale was missing: 8 makes a Meal row look cramped
  /// and 16 makes it fall apart into pieces.
  static const double row = 12;

  /// 16 logical pixels. Card padding, gap between cards, form field gaps.
  /// The default. When unsure, this one.
  static const double md = 16;

  /// 24 logical pixels. Screen gutters on mobile, section padding in cards.
  static const double lg = 24;

  /// 32 logical pixels. Between two unrelated groups on one screen.
  static const double xl = 32;

  /// The minimum tap target Kafoo ships, in logical pixels.
  ///
  /// Anything smaller fails the accessibility review.
  static const double minTapTarget = 48;

  /// 48 logical pixels. Between major sections.
  ///
  /// Deliberately the same number as [minTapTarget]: the rhythm of the page and
  /// the size of a finger are one unit, so vertical spacing can never
  /// accidentally shrink a target. Written as an alias rather than a second
  /// literal so the two can never drift apart.
  static const double section = minTapTarget;

  /// The talk button, in logical pixels.
  ///
  /// Larger than [minTapTarget] because it is found by thumb without looking,
  /// sometimes with wet hands. It is not merely compliant; it is unmissable.
  static const double talkButton = 88;

  /// The talk button on an empty screen, where speaking is the only invitation.
  static const double talkButtonInvitation = 120;

  /// The «أيوة» target on a confirmation gate.
  ///
  /// Bigger than the «لأ» beside it ([confirmNo]) because it is the common
  /// case — not because Kafoo wants the yes.
  static const double confirmYes = 72;

  /// The «لأ» target on a confirmation gate. Outline only, never solid.
  static const double confirmNo = 56;

  /// The thumb zone at the bottom of a screen.
  ///
  /// Primary actions live here. Destructive actions never do.
  static const double thumbZone = 96;

  /// The minimum gap between two adjacent tap targets.
  static const double targetGap = 8;
}

/// Corner radii.
///
/// Radius decreases as an element gets smaller and more functional — a 24px
/// radius on a 48px button eats its own corners.
abstract final class KafooRadius {
  /// Buttons, inputs, chips-that-are-not-pills.
  static const double control = 12;

  /// Meal thumbnails.
  static const double thumbnail = 14;

  /// Rows and panels.
  static const double panel = 16;

  /// Cards.
  static const double card = 24;

  /// The top corners of a bottom sheet.
  static const double sheet = 26;

  /// Pills and circles.
  static const double pill = 999;
}

/// The colour palette.
///
/// Contrast is checked against a phone held in a bright kitchen, not a
/// designer's monitor. Every text pair here meets WCAG AA (4.5:1) against
/// [surface] — verified by `test/contrast_test.dart`, which computes the ratios
/// rather than trusting this comment.
///
/// There is no dark mode, deliberately: the primary usage context is bright
/// daylight and a dark theme built without that testing would be guesswork.
/// That is also why these are plain constants rather than a `ThemeExtension` —
/// an extension buys the ability to swap palettes at runtime, and there is no
/// second palette to swap to.
abstract final class KafooColors {
  /// Primary actions, active filter chips, brand accent.
  ///
  /// Terracotta and red pepper — warm, unmistakably Egyptian, and reads as
  /// "home" rather than "chain".
  static const Color primary = Color(0xFFC2410C);

  /// Coloured *text*, links, secondary button labels, pressed primary fill.
  ///
  /// [primary] is fine as a large fill, but thin Arabic strokes at 14–16px sit
  /// too light against the surface. Text needs a darker step.
  static const Color primaryDeep = Color(0xFF9A3412);

  /// Secondary button fill, empty-state medallion, informational panels.
  static const Color primaryTint = Color(0xFFFFF7ED);

  /// The edge of a tinted surface, which would otherwise dissolve outdoors.
  static const Color primaryBorder = Color(0xFFF0C9A8);

  /// App background. White warmed by one step, which cuts glare.
  static const Color surface = Color(0xFFFFFBF7);

  /// Rows and panels sitting *on* [surface].
  ///
  /// Pure white is a lift against the warm surface, never the page background.
  static const Color surfaceRaised = Color(0xFFFFFFFF);

  /// Table headers, draft-state fills, subtle wells.
  static const Color surfaceSunken = Color(0xFFFAF5F0);

  /// Primary text. Near-black with a brown cast, so it does not cut against
  /// the warmth.
  static const Color onSurface = Color(0xFF1C1917);

  /// Text and icons on [primary].
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Secondary text, metadata, helper text.
  ///
  /// Deliberately dark for a "muted" token — the usual greys are unreadable in
  /// sunlight.
  static const Color textMuted = Color(0xFF57534E);

  /// Non-essential annotation only.
  ///
  /// Passes AA but only just. Never a price, a label, or an instruction.
  static const Color textSubtle = Color(0xFF78716C);

  /// Disabled control labels.
  ///
  /// **Intentionally sub-AA.** Failing contrast is the signal that the control
  /// is inert. Never use it for readable content.
  static const Color textDisabled = Color(0xFFA8A29E);

  /// Disabled control fills.
  static const Color disabledFill = Color(0xFFF0E9E1);

  /// Listening, speaking and transcribing states.
  ///
  /// The one cool colour in the system. Reserving a hue for voice means the
  /// mic state is identifiable before any word is read — "I'm hearing you" can
  /// never be confused with "buy this".
  static const Color voice = Color(0xFF0F766E);

  /// Assistant speech set as text, and the «محفوظ» glance word.
  static const Color voiceDeep = Color(0xFF115E59);

  /// Voice panels and assistant speech backgrounds.
  ///
  /// A human message bubble must never use this — teal means the machine is
  /// talking.
  static const Color voiceTint = Color(0xFFF0FDFA);

  /// Voice panel borders.
  static const Color voiceBorder = Color(0xFF99E2DA);

  /// Destructive actions, validation failures, offline.
  ///
  /// Replaced `#B91C1C`, which sat in the same hue family as [primary]: in
  /// sunlight the two washed out to the same colour and a normal button became
  /// indistinguishable from an error. Crimson separates by hue, not only by
  /// lightness.
  static const Color error = Color(0xFF9F1239);

  /// Error field fills, destructive button rest state.
  static const Color errorTint = Color(0xFFFEF2F2);

  /// Error field and destructive button borders.
  static const Color errorBorder = Color(0xFFF3B8C4);

  /// Order confirmed, Meal published.
  ///
  /// The darkest green that still reads as green — lighter leaf greens drop
  /// below AA on a warm surface.
  static const Color success = Color(0xFF15803D);

  /// Success panels, published-status fills.
  static const Color successTint = Color(0xFFF0FDF4);

  /// "Unavailable today", paused Meals.
  ///
  /// **Borrowed, and a known gap.** The palette has no dedicated warning hue;
  /// deep terracotta stands in and reads as "paused", not "wrong". If paused
  /// states spread beyond the Meal list, this needs its own value — and that is
  /// a founder decision, not one to make while implementing a screen.
  static const Color warning = Color(0xFF9A3412);

  /// Default dividers and card edges. Use this instead of a shadow wherever
  /// structure must survive sunlight.
  static const Color border = Color(0xFFE7DED3);

  /// Drag handles, and any edge that needs more weight than [border].
  static const Color borderStrong = Color(0xFFD6CCC0);

  /// The visible boundary of a *control* — an input, a switch track, a
  /// checkbox.
  ///
  /// **Borrowed, and a gap in the palette, in the same sense as [warning].**
  /// DESIGN.md gives input borders as `border-strong`, which measures 1.54:1
  /// against [surface]. WCAG 1.4.11 requires 3:1 for the boundary of a user
  /// interface component, because that boundary is the only thing telling
  /// somebody where the control is — and the web surface had already fixed
  /// exactly this bug once, on the search box, before this palette landed.
  /// Implementing the documented value literally would have put it back.
  ///
  /// No border token in the palette reaches 3:1: `border` is 1.29:1,
  /// `primary-border` 1.50:1, `voice-border` 1.43:1. So this reuses
  /// [textSubtle] (4.66:1) rather than inventing a hex, and the real fix is a
  /// design decision about what a control's edge should look like in sunlight.
  static const Color borderInput = textSubtle;

  /// The dashed edge of an empty image slot.
  ///
  /// Named in DESIGN.md's *Placeholders* rule but absent from its palette
  /// table, so it is a token here rather than a literal in a painter.
  static const Color placeholderBorder = Color(0xFFC7B9A8);

  /// The background of a voice panel that takes over the screen.
  static const Color darkSurface = Color(0xFF1C1917);

  /// Assistant speech quoted on [darkSurface].
  static const Color quotedText = Color(0xFFCCFBF1);
}

/// Elevation.
///
/// Expressed by border and background first, shadow second — a shadow is nearly
/// invisible on a cheap panel in sunlight, so nothing may depend on it alone.
/// Shadow colour is always the text brown at low alpha, never neutral grey: a
/// grey shadow on a warm surface goes visibly cold.
abstract final class KafooElevation {
  /// Level 2 — a card that must read as pickable-up.
  static const List<BoxShadow> lifted = [
    BoxShadow(
      color: Color(0x0F1C1917),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];

  /// Level 3 — bottom sheets and dialogs. Never two at once.
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x1F1C1917),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// Behind a level-3 surface.
  static const Color scrim = Color(0x8C1C1917);

  /// Focus is a 3px halo, never a colour-only change — a colour shift alone is
  /// invisible in sunlight.
  static const Color focusRing = Color(0x2EC2410C);

  /// The width of that halo.
  static const double focusRingWidth = 3;

  /// The glow around an active talk button.
  static const Color talkOrbHalo = Color(0x2E0F766E);
}

/// Motion.
///
/// Nothing bounces or springs; a kitchen is calm. Honour
/// `MediaQuery.disableAnimations` by replacing movement with an opacity change
/// rather than by skipping the feedback entirely.
abstract final class KafooMotion {
  /// Entering. Pair with [enterCurve].
  static const Duration enter = Duration(milliseconds: 250);

  /// Leaving. Pair with [exitCurve].
  static const Duration exit = Duration(milliseconds: 150);

  /// Ease-out in.
  static const Curve enterCurve = Curves.easeOut;

  /// Ease-in out.
  static const Curve exitCurve = Curves.easeIn;

  /// One turn of a loading spinner.
  static const Duration spinner = Duration(milliseconds: 700);

  /// How long the app has to acknowledge that the talk button was pressed.
  ///
  /// Half a second of silence reads as "the button didn't work", so the user
  /// taps again and cuts off their own speech.
  static const Duration voiceAcknowledgement = Duration(milliseconds: 150);

  /// How long the app has to show that it is thinking.
  static const Duration voiceThinkingVisible = Duration(milliseconds: 400);
}
