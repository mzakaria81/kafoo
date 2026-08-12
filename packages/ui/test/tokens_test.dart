import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ui/ui.dart';

void main() {
  group('KafooSpacing', () {
    test('the scale ascends', () {
      expect(KafooSpacing.xs, lessThan(KafooSpacing.sm));
      expect(KafooSpacing.sm, lessThan(KafooSpacing.row));
      expect(KafooSpacing.row, lessThan(KafooSpacing.md));
      expect(KafooSpacing.md, lessThan(KafooSpacing.lg));
      expect(KafooSpacing.lg, lessThan(KafooSpacing.xl));
      expect(KafooSpacing.xl, lessThan(KafooSpacing.section));
    });

    test('the minimum tap target meets the accessibility floor', () {
      expect(KafooSpacing.minTapTarget, greaterThanOrEqualTo(48));
    });

    test('a section gap is a finger wide, on purpose', () {
      // The rhythm of the page and the size of a finger are one unit, so
      // vertical spacing can never accidentally shrink a target.
      expect(KafooSpacing.section, KafooSpacing.minTapTarget);
    });

    test('the voice targets are larger than merely compliant', () {
      // The talk button is found by thumb without looking, sometimes with wet
      // hands; «أيوة» is the common answer to a gate and both answers must be
      // unmissable.
      expect(KafooSpacing.talkButton, greaterThan(KafooSpacing.minTapTarget));
      expect(KafooSpacing.confirmYes, greaterThan(KafooSpacing.confirmNo));
      expect(KafooSpacing.confirmNo, greaterThan(KafooSpacing.minTapTarget));
    });
  });

  group('KafooRadius', () {
    test('radius shrinks as the element gets smaller and more functional', () {
      // A 24px radius on a 48px button eats its own corners.
      expect(KafooRadius.control, lessThan(KafooRadius.thumbnail));
      expect(KafooRadius.thumbnail, lessThan(KafooRadius.panel));
      expect(KafooRadius.panel, lessThan(KafooRadius.card));
      expect(KafooRadius.card, lessThan(KafooRadius.sheet));
    });
  });

  group('kafooTheme', () {
    test('keeps the warmed surface rather than a generated white', () {
      final theme = kafooTheme();
      expect(theme.colorScheme.surface, KafooColors.surface);
      expect(theme.scaffoldBackgroundColor, KafooColors.surface);
      expect(theme.colorScheme.error, KafooColors.error);
    });

    test('cards carry a border and no shadow', () {
      // A soft shadow is nearly invisible on a mid-range panel in direct sun,
      // so structure that carries meaning uses a border instead.
      expect(kafooTheme().cardTheme.elevation, 0);
    });

    test('buttons floor at the tap target without fixing their height', () {
      final style = kafooTheme().elevatedButtonTheme.style!;
      final size = style.minimumSize!.resolve({})!;
      expect(size.height, KafooSpacing.minTapTarget);
      // Padding, not a fixed height, so the button grows with scaled text
      // instead of clipping it.
      expect(style.fixedSize, isNull);
      expect(style.padding, isNotNull);
    });
  });
}
