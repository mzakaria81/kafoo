import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/discovery/data/discovery_repository.dart';
import 'package:kafoo_mobile/features/discovery/presentation/search_screen.dart';
import 'package:kafoo_mobile/features/settings/data/search_consent_store.dart';
import 'package:kafoo_mobile/features/settings/presentation/settings_screen.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';

import 'support/fake_discovery_repository.dart';
import 'support/fake_search_consent_store.dart';

const _k = KitchenProfile(
  id: 'k1', cookId: 'c1', displayName: 'مطبخ فاطمة', story: 's',
  area: 'المهندسين', deliveryTerms: 'd',
);

Meal _meal(String id, String title) => Meal(
      id: id, cookId: 'c1', title: title, description: 'd', price: '35',
      cuisine: Cuisine.egyptian, category: MealCategory.main,
      status: MealStatus.published, nutritionSource: NutritionSource.ai,
    );

// Realistic Meal titles a Cook would actually write, including a transliterated
// brand-ish word and a number — the bidi case.
final _long = <Meal>[
  _meal('m1', 'محشي ورق عنب بزيت الزيتون'),
  _meal('m2', 'برجر لحمة بلدي مع بطاطس'),
  _meal('m3', 'فراخ مشوية على الفحم ٢ قطعة'),
];

Widget _app(FakeDiscoveryRepository repo, FakeSearchConsentStore consent) =>
    ProviderScope(
      overrides: [
        discoveryRepositoryProvider.overrideWithValue(repo),
        searchConsentStoreProvider.overrideWithValue(consent),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: SearchScreen(onOpen: (_) {}),
      ),
    );

Future<void> _ask(WidgetTester t, String phrase) async {
  await t.enterText(find.byType(TextField).first, phrase);
  await t.testTextInput.receiveAction(TextInputAction.search);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('PROBE: three long titles at 200% on a 360dp phone',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final items = [for (final m in _long) DiscoveredMeal(meal: m, kitchen: _k)];
    final repo = FakeDiscoveryRepository(onOffer: items)
      ..searchOutcome = SearchOutcome(
        results: DiscoveryResults(results: [
          for (final (i, it) in items.indexed)
            DiscoveryResult(item: it, rank: i + 1),
        ]),
      )
      ..judgement = NothingAnswers(alternatives: _long);
    final consent = FakeSearchConsentStore(SearchConsent.granted);

    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: _app(repo, consent),
    ));
    await tester.pumpAndSettle();
    await _ask(tester, 'عايز سوشي ياباني');
    await tester.pumpAndSettle();

    final note = find.textContaining('مفيش أكلة هنا');
    expect(note, findsOneWidget);
    final w = tester.widget<Text>(note);
    debugPrint('PROBE string >>>${w.data}<<<');
    debugPrint('PROBE fontSize=${w.style?.fontSize} maxLines=${w.maxLines} '
        'overflow=${w.overflow} softWrap=${w.softWrap}');
    final box = tester.renderObject<RenderBox>(note);
    final mq = tester.element(note);
    debugPrint('PROBE screen=${MediaQuery.sizeOf(mq)} '
        'scaler=${MediaQuery.textScalerOf(mq)}');
    debugPrint('PROBE note size=${box.size}');
    debugPrint('PROBE didExceedMaxLines='
        '${(box as dynamic).debugNeedsLayout}');
    expect(tester.takeException(), isNull);

    // Semantics: what a screen reader announces for the note.
    final handle = tester.ensureSemantics();
    final node = tester.getSemantics(note);
    debugPrint('PROBE semantics label >>>${node.label}<<<');
    debugPrint('PROBE isLiveRegion=${node.hasFlag(SemanticsFlag.isLiveRegion)}');
    debugPrint('PROBE textDirection=${node.textDirection}');
    handle.dispose();
  });

  testWidgets('PROBE: alternatives ordering vs result ordering',
      (tester) async {
    final items = [for (final m in _long) DiscoveredMeal(meal: m, kitchen: _k)];
    final repo = FakeDiscoveryRepository(onOffer: items)
      ..searchOutcome = SearchOutcome(
        results: DiscoveryResults(results: [
          for (final (i, it) in items.indexed)
            DiscoveryResult(item: it, rank: i + 1),
        ]),
      )
      // Deliberately reversed: does the sentence reorder what the DB returned?
      ..judgement = NothingAnswers(alternatives: _long.reversed.toList());
    final consent = FakeSearchConsentStore(SearchConsent.granted);
    await tester.pumpWidget(_app(repo, consent));
    await tester.pumpAndSettle();
    await _ask(tester, 'عايز سوشي ياباني');
    await tester.pumpAndSettle();
    final w = tester.widget<Text>(find.textContaining('مفيش أكلة هنا'));
    debugPrint('PROBE reversed-alternatives string >>>${w.data}<<<');
  });

  testWidgets('PROBE: one alternative, and the empty-alternatives sentence',
      (tester) async {
    final items = [for (final m in _long) DiscoveredMeal(meal: m, kitchen: _k)];
    for (final alts in [<Meal>[], [_long.first], _long.take(2).toList()]) {
      final repo = FakeDiscoveryRepository(onOffer: items)
        ..searchOutcome = SearchOutcome(
          results: DiscoveryResults(results: [
            for (final (i, it) in items.indexed)
              DiscoveryResult(item: it, rank: i + 1),
          ]),
        )
        ..judgement = NothingAnswers(alternatives: alts);
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();
      await _ask(tester, 'عايز سوشي ياباني');
      await tester.pumpAndSettle();
      final w = tester.widget<Text>(find.textContaining('مفيش أكلة هنا'));
      debugPrint('PROBE alts=${alts.length} >>>${w.data}<<<');
    }
  });
}
