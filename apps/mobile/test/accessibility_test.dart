import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output_provider.dart';
import 'package:kafoo_mobile/features/discovery/data/discovery_repository.dart';
import 'package:kafoo_mobile/features/discovery/presentation/browse_screen.dart';
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
import 'package:kafoo_ui/ui.dart';

import 'support/fake_account_repository.dart';
import 'support/fake_discovery_repository.dart';
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

/// The app under test, **with the app's own theme**.
///
/// Until 2026-08-10 this built a themeless `MaterialApp`, so all thirty
/// assertions below ran against Material's defaults and not one of them had ever
/// seen `kafooTheme()` — the thing that decides every colour and size a Cook
/// actually looks at. The design system shipped with token-level tests only, and
/// token tests pass while screens clip, because a colour cannot overflow.
Widget _testApp(Widget child, {double textScale = 1.0}) {
  return ProviderScope(
    // EVERY SCREEN IN THIS SWEEP SPEAKS NOW, so every one of them needs the
    // voice seam replaced. Left real they reach Kafoo's `speak` function — and
    // a paid provider — from a widget test, and its timeouts leave pending
    // timers the framework rejects.
    overrides: [speechOutputProvider.overrideWithValue(FakeSpeechOutput())],
    child: MaterialApp(
      theme: kafooTheme(),
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
    ),
  );
}

/// Every screen E1 adds, built the way a test can reach it.
const _browseFixture = <DiscoveredMeal>[
  DiscoveredMeal(
    meal: Meal(
      id: 'm1',
      cookId: 'c1',
      title: 'كشري',
      description: 'عدس ومكرونة وأرز',
      price: '35',
      cuisine: Cuisine.egyptian,
      category: MealCategory.main,
      status: MealStatus.published,
      nutritionSource: NutritionSource.ai,
    ),
    kitchen: KitchenProfile(
      id: 'k1',
      cookId: 'c1',
      displayName: 'مطبخ فاطمة',
      story: 'بطبخ من زمان',
      area: 'المهندسين',
      deliveryTerms: 'توصيل لحد باب البيت',
    ),
  ),
];

Map<String, Widget> _screens() => {
      // The signed-out front door: the most-seen screen in the app, and it was
      // the only one this sweep did not measure. Includes the sign-in entry,
      // because without it the sweep passes by having nothing to measure —
      // which is the failure mode this file already warns about.
      'browse': ProviderScope(
        overrides: [
          discoveryRepositoryProvider.overrideWithValue(
            FakeDiscoveryRepository(onOffer: _browseFixture),
          ),
        ],
        child: BrowseScreen(
          entry: TextButton(onPressed: () {}, child: const Text('دخول')),
        ),
      ),
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
  // ──────────────────────────────────────────────────────────────────────────
  // EVERY SCREEN SPEAKS, AND EVERY SCREEN CAN BE SILENCED. Founder's
  // instruction, 2026-08-14: Kafoo is voice-first and most of it was mute.
  //
  // This sweep is here rather than in a file of its own for the same reason the
  // right-to-left and tap-target sweeps are: `_screens()` is the one list of
  // every screen anybody can reach, and a second copy of it would be a second
  // place to forget the screen that was just added. §10.2 — the assistant
  // speaks first and the screen is the receipt; for a Cook who does not read
  // comfortably, a silent screen is a blank one.
  //
  // **The Meal list and the two conversations are absent from this map**, not
  // exempt: they carry their own bar and their own greeting, and they are
  // covered by their own suites.
  // ──────────────────────────────────────────────────────────────────────────
  for (final entry in _screens().entries) {
    testWidgets('${entry.key} can be silenced', (tester) async {
      await tester.pumpWidget(_testApp(entry.value));
      await tester.pumpAndSettle();

      expect(
        find.byType(KafooMuteButton),
        findsOneWidget,
        reason: 'The mute control is persistent by design. A control the '
            'design calls persistent that some screens lack does not persist.',
      );
    });
  }

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
  //
  // **AT PHONE SIZES, AND THAT IS THE HALF THAT WAS MISSING.** This loop ran only
  // at Flutter's 800x600 test default, where a tall layout has room it will never
  // have on a handset. Five screens overflowed at 360x640 while every assertion
  // here stayed green — including the conversational publish flow, which is the
  // path a Cook lands on when speech recognition is unavailable on her phone.
  //
  // 360x640 is the modal cheap Android; 320x568 is the smallest still in use.
  const viewports = <String, Size>{
    'default': Size.zero, // whatever the harness gives us
    '360x640': Size(360, 640),
    '320x568': Size(320, 568),
  };

  for (final entry in _screens().entries) {
    for (final vp in viewports.entries) {
      testWidgets('${entry.key} does not clip at 200% text scale, ${vp.key}',
          (tester) async {
        if (vp.value != Size.zero) {
          tester.view.physicalSize = vp.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
        }
        await tester.pumpWidget(_testApp(entry.value, textScale: 2.0));
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: '${entry.key} clips at 200% on ${vp.key}. An overflowing '
              'Column drops its LAST child, which is usually the button that '
              'finishes the task.',
        );
      });
    }
  }
}
