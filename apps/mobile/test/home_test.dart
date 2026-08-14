import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output_provider.dart';
import 'package:kafoo_mobile/features/identity/presentation/remove_account_screen.dart';
import 'package:kafoo_mobile/features/meal/data/meal_repository.dart';
import 'package:kafoo_mobile/home.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';
import 'package:kafoo_ui/ui.dart';

import 'support/fake_kitchen_profile_repository.dart';
import 'support/fake_meal_repository.dart';

/// THE SIGNED-IN HOME, WHICH IS NOW THE MEAL LIST RATHER THAN A MENU.
///
/// It was five stacked text buttons until 2026-08-14 — أكلاتي، أكلة جديدة،
/// مطبخك، غيّر رقم الموبايل، امسح حسابي — and every test in this file asserted
/// that they were all present, which is how a screen the design package never
/// drew survived a green gate for months. The package draws no menu because a
/// voice-first product has none: the canonical screen IS the home, and it opens
/// speaking.
///
/// So these tests assert two different things from the ones they replaced:
/// the Cook lands ON her Meals rather than on a list of places she could go,
/// and everything the menu used to carry is still reachable — one tap into the
/// account sheet, with leaving visible in it without scrolling.
const _profile = KitchenProfile(
  id: 'test-id',
  cookId: 'test-cook',
  displayName: 'مطبخ أم علي',
  story: 'بنطبخ أكل بيتي',
  area: 'المعادي',
  deliveryTerms: 'توصيل في ساعة',
);

const _published = CookMeal(
  id: 'm-pub',
  cookId: 'test-cook',
  title: 'كشري',
  description: 'عدس ورز',
  price: '35',
  cuisine: Cuisine.egyptian,
  category: MealCategory.main,
  status: MealStatus.published,
  nutritionSource: NutritionSource.ai,
);

Widget _testApp(Widget child, {FakeMealRepository? meals}) => ProviderScope(
      overrides: [
        mealRepositoryProvider.overrideWithValue(
          meals ?? FakeMealRepository(meals: const [_published]),
        ),
        // Recorded rather than spoken. Left real, the Meal list reaches Kafoo's
        // `speak` function — and a paid provider — from a widget test, and its
        // timeouts leave pending timers the framework rejects.
        speechOutputProvider.overrideWithValue(FakeSpeechOutput()),
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
        home: child,
      ),
    );

Future<void> _openAccountSheet(
    WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(find.byTooltip(l10n.accountEntry));
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  testWidgets('a Cook lands on her own Meals, not on a menu', (tester) async {
    await tester.pumpWidget(_testApp(SignedInHome(
      kitchenProfileRepository: FakeKitchenProfileRepository(
        existing: _profile,
      ),
    )));
    await tester.pumpAndSettle();

    // Her Meal is on screen, which no menu could show her.
    expect(find.text(_published.title!), findsOneWidget);
    // And the orb owns the bottom of it.
    expect(find.byType(KafooTalkButton), findsOneWidget);
    // The menu entries are NOT on the home any more. This is the assertion the
    // old file had inverted, and inverting it is the whole redesign.
    expect(find.text(l10n.newMealEntry), findsNothing);
    expect(find.text(l10n.kitchenViewTitle), findsNothing);
    expect(find.text(l10n.removeAccountEntry('other')), findsNothing);
  });

  testWidgets('the account sheet carries everything the menu used to',
      (tester) async {
    await tester.pumpWidget(_testApp(SignedInHome(
      kitchenProfileRepository: FakeKitchenProfileRepository(
        existing: _profile,
      ),
    )));
    await tester.pumpAndSettle();
    await _openAccountSheet(tester, l10n);

    expect(find.text(l10n.kitchenViewTitle), findsOneWidget);
    expect(find.text(l10n.changePhoneEntry('other')), findsOneWidget);
    // SC-011: leaving takes no more steps than joining did — joining is a phone
    // number and a code, this is one tap — and it is visible here without
    // scrolling, which is the part that stops the sheet becoming a place to
    // bury it.
    expect(find.text(l10n.removeAccountEntry('other')), findsOneWidget);
  });

  testWidgets('the mute control survives every state of the list',
      (tester) async {
    // It used to live inside the loaded state only, so a Cook stuck on an empty
    // or failed list could not silence the assistant at all. A control the
    // design calls persistent that disappears when something goes wrong is not
    // persistent.
    for (final repo in [
      FakeMealRepository(meals: const []),
      FakeMealRepository(failOperations: true),
    ]) {
      await tester.pumpWidget(_testApp(
        SignedInHome(
          kitchenProfileRepository: FakeKitchenProfileRepository(
            existing: _profile,
          ),
        ),
        meals: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(KafooMuteButton), findsOneWidget);
      expect(find.byTooltip(l10n.accountEntry), findsOneWidget);
    }
  });

  testWidgets(
      'the kitchen entry waits for the read rather than offering to '
      'create a second kitchen', (tester) async {
    // The gate is the whole test. Without it findMine returns in the same
    // microtask, the not-yet-loaded frame never renders, and this passes while
    // asserting nothing.
    final gate = Completer<void>();
    final repo = FakeKitchenProfileRepository(existing: _profile)
      ..findMineGate = gate;

    await tester.pumpWidget(_testApp(
      SignedInHome(kitchenProfileRepository: repo),
    ));
    await tester.pump();
    await _openAccountSheet(tester, l10n);

    // Tapped WHILE THE READ IS STILL IN FLIGHT, which is the case that used to
    // offer a second kitchen to a Cook who has one.
    await tester.tap(find.text(l10n.kitchenViewTitle));
    await tester.pump();
    expect(
      repo.createCalls,
      0,
      reason: 'Nothing may be created on a null the read has not confirmed.',
    );

    gate.complete();
    await tester.pumpAndSettle();

    // Once it lands she is on HER kitchen, not in the flow that makes one.
    expect(find.text(_profile.displayName), findsWidgets);
    expect(repo.createCalls, 0);
  });

  testWidgets('a Cook who has a kitchen opens it rather than making another',
      (tester) async {
    final repo = FakeKitchenProfileRepository(existing: _profile);
    await tester.pumpWidget(_testApp(
      SignedInHome(kitchenProfileRepository: repo),
    ));
    await tester.pumpAndSettle();
    await _openAccountSheet(tester, l10n);

    await tester.tap(find.text(l10n.kitchenViewTitle));
    await tester.pumpAndSettle();

    // The Kitchen Profile screen shows what the kitchen says; the conversation
    // that creates one would not know this Cook's display name.
    expect(find.text(_profile.displayName), findsWidgets);
    expect(
      repo.createCalls,
      0,
      reason: 'Opening an existing Kitchen Profile must never create one.',
    );
    // THE SHEET CLOSED BEHIND HER. Pushing a route from inside a modal sheet
    // without popping it first leaves the sheet sitting above the screen it
    // opened, so she comes back to something she has no memory of opening.
    expect(find.byType(KafooSheet), findsNothing);
  });

  testWidgets('a failed Meal read still leaves the account reachable',
      (tester) async {
    await tester.pumpWidget(_testApp(
      SignedInHome(
        kitchenProfileRepository: FakeKitchenProfileRepository(
          failFindMine: true,
        ),
      ),
      meals: FakeMealRepository(failOperations: true),
    ));
    await tester.pumpAndSettle();
    await _openAccountSheet(tester, l10n);

    // Neither of these needs a Kitchen Profile or a Meal list, and neither may
    // disappear because reading one failed.
    expect(find.text(l10n.changePhoneEntry('other')), findsOneWidget);
    expect(find.text(l10n.removeAccountEntry('other')), findsOneWidget);
  });

  testWidgets('every account entry clears the 48dp floor', (tester) async {
    await tester.pumpWidget(_testApp(SignedInHome(
      kitchenProfileRepository: FakeKitchenProfileRepository(
        existing: _profile,
      ),
    )));
    await tester.pumpAndSettle();
    await _openAccountSheet(tester, l10n);

    for (final label in [
      l10n.kitchenViewTitle,
      l10n.changePhoneEntry('other'),
      l10n.removeAccountEntry('other'),
      l10n.accountSheetClose('other'),
    ]) {
      // byWidgetPredicate, not byType: ButtonStyleButton is abstract and
      // byType matches an exact runtime type, so it finds nothing here.
      final size = tester.getSize(find
          .ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          )
          .first);
      expect(
        size.height,
        greaterThanOrEqualTo(48.0),
        reason: '"$label" is below the tap-target floor.',
      );
    }
  });

  testWidgets('leaving survives 200% text on a small screen', (tester) async {
    // SC-011 says leaving takes no more steps than joining did. Double text
    // size on a 320x480 phone is where a Column that cannot scroll resolves an
    // overflow by pushing its LAST child off the bottom — which here is the way
    // out. The sheet scrolls, so this checks the whole path rather than one
    // frame: open it, reach the entry, and land on the screen it promises.
    //
    // It walks INTO RemoveAccountScreen rather than stopping at the tap, which
    // is how that screen's identical overflow was found.
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // SET ON THE VIEW, NOT BY WRAPPING IN A `MediaQuery`. A bare
    // `MediaQuery(data: MediaQueryData(textScaler: ...))` REPLACES the whole
    // data object, so the screen size inside it becomes zero — and this sheet
    // caps its own height at 90% of that, which is 90% of nothing. The sheet
    // then laid out taller than the phone and put «امسح حسابي» 120 pixels below
    // the bottom of the screen, which is exactly the failure this test is for
    // and would have been reported as a false one.
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_testApp(SignedInHome(
      kitchenProfileRepository: FakeKitchenProfileRepository(
        existing: _profile,
      ),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await _openAccountSheet(tester, l10n);

    final leave = find.text(l10n.removeAccountEntry('other'));
    expect(leave, findsOneWidget);
    await tester.ensureVisible(leave);
    await tester.tap(leave);
    await tester.pumpAndSettle();

    // ARRIVED, AND THE SHEET CLOSED BEHIND HER. The departure assertion is the
    // sheet rather than the Meal list: a pushed route keeps the route beneath
    // it alive, so `findsNothing` on the home would fail here while proving
    // nothing about whether anybody popped anything.
    expect(find.byType(RemoveAccountScreen), findsOneWidget);
    expect(find.byType(KafooSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
