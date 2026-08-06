import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/discovery/data/discovery_repository.dart';
import 'package:kafoo_mobile/features/discovery/presentation/browse_screen.dart';
import 'package:kafoo_mobile/features/meal/presentation/public_meal_view.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';

import 'support/fake_discovery_repository.dart';

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

Widget _app(
  FakeDiscoveryRepository repo, {
  void Function(DiscoveredMeal item)? onOpen,
}) =>
    ProviderScope(
      overrides: [discoveryRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: BrowseScreen(onOpen: onOpen),
      ),
    );

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  testWidgets('shows what is on offer, with the kitchen behind each Meal',
      (tester) async {
    await tester.pumpWidget(_app(FakeDiscoveryRepository(onOffer: _onOffer)));
    await tester.pumpAndSettle();

    expect(find.text('كشري'), findsOneWidget);
    expect(find.text('ملوخية'), findsOneWidget);
    // "Who cooked this" is the question a Customer asks first. A Meal shown
    // without its kitchen is the failure this asserts against. Matched as a
    // substring because the card phrases it ("from Fatma's Kitchen") and the
    // assertion is about the kitchen being reachable, not about the wording.
    expect(find.textContaining('مطبخ فاطمة'), findsOneWidget);
    expect(find.textContaining('مطبخ أم أحمد'), findsOneWidget);
  });

  testWidgets('says in words that nothing is on offer, never a blank screen',
      (tester) async {
    // FR-006. An empty screen reads as a broken app; it has to say so.
    await tester.pumpWidget(_app(FakeDiscoveryRepository()));
    await tester.pumpAndSettle();

    expect(find.text(l10n.browseNothingOnOffer), findsOneWidget);
  });

  testWidgets('an empty result is not shown while the first load is running',
      (tester) async {
    // The state that cost E1 a screen: "no Meals" and "not answered yet" look
    // identical unless loading is modelled separately, and a Customer told
    // there is no food every time they open the app will stop opening it.
    await tester.pumpWidget(_app(FakeDiscoveryRepository(hold: true)));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(l10n.browseNothingOnOffer), findsNothing);
  });

  testWidgets('a failure says something rather than showing an empty screen',
      (tester) async {
    await tester.pumpWidget(_app(FakeDiscoveryRepository(fail: true)));
    await tester.pumpAndSettle();

    expect(find.text(l10n.discoveryLoadError), findsOneWidget);
    // A failure must not be dressed up as "nothing on offer" — one is Kafoo's
    // fault and the other is the marketplace's state, and telling a Customer
    // the wrong one is a small lie.
    expect(find.text(l10n.browseNothingOnOffer), findsNothing);
  });

  testWidgets('opening a Meal hands back the Meal and its kitchen',
      (tester) async {
    DiscoveredMeal? opened;
    await tester.pumpWidget(_app(
      FakeDiscoveryRepository(onOffer: _onOffer),
      onOpen: (item) => opened = item,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('كشري'));
    await tester.pumpAndSettle();

    expect(opened?.meal.id, 'm1');
    // The route to the kitchen has to carry the kitchen, because a Customer
    // reaching a Meal must be able to reach who cooked it (FR-003).
    expect(opened?.kitchen.displayName, 'مطبخ فاطمة');
  });

  testWidgets('a signed-out Customer reaches a Meal in one action (SC-001)',
      (tester) async {
    // SC-001 says a Meal's full details are reachable within three actions of
    // arriving, WITHOUT signing in. The measurable part is that opening a Meal
    // needs nothing the browse list did not already carry — no second fetch,
    // no sign-in, no lookup of who cooked it. If PublicMealView can be built
    // from what onOpen hands back, the hop is one action and the criterion
    // holds; if it needed anything more, this would not compile.
    DiscoveredMeal? opened;
    await tester.pumpWidget(_app(
      FakeDiscoveryRepository(onOffer: _onOffer),
      onOpen: (item) => opened = item,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('كشري'));
    await tester.pumpAndSettle();

    final item = opened!;
    final view = PublicMealView(
      meal: item.meal,
      // The Cook's own stored form, carried by the card rather than looked up.
      cookAddressForm: item.kitchen.addressForm,
    );
    expect(view.meal.title, 'كشري');
    expect(view.cookAddressForm, item.kitchen.addressForm);
  });

  testWidgets('a Meal card can be OPENED by a screen reader, not just read',
      (tester) async {
    // This assertion exists because its weaker form passed while the feature
    // was broken. Asserting the label is present proved only that the card
    // announced itself — and it announced itself as a BUTTON whose tap action
    // had been swallowed, so a blind Customer heard "button", double tapped,
    // and nothing happened. Browsing was a dead end and every test was green.
    //
    // SemanticsAction.tap is what a screen reader's double tap sends. Its
    // presence on the node is the discriminator: the broken version carried
    // isButton with an EMPTY action set, which no label assertion can see.
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(
      FakeDiscoveryRepository(onOffer: _onOffer),
      onOpen: (_) {},
    ));
    await tester.pumpAndSettle();

    final data = tester
        .getSemantics(find.bySemanticsLabel(RegExp('كشري')))
        .getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue,
        reason: 'a node that says it is a button must be pressable');
    handle.dispose();
  });

  testWidgets('the error state offers a way back that is not a gesture',
      (tester) async {
    // RefreshIndicator exposes no semantics action at all, so pull-to-refresh
    // as the only retry left a screen-reader Customer stranded on a message
    // with nothing to press.
    final repo = FakeDiscoveryRepository(fail: true);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text(l10n.browseRetry), findsOneWidget);
    final before = repo.calls;
    repo.fail = false;
    repo.onOffer = _onOffer;
    await tester.tap(find.text(l10n.browseRetry));
    await tester.pumpAndSettle();

    expect(repo.calls, greaterThan(before));
    expect(find.text('كشري'), findsOneWidget);
  });
}
