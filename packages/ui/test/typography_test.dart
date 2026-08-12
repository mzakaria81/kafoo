import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ui/ui.dart';

/// The two typographic rules that are easiest to break by accident.
void main() {
  group('Arabic line-height runs higher than Latin', () {
    // Arabic stacks marks above and below the baseline — hamza, shadda, sukun,
    // and the descenders of ج/ح/ع — and at Latin leading these collide between
    // lines. A shared value either wastes space in Latin or breaks Arabic.
    final pairs = <String, (double, double)>{
      'display': (
        KafooType.display(arabic: true).height!,
        KafooType.display(arabic: false).height!
      ),
      'screen title': (
        KafooType.screenTitle(arabic: true).height!,
        KafooType.screenTitle(arabic: false).height!
      ),
      'section': (
        KafooType.section(arabic: true).height!,
        KafooType.section(arabic: false).height!
      ),
      'meal name': (
        KafooType.mealName(arabic: true).height!,
        KafooType.mealName(arabic: false).height!
      ),
      'body': (
        KafooType.body(arabic: true).height!,
        KafooType.body(arabic: false).height!
      ),
      'body small': (
        KafooType.bodySmall(arabic: true).height!,
        KafooType.bodySmall(arabic: false).height!
      ),
      'caption': (
        KafooType.caption(arabic: true).height!,
        KafooType.caption(arabic: false).height!
      ),
    };

    pairs.forEach((role, heights) {
      test(role, () => expect(heights.$1, greaterThan(heights.$2)));
    });

    test('body sits at the documented 1.75 / 1.6', () {
      expect(KafooType.body(arabic: true).height, 1.75);
      expect(KafooType.body(arabic: false).height, 1.6);
    });
  });

  test('no style applies letter-spacing', () {
    // Arabic is cursive; positive tracking severs the joins and produces
    // broken-looking words. Material's own TextTheme sets letterSpacing on most
    // roles, so every style has to zero it rather than inherit.
    final theme = kafooTextTheme(arabic: true);
    for (final style in [
      theme.displaySmall,
      theme.headlineMedium,
      theme.headlineSmall,
      theme.titleLarge,
      theme.bodyLarge,
      theme.bodyMedium,
      theme.bodySmall,
      theme.labelLarge,
      theme.labelSmall,
      KafooType.glanceWordRow,
      KafooType.glanceWordVerdict,
      KafooType.numeralRow,
      KafooType.numeralVerdict,
    ]) {
      expect(style!.letterSpacing, 0);
    }
  });

  test('numerals are the largest type in the system', () {
    // Numbers are read by nearly everyone; words are not. If the only
    // difference between two choices is set in small text, the screen has
    // failed.
    expect(
      KafooType.numeralRow.fontSize,
      greaterThan(KafooType.mealName(arabic: true).fontSize!),
    );
    expect(
      KafooType.numeralRow.fontSize,
      greaterThan(KafooType.glanceWordRow.fontSize!),
    );
    expect(
      KafooType.numeralVerdict.fontSize,
      greaterThan(KafooType.numeralRow.fontSize!),
    );
  });

  test('nothing is set below the 13px floor', () {
    final theme = kafooTextTheme(arabic: true);
    for (final style in [
      theme.bodyMedium,
      theme.bodySmall,
      theme.labelLarge,
      theme.labelSmall,
    ]) {
      expect(style!.fontSize, greaterThanOrEqualTo(13));
    }
  });

  test('an input never renders below 16px', () {
    // Smaller triggers iOS zoom-on-focus and is hard to proof-read in sun.
    expect(kafooTheme().inputDecorationTheme.hintStyle!.fontSize,
        greaterThanOrEqualTo(16));
  });
}
