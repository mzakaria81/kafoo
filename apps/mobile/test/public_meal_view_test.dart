import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output_provider.dart';
import 'package:kafoo_mobile/features/meal/presentation/public_meal_view.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';
import 'package:kafoo_ui/ui.dart';

const _mealAi = Meal(
  id: 'm1-0000-0000-4000-8000-000000000001',
  cookId: 'c1-0000-0000-4000-8000-000000000002',
  title: 'كشري',
  description: 'عدس ورز ومكرونة مع صلصة الطماطم والبصل المقلي',
  price: '35.00',
  cuisine: Cuisine.egyptian,
  category: MealCategory.main,
  status: MealStatus.published,
  nutritionSource: NutritionSource.ai,
  ingredients: ['عدس', 'رز', 'مكرونة'],
  calories: 520,
  allergens: ['جلوتين'],
);

const _mealCook = Meal(
  id: 'm2-0000-0000-4000-8000-000000000003',
  cookId: 'c2-0000-0000-4000-8000-000000000004',
  title: 'محشي',
  description: 'ورق عنب محشي بالأرز واللحمة',
  price: '50.00',
  cuisine: Cuisine.egyptian,
  category: MealCategory.main,
  status: MealStatus.published,
  nutritionSource: NutritionSource.cook,
  ingredients: ['ورق عنب', 'رز', 'لحمة'],
  calories: 400,
  allergens: [],
);

Widget _testApp(Widget child) {
  return ProviderScope(
    overrides: [speechOutputProvider.overrideWithValue(FakeSpeechOutput())],
    child: MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

void main() {
  testWidgets(
      'renders the dish, its price, its description and its ingredients',
      (tester) async {
    await tester.pumpWidget(
        _testApp(const PublicMealView(meal: _mealAi, cookAddressForm: null)));
    await tester.pumpAndSettle();

    expect(find.text('كشري'), findsWidgets);
    // ٣٥٫٠٠ and not 35.00: an Arabic screen reads Arabic-Indic digits, and the
    // price is the element a Customer is most likely to read. The value is
    // untouched — this is a glyph swap, so both decimal places survive it.
    expect(find.text('٣٥٫٠٠ جنيه'), findsOneWidget);
    expect(find.text('35.00 جنيه'), findsNothing);
    expect(
      find.text('عدس ورز ومكرونة مع صلصة الطماطم والبصل المقلي'),
      findsOneWidget,
    );
    expect(find.text('عدس، رز، مكرونة'), findsOneWidget);
  });

  testWidgets('an AI-sourced figure is marked as an estimate', (tester) async {
    await tester.pumpWidget(
        _testApp(const PublicMealView(meal: _mealAi, cookAddressForm: null)));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    // The estimate notice text is on screen.
    expect(find.text(l10n.aiEstimateNotice('other')), findsOneWidget);

    // The estimate badge appears once per marked row (calories + allergens = 2).
    expect(find.text(l10n.mealSummaryEstimateBadge), findsNWidgets(2));
  });

  testWidgets('a Cook-corrected figure is NOT marked as an estimate',
      (tester) async {
    await tester.pumpWidget(
        _testApp(const PublicMealView(meal: _mealCook, cookAddressForm: null)));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    // No estimate notice.
    expect(find.text(l10n.aiEstimateNotice('other')), findsNothing);

    // No estimate badge.
    expect(find.text(l10n.mealSummaryEstimateBadge), findsNothing);

    // The "figures are the Cook's" text is present.
    expect(
        find.text(l10n.publicMealNutritionFromCook('other')), findsOneWidget);
  });

  testWidgets('a Meal with no calorie figure says so', (tester) async {
    const mealNoCalories = Meal(
      id: 'm3-0000-0000-4000-8000-000000000005',
      cookId: 'c3-0000-0000-4000-8000-000000000006',
      title: 'فتة',
      description: 'فتة باللحمة',
      price: '60.00',
      cuisine: Cuisine.egyptian,
      category: MealCategory.main,
      status: MealStatus.published,
      nutritionSource: NutritionSource.ai,
      calories: null,
    );

    await tester.pumpWidget(
      _testApp(
          const PublicMealView(meal: mealNoCalories, cookAddressForm: null)),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    expect(find.text(l10n.publicMealCaloriesUnknown), findsOneWidget);
    expect(find.text('0 سعرة'), findsNothing);
  });

  // The combination that matters is an EMPTY allergen list the AI Assistant
  // produced: a Customer with an allergy reading a blank row would take it for
  // an all-clear, and nothing here has been checked by anyone. So the empty
  // list must say nothing was listed, and must still carry the estimate
  // marking. _mealCook covers the other half of the pair below.
  testWidgets(
      'an empty AI allergen list says nothing was listed, and is still '
      'marked an estimate', (tester) async {
    const mealNoAllergens = Meal(
      id: 'm4-0000-0000-4000-8000-000000000007',
      cookId: 'c4-0000-0000-4000-8000-000000000008',
      title: 'شوربة عدس',
      description: 'شوربة عدس بالكمون',
      price: '25.00',
      cuisine: Cuisine.egyptian,
      category: MealCategory.soup,
      status: MealStatus.published,
      nutritionSource: NutritionSource.ai,
      calories: 180,
      allergens: [],
    );

    await tester.pumpWidget(
      _testApp(
          const PublicMealView(meal: mealNoAllergens, cookAddressForm: null)),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    expect(find.text(l10n.publicMealAllergensUnknown('other')), findsOneWidget);
    expect(find.text(l10n.aiEstimateNotice('other')), findsOneWidget);
  });

  testWidgets(
      'an empty allergen list the Cook owns still says nothing was '
      'listed', (tester) async {
    await tester.pumpWidget(
        _testApp(const PublicMealView(meal: _mealCook, cookAddressForm: null)));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    expect(find.text(l10n.publicMealAllergensUnknown('other')), findsOneWidget);
  });

  testWidgets('exposes no identifier and no phone number by any route',
      (tester) async {
    await tester.pumpWidget(
        _testApp(const PublicMealView(meal: _mealAi, cookAddressForm: null)));
    await tester.pumpAndSettle();

    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');

    expect(rendered, isNot(contains(_mealAi.cookId)));
    expect(rendered, isNot(contains(_mealAi.id)));
    expect(RegExp(r'\d{7,}').hasMatch(rendered), isFalse);
  });

  testWidgets('shows the photo only when there is one', (tester) async {
    await tester.pumpWidget(
        _testApp(const PublicMealView(meal: _mealAi, cookAddressForm: null)));
    await tester.pumpAndSettle();
    expect(find.byType(MealPhoto), findsNothing);

    await tester.pumpWidget(_testApp(
      const PublicMealView(
        meal: _mealAi,
        cookAddressForm: null,
        photoUrl: 'https://example.test/meal.jpg',
      ),
    ));
    await tester.pump();
    expect(find.byType(MealPhoto), findsOneWidget);
  });

  testWidgets('the Kitchen Profile link is rendered and calls back when tapped',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(_testApp(
      PublicMealView(
        meal: _mealAi,
        cookAddressForm: null,
        onOpenKitchen: () => tapped = true,
      ),
    ));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    expect(find.text(l10n.publicMealOpenKitchen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(l10n.publicMealOpenKitchen),
      50.0,
    );
    await tester.tap(find.text(l10n.publicMealOpenKitchen));
    expect(tapped, isTrue);
  });

  testWidgets('the Kitchen Profile link is absent when onOpenKitchen is null',
      (tester) async {
    await tester.pumpWidget(
        _testApp(const PublicMealView(meal: _mealAi, cookAddressForm: null)));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    expect(find.text(l10n.publicMealOpenKitchen), findsNothing);
  });
}
