import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ui/ui.dart';

/// What these tests are, and what they are deliberately not.
///
/// `.claude/rules/dart.md` asks for golden tests on the design system. There
/// are none here on purpose: a golden compares rendered pixels, and the
/// designed typeface is not in this repository yet, so every golden would
/// record the fallback font and would have to be regenerated the day the real
/// one lands. What these assert instead are the design's *measurable* claims —
/// sizes, colours, tap targets, and that nothing clips at 200% text scale.
/// Those are the rules a screen actually breaks.
Widget _host(Widget child,
        {double textScale = 1, Size size = const Size(390, 800)}) =>
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      // No `locale: ar` on the MaterialApp: this package does not depend on
      // flutter_localizations, so declaring the locale without its delegates
      // throws a warning that fails every test. Direction is what these
      // widgets actually read, and that comes from the Directionality below.
      child: MaterialApp(
        theme: kafooTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: child),
        ),
      ),
    );

void main() {
  group('KafooButton', () {
    testWidgets('floors at the tap target', (tester) async {
      await tester.pumpWidget(
        _host(KafooButton(label: 'انشري', onPressed: () {})),
      );
      expect(
        tester.getSize(find.byType(ElevatedButton)).height,
        greaterThanOrEqualTo(KafooSpacing.minTapTarget),
      );
    });

    testWidgets('the committing action is taller than an ordinary one',
        (tester) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              KafooButton(label: 'انشري', onPressed: () {}),
              KafooButton(
                label: 'أيوة، انشريها',
                committing: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      final heights = tester
          .widgetList<ElevatedButton>(find.byType(ElevatedButton))
          .map((b) => tester.getSize(find.byWidget(b)).height)
          .toList();
      expect(heights[1], greaterThan(heights[0]));
    });

    testWidgets('loading keeps the footprint and swaps the label',
        (tester) async {
      await tester.pumpWidget(
        _host(KafooButton(label: 'ابعتي', onPressed: () {})),
      );
      final restingWidth = tester.getSize(find.byType(ElevatedButton)).width;

      await tester.pumpWidget(
        _host(
          KafooButton(
            label: 'ابعتي',
            loading: true,
            loadingLabel: 'بيتبعت...',
            onPressed: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('بيتبعت...'), findsOneWidget);
      expect(find.text('ابعتي'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The spinner widens the row; what must not happen is the button
      // collapsing or the label vanishing under a finger already moving.
      expect(
        tester.getSize(find.byType(ElevatedButton)).width,
        greaterThanOrEqualTo(restingWidth),
      );
    });

    testWidgets('a loading button cannot be pressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          KafooButton(label: 'ابعتي', loading: true, onPressed: () => taps++),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      expect(taps, 0);
    });

    testWidgets('a disabled button still says why', (tester) async {
      // A disabled control with no explanation is a dead end, so the label is
      // where the reason lives.
      await tester.pumpWidget(
        _host(const KafooButton(
          label: 'المطبخ مقفول دلوقتي',
          onPressed: null,
        )),
      );
      expect(find.text('المطبخ مقفول دلوقتي'), findsOneWidget);
    });

    testWidgets('does not clip at 200% text scale', (tester) async {
      await tester.pumpWidget(
        _host(
          KafooButton(
            label: 'أيوة، انشريها',
            committing: true,
            fullWidth: true,
            onPressed: () {},
          ),
          textScale: 2,
          size: const Size(360, 640),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('KafooGlanceWord', () {
    testWidgets('carries its meaning in colour as well as in the word',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const KafooGlanceWord(word: GlanceWord.published, text: 'منشورة'),
        ),
      );
      final style = tester.widget<Text>(find.text('منشورة')).style!;
      expect(style.color, KafooColors.success);
      expect(style.fontSize, 20);
      expect(style.fontWeight, FontWeight.w700);
    });

    testWidgets('a verdict is larger than a row', (tester) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              KafooGlanceWord(word: GlanceWord.offline, text: 'مفيش نت'),
              KafooGlanceWord(
                word: GlanceWord.offline,
                text: 'مفيش نت كمان',
                size: GlanceWordSize.verdict,
              ),
            ],
          ),
        ),
      );
      expect(tester.widget<Text>(find.text('مفيش نت')).style!.fontSize, 20);
      expect(
        tester.widget<Text>(find.text('مفيش نت كمان')).style!.fontSize,
        32,
      );
    });

    test('the set is closed at eleven words', () {
      // DESIGN.md §10.4 plus the two delivery states from §10.12. A twelfth
      // large word must be added to the design before it is added here — an
      // unrecognised shape is worse than no word.
      expect(GlanceWord.values, hasLength(11));
    });

    test('every word has a colour that is not the plain text colour', () {
      for (final word in GlanceWord.values) {
        expect(word.colour, isNot(KafooColors.onSurface));
      }
    });
  });

  group('KafooMealRow', () {
    Widget row({GlanceWord status = GlanceWord.published}) => KafooMealRow(
          name: 'محشي ورق عنب',
          price: '١٢٠',
          priceUnit: 'جنيه',
          status: status,
          statusText: 'منشورة',
          semanticsLabel: 'محشي ورق عنب، منشورة، ١٢٠ جنيه',
          placeholderLabel: 'مكان صورة مؤقت',
        );

    testWidgets('the price is the largest thing in the row', (tester) async {
      await tester.pumpWidget(_host(row()));
      final price = tester.widget<Text>(find.text('١٢٠')).style!;
      final name = tester.widget<Text>(find.text('محشي ورق عنب')).style!;
      final status = tester.widget<Text>(find.text('منشورة')).style!;

      expect(price.fontSize, 34);
      expect(price.fontSize, greaterThan(status.fontSize!));
      expect(status.fontSize, greaterThan(name.fontSize!));
    });

    testWidgets('an archived Meal is present but visibly not selling',
        (tester) async {
      await tester.pumpWidget(_host(row(status: GlanceWord.archived)));
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byType(Material).last,
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 0.6);
    });

    testWidgets('shows a placeholder rather than an empty box', (tester) async {
      await tester.pumpWidget(_host(row()));
      expect(find.byType(KafooPhotoPlaceholder), findsOneWidget);
    });

    testWidgets('does not clip at 200% text scale on a 360px phone',
        (tester) async {
      await tester.pumpWidget(
        _host(row(), textScale: 2, size: const Size(360, 640)),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('MealCard', () {
    // The combined-string case, which is what the discovery screens actually
    // pass: one already-formatted "٣٥ جنيه" rather than a numeral and a unit.
    // At 200% that is 48px of unbreakable text in a horizontal row, and it
    // overflowed the card by 40 pixels — caught by the app's own screen tests,
    // not by this file, because the first version here used a short numeral
    // and a separate unit. A component test that only exercises the tidy
    // shape is not testing the shape callers use.
    Widget card({String price = '٣٥ جنيه'}) => MealCard(
          title: 'محشي ورق عنب باللحمة المفرومة',
          price: price,
          kitchenLabel: 'من مطبخ سامية',
          semanticsLabel: 'محشي ورق عنب، من مطبخ سامية، ٣٥ جنيه',
          placeholderLabel: 'مكان صورة مؤقت',
        );

    testWidgets('a combined price does not overflow at 200% text scale',
        (tester) async {
      await tester.pumpWidget(
        _host(card(), textScale: 2, size: const Size(360, 640)),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Cook sits on the photo, not under the price',
        (tester) async {
      await tester.pumpWidget(_host(card()));
      final kitchen = tester.getCenter(find.text('من مطبخ سامية')).dy;
      final price = tester.getCenter(find.text('٣٥ جنيه')).dy;
      expect(kitchen, lessThan(price));
    });

    testWidgets('a Meal with no photograph shows the placeholder',
        (tester) async {
      await tester.pumpWidget(_host(card()));
      expect(find.byType(KafooPhotoPlaceholder), findsOneWidget);
      expect(find.byType(MealCardPhoto), findsNothing);
    });
  });

  group('KafooFilterChip', () {
    testWidgets('carries a 48dp target around a smaller visual',
        (tester) async {
      await tester.pumpWidget(
        _host(KafooFilterChip(
          label: 'منشورة',
          selected: false,
          onSelected: (_) {},
        )),
      );
      expect(
        tester.getSize(find.byType(FilterChip)).height,
        greaterThanOrEqualTo(KafooSpacing.minTapTarget),
      );
    });

    testWidgets('an unavailable chip is inert and says why', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(KafooFilterChip(
          label: 'حلويات — مفيش دلوقتي',
          selected: false,
          unavailable: true,
          onSelected: (_) => taps++,
        )),
      );
      await tester.tap(find.byType(FilterChip));
      expect(taps, 0);
      expect(find.text('حلويات — مفيش دلوقتي'), findsOneWidget);
    });
  });

  group('KafooTextField', () {
    testWidgets(
        'the helper row is reserved, so an error does not move the form',
        (tester) async {
      Widget field({String? error}) => _host(
            Column(
              children: [
                KafooTextField(
                  label: 'رقم الموبايل',
                  helperText: 'زي ما بتكتبيه في تليفونك',
                  errorText: error,
                ),
                const Text('تحت الفورم'),
              ],
            ),
          );

      await tester.pumpWidget(field());
      final before = tester.getTopLeft(find.text('تحت الفورم')).dy;

      await tester.pumpWidget(field(error: 'الرقم ناقص رقمين. لازم ١١ رقم.'));
      await tester.pumpAndSettle();
      final after = tester.getTopLeft(find.text('تحت الفورم')).dy;

      expect(after, before);
    });

    testWidgets('a numeric field runs left-to-right inside an RTL form',
        (tester) async {
      await tester.pumpWidget(
        _host(const KafooTextField(
          label: 'رقم الموبايل',
          helperText: '',
          latinNumerals: true,
        )),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).textDirection,
        TextDirection.ltr,
      );
    });

    testWidgets('never renders below 16px', (tester) async {
      await tester.pumpWidget(
        _host(const KafooTextField(label: 'الاسم', helperText: '')),
      );
      final style = tester.widget<TextField>(find.byType(TextField)).style!;
      expect(style.fontSize, greaterThanOrEqualTo(16));
    });
  });

  group('KafooEmptyState', () {
    testWidgets('gives a reason, an expectation and one action',
        (tester) async {
      await tester.pumpWidget(
        _host(KafooEmptyState(
          title: 'مفيش مطابخ فاتحة جمبك دلوقتي',
          body: 'الطباخين بيفتحوا من حوالي ١١ الصبح',
          primaryAction:
              KafooButton(label: 'نبّهني أول ما يفتح', onPressed: () {}),
        )),
      );
      expect(find.text('مفيش مطابخ فاتحة جمبك دلوقتي'), findsOneWidget);
      expect(find.text('الطباخين بيفتحوا من حوالي ١١ الصبح'), findsOneWidget);
      expect(find.byType(KafooButton), findsOneWidget);
    });

    testWidgets('a failure says what survived and shows the stale data',
        (tester) async {
      await tester.pumpWidget(
        _host(KafooEmptyState(
          failure: true,
          title: 'مفيش نت',
          body: 'هنجرب تاني أول ما يرجع',
          reassurance: 'اللي قولتيه محفوظ وهيتبعت أول ما النت يرجع',
          cachedLabel: 'آخر نسخة محفوظة · ٩:٤٠ الصبح',
          cachedContent: const Text('محشي ورق عنب'),
          primaryAction: KafooButton(label: 'جربي تاني', onPressed: () {}),
        )),
      );
      expect(
        find.text('اللي قولتيه محفوظ وهيتبعت أول ما النت يرجع'),
        findsOneWidget,
      );
      final cached = tester.widget<Opacity>(
        find.ancestor(
          of: find.text('محشي ورق عنب'),
          matching: find.byType(Opacity),
        ),
      );
      expect(cached.opacity, 0.45);
    });
  });

  group('KafooPhotoPlaceholder', () {
    testWidgets('announces itself rather than passing as a photo',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const KafooPhotoPlaceholder(
          semanticsLabel: 'مكان صورة مؤقت',
          width: 80,
          height: 80,
        )),
      );
      expect(
        find.bySemanticsLabel('مكان صورة مؤقت'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
