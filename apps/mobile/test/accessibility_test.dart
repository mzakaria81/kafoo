import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/identity/presentation/change_phone_screen.dart';
import 'package:kafoo_mobile/features/identity/presentation/email_sign_in_screen.dart';
import 'package:kafoo_mobile/features/identity/presentation/remove_account_screen.dart';
import 'package:kafoo_mobile/features/identity/presentation/sign_in_screen.dart';
import 'package:kafoo_mobile/features/kitchen_profile/presentation/kitchen_profile_screen.dart';
import 'package:kafoo_mobile/features/kitchen_profile/presentation/public_kitchen_view.dart';
import 'package:kafoo_mobile/features/meal/data/meal_repository.dart';
import 'package:kafoo_mobile/features/meal/presentation/meal_edit_screen.dart';
import 'package:kafoo_mobile/features/meal/presentation/my_meals_screen.dart';
import 'package:kafoo_mobile/features/meal/presentation/public_meal_view.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';

import 'support/fake_account_repository.dart';
import 'support/fake_kitchen_profile_repository.dart';
import 'support/fake_meal_repository.dart';

const _profile = KitchenProfile(
  id: 'test-id',
  cookId: 'test-cook',
  displayName: 'مطبخ أم علي',
  story: 'بنطبخ أكل بيتي',
  area: 'المعادي',
  deliveryTerms: 'توصيل في ساعة',
);

const _meal = Meal(
  id: 'test-meal-id',
  cookId: 'test-meal-cook',
  title: 'كشري',
  description: 'عدس ورز ومكرونة',
  price: '35.00',
  cuisine: Cuisine.egyptian,
  category: MealCategory.main,
  status: MealStatus.published,
  nutritionSource: NutritionSource.ai,
  ingredients: ['عدس', 'رز', 'مكرونة'],
  calories: 520,
  allergens: ['جلوتين'],
);

const _cookMeal = CookMeal(
  id: 'test-meal-id',
  cookId: 'test-meal-cook',
  title: 'كشري',
  description: 'عدس ورز ومكرونة',
  price: '35.00',
  cuisine: Cuisine.egyptian,
  category: MealCategory.main,
  status: MealStatus.published,
  nutritionSource: NutritionSource.ai,
  ingredients: ['عدس', 'رز', 'مكرونة'],
  calories: 520,
  allergens: ['جلوتين'],
);

Widget _testApp(Widget child, {double textScale = 1.0}) {
  return MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery.withClampedTextScaling(
      minScaleFactor: textScale,
      maxScaleFactor: textScale,
      child: child!,
    ),
    home: child,
  );
}

/// Every screen E1 adds, built the way a test can reach it.
Map<String, Widget> _screens() => {
      'sign in': const SignInScreen(),
      'email sign in': EmailSignInScreen(repository: FakeAccountRepository()),
      'change phone': ChangePhoneScreen(repository: FakeAccountRepository()),
      'remove account':
          RemoveAccountScreen(repository: FakeAccountRepository()),
      'kitchen profile': KitchenProfileScreen(
        profile: _profile,
        repository: FakeKitchenProfileRepository(existing: _profile),
      ),
      'public kitchen': const PublicKitchenView(profile: _profile),
      // onOpenKitchen is supplied so the Kitchen Profile link exists. It is
      // the only interactive widget on this screen, so without it the
      // tap-target sweep below would pass by having nothing to measure.
      'public meal': PublicMealView(
          meal: _meal, cookAddressForm: null, onOpenKitchen: () {}),
      // A published Meal so the availability control exists for tap-target
      // measurement — the only interactive widget on this screen.
      'my meals': ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(
            FakeMealRepository(meals: [_cookMeal]),
          ),
        ],
        child: const MyMealsScreen(),
      ),
      'meal edit': ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(
            FakeMealRepository(existing: _meal),
          ),
        ],
        child: const MealEditScreen(meal: _meal),
      ),
    };

void main() {
  // SC-005 / T066: Arabic is the default locale, not a fallback, so every
  // screen must lay out right-to-left. A screen that only looks right in
  // English is a screen no Cook will ever see working.
  for (final entry in _screens().entries) {
    testWidgets('${entry.key} lays out right-to-left', (tester) async {
      await tester.pumpWidget(_testApp(entry.value));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold).first);
      expect(Directionality.of(context), TextDirection.rtl);
    });
  }

  // T067: tap targets ≥48dp. Checked on the rendered geometry rather than by
  // reading styles, so a button that is nominally sized but squeezed by its
  // parent still fails.
  for (final entry in _screens().entries) {
    testWidgets('${entry.key} has no tap target under 48dp', (tester) async {
      await tester.pumpWidget(_testApp(entry.value));
      await tester.pumpAndSettle();

      final buttons = find.byWidgetPredicate((w) =>
          w is FilledButton ||
          w is TextButton ||
          w is OutlinedButton ||
          w is ElevatedButton);

      for (final element in buttons.evaluate()) {
        final size = element.size;
        if (size == null || size.isEmpty) continue;
        expect(
          size.height,
          greaterThanOrEqualTo(48.0),
          reason: '${entry.key}: a ${element.widget.runtimeType} is '
              '${size.height}dp tall, under the 48dp floor',
        );
      }
    });
  }

  // dart.md: layout must not clip at 200% text scale. Overflow is reported as
  // a framework exception, so a clean pump is the assertion.
  for (final entry in _screens().entries) {
    testWidgets('${entry.key} does not clip at 200% text scale',
        (tester) async {
      await tester.pumpWidget(_testApp(entry.value, textScale: 2.0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
