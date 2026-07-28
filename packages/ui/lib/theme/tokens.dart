import 'package:flutter/widgets.dart';

/// The spacing scale.
///
/// Use these rather than literal numbers, and pair them with
/// `EdgeInsetsDirectional` so layouts survive RTL.
abstract final class KafooSpacing {
  /// 4 logical pixels.
  static const double xs = 4;

  /// 8 logical pixels.
  static const double sm = 8;

  /// 16 logical pixels.
  static const double md = 16;

  /// 24 logical pixels.
  static const double lg = 24;

  /// 32 logical pixels.
  static const double xl = 32;

  /// The minimum tap target Kafoo ships, in logical pixels.
  ///
  /// Anything smaller fails the accessibility review.
  static const double minTapTarget = 48;
}

/// The color palette.
///
/// Contrast is checked against a phone held in a bright kitchen, not a
/// designer's monitor.
abstract final class KafooColors {
  /// Primary brand color.
  static const Color primary = Color(0xFFC2410C);

  /// Surface behind most content.
  static const Color surface = Color(0xFFFFFBF7);

  /// Default body text.
  static const Color onSurface = Color(0xFF1C1917);

  /// Text and icons on [primary].
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Errors and destructive actions.
  static const Color danger = Color(0xFFB91C1C);
}
