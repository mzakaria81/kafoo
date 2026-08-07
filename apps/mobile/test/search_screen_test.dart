// What a Customer touches when they ask for food — and, above everything else,
// WHAT LEAVES THE DEVICE WHEN THEY HAVE SAID NO.
//
// SC-014 is verified by watching what leaves rather than by reading the code
// that decides. `FakeDiscoveryRepository.phrases` and `.judged` record every
// phrase handed to the network layer, so a test that finds them empty is
// evidence about traffic and not about a branch. A test asserting "the refused
// branch was taken" would pass just as happily against an implementation that
// took the branch AND sent the phrase.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/analytics/emit_event.dart';
import 'package:kafoo_mobile/features/discovery/application/search_controller.dart';
import 'package:kafoo_mobile/features/discovery/data/discovery_repository.dart';
import 'package:kafoo_mobile/features/discovery/presentation/opened_meal.dart';
import 'package:kafoo_mobile/features/discovery/presentation/search_screen.dart';
import 'package:kafoo_mobile/features/settings/data/search_consent_store.dart';
import 'package:kafoo_mobile/features/settings/presentation/settings_screen.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';

import 'support/fake_discovery_repository.dart';
import 'support/fake_search_consent_store.dart';

const _kitchen = KitchenProfile(
  id: 'k1',
  cookId: 'c1',
  displayName: 'مطبخ فاطمة',
  story: 'بطبخ من زمان',
  area: 'المهندسين',
  deliveryTerms: 'توصيل لحد باب البيت',
);

const _otherKitchen = KitchenProfile(
  id: 'k2',
  cookId: 'c2',
  displayName: 'مطبخ أم أحمد',
  story: 'أكل بيتي',
  area: 'الدقي',
  deliveryTerms: 'استلام من البيت',
);

const _koshari = Meal(
  id: 'm1',
  cookId: 'c1',
  title: 'كشري',
  description: 'عدس ومكرونة وأرز',
  price: '35',
  cuisine: Cuisine.egyptian,
  category: MealCategory.main,
  status: MealStatus.published,
  nutritionSource: NutritionSource.ai,
);

const _molokhia = Meal(
  id: 'm2',
  cookId: 'c2',
  title: 'ملوخية',
  description: 'ملوخية بالفراخ',
  price: '55',
  cuisine: Cuisine.egyptian,
  category: MealCategory.main,
  status: MealStatus.published,
  nutritionSource: NutritionSource.ai,
);

const _onOffer = <DiscoveredMeal>[
  DiscoveredMeal(meal: _koshari, kitchen: _kitchen),
  DiscoveredMeal(meal: _molokhia, kitchen: _otherKitchen),
];

SearchOutcome _outcome({
  List<DiscoveredMeal> items = const [_koshariPair],
  String? excludedId,
  bool notUnderstood = false,
  String? area,
}) =>
    SearchOutcome(
      results: DiscoveryResults(
        results: [
          for (final (index, item) in items.indexed)
            DiscoveryResult(item: item, rank: index + 1),
        ],
      ),
      excludedId: excludedId,
      notUnderstood: notUnderstood,
      area: area,
    );

const _koshariPair = DiscoveredMeal(meal: _koshari, kitchen: _kitchen);

/// A Meal whose title is whatever a case needs — Latin script, for the bidi
/// cases that only appear when two of them sit next to each other.
Meal _mealNamed(String id, String title) => Meal(
      id: id,
      cookId: 'c1',
      title: title,
      description: 'وصف',
      price: '40',
      cuisine: Cuisine.egyptian,
      category: MealCategory.main,
      status: MealStatus.published,
      nutritionSource: NutritionSource.ai,
    );

Widget _app(
  FakeDiscoveryRepository repo,
  FakeSearchConsentStore consent, {
  void Function(DiscoveredMeal item)? onOpen,
  Locale locale = const Locale('ar'),
}) =>
    ProviderScope(
      overrides: [
        discoveryRepositoryProvider.overrideWithValue(repo),
        searchConsentStoreProvider.overrideWithValue(consent),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: SearchScreen(onOpen: onOpen),
      ),
    );

/// Types a phrase and presses search. The only way a phrase reaches anything in
/// these tests, deliberately — a test that called the controller directly would
/// walk past the screen it is meant to be exercising.
Future<void> _ask(WidgetTester tester, String phrase) async {
  await tester.enterText(find.byType(TextField), phrase);
  await tester.tap(find.byIcon(Icons.search));
  await tester.pumpAndSettle();
}

/// Browse fails while search succeeds. The shipped fake fails both together,
/// which is why the empty-area state could tell a Customer the marketplace was
/// empty for two months of nobody noticing.
class _BrowseFails extends FakeDiscoveryRepository {
  @override
  Future<Result<List<DiscoveredMeal>, AppError>> mealsOnOffer() async =>
      const Failure(AppError(messageKey: 'discoveryLoadError'));
}

/// Browse has not answered yet. The ordinary case, not the exotic one: search
/// answers in a few hundred milliseconds.
class _BrowseHangs extends FakeDiscoveryRepository {
  @override
  Future<Result<List<DiscoveredMeal>, AppError>> mealsOnOffer() async {
    await Completer<void>().future;
    return const Success(<DiscoveredMeal>[]);
  }
}

late AppLocalizations ar;

void main() {
  setUpAll(() async {
    ar = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  group('the answer is asked once, at the first search, never on arrival', () {
    testWidgets('arriving asks nothing and sends nothing', (tester) async {
      final repo = FakeDiscoveryRepository(onOffer: _onOffer);
      final consent = FakeSearchConsentStore();
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      // FR-029a: browsing must not require an answer.
      expect(find.text(ar.searchConsentQuestion), findsNothing);
      expect(find.text('كشري'), findsOneWidget);
      expect(repo.phrases, isEmpty);
      expect(consent.writes, isEmpty);
    });

    testWidgets('THE FIRST SEARCH ASKS, AND NOTHING HAS LEFT YET',
        (tester) async {
      final repo = FakeDiscoveryRepository(onOffer: _onOffer);
      final consent = FakeSearchConsentStore();
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'عايز حاجة سخنة');

      expect(find.text(ar.searchConsentQuestion), findsOneWidget);
      // The whole point of asking BEFORE rather than after.
      expect(repo.phrases, isEmpty);
      expect(repo.judged, isEmpty);
    });

    testWidgets('agreeing runs the search they already asked for',
        (tester) async {
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome();
      final consent = FakeSearchConsentStore();
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'عايز حاجة سخنة');
      await tester.tap(find.text(ar.searchConsentAgree));
      await tester.pumpAndSettle();

      expect(repo.phrases, ['عايز حاجة سخنة']);
      expect(consent.writes, [SearchConsent.granted]);
      expect(find.text(ar.searchConsentQuestion), findsNothing);
    });

    testWidgets('backing out of the question is not an answer', (tester) async {
      // A dismissal is neither yes nor no. Nothing is sent and nothing is
      // written, so they are asked again — treating it as either answer would
      // be deciding for them.
      final repo = FakeDiscoveryRepository(onOffer: _onOffer);
      final consent = FakeSearchConsentStore();
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'عايز حاجة سخنة');
      expect(find.text(ar.searchConsentQuestion), findsOneWidget);

      final element = tester.element(find.byType(SearchScreen));
      ProviderScope.containerOf(element, listen: false)
          .read(searchControllerProvider.notifier)
          .dismissConsent();
      await tester.pumpAndSettle();

      expect(consent.writes, isEmpty);
      expect(repo.phrases, isEmpty);

      // Asked again, because nothing was answered — SC-015 counts answers, not
      // appearances of the question.
      await _ask(tester, 'عايز حاجة سخنة');
      expect(find.text(ar.searchConsentQuestion), findsOneWidget);
    });

    testWidgets(
        'SC-015: after an answer the question never returns, '
        'including across a restart', (tester) async {
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome();
      final consent = FakeSearchConsentStore();
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'كشري');
      await tester.tap(find.text(ar.searchConsentAgree));
      await tester.pumpAndSettle();

      await _ask(tester, 'ملوخية');
      expect(find.text(ar.searchConsentQuestion), findsNothing);

      // The restart. Same device, same stored answer, a fresh app.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'فراخ');
      expect(find.text(ar.searchConsentQuestion), findsNothing);
      expect(repo.phrases, ['كشري', 'ملوخية', 'فراخ']);
    });
  });

  group('with the switch off', () {
    testWidgets('SC-014: ZERO WORDS LEAVE THE DEVICE', (tester) async {
      // THE HARDEST CRITERION IN THIS PACKAGE, and the reason the fake records
      // phrases instead of counting calls. This asserts on traffic.
      final repo = FakeDiscoveryRepository(onOffer: _onOffer);
      final consent = FakeSearchConsentStore(SearchConsent.refused);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      // There is nothing to type into — see the note on `searchIsOff` in the
      // screen. So the phrase is pushed straight at the controller, which is
      // the ONLY door to the network and therefore the only thing worth
      // testing here: a second entry point added later would come through it
      // too.
      final controller = ProviderScope.containerOf(
        tester.element(find.byType(SearchScreen)),
        listen: false,
      ).read(searchControllerProvider.notifier);

      await controller.search('عايز فراخ مشوية في المهندسين');
      // And again, because a second attempt is the one a lazy guard misses.
      await controller.search('كشري');
      await controller.chooseArea('المهندسين');
      expect(await controller.requestVoice(), isFalse);
      await tester.pumpAndSettle();

      // `chooseArea` with no earlier search returns before it reaches anything,
      // so the line above proves nothing about the gate — trust-reviewer found
      // it passing vacuously on 2026-08-07. The real case is below.

      expect(repo.phrases, isEmpty);
      expect(repo.judged, isEmpty);
      expect(find.text(ar.searchIsOff), findsOneWidget);
    });

    testWidgets(
        'SWITCHING OFF MID-SESSION STOPS THE NEXT PHRASE, INCLUDING '
        'the one behind an area button', (tester) async {
      // The second entry point. FR-024a requires that a Customer may choose
      // another area, and `chooseArea` reached the network without passing the
      // gate: search, turn the switch off, choose an area, and the sentence
      // went out. The screen hid the buttons, which made a widget branch the
      // only thing standing between a refused Customer and an outbound phrase
      // — the exact arrangement SC-014 exists to forbid.
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome(items: const [], area: 'أسوان');
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'كشري في أسوان');
      expect(repo.phrases, ['كشري في أسوان']);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SearchScreen)),
        listen: false,
      );
      await container
          .read(searchConsentControllerProvider.notifier)
          .answer(SearchConsent.refused);
      await tester.pumpAndSettle();

      await container
          .read(searchControllerProvider.notifier)
          .chooseArea('الدقي');
      await tester.pumpAndSettle();

      expect(repo.phrases, ['كشري في أسوان'],
          reason: 'a refused Customer sent a second phrase');
      expect(find.text(ar.searchIsOff), findsOneWidget);
    });

    testWidgets('THE QUESTION DOES NOT COME BACK AFTER SETTINGS ANSWERS IT',
        (tester) async {
      // SC-015. `searchConsentNote` tells the Customer they can change the
      // answer in Settings and the Settings icon is in this screen's own bar,
      // so this is the route the copy sends them down. It came back to the
      // question they had just answered, with a live "No" button on top of a
      // granted answer.
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome();
      final consent = FakeSearchConsentStore();
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'كشري');
      expect(find.text(ar.searchConsentQuestion), findsOneWidget);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(consent.stored, SearchConsent.granted);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text(ar.searchConsentQuestion), findsNothing);
      expect(find.text(ar.searchConsentRefuse), findsNothing);
    });

    testWidgets('search is UNAVAILABLE, not degraded, and browsing works',
        (tester) async {
      // FR-029e. There is no reduced search matching on spelling — a phrase
      // leaves Kafoo in order to become searchable at all, so a halfway state
      // would be a worse search sold as a kindness.
      final repo = FakeDiscoveryRepository(onOffer: _onOffer);
      final consent = FakeSearchConsentStore(SearchConsent.refused);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      // Nothing to type into: the input is gone rather than dead.
      expect(find.byType(TextField), findsNothing);
      expect(find.text(ar.searchIsOff), findsOneWidget);
      // Browsing is untouched.
      expect(find.text('كشري'), findsOneWidget);
      expect(find.text('ملوخية'), findsOneWidget);
    });

    testWidgets('refusing at the question sends nothing', (tester) async {
      final repo = FakeDiscoveryRepository(onOffer: _onOffer);
      final consent = FakeSearchConsentStore();
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'عايز حاجة سخنة');
      await tester.tap(find.text(ar.searchConsentRefuse));
      await tester.pumpAndSettle();

      expect(repo.phrases, isEmpty);
      expect(consent.writes, [SearchConsent.refused]);
      expect(find.text(ar.searchIsOff), findsOneWidget);
    });

    testWidgets('the answer is reachable and reversible from Settings',
        (tester) async {
      // FR-029c: at any time, in one place, in both directions.
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome();
      final consent = FakeSearchConsentStore(SearchConsent.refused);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isFalse);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(consent.stored, SearchConsent.granted);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Searching now works, and the question is not asked — it was answered.
      await _ask(tester, 'كشري');
      expect(find.text(ar.searchConsentQuestion), findsNothing);
      expect(repo.phrases, ['كشري']);

      // And back off again.
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(consent.stored, SearchConsent.refused);
    });
  });

  group('results', () {
    testWidgets('FR-011: results render while the judgement never arrives',
        (tester) async {
      // The judgement is stubbed to HANG. If anything awaited it, this test
      // would time out rather than fail — which is why the fake holds forever
      // instead of returning slowly.
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome()
        ..holdJudgement = true;
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'كشري');

      expect(find.text('كشري'), findsWidgets);
      expect(repo.judged, ['كشري']);
    });

    testWidgets('nothing matched falls back to what is on offer',
        (tester) async {
      // FR-012: the zero state of search is browse, and so is this.
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome(items: const []);
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'سوشي');

      expect(find.text(ar.searchFoundNothing), findsOneWidget);
      expect(find.text('ملوخية'), findsOneWidget);
    });

    testWidgets('a failure says search is unavailable and keeps browsing',
        (tester) async {
      final repo = FakeDiscoveryRepository(onOffer: _onOffer, fail: true);
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      // `fail` also fails the browse load, so the browse error is expected
      // underneath; what matters is that the two are different sentences.
      await _ask(tester, 'كشري');
      expect(find.text(ar.searchUnavailable), findsOneWidget);
      expect(find.text(ar.searchIsOff), findsNothing);
    });

    testWidgets('states what it filtered on and NEVER that a Meal is safe',
        (tester) async {
      // WP-017's last criterion. `meals.allergens` is frequently an AI estimate,
      // so the strongest true statement is what was removed and where that came
      // from — never that what remains is safe to eat.
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome(excludedId: 'meat');
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'حاجة من غير لحمة');

      expect(find.text(ar.searchFilteredOn(ar.exclusionName('meat'))),
          findsOneWidget);
      // The sentence names the source of the information and refuses the claim.
      final stated = ar.searchFilteredOn(ar.exclusionName('meat'));
      expect(stated.contains('لحمة'), isTrue);
      expect(stated.contains('مش معناه'), isTrue);
    });

    testWidgets('an exclusion Kafoo did not understand is said out loud',
        (tester) async {
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome(notUnderstood: true);
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'من غير كافيار');

      expect(find.text(ar.searchExclusionNotUnderstood), findsOneWidget);
    });
  });

  group('area', () {
    testWidgets(
        'FR-024 and FR-024a: an empty area says so and names the '
        'areas that are not', (tester) async {
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome(items: const [], area: 'أسوان');
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'كشري في أسوان');

      expect(find.text(ar.searchAreaEmpty('أسوان')), findsOneWidget);
      expect(find.text('المهندسين'), findsOneWidget);
      expect(find.text('الدقي'), findsOneWidget);
      // WIDENING IS THE CUSTOMER'S ACTION. Nothing from another area is shown
      // until they choose one, so the offer is a question rather than a
      // substitution.
      expect(find.text('كشري'), findsNothing);
      expect(find.text('ملوخية'), findsNothing);
    });

    testWidgets('choosing an area searches again, narrowed to it',
        (tester) async {
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome(items: const [], area: 'أسوان');
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'كشري في أسوان');
      repo.searchOutcome = _outcome(area: 'المهندسين');
      await tester.tap(find.text('المهندسين'));
      await tester.pumpAndSettle();

      // The same sentence, asked again with the area they chose.
      expect(repo.phrases, ['كشري في أسوان', 'كشري في أسوان']);
      expect(repo.areas, [null, 'المهندسين']);
      expect(find.text(ar.searchNarrowedToArea('المهندسين')), findsOneWidget);
    });

    testWidgets('AN AREA KAFOO COULD NOT CHECK IS NEVER AN EMPTY MARKETPLACE',
        (tester) async {
      // Search answers in a few hundred milliseconds and browse has not, or
      // browse failed. `onOffer` is empty in both, and neither means no Cook
      // anywhere has food. Saying so lands immediately after telling the
      // Customer their own area is empty — two sentences of Kafoo asserting
      // something it does not know. `BrowseState.saysNothingOnOffer` exists to
      // prevent exactly this and was not being asked.
      //
      // The shipped fake fails browse and search TOGETHER, which is why this
      // was never seen: these two subclasses break only browse.
      for (final broken in [_BrowseFails.new, _BrowseHangs.new]) {
        final repo = broken()
          ..searchOutcome = _outcome(items: const [], area: 'أسوان');
        final consent = FakeSearchConsentStore(SearchConsent.granted);
        await tester.pumpWidget(_app(repo, consent));
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'كشري في أسوان');
        await tester.tap(find.byIcon(Icons.search));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }

        expect(find.text(ar.searchAreaEmpty('أسوان')), findsOneWidget);
        expect(find.text(ar.browseNothingOnOffer), findsNothing,
            reason: 'Kafoo claimed the marketplace is empty without knowing');
      }
    });
    testWidgets(
        'FR-024b and FR-024c: no distance, no ordering by proximity, '
        'no promise of delivery', (tester) async {
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome(items: const [], area: 'أسوان');
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'كشري في أسوان');

      // Asserted against the copy itself rather than the screen, because the
      // failure is a sentence somebody adds later. Kafoo holds no location for
      // any Customer and no notion of where an area is.
      for (final forbidden in ['كيلو', 'متر', 'قريب', 'أقرب', 'المسافة بينك']) {
        expect(ar.searchAreaChoose.contains(forbidden), isFalse,
            reason: 'searchAreaChoose implies distance: $forbidden');
        expect(ar.searchAreaEmpty('أسوان').contains(forbidden), isFalse);
      }
      // The areas are in the order their Meals came back, never ranked.
      final buttons = tester
          .widgetList<OutlinedButton>(find.byType(OutlinedButton))
          .toList();
      expect(buttons.length, 2);
    });
  });

  group('the judgement', () {
    testWidgets('NOTHING HERE ANSWERS, AND THE RESULTS DO NOT MOVE',
        (tester) async {
      // The whole design in one assertion. The judgement says something ABOUT a
      // set; it may not reorder, filter, add to or remove a Meal. A screen
      // showing only the named alternatives would be filtering wearing a
      // layout, and it is the failure this test exists to catch.
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome(items: _onOffer)
        ..judgement = NothingAnswers(alternatives: [_onOffer.first.meal]);
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'عايز سوشي ياباني');
      await tester.pumpAndSettle();

      expect(find.textContaining('مفيش أكلة هنا'), findsOneWidget);

      // EVERY Meal is still on screen, in the order the database returned.
      for (final item in _onOffer) {
        expect(find.text(item.meal.title), findsOneWidget,
            reason: '${item.meal.title} was removed by an opinion about it');
      }
      final titles = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((d) => _onOffer.any((i) => i.meal.title == d))
          .toList();
      expect(titles, _onOffer.map((i) => i.meal.title).toList(),
          reason: 'the judgement reordered the results');
    });

    testWidgets('the named alternative is a real Meal title, not model prose',
        (tester) async {
      final named = _onOffer.first.meal;
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome(items: _onOffer)
        ..judgement = NothingAnswers(alternatives: [named]);
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'عايز سوشي ياباني');
      await tester.pumpAndSettle();

      expect(find.textContaining(named.title), findsWidgets);
    });

    testWidgets('a judgement that never arrives costs a sentence, not results',
        (tester) async {
      // T161. The Customer keeps every Meal and simply never sees the note.
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome(items: _onOffer)
        ..holdJudgement = true;
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'عايز سوشي ياباني');
      await tester.pumpAndSettle();

      for (final item in _onOffer) {
        expect(find.text(item.meal.title), findsOneWidget);
      }
      expect(find.textContaining('مفيش أكلة هنا'), findsNothing);
    });

    testWidgets('results that answer say nothing at all', (tester) async {
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome(items: _onOffer)
        ..judgement = const ResultsAnswer();
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'عايز فراخ مشوية');
      await tester.pumpAndSettle();

      expect(find.textContaining('مفيش أكلة هنا'), findsNothing);
    });

    testWidgets('revoking consent stops the judgement being asked',
        (tester) async {
      // The judgement is a second outbound call carrying the same phrase, made
      // after the search returns. Consent is re-read before it goes.
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome(items: _onOffer)
        ..judgement = NothingAnswers(alternatives: [_onOffer.first.meal]);
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SearchScreen)),
        listen: false,
      );
      await container
          .read(searchControllerProvider.notifier)
          .answerConsent(SearchConsent.refused);
      await tester.pumpAndSettle();

      await container.read(searchControllerProvider.notifier).search('كشري');
      await tester.pumpAndSettle();

      expect(repo.judged, isEmpty,
          reason: 'the phrase was sent again after consent was withdrawn');
    });

    testWidgets('the English locale never renders an Arabic comma',
        (tester) async {
      // The separator was hardcoded in Dart as `، `, so English readers were
      // shown Arabic commas and never the word "and". Joining is grammar and it
      // now lives in the ARB; this is what stops it coming back to a widget.
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome(items: _onOffer)
        ..judgement = NothingAnswers(
          alternatives: [_onOffer.first.meal, _onOffer.last.meal],
        );
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent, locale: const Locale('en')));
      await tester.pumpAndSettle();

      await _ask(tester, 'sushi');
      await tester.pumpAndSettle();

      final rendered = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((d) => d.contains('Nothing here'));
      expect(rendered.contains('\u060C'), isFalse,
          reason: 'an Arabic comma reached an English reader: $rendered');
      expect(rendered.contains(' and '), isTrue,
          reason: 'English joins a list with "and": $rendered');
    });

    testWidgets('TWO LATIN TITLES ARE READ IN THE ORDER THEY WERE NAMED',
        (tester) async {
      // Under RTL, two Latin-script titles side by side fuse into one
      // left-to-right island whose internal order runs against the sentence —
      // measured, the Meal named FIRST was rendered to the left and therefore
      // read SECOND. Each title is isolated between U+2068 and U+2069 to stop
      // it. In Arabic, first-named means rightmost.
      final latin = [
        DiscoveredMeal(meal: _mealNamed('m9', 'Pizza'), kitchen: _kitchen),
        DiscoveredMeal(meal: _mealNamed('m10', 'Burger'), kitchen: _kitchen),
      ];
      final repo = FakeDiscoveryRepository(onOffer: latin)
        ..searchOutcome = _outcome(items: latin)
        ..judgement = NothingAnswers(
          alternatives: [latin.first.meal, latin.last.meal],
        );
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'عايز سوشي');
      await tester.pumpAndSettle();

      final note = find.textContaining('مفيش أكلة هنا');
      expect(note, findsOneWidget);
      final text = tester.widget<Text>(note).data!;
      // The isolate marks are present and wrap each name, which is what makes
      // the visual order follow the naming order.
      expect(text.indexOf('\u2068Pizza\u2069') >= 0, isTrue, reason: text);
      expect(text.indexOf('\u2068Burger\u2069') >= 0, isTrue, reason: text);
      expect(text.indexOf('Pizza') < text.indexOf('Burger'), isTrue,
          reason: 'the Meal named first must come first in the string: $text');
    });

    testWidgets('the sentence fits at 200% text scale', (tester) async {
      // Six Customer-facing sentences shipped at 48 points past twenty-five
      // passing tests this week. A sentence nobody can read is a sentence Kafoo
      // did not say.
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome(items: _onOffer)
        ..judgement = NothingAnswers(alternatives: [_onOffer.first.meal]);
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _app(repo, consent),
        ),
      );
      await tester.pumpAndSettle();

      await _ask(tester, 'عايز سوشي ياباني');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('مفيش أكلة هنا'), findsOneWidget);
    });
  });

  group('measurement', () {
    testWidgets('SearchPerformed carries result_count AND NOTHING ELSE',
        (tester) async {
      // FR-029 and SC-011. Asserted on the ATTRIBUTE SET rather than the count,
      // because a phrase added alongside it later would still pass a test that
      // only checked the number.
      final events = <(String, Map<String, Object>)>[];
      debugEventRecorder = (name, attributes) => events.add((name, attributes));
      addTearDown(() => debugEventRecorder = null);

      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome(items: _onOffer);
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'عايز فراخ مشوية في المهندسين');

      final performed = events.where((e) => e.$1 == 'SearchPerformed').toList();
      expect(performed.length, 1);
      expect(performed.single.$2.keys.toList(), ['result_count']);
      expect(performed.single.$2['result_count'], 2);

      // And the phrase is nowhere in anything that was emitted.
      for (final event in events) {
        expect(event.$2.values.join(' ').contains('فراخ'), isFalse,
            reason: '${event.$1} carries the phrase');
      }
    });

    testWidgets(
        'SearchFailed carries NOTHING, and only when the judgement says so',
        (tester) async {
      // The attribute SET is asserted empty, not its size. A test checking only
      // a count stays green the day somebody adds the phrase beside it, which
      // is the one thing FR-029 forbids.
      final events = <(String, Map<String, Object>)>[];
      debugEventRecorder = (name, attributes) => events.add((name, attributes));
      addTearDown(() => debugEventRecorder = null);

      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome(items: _onOffer)
        ..judgement = NothingAnswers(alternatives: [_onOffer.first.meal]);
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'عايز سوشي ياباني');
      await tester.pumpAndSettle();

      final failed = events.where((e) => e.$1 == 'SearchFailed').toList();
      expect(failed.length, 1);
      expect(failed.single.$2, isEmpty,
          reason: 'SearchFailed carries no attributes at all');

      for (final event in events) {
        expect(event.$2.values.join(' ').contains('سوشي'), isFalse,
            reason: '${event.$1} carries the phrase');
      }
    });

    testWidgets('results that answer emit no SearchFailed', (tester) async {
      // The event names a judgement, not an empty database. Emitting it
      // whenever retrieval was thin would measure the fact a score already
      // failed to measure.
      final events = <String>[];
      debugEventRecorder = (name, _) => events.add(name);
      addTearDown(() => debugEventRecorder = null);

      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome(items: _onOffer)
        ..judgement = const ResultsAnswer();
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      await _ask(tester, 'عايز فراخ مشوية');
      await tester.pumpAndSettle();

      expect(events.contains('SearchFailed'), isFalse);
    });

    testWidgets('RecommendationAccepted only for a Meal the judgement named',
        (tester) async {
      final events = <(String, Map<String, Object>)>[];
      debugEventRecorder = (name, attributes) => events.add((name, attributes));
      addTearDown(() => debugEventRecorder = null);

      final named = _onOffer.first.meal;
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome(items: _onOffer)
        ..judgement = NothingAnswers(alternatives: [named]);
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      // An opener is required: without one the cards are not openable at all,
      // and a test that taps nothing would pass by emitting nothing.
      await tester.pumpWidget(_app(repo, consent, onOpen: (_) {}));
      await tester.pumpAndSettle();

      await _ask(tester, 'عايز سوشي ياباني');
      await tester.pumpAndSettle();

      // The Meal that was NOT named. Opening it is an ordinary open.
      await tester.tap(find.text(_onOffer.last.meal.title).first);
      await tester.pumpAndSettle();
      expect(events.where((e) => e.$1 == 'RecommendationAccepted'), isEmpty);

      await tester.tap(find.text(named.title).first);
      await tester.pumpAndSettle();

      final accepted =
          events.where((e) => e.$1 == 'RecommendationAccepted').toList();
      expect(accepted.length, 1);
      expect(accepted.single.$2.keys.toList(), ['rank']);
      for (final event in events) {
        expect(event.$2.values.join(' ').contains('سوشي'), isFalse,
            reason: '${event.$1} carries the phrase');
      }
    });

    testWidgets('a refused search emits nothing at all', (tester) async {
      final events = <String>[];
      debugEventRecorder = (name, _) => events.add(name);
      addTearDown(() => debugEventRecorder = null);

      final repo = FakeDiscoveryRepository(onOffer: _onOffer);
      final consent = FakeSearchConsentStore(SearchConsent.refused);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      // Through the controller, because a refused Customer has no input to
      // type into — see SC-014 above.
      await ProviderScope.containerOf(
        tester.element(find.byType(SearchScreen)),
        listen: false,
      ).read(searchControllerProvider.notifier).search('كشري');
      await tester.pumpAndSettle();

      expect(events, isEmpty);
    });
  });

  group('freshness', () {
    Widget openedMeal(FakeDiscoveryRepository repo) => ProviderScope(
          overrides: [discoveryRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            locale: Locale('ar'),
            supportedLocales: [Locale('ar'), Locale('en')],
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: OpenedMeal(item: _koshariPair),
          ),
        );

    testWidgets(
        'FR-005: a Meal taken off the menu while it is being read says so',
        (tester) async {
      // Discovery reflects what is on offer when it is ASKED, and opening a
      // Meal is a later moment. The Meal stays on screen with the truth on top
      // of it — replacing it with an error would lose what they were reading.
      final repo = FakeDiscoveryRepository()..stillOnOffer = false;
      await tester.pumpWidget(openedMeal(repo));
      await tester.pumpAndSettle();

      expect(find.text(ar.mealNoLongerOnOffer), findsOneWidget);
      // Still readable. The sentence is on top of the Meal, not instead of it.
      expect(find.text('عدس ومكرونة وأرز'), findsOneWidget);
    });

    testWidgets('a Meal that is still on offer says nothing', (tester) async {
      final repo = FakeDiscoveryRepository();
      await tester.pumpWidget(openedMeal(repo));
      await tester.pumpAndSettle();

      expect(find.text(ar.mealNoLongerOnOffer), findsNothing);
      expect(find.text('عدس ومكرونة وأرز'), findsOneWidget);
    });
  });

  group('it renders on a phone', () {
    // NOTHING IN THIS REPOSITORY SET A TEXT SCALE OR A PHONE-SIZED VIEWPORT
    // UNTIL 2026-08-07, and the default test surface is 800x600 — a viewport no
    // phone has. Twenty-five tests passed over six Customer-facing sentences
    // that were rendering in MaterialApp's error style: 48-point monospace
    // under a double yellow underline, overflowing a 360dp screen at ORDINARY
    // text scale. `find.text` does not look at style, and nothing looked at
    // size. `.claude/rules/dart.md` has required "test at 200% text scale" all
    // along and nothing enforced it.
    Future<void> onAPhone(
      WidgetTester tester,
      Widget app, {
      double scale = 1.0,
    }) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: app,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a sentence Kafoo says is body text, not the error style',
        (tester) async {
      final repo = FakeDiscoveryRepository(onOffer: _onOffer);
      final consent = FakeSearchConsentStore(SearchConsent.refused);
      await onAPhone(tester, _app(repo, consent));

      final style = tester.widget<Text>(find.text(ar.searchIsOff)).style!;
      // The error style is 48-point w900 monospace with a yellow double
      // underline. Asserting "not that" rather than an exact size, because the
      // theme's body size is the theme's business and this is not.
      expect(style.fontSize ?? 14, lessThan(24));
      expect(style.decoration, isNot(TextDecoration.underline));
      expect(style.fontFamily, isNot('monospace'));
    });

    testWidgets('nothing overflows at 200% text scale', (tester) async {
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome(excludedId: 'meat', area: 'المهندسين');
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await onAPhone(tester, _app(repo, consent), scale: 2.0);

      await tester.enterText(find.byType(TextField), 'من غير لحمة');
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the consent question fits at 200% text scale', (tester) async {
      final repo = FakeDiscoveryRepository(onOffer: _onOffer);
      final consent = FakeSearchConsentStore();
      await onAPhone(tester, _app(repo, consent), scale: 2.0);

      await tester.enterText(find.byType(TextField), 'كشري');
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.text(ar.searchConsentQuestion), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('BOTH ANSWERS ARE THE SAME KIND OF BUTTON', (tester) async {
      // Same size and same prominence, in fact rather than in a comment. A
      // FilledButton beside an OutlinedButton is Material's high-emphasis
      // widget beside its medium-emphasis one, which on a consent choice is
      // the dark pattern the trust rules call product-fatal.
      final repo = FakeDiscoveryRepository(onOffer: _onOffer);
      final consent = FakeSearchConsentStore();
      await onAPhone(tester, _app(repo, consent));

      await tester.enterText(find.byType(TextField), 'كشري');
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.text(ar.searchConsentAgree), findsOneWidget);
      expect(find.text(ar.searchConsentRefuse), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      final agree = tester.getSize(
        find.ancestor(
          of: find.text(ar.searchConsentAgree),
          matching: find.byType(OutlinedButton),
        ),
      );
      final refuse = tester.getSize(
        find.ancestor(
          of: find.text(ar.searchConsentRefuse),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(agree.width, refuse.width);
    });
  });

  group('voice', () {
    testWidgets('FR-008: with no recognition, typing is not a degraded path',
        (tester) async {
      // Speech is unavailable in a widget test, which is also the likeliest
      // real outcome on an Egyptian handset — research.md §3.
      final repo = FakeDiscoveryRepository(onOffer: _onOffer)
        ..searchOutcome = _outcome();
      final consent = FakeSearchConsentStore(SearchConsent.granted);
      await tester.pumpWidget(_app(repo, consent));
      await tester.pumpAndSettle();

      expect(find.text(ar.searchVoiceUnavailable), findsOneWidget);

      await _ask(tester, 'كشري');
      expect(repo.phrases, ['كشري']);
    });
  });
}
