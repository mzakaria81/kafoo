import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ui/ui.dart';

/// WCAG 2.x relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

/// The palette's contrast claims, computed rather than asserted in a comment.
///
/// DESIGN.md states a ratio beside every token, and those numbers run about two
/// percent high — `voice-deep` is documented at 8.9:1 and measures 7.36:1. None
/// of them changes a pass into a fail, so what this file checks is the
/// threshold that matters (AA, 4.5:1) rather than the documented figure. If a
/// token is ever nudged "just a shade lighter" to look nicer on a laptop, this
/// is what says no.
void main() {
  const surface = KafooColors.surface;

  group('text on the app surface meets WCAG AA', () {
    const pairs = <String, Color>{
      'text': KafooColors.onSurface,
      'text-muted': KafooColors.textMuted,
      'text-subtle': KafooColors.textSubtle,
      'primary': KafooColors.primary,
      'primary-deep': KafooColors.primaryDeep,
      'voice': KafooColors.voice,
      'voice-deep': KafooColors.voiceDeep,
      'error': KafooColors.error,
      'success': KafooColors.success,
      'warning': KafooColors.warning,
    };

    pairs.forEach((name, colour) {
      test(name, () {
        expect(
          _contrast(colour, surface),
          greaterThanOrEqualTo(4.5),
          reason: '$name must stay readable on a washed-out screen in sunlight',
        );
      });
    });
  });

  group('white labels on coloured fills meet WCAG AA', () {
    const fills = <String, Color>{
      'primary': KafooColors.primary,
      'voice': KafooColors.voice,
      'error': KafooColors.error,
      'success': KafooColors.success,
    };

    fills.forEach((name, fill) {
      test(name, () {
        expect(
            _contrast(KafooColors.onPrimary, fill), greaterThanOrEqualTo(4.5));
      });
    });
  });

  test('text on tinted panels meets WCAG AA', () {
    expect(_contrast(KafooColors.primaryDeep, KafooColors.primaryTint),
        greaterThanOrEqualTo(4.5));
    expect(_contrast(KafooColors.voiceDeep, KafooColors.voiceTint),
        greaterThanOrEqualTo(4.5));
    expect(_contrast(KafooColors.error, KafooColors.errorTint),
        greaterThanOrEqualTo(4.5));
    expect(_contrast(KafooColors.success, KafooColors.successTint),
        greaterThanOrEqualTo(4.5));
    expect(_contrast(KafooColors.textMuted, KafooColors.surfaceSunken),
        greaterThanOrEqualTo(4.5));
  });

  test('assistant speech is readable on a dark voice panel', () {
    expect(_contrast(KafooColors.quotedText, KafooColors.darkSurface),
        greaterThanOrEqualTo(4.5));
  });

  test('text-disabled fails AA on purpose', () {
    // The failing contrast IS the signal that the control is inert. If someone
    // "fixes" this token, disabled controls stop looking disabled.
    expect(_contrast(KafooColors.textDisabled, surface), lessThan(4.5));
  });

  test('error and primary separate by hue, not only by lightness', () {
    // In sunlight, perceived contrast compresses and two colours of similar
    // hue wash out to the same colour — which is how a normal button became
    // indistinguishable from an error. The fix was to move `error` out of the
    // terracotta hue family, so the guard is comparative: the current error
    // must sit further from primary than the red it replaced, which was only
    // about 19 degrees away.
    double apart(Color a, Color b) {
      final d = (HSLColor.fromColor(a).hue - HSLColor.fromColor(b).hue).abs();
      return d > 180 ? 360 - d : d;
    }

    const replacedRed = Color(0xFFB91C1C);
    final now = apart(KafooColors.error, KafooColors.primary);
    final before = apart(replacedRed, KafooColors.primary);

    expect(now, greaterThan(before * 1.5));
    expect(now, greaterThan(30));
  });

  test('voice is the only cool colour in the system', () {
    // Everything else is warm. Reserving one hue for voice is what lets a Cook
    // tell "I'm hearing you" from "buy this" before reading a word.
    for (final warm in const [
      KafooColors.primary,
      KafooColors.primaryDeep,
      KafooColors.error,
      KafooColors.warning,
      KafooColors.success,
    ]) {
      final hue = HSLColor.fromColor(warm).hue;
      expect(
        hue > 150 && hue < 250,
        isFalse,
        reason: 'only voice may sit in the blue-teal range',
      );
    }
    final voiceHue = HSLColor.fromColor(KafooColors.voice).hue;
    expect(voiceHue, inInclusiveRange(150, 250));
  });
}
