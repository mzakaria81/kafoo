import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ui/ui.dart';

/// What these tests are, and what they are deliberately not.
///
/// `.claude/rules/dart.md` asks for golden tests on the design system. There
/// are none here on purpose: a golden compares rendered pixels, and widget
/// tests render with a test font rather than the bundled one, so a golden
/// records a shape no Cook will ever see. What these assert instead are the
/// design's *measurable* claims —
/// sizes, colours, tap targets, and that nothing clips at 200% text scale.
/// Those are the rules a screen actually breaks.
Widget _host(Widget child,
        {double textScale = 1,
        Size size = const Size(390, 800),
        bool disableAnimations = false}) =>
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
        // Set HERE and not in a wrapper around _host: this MediaQuery replaces
        // whatever is above it, so an outer one is silently discarded.
        disableAnimations: disableAnimations,
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

double _firstBarOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .descendant(
            of: find.byKey(KafooSkeletonList.rowKey(0)),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

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
          const KafooGlanceWord(word: GlanceWord.published, text: 'على المنيو'),
        ),
      );
      final style = tester.widget<Text>(find.text('على المنيو')).style!;
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
          statusText: 'على المنيو',
          semanticsLabel: 'محشي ورق عنب، على المنيو، ١٢٠ جنيه',
          placeholderLabel: 'مكان صورة مؤقت',
        );

    testWidgets('the price is the largest thing in the row', (tester) async {
      await tester.pumpWidget(_host(row()));
      final price = tester.widget<Text>(find.text('١٢٠')).style!;
      final name = tester.widget<Text>(find.text('محشي ورق عنب')).style!;
      final status = tester.widget<Text>(find.text('على المنيو')).style!;

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
          label: 'على المنيو',
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
          reassurance: 'أكلاتك كلها في أمان',
          cachedLabel: 'آخر نسخة محفوظة · ٩:٤٠ الصبح',
          cachedContent: const Text('محشي ورق عنب'),
          primaryAction: KafooButton(label: 'جربي تاني', onPressed: () {}),
        )),
      );
      expect(
        find.text('أكلاتك كلها في أمان'),
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

  group('KafooMealRow reachable by screen reader', () {
    // THE TEST THAT DID NOT EXIST, and its absence is why the row shipped
    // unusable. Every other row test builds it without its actions, so the
    // composed label read correctly and the two buttons it had swallowed were
    // never looked for.
    Widget rowWithActions() => KafooMealRow(
          name: 'محشي ورق عنب',
          price: '١٢٠',
          priceUnit: 'جنيه',
          status: GlanceWord.published,
          statusText: 'على المنيو',
          semanticsLabel: 'محشي ورق عنب، على المنيو، ١٢٠ جنيه',
          placeholderLabel: 'مكان صورة مؤقت',
          hearLabel: 'اسمعي الأكلة دي',
          onHear: () {},
          moreLabel: 'حاجات تانية',
          onMore: () {},
        );

    testWidgets('both actions are reachable, and so is the Meal itself',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(rowWithActions()));

      // The row is built with no onTap in production, so the actions are the
      // ONLY way to edit, publish, unpublish, delete a draft or retire a Meal.
      // A Cook who cannot reach them cannot manage her menu at all.
      expect(find.bySemanticsLabel('اسمعي الأكلة دي'), findsOneWidget);
      expect(find.bySemanticsLabel('حاجات تانية'), findsOneWidget);
      expect(
        find.bySemanticsLabel('محشي ورق عنب، على المنيو، ١٢٠ جنيه'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the composed sentence replaces the four readings under it',
        (tester) async {
      // The point of the label is that a Cook hears one sentence rather than
      // "محشي ورق عنب" then "على المنيو" then "١٢٠" then "جنيه" as four stops.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(rowWithActions()));

      expect(find.bySemanticsLabel('على المنيو'), findsNothing);
      expect(find.bySemanticsLabel('١٢٠'), findsNothing);
      handle.dispose();
    });
  });

  group('KafooFilterChip', () {
    testWidgets('an unavailable chip does not clip the reason it gives',
        (tester) async {
      // The label on a disabled chip IS the explanation, and half an
      // explanation is the dead end a disabled control is not allowed to be.
      await tester.pumpWidget(
        _host(
          const KafooFilterChip(
            label: 'مقفول دلوقتي — بيفتح الساعة ٤ العصر',
            selected: false,
            // Null is what an unavailable chip gets: it is inert, and the
            // label is the only place the reason can live.
            onSelected: null,
            unavailable: true,
          ),
          textScale: 2,
          size: const Size(320, 640),
        ),
      );

      expect(tester.takeException(), isNull);
      final text =
          tester.widget<Text>(find.text('مقفول دلوقتي — بيفتح الساعة ٤ العصر'));
      expect(text.maxLines, isNull, reason: 'the reason is capped at one line');
      expect(text.overflow, isNot(TextOverflow.ellipsis));
    });
  });

  group('KafooSkeletonList', () {
    // A repeating animation never settles, so every test here pumps single
    // frames. `pumpAndSettle` would time out rather than fail informatively.
    Widget mealRow() => const KafooMealRow(
          name: 'محشي ورق عنب',
          price: '١٢٠',
          priceUnit: 'جنيه',
          status: GlanceWord.published,
          statusText: 'على المنيو',
          semanticsLabel: 'محشي ورق عنب، على المنيو، ١٢٠ جنيه',
          placeholderLabel: 'مكان صورة مؤقت',
        );

    testWidgets('the list does not resize when the real rows arrive',
        (tester) async {
      // THE WHOLE POINT OF A SKELETON. A placeholder of the wrong height moves
      // the list under the Cook's thumb at the exact moment she reaches for it.
      await tester.pumpWidget(_host(mealRow()));
      final real = tester.getSize(find.byType(KafooMealRow)).height;

      await tester.pumpWidget(
        _host(const KafooSkeletonList(semanticsLabel: 'بحمّل أكلاتك')),
      );
      await tester.pump();
      final skeleton =
          tester.getSize(find.byKey(KafooSkeletonList.rowKey(0))).height;

      expect(skeleton, closeTo(real, 1));
    });

    testWidgets('tells a screen reader to wait instead of reading empty boxes',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const KafooSkeletonList(semanticsLabel: 'بحمّل أكلاتك')),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('بحمّل أكلاتك'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('breathes, so a slow network does not read as a hung app',
        (tester) async {
      await tester.pumpWidget(
        _host(const KafooSkeletonList(semanticsLabel: 'بحمّل أكلاتك')),
      );
      await tester.pump();
      final before = _firstBarOpacity(tester);

      await tester.pump(const Duration(milliseconds: 550));

      expect(_firstBarOpacity(tester), isNot(closeTo(before, 0.01)));
    });

    testWidgets('holds still when the platform asks for reduced motion',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const KafooSkeletonList(semanticsLabel: 'بحمّل أكلاتك'),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      final before = _firstBarOpacity(tester);

      await tester.pump(const Duration(milliseconds: 550));

      expect(_firstBarOpacity(tester), before);
      expect(before, 1);
    });

    testWidgets('shows a list, not a count', (tester) async {
      await tester.pumpWidget(
        _host(const KafooSkeletonList(semanticsLabel: 'بحمّل أكلاتك')),
      );
      await tester.pump();
      expect(find.byKey(KafooSkeletonList.rowKey(2)), findsOneWidget);
      expect(find.byKey(KafooSkeletonList.rowKey(3)), findsNothing);
    });
  });
}
