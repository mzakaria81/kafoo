import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/analytics/emit_event.dart';
import 'package:kafoo_mobile/features/analytics/event_names.dart';
import 'package:kafoo_mobile/features/meal/application/my_meals_controller.dart';
import 'package:kafoo_mobile/features/meal/data/meal_repository.dart';
import 'package:kafoo_mobile/features/meal/presentation/my_meals_screen.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';

import 'support/fake_meal_repository.dart';

const _draft = CookMeal(
  id: 'm-draft',
  cookId: 'c1',
  title: 'كشري مسودة',
  description: 'مسودة',
  price: '30',
  cuisine: Cuisine.egyptian,
  category: MealCategory.main,
  status: MealStatus.draft,
  nutritionSource: NutritionSource.ai,
);

const _halfDraft = CookMeal(
  id: 'm-half',
  cookId: 'c1',
  title: 'ملوخية نص',
  status: MealStatus.draft,
  nutritionSource: NutritionSource.ai,
);

const _published = CookMeal(
  id: 'm-pub',
  cookId: 'c1',
  title: 'كشري',
  description: 'عدس ورز',
  price: '35',
  cuisine: Cuisine.egyptian,
  category: MealCategory.main,
  status: MealStatus.published,
  nutritionSource: NutritionSource.ai,
);

const _unavailable = CookMeal(
  id: 'm-unavail',
  cookId: 'c1',
  title: 'محشي',
  description: 'ورق عنب',
  price: '50',
  cuisine: Cuisine.egyptian,
  category: MealCategory.main,
  status: MealStatus.unavailable,
  nutritionSource: NutritionSource.ai,
);

const _archived = CookMeal(
  id: 'm-arch',
  cookId: 'c1',
  title: 'فتة',
  description: 'فتة باللحمة',
  price: '60',
  cuisine: Cuisine.egyptian,
  category: MealCategory.main,
  status: MealStatus.archived,
  nutritionSource: NutritionSource.ai,
);

const _publishedSecond = CookMeal(
  id: 'm-pub-2',
  cookId: 'c1',
  title: 'محشي',
  description: 'ورق عنب',
  price: '50',
  cuisine: Cuisine.egyptian,
  category: MealCategory.main,
  status: MealStatus.published,
  nutritionSource: NutritionSource.ai,
);

Widget _app(FakeMealRepository repo) => ProviderScope(
      overrides: [
        mealRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: [Locale('ar'), Locale('en')],
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MyMealsScreen(),
      ),
    );

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  setUp(() {
    debugEventRecorder = null;
  });

  tearDown(() {
    debugEventRecorder = null;
  });

  // The bug this catches shipped once: with no loading state, "no Meals yet,
  // start one" renders for the whole of the first load. A Cook with a full
  // menu is told their work is gone, every time they open the screen.
  testWidgets('while loading, does not claim the Cook has no Meals',
      (tester) async {
    final repo = FakeMealRepository(meals: [_published])
      ..myMealsDelay = const Duration(milliseconds: 100);

    await tester.pumpWidget(_app(repo));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(l10n.myMealsEmpty), findsNothing);

    await tester.pumpAndSettle();

    expect(find.text(l10n.myMealsEmpty), findsNothing);
    expect(find.text(_published.title!), findsOneWidget);
  });

  testWidgets('a Cook with no Meals is told so, once the load has answered',
      (tester) async {
    final repo = FakeMealRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text(l10n.myMealsEmpty), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows every status, including drafts', (tester) async {
    final repo = FakeMealRepository(
      meals: [_draft, _published, _unavailable, _archived],
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text(l10n.myMealsStatusDraft), findsOneWidget);
    expect(find.text(l10n.myMealsStatusPublished), findsOneWidget);
    expect(find.text(l10n.myMealsStatusUnavailable), findsOneWidget);
    expect(find.text(l10n.myMealsStatusArchived), findsOneWidget);
  });

  testWidgets(
      'a published Meal offers to come off the menu; an unavailable one offers to go back on',
      (tester) async {
    final repo = FakeMealRepository(meals: [_published, _unavailable]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealMakeUnavailable), findsOneWidget);
    expect(find.text(l10n.mealMakeAvailable), findsOneWidget);
  });

  testWidgets('a retired Meal offers no action at all', (tester) async {
    final repo = FakeMealRepository(meals: [_archived]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealMakeUnavailable), findsNothing);
    expect(find.text(l10n.mealMakeAvailable), findsNothing);
  });

  testWidgets(
      'taking an ordinary Meal off the menu writes the new status and nothing else',
      (tester) async {
    final repo = FakeMealRepository(
      meals: [_published, _publishedSecond],
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Tap the button on the first Meal row (كشري), not the second.
    final firstRow = find.byType(MyMealRow).first;
    await tester.tap(
      find.descendant(
        of: firstRow,
        matching: find.text(l10n.mealMakeUnavailable),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.setStatusArgs, hasLength(1));
    expect(repo.setStatusArgs.single.mealId, _published.id);
    expect(repo.setStatusArgs.single.next, MealStatus.unavailable);
    expect(repo.updateDraftArgs, isEmpty);
  });

  testWidgets(
      'taking the LAST Meal off the menu warns first, and writes nothing until confirmed',
      (tester) async {
    final repo = FakeMealRepository(meals: [_published]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.mealMakeUnavailable));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealLastOnOfferWarning), findsOneWidget);
    expect(repo.setStatusArgs, isEmpty);

    await tester.tap(find.text(l10n.mealLastOnOfferCancel));
    await tester.pumpAndSettle();
    expect(repo.setStatusArgs, isEmpty);

    await tester.tap(find.text(l10n.mealMakeUnavailable));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.mealLastOnOfferConfirm));
    await tester.pumpAndSettle();

    expect(repo.setStatusArgs, hasLength(1));
    expect(repo.setStatusArgs.single.next, MealStatus.unavailable);
  });

  testWidgets(
      'the availability change emits MealUpdated with changed = availability',
      (tester) async {
    final repo = FakeMealRepository(
      meals: [_published, _publishedSecond],
    );
    final events = <({String name, Map<String, Object> attributes})>[];
    debugEventRecorder = (name, attributes) {
      events.add((name: name, attributes: attributes));
    };

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    final firstRow = find.byType(MyMealRow).first;
    await tester.tap(
      find.descendant(
        of: firstRow,
        matching: find.text(l10n.mealMakeUnavailable),
      ),
    );
    await tester.pumpAndSettle();

    final updated =
        events.where((e) => e.name == EventNames.mealUpdated).toList();
    expect(updated, hasLength(1));
    expect(updated.single.attributes['changed'], 'availability');
  });

  testWidgets('a failed change tells the Cook, in Arabic', (tester) async {
    final repo = FakeMealRepository(
      meals: [_published, _publishedSecond],
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Now flip the fail flag so the setStatus call fails.
    repo.failOperations = true;

    final firstRow = find.byType(MyMealRow).first;
    await tester.tap(
      find.descendant(
        of: firstRow,
        matching: find.text(l10n.mealMakeUnavailable),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealAvailabilityError), findsOneWidget);
  });

  testWidgets(
      'retiring takes one confirmation, and writes nothing until it is given',
      (tester) async {
    final repo = FakeMealRepository(meals: [_published]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    final firstRow = find.byType(MyMealRow).first;
    await tester.tap(
      find.descendant(
        of: firstRow,
        matching: find.text(l10n.mealRetire),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealRetireWarning), findsOneWidget);
    expect(repo.setStatusArgs, isEmpty);

    await tester.tap(find.text(l10n.mealRetireCancel));
    await tester.pumpAndSettle();
    expect(repo.setStatusArgs, isEmpty);

    await tester.tap(
      find.descendant(
        of: firstRow,
        matching: find.text(l10n.mealRetire),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l10n.mealRetireConfirm),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.setStatusArgs, hasLength(1));
    expect(repo.setStatusArgs.single.mealId, _published.id);
    expect(repo.setStatusArgs.single.next, MealStatus.archived);
  });

  testWidgets('retiring emits MealArchived, and does not emit MealUpdated',
      (tester) async {
    final repo = FakeMealRepository(
      meals: [_published, _publishedSecond],
    );
    final events = <({String name, Map<String, Object> attributes})>[];
    debugEventRecorder = (name, attributes) {
      events.add((name: name, attributes: attributes));
    };

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    final firstRow = find.byType(MyMealRow).first;
    await tester.tap(
      find.descendant(
        of: firstRow,
        matching: find.text(l10n.mealRetire),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l10n.mealRetireConfirm),
      ),
    );
    await tester.pumpAndSettle();

    final archived =
        events.where((e) => e.name == EventNames.mealArchived).toList();
    expect(archived, hasLength(1));
    expect(archived.single.attributes, isEmpty);

    final updated =
        events.where((e) => e.name == EventNames.mealUpdated).toList();
    expect(updated, isEmpty);
  });

  testWidgets('a retired Meal offers no route back', (tester) async {
    final repo = FakeMealRepository(meals: [_archived]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealMakeUnavailable), findsNothing);
    expect(find.text(l10n.mealMakeAvailable), findsNothing);
    expect(find.text(l10n.mealRetire), findsNothing);
    expect(find.text(l10n.mealDeleteDraft), findsNothing);
  });

  test(
      'the controller refuses an illegal transition without calling the repository',
      () async {
    final repo = FakeMealRepository(meals: [_archived]);
    final container = ProviderContainer(
      overrides: [mealRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final controller = container.read(myMealsControllerProvider.notifier);
    final result = await controller.setStatus(_archived, MealStatus.published);

    expect(result, isFalse);
    expect(repo.setStatusArgs, isEmpty);
  });

  testWidgets('only a draft offers deletion', (tester) async {
    final repo = FakeMealRepository(
      meals: [_draft, _published, _unavailable, _archived],
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealDeleteDraft), findsOneWidget);

    final deleteButton = find.text(l10n.mealDeleteDraft);
    final draftRow = find.byType(MyMealRow).first;
    expect(
      find.descendant(of: draftRow, matching: deleteButton),
      findsOneWidget,
    );

    for (final mealLabel in [
      l10n.myMealsStatusPublished,
      l10n.myMealsStatusUnavailable,
      l10n.myMealsStatusArchived,
    ]) {
      final rowFinder = find.ancestor(
        of: find.text(mealLabel),
        matching: find.byType(MyMealRow),
      );
      expect(
        find.descendant(of: rowFinder, matching: deleteButton),
        findsNothing,
      );
    }
  });

  testWidgets(
      'deleting a draft takes one confirmation and deletes the right one',
      (tester) async {
    final repo = FakeMealRepository(meals: [_draft]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(repo.lastDeletedMealId, isNull);

    await tester.tap(find.text(l10n.mealDeleteDraft));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealDeleteDraftWarning), findsOneWidget);
    expect(repo.lastDeletedMealId, isNull);

    await tester.tap(find.text(l10n.mealDeleteDraftConfirm));
    await tester.pumpAndSettle();

    expect(repo.lastDeletedMealId, _draft.id);
  });

  testWidgets('deleting a draft emits no event at all', (tester) async {
    final repo = FakeMealRepository(meals: [_draft]);
    final events = <({String name, Map<String, Object> attributes})>[];
    debugEventRecorder = (name, attributes) {
      events.add((name: name, attributes: attributes));
    };

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.mealDeleteDraft));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.mealDeleteDraftConfirm));
    await tester.pumpAndSettle();

    expect(events, isEmpty);
  });

  // The defect this catches: a half-answered draft used to throw inside
  // _fromRow, turn the whole load into mealLoadError, and hide every Meal.
  testWidgets('a half-answered draft renders instead of breaking the list',
      (tester) async {
    final repo = FakeMealRepository(meals: [_halfDraft, _published]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text(_halfDraft.title!), findsOneWidget);
    expect(find.text(_published.title!), findsOneWidget);
    expect(find.text(l10n.myMealsStatusDraft), findsOneWidget);
    expect(find.text(l10n.myMealsStatusPublished), findsOneWidget);
    expect(find.text(l10n.mealLoadError), findsNothing);
    expect(find.byType(MyMealRow), findsNWidgets(2));
  });

  testWidgets('a draft with no price says so rather than rendering "null"',
      (tester) async {
    final repo = FakeMealRepository(meals: [_halfDraft]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text(l10n.myMealsNoPriceYet), findsOneWidget);

    final texts = tester.widgetList<Text>(find.byType(Text));
    for (final text in texts) {
      final data = text.data ?? text.textSpan?.toPlainText() ?? '';
      expect(data.contains('null'), isFalse, reason: 'found "null" in: $data');
    }
  });

  testWidgets(
      'a half-answered draft offers deletion but no availability action',
      (tester) async {
    final repo = FakeMealRepository(meals: [_halfDraft]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealDeleteDraft), findsOneWidget);
    expect(find.text(l10n.mealMakeUnavailable), findsNothing);
    expect(find.text(l10n.mealMakeAvailable), findsNothing);
    expect(find.text(l10n.mealRetire), findsNothing);
  });

  // The schema dropped NOT NULL from title along with the other four answers,
  // so a title-less row is possible even though today's only insert path always
  // supplies one. The row mapper must not be able to throw on ANY column: it
  // runs over every row, so one bad cast takes down the Cook's whole list
  // rather than the single entry it could not read.
  testWidgets('a draft with no title yet is named, not left blank',
      (tester) async {
    const untitled = CookMeal(
      id: 'm-untitled',
      cookId: 'c1',
      status: MealStatus.draft,
      nutritionSource: NutritionSource.ai,
    );
    final repo = FakeMealRepository(meals: [untitled, _published]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text(l10n.myMealsUntitledDraft), findsOneWidget);
    expect(find.text(l10n.mealLoadError), findsNothing);
    expect(find.byType(MyMealRow), findsNWidgets(2));

    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(rendered, isNot(contains('null')));
  });
}
