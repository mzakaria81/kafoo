import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ui/ui.dart';

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// CIE L*a*b*, for perceptual distance rather than contrast.
///
/// Contrast answers "can this be read against that". It says nothing about
/// whether two colours look like the same colour, which is a different failure
/// and the one that put a terracotta primary next to a terracotta error for
/// three weeks.
List<double> _lab(Color c) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  final r = lin(c.r);
  final g = lin(c.g);
  final b = lin(c.b);
  final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  final fx = f(x);
  final fy = f(y);
  final fz = f(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

double _deltaE(Color a, Color b) {
  final la = _lab(a);
  final lb = _lab(b);
  return math.sqrt(
    math.pow(la[0] - lb[0], 2) +
        math.pow(la[1] - lb[1], 2) +
        math.pow(la[2] - lb[2], 2),
  );
}

void main() {
  group('KafooSpacing', () {
    test('the scale ascends', () {
      expect(KafooSpacing.xs, lessThan(KafooSpacing.sm));
      expect(KafooSpacing.sm, lessThan(KafooSpacing.rowGap));
      expect(KafooSpacing.rowGap, lessThan(KafooSpacing.md));
      expect(KafooSpacing.md, lessThan(KafooSpacing.lg));
      expect(KafooSpacing.lg, lessThan(KafooSpacing.xl));
      expect(KafooSpacing.xl, lessThan(KafooSpacing.xxl));
    });

    test('the minimum tap target meets the accessibility floor', () {
      expect(KafooSpacing.minTapTarget, greaterThanOrEqualTo(48));
    });

    test('section spacing and a finger are the same number, on purpose', () {
      // DESIGN.md §4: one value doing two jobs so vertical rhythm can never
      // accidentally shrink a tap target.
      expect(KafooSpacing.xxl, KafooSpacing.minTapTarget);
    });

    test('the voice targets are larger than the floor', () {
      // ADR-0013: the talk button is found by thumb without looking, and «أيوة»
      // is the common answer on a gate.
      expect(KafooSpacing.talkButton, greaterThan(KafooSpacing.minTapTarget));
      expect(KafooSpacing.gateConfirm, greaterThan(KafooSpacing.minTapTarget));
    });
  });

  group('KafooColors contrast on the surface', () {
    // Measured, not asserted from the design's own table — the point of a test
    // is to disagree with the document when the document is wrong.
    const surface = KafooColors.surface;

    test('every text token passes AA on EVERY surface, not just the page', () {
      // textSubtle passed on `surface` at 4.66:1 and failed on `surfaceSunken`
      // at 4.43:1 — and surfaceSunken is the documented fill for drafts and
      // wells, which is exactly where annotation lands. Checking one background
      // is checking the easy case.
      const backgrounds = <String, Color>{
        'surface': KafooColors.surface,
        'surfaceRaised': KafooColors.surfaceRaised,
        'surfaceSunken': KafooColors.surfaceSunken,
      };
      const texts = <String, Color>{
        'onSurface': KafooColors.onSurface,
        'textMuted': KafooColors.textMuted,
        'textSubtle': KafooColors.textSubtle,
        'primaryDeep': KafooColors.primaryDeep,
        'voiceDeep': KafooColors.voiceDeep,
        'danger': KafooColors.danger,
        'success': KafooColors.success,
        'warning': KafooColors.warning,
      };
      texts.forEach((tName, text) {
        backgrounds.forEach((bName, bg) {
          expect(
            _contrast(text, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$tName on $bName is below AA.',
          );
        });
      });
    });

    test('a boundary that carries meaning clears 3:1', () {
      // WCAG 1.4.11. `border` and `borderStrong` are 1.29:1 and 1.54:1 — correct
      // as the design drew them, and decorative by this measure. An empty input
      // field is the typing fallback a Cook reaches when speech fails her, so
      // its edge is the only thing marking where to tap and cannot be decorative.
      expect(
        _contrast(KafooColors.borderMeaningful, KafooColors.surface),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('the documented ratios are the measured ratios', () {
      // Two comments claimed numbers computed against pure white rather than the
      // warm surface. A wrong figure in a comment is what the next person trusts
      // instead of measuring.
      expect(
        _contrast(KafooColors.voiceDeep, KafooColors.surface),
        closeTo(7.36, 0.05),
      );
      expect(
        _contrast(KafooColors.textDisabled, KafooColors.surface),
        closeTo(2.45, 0.05),
      );
      expect(
        _contrast(KafooColors.voiceDeep, KafooColors.voiceTint),
        greaterThanOrEqualTo(7.0), // the AAA claim
      );
    });

    test('legacy: text tokens pass on the page', () {
      const pairs = <String, Color>{
        'onSurface': KafooColors.onSurface,
        'textMuted': KafooColors.textMuted,
        'textSubtle': KafooColors.textSubtle,
        'primaryDeep': KafooColors.primaryDeep,
        'voiceDeep': KafooColors.voiceDeep,
        'danger': KafooColors.danger,
        'success': KafooColors.success,
        'warning': KafooColors.warning,
      };
      pairs.forEach((name, color) {
        expect(
          _contrast(color, surface),
          greaterThanOrEqualTo(4.5),
          reason: '$name is below AA on the surface. Sunlight compresses '
              'perceived contrast further, so AA is the floor here, not a goal.',
        );
      });
    });

    test('a label on a primary fill passes AA', () {
      expect(
        _contrast(KafooColors.onPrimary, KafooColors.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('textDisabled fails AA, deliberately', () {
      // Not an oversight. Failing contrast IS the signal that a control is
      // inert. A future change that "fixes" this has removed the signal, so the
      // test asserts the failure.
      expect(
        _contrast(KafooColors.textDisabled, surface),
        lessThan(4.5),
        reason: 'textDisabled must stay sub-AA — it means "you cannot use '
            'this". If it now passes, it is being used for readable content '
            'somewhere and needs a different token.',
      );
    });
  });

  group('ColorScheme slots the app reads as text', () {
    // THE TEST THAT WOULD HAVE CAUGHT THE WORST BUG IN THIS DESIGN SYSTEM.
    //
    // `outline` was wired to a 1.54:1 border colour while thirteen call sites in
    // the app used it as a text colour — including the "this is an AI estimate"
    // notice beside allergens and the sentence telling a Cook she must approve
    // those estimates before publishing. Every token test passed, because the
    // tokens were fine; the WIRING was wrong, and nothing looked at the wiring.
    final scheme = kafooTheme().colorScheme;

    test('every slot used as a text colour clears AA on the surface', () {
      final slots = <String, Color>{
        'onSurface': scheme.onSurface,
        'onSurfaceVariant': scheme.onSurfaceVariant,
        'outline': scheme.outline,
        'error': scheme.error,
        'primary': scheme.primary,
        'onPrimaryContainer': scheme.onPrimaryContainer,
        'onSecondaryContainer': scheme.onSecondaryContainer,
        'onTertiaryContainer': scheme.onTertiaryContainer,
        'onErrorContainer': scheme.onErrorContainer,
      };
      slots.forEach((name, color) {
        expect(
          _contrast(color, scheme.surface),
          greaterThanOrEqualTo(4.5),
          reason: 'colorScheme.$name is below AA on the surface. Grep the app '
              'before assuming this slot is decorative — Material role names '
              'suggest borders and the app reads several of them as text.',
        );
      });
    });

    test('a dialog has a background distinct from the page behind it', () {
      // All six surfaceContainer roles were unset, so a dialog rendered at
      // 1.00:1 against the page — no boundary but the scrim. ADR-0013 makes the
      // confirmation gate the one surface that must be unmistakably in front.
      expect(scheme.surfaceContainerHigh, isNot(scheme.surface));
    });

    test('tertiary is not the reserved voice hue', () {
      // Unset, tertiary resolves to secondary — the teal ADR-0013 reserves for
      // "the machine is talking".
      expect(scheme.tertiary, isNot(KafooColors.voice));
    });
  });

  group('KafooColors hue separation', () {
    test('danger is not the same colour as primary at a glance', () {
      // THE TEST THIS FILE EXISTS FOR. Kafoo shipped #B91C1C as danger beside
      // #C2410C as primary until 2026-08-10: both passed contrast, and in
      // sunlight they washed out to the same colour, so an ordinary button and
      // an error message became indistinguishable. Contrast could not catch it
      // because contrast is not the property that failed.
      //
      // Under about 20 reads as one colour family; over about 20 reads as two
      // hues. The old pair measured 16.4. The current pair measures ~39.5.
      expect(
        _deltaE(KafooColors.danger, KafooColors.primary),
        greaterThan(20),
        reason: 'danger and primary are perceptually too close. A Cook in '
            'daylight will not tell a destructive action from an ordinary one.',
      );
    });

    test('voice is the only cool hue, and separates from primary', () {
      // ADR-0013 reserves a hue to mean "the machine is talking". If it drifts
      // toward the brand colour, that meaning stops being readable before any
      // word is read.
      expect(_deltaE(KafooColors.voice, KafooColors.primary), greaterThan(30));
    });

    test('success separates from voice — both are green-ish', () {
      expect(_deltaE(KafooColors.success, KafooColors.voice), greaterThan(20));
    });
  });

  group('KafooType', () {
    test('Arabic line-heights exceed the Latin equivalents', () {
      // DESIGN.md §3: Arabic stacks marks above and below the baseline, so at
      // Latin leading they collide between lines. Body is 1.75 in Arabic where
      // Latin would be 1.6. A change that "normalises" these breaks Arabic.
      expect(KafooType.body.height, greaterThanOrEqualTo(1.7));
      expect(KafooType.bodyLarge.height, greaterThanOrEqualTo(1.7));
      expect(KafooType.bodySmall.height, greaterThanOrEqualTo(1.6));
    });

    test('nothing in the scale is below the 13px floor', () {
      final sizes = [
        KafooType.display,
        KafooType.screenTitle,
        KafooType.section,
        KafooType.mealName,
        KafooType.bodyLarge,
        KafooType.body,
        KafooType.bodySmall,
        KafooType.label,
        KafooType.caption,
      ].map((s) => s.fontSize!);
      for (final size in sizes) {
        expect(size, greaterThanOrEqualTo(13));
      }
    });

    test('no Arabic style is lighter than 400', () {
      // Thin strokes vanish outdoors.
      final weights = [
        KafooType.bodyLarge,
        KafooType.body,
        KafooType.bodySmall,
        KafooType.caption,
      ].map((s) => s.fontWeight!.value);
      for (final weight in weights) {
        expect(weight, greaterThanOrEqualTo(FontWeight.w400.value));
      }
    });

    test('a numeral is the largest thing in the system', () {
      // ADR-0013: numbers are read by nearly everyone, words are not. If a
      // heading ever outgrows a price, the hierarchy has inverted.
      expect(
        KafooType.numeralRow.fontSize,
        greaterThan(KafooType.section.fontSize!),
      );
      expect(
        KafooType.numeralVerdict.fontSize,
        greaterThan(KafooType.display.fontSize!),
      );
    });

    test('a glance word outranks the Meal name beside it', () {
      // The status is recognised by shape; the name is spoken on tap. If the
      // name were larger, the screen would be asking to be read.
      expect(
        KafooType.glanceWordRow.fontSize,
        greaterThanOrEqualTo(KafooType.mealName.fontSize!),
      );
      expect(KafooType.glanceWordRow.fontWeight, FontWeight.w700);
    });

    test('no style applies letter-spacing', () {
      // Arabic is cursive: positive tracking severs the joins and produces
      // broken-looking words.
      final styles = [
        KafooType.display,
        KafooType.screenTitle,
        KafooType.section,
        KafooType.mealName,
        KafooType.bodyLarge,
        KafooType.body,
        KafooType.bodySmall,
        KafooType.label,
        KafooType.caption,
        KafooType.glanceWordRow,
        KafooType.glanceWordVerdict,
        KafooType.numeralRow,
        KafooType.numeralVerdict,
      ];
      for (final style in styles) {
        expect(style.letterSpacing, anyOf(isNull, 0.0));
      }
    });
  });

  group('kafooTheme', () {
    test('carries the bundled Arabic font, with an Arabic fallback', () {
      final theme = kafooTheme();
      expect(theme.textTheme.bodyMedium?.fontFamily, KafooType.fontFamily);
      // Arabic-first fallback: a swap from a Latin-metric face reflows the
      // whole screen.
      expect(
        theme.textTheme.bodyMedium?.fontFamilyFallback,
        contains('Noto Sans Arabic'),
      );
    });

    test('uses the chosen colours rather than deriving them from a seed', () {
      final theme = kafooTheme();
      expect(theme.colorScheme.primary, KafooColors.primary);
      expect(theme.colorScheme.error, KafooColors.danger);
      expect(theme.colorScheme.surface, KafooColors.surface);
      expect(theme.scaffoldBackgroundColor, KafooColors.surface);
    });

    test('the app bar is bordered, not shadowed', () {
      // DESIGN.md §5: a shadow is nearly invisible on a cheap panel in
      // sunlight, so structure that carries meaning uses a border.
      final theme = kafooTheme();
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.shape, isA<Border>());
    });

    test('buttons carry the tap-target floor by default', () {
      // So a screen cannot drop below 48dp by forgetting to ask.
      final theme = kafooTheme();
      final size =
          theme.filledButtonTheme.style?.minimumSize?.resolve(<WidgetState>{});
      expect(size?.height, greaterThanOrEqualTo(KafooSpacing.minTapTarget));
    });
  });
}
