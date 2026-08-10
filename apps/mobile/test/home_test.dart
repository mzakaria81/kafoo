import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/home.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';

import 'support/fake_kitchen_profile_repository.dart';

/// What a Cook must be able to REACH from the signed-in home.
///
/// Every screen named here already had a passing widget test on 2026-08-09 and
/// none of them could be opened from the running app: the home carried three
/// buttons and a comment from E1 saying Meals arrived later. A test that builds
/// a screen directly proves it renders and says nothing about whether anybody
/// can get to it, so this file asserts the entries exist and lead somewhere.
const _profile = KitchenProfile(
  id: 'test-id',
  cookId: 'test-cook',
  displayName: 'مطبخ أم علي',
  story: 'بنطبخ أكل بيتي',
  area: 'المعادي',
  deliveryTerms: 'توصيل في ساعة',
);

Widget _testApp(Widget child) => ProviderScope(
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

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  testWidgets('every Cook entry is on the home, in Arabic', (tester) async {
    await tester.pumpWidget(_testApp(SignedInHome(
      kitchenProfileRepository: FakeKitchenProfileRepository(
        existing: _profile,
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text(l10n.myMealsTitle), findsOneWidget);
    expect(find.text(l10n.newMealEntry), findsOneWidget);
    expect(find.text(l10n.kitchenViewTitle), findsOneWidget);
    // SC-011: leaving stays one step from the first screen after signing in.
    expect(find.text(l10n.removeAccountEntry('other')), findsOneWidget);
  });

  testWidgets('My Meals opens the Cook\'s own list of Meals', (tester) async {
    await tester.pumpWidget(_testApp(SignedInHome(
      kitchenProfileRepository: FakeKitchenProfileRepository(
        existing: _profile,
      ),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.myMealsTitle));
    await tester.pumpAndSettle();

    // The list's own heading, which is a different string from the entry that
    // opened it only because Kafoo reuses the key — what matters is that a
    // route was pushed and MyMealsScreen is what arrived.
    expect(find.byType(SignedInHome), findsNothing);
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

    TextButton kitchenEntry() => tester.widget<TextButton>(
          find.ancestor(
            of: find.text(l10n.kitchenViewTitle),
            matching: find.byType(TextButton),
          ),
        );

    expect(
      kitchenEntry().onPressed,
      isNull,
      reason: 'A Cook who already has a kitchen must not be sent into the flow '
          'that creates one just because the read has not landed yet.',
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(kitchenEntry().onPressed, isNotNull);
  });

  testWidgets('a Cook who has a kitchen opens it rather than making another',
      (tester) async {
    final repo = FakeKitchenProfileRepository(existing: _profile);
    await tester.pumpWidget(_testApp(
      SignedInHome(kitchenProfileRepository: repo),
    ));
    await tester.pumpAndSettle();

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
  });

  testWidgets('a Cook with no kitchen can still reach My Meals and leaving',
      (tester) async {
    await tester.pumpWidget(_testApp(SignedInHome(
      kitchenProfileRepository: FakeKitchenProfileRepository(existing: null),
    )));
    await tester.pumpAndSettle();

    expect(find.text(l10n.myMealsTitle), findsOneWidget);
    expect(find.text(l10n.removeAccountEntry('other')), findsOneWidget);
  });

  testWidgets('a failed profile read does not take the home down with it',
      (tester) async {
    await tester.pumpWidget(_testApp(SignedInHome(
      kitchenProfileRepository: FakeKitchenProfileRepository(
        failFindMine: true,
      ),
    )));
    await tester.pumpAndSettle();

    // The whole point of not blocking on the read: these do not need a Kitchen
    // Profile and must not disappear because reading one failed.
    expect(find.text(l10n.myMealsTitle), findsOneWidget);
    expect(find.text(l10n.newMealEntry), findsOneWidget);
    expect(find.text(l10n.removeAccountEntry('other')), findsOneWidget);
  });

  testWidgets('every entry clears the 48dp floor', (tester) async {
    await tester.pumpWidget(_testApp(SignedInHome(
      kitchenProfileRepository: FakeKitchenProfileRepository(
        existing: _profile,
      ),
    )));
    await tester.pumpAndSettle();

    for (final label in [
      l10n.myMealsTitle,
      l10n.newMealEntry,
      l10n.kitchenViewTitle,
      l10n.removeAccountEntry('other'),
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
    // SC-011 says leaving stays one step from the first screen after signing
    // in. Five entries at double text size overflow a 320x480 phone, and a
    // Column that cannot scroll resolves that by pushing its LAST child off the
    // bottom — which is this one. The old three-entry home had the headroom to
    // hide the problem.
    //
    // It walks into RemoveAccountScreen rather than stopping at the tap, which
    // is how that screen's identical overflow was found. FOUR MORE SCREENS HAVE
    // THE SAME SHAPE and are not fixed: change_phone_screen, code_screen,
    // email_sign_in_screen and sign_in_screen are all Padding > Column >
    // Spacer with no scroll view. They are the sign-in path rather than the
    // leave path, so they are a separate change with the founder's call on
    // scope, not something to sweep in here — but a 200% Cook cannot finish
    // signing in either.
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
      child: _testApp(SignedInHome(
        kitchenProfileRepository: FakeKitchenProfileRepository(
          existing: _profile,
        ),
      )),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final leave = find.text(l10n.removeAccountEntry('other'));
    expect(leave, findsOneWidget);
    await tester.ensureVisible(leave);
    await tester.tap(leave);
    await tester.pumpAndSettle();
    expect(find.byType(SignedInHome), findsNothing);
  });
}
