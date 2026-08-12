import 'package:flutter/material.dart';

import 'tokens.dart';

/// The type scale.
///
/// Two rules govern everything here, and both are easy to break by accident:
///
/// **Arabic runs at roughly 0.15 more line-height than Latin at the same size.**
/// Arabic stacks marks above and below the baseline — hamza, shadda, sukun, and
/// the descenders of ج/ح/ع — and at Latin leading these collide between lines.
/// So body text is 16/1.75 in Arabic and 16/1.6 in Latin. Do not normalise the
/// two: one shared value either wastes space in Latin or breaks Arabic.
///
/// **Arabic never takes letter-spacing.** Arabic is cursive; positive tracking
/// severs the joins and produces broken-looking words. Material's own
/// `TextTheme` sets `letterSpacing` on most roles, so every Arabic style below
/// zeroes it explicitly rather than inheriting.
abstract final class KafooType {
  /// The designed face, bundled in `apps/mobile/assets/fonts/` and declared in
  /// that app's `pubspec.yaml` — four weights, 400/500/600/700.
  ///
  /// **App-level rather than package-level, and the name follows from that.** A
  /// font a package owns is spelled `packages/kafoo_ui/…`; a font the app
  /// bundles is spelled plainly, as here. Getting it wrong does not fail — it
  /// silently falls back to the platform default, which is the whole bug
  /// bundling the font was meant to end. Glyph coverage includes the
  /// Arabic-Indic digits ٠–٩ and the U+066B/U+066C separators, because prices
  /// are written in them.
  static const String fontFamily = 'IBMPlexSansArabic';

  /// Reached only for a glyph the bundled face does not carry. Arabic rather
  /// than Latin on purpose: a Latin-metric fallback reflows a whole paragraph
  /// around one missing character.
  static const List<String> fontFamilyFallback = ['Noto Sans Arabic'];

  /// Tracking is allowed on Latin eyebrow and label text only, never on Arabic.
  static const double latinLabelTracking = 0.06;

  static const FontWeight _regular = FontWeight.w400;
  static const FontWeight _semi = FontWeight.w600;
  static const FontWeight _bold = FontWeight.w700;

  static TextStyle _style(double size, FontWeight weight, double height) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        height: height,
        // Zeroed, not omitted. See the class comment.
        letterSpacing: 0,
      );

  /// Welcome and onboarding only. Tight leading is safe because it is one or
  /// two lines and never sits in a paragraph.
  static TextStyle display({required bool arabic}) =>
      _style(40, _bold, arabic ? 1.35 : 1.2);

  /// The first line of a screen.
  static TextStyle screenTitle({required bool arabic}) =>
      _style(32, _bold, arabic ? 1.4 : 1.25);

  /// Section headings and sheet titles.
  ///
  /// 600 rather than 700: at 24px, bold Arabic starts to close its counters.
  static TextStyle section({required bool arabic}) =>
      _style(24, _semi, arabic ? 1.45 : 1.35);

  /// Card and row titles.
  static TextStyle mealName({required bool arabic}) =>
      _style(20, _semi, arabic ? 1.5 : 1.35);

  /// Voice assistant replies and primary buttons — read at arm's length or
  /// glanced at while cooking.
  static TextStyle bodyLarge({required bool arabic}) =>
      _style(18, _regular, arabic ? 1.75 : 1.6);

  /// The default for everything, and the minimum for any input field — smaller
  /// triggers iOS zoom-on-focus and is hard to proof-read in sun.
  static TextStyle body({required bool arabic}) =>
      _style(16, _regular, arabic ? 1.75 : 1.6);

  /// Metadata under a title.
  static TextStyle bodySmall({required bool arabic}) =>
      _style(14, _regular, arabic ? 1.7 : 1.5);

  /// Buttons, tabs, field labels. Weight carries the emphasis so the size can
  /// stay small.
  static TextStyle label({required bool arabic}) => _style(14, _semi, 1.4);

  /// The floor. Legal text and annotation — never a price, a button, or an
  /// instruction. If information matters it is 14px or larger.
  static TextStyle caption({required bool arabic}) =>
      _style(13, _regular, arabic ? 1.6 : 1.5);

  /// A status word from the closed set, in a list row.
  ///
  /// Large Arabic text is a closed vocabulary, each word always at the same
  /// size, weight, colour and position so it is recognised by silhouette rather
  /// than read. Colour must carry the same meaning as the word, redundantly: if
  /// the word is not read, the colour alone has to land.
  static final TextStyle glanceWordRow = _style(20, _bold, 1.4);

  /// The same word as a screen verdict.
  static final TextStyle glanceWordVerdict = _style(32, _bold, 1.4);

  /// A price, count or time in a list row.
  ///
  /// The largest type in the system, and that is the point: numbers are read by
  /// nearly everyone, words are not. Arabic-Indic numerals, never abbreviated.
  static final TextStyle numeralRow = _style(34, _bold, 1.2);

  /// The same, as a screen verdict. Ranges to 64 where the number is the whole
  /// screen; [numeralVerdictLarge] is that end of the range.
  static final TextStyle numeralVerdict = _style(48, _bold, 1.2);

  /// A verdict numeral on a confirmation gate, where nothing competes with it.
  static final TextStyle numeralVerdictLarge = _style(64, _bold, 1.2);
}

/// The Material [TextTheme] built from [KafooType].
///
/// Pass `arabic: false` only for a genuinely Latin surface. Arabic is the
/// source language, so it is the shape the scale is tuned for.
TextTheme kafooTextTheme({required bool arabic}) => TextTheme(
      displaySmall: KafooType.display(arabic: arabic),
      headlineMedium: KafooType.screenTitle(arabic: arabic),
      headlineSmall: KafooType.section(arabic: arabic),
      titleLarge: KafooType.mealName(arabic: arabic),
      bodyLarge: KafooType.bodyLarge(arabic: arabic),
      bodyMedium: KafooType.body(arabic: arabic),
      bodySmall: KafooType.bodySmall(arabic: arabic),
      labelLarge: KafooType.label(arabic: arabic),
      labelSmall: KafooType.caption(arabic: arabic),
    ).apply(
      fontFamily: KafooType.fontFamily,
      fontFamilyFallback: KafooType.fontFamilyFallback,
      bodyColor: KafooColors.onSurface,
      displayColor: KafooColors.onSurface,
    );
