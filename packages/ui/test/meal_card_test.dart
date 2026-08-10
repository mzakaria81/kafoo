import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ui/ui.dart';

/// The one shared widget the design system owns, and it had no test at all.
///
/// `dart.md` asks for golden tests on `packages/ui/` components. This is not a
/// golden — a golden would pin the pixels and this pins the two things that were
/// actually wrong on 2026-08-10: the price was the smallest text on the card
/// while a token test claimed numerals are the largest thing in the system, and
/// nothing had ever rendered the card at a real phone size with the text turned
/// up, which is the combination that overflows.
Widget _app(Widget child, {double textScale = 1.0}) => MaterialApp(
      theme: kafooTheme(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: child),
        ),
      ),
    );

const _card = MealCard(
  title: 'محشي ورق عنب بالزيت',
  price: '١٢٠ جنيه',
  kitchenLabel: 'مطبخ أم علي',
  semanticsLabel: 'محشي ورق عنب بالزيت، ١٢٠ جنيه، من مطبخ أم علي',
);

void main() {
  testWidgets('the price is the largest text on the card', (tester) async {
    await tester.pumpWidget(_app(_card));

    double sizeOf(String text) =>
        tester.widget<Text>(find.text(text)).style!.fontSize!;

    final price = sizeOf('١٢٠ جنيه');
    expect(
      price,
      greaterThan(sizeOf('محشي ورق عنب بالزيت')),
      reason: 'The Meal name outranks the price. For a Cook or Customer who '
          'does not read comfortably the number is the one reliably readable '
          'thing on this card, so it cannot be the smallest.',
    );
    expect(price, greaterThan(sizeOf('مطبخ أم علي')));
    expect(price, KafooType.numeralRow.fontSize);
  });

  testWidgets('it does not clip at 200% on a small phone', (tester) async {
    // 320x568 is the smallest handset still in use. A 34px numeral beside a
    // thumbnail in a Row is exactly the shape that overflows, so this needs the
    // assertion at the size that breaks rather than the harness default.
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_card, textScale: 2.0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('it carries one screen-reader label, not three', (tester) async {
    await tester.pumpWidget(_app(_card));
    expect(
      find.bySemanticsLabel('محشي ورق عنب بالزيت، ١٢٠ جنيه، من مطبخ أم علي'),
      findsOneWidget,
    );
  });

  testWidgets('the price uses a token colour, not a derived one',
      (tester) async {
    // primaryDeep rather than colorScheme.primary: a price is text at a weight
    // where terracotta sits too light against the warm surface.
    await tester.pumpWidget(_app(_card));
    final style = tester.widget<Text>(find.text('١٢٠ جنيه')).style!;
    expect(style.color, KafooColors.primaryDeep);
  });
}
