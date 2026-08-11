import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ai/ai.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/discovery/data/discovery_repository.dart';
import 'package:kafoo_mobile/features/identity/presentation/code_screen.dart';
import 'package:kafoo_mobile/features/identity/presentation/sign_in_screen.dart';
import 'package:kafoo_mobile/features/meal/data/ai_provider.dart';
import 'package:kafoo_mobile/features/meal/data/meal_repository.dart';
import 'package:kafoo_mobile/features/meal/presentation/meal_conversation.dart';
import 'package:kafoo_mobile/home.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';
import 'package:kafoo_mobile/main.dart';
import 'package:kafoo_ui/ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fake_account_repository.dart';
import 'support/fake_discovery_repository.dart';
import 'support/fake_kitchen_profile_repository.dart';
import 'support/fake_meal_repository.dart';

/// THE APP, BOOTED WHOLE AND WALKED THROUGH.
///
/// Every other test in this directory builds ONE screen and hands it fakes.
/// That proves the screen and says nothing about the joins between screens —
/// and on 2026-08-10 five defects came out of those joins in a single day,
/// every one of them invisible to a green gate and obvious to the founder
/// holding a phone:
///
///   1. Material icons rendered as Chinese characters — an asset never bundled.
///   2. The app threw on its first frame with no `ProviderScope`.
///   3. Four Cook screens existed, passed their tests, and had no route in.
///   4. The design system's theme was rendered by no test at all.
///   5. A correct sign-in code signed the Cook in and navigated nowhere.
///
/// None of those is a bug *inside* a widget. Each is a bug in how the app is
/// assembled, so no amount of per-widget testing could see them. This file is
/// the answer to "how do we catch this class in future": boot `KafooApp`
/// itself, drive it the way a person does, and assert on what she would see.
///
/// **Rules for anything added here.** Drive by tapping and typing what a Cook
/// would tap and type — never by calling a method on a controller. Assert on
/// rendered Arabic, not on widget types where a string will do. And when a
/// journey breaks in the founder's hand, the fix lands here first, as the test
/// that fails.
const _profile = KitchenProfile(
  id: 'k1',
  cookId: 'c1',
  displayName: 'مطبخ أم علي',
  story: 'بنطبخ أكل بيتي',
  area: 'المعادي',
  deliveryTerms: 'توصيل في ساعة',
);

/// One Meal on offer, so browse reaches its success path.
///
/// It has to: the sign-in entry renders inside the loaded list, so a browse that
/// fails to load shows a Customer no way to sign in at all. That is a real
/// product gap and it is recorded in the journey below rather than worked
/// around silently.
const _onOffer = <DiscoveredMeal>[
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
    kitchen: _profile,
  ),
];

/// The app under test, with every seam replaced by a fake and nothing else.
Widget _app({
  required Stream<AuthState> auth,
  required FakeAccountRepository account,
  required FakeKitchenProfileRepository kitchen,
  FakeMealRepository? meals,
}) =>
    ProviderScope(
      overrides: [
        discoveryRepositoryProvider.overrideWithValue(
          FakeDiscoveryRepository(onOffer: _onOffer),
        ),
        if (meals != null) mealRepositoryProvider.overrideWithValue(meals),
        // The Meal conversation starts an analysis as soon as a description
        // arrives. Left real it reaches a model provider from a test.
        aiProviderProvider.overrideWithValue(StubAiProvider(const {})),
      ],
      child: KafooApp(
        authState: auth,
        accountRepository: account,
        kitchenProfileRepository: kitchen,
      ),
    );

/// The text field ON a given screen.
///
/// Never a bare `find.byType(TextField)`: a pushed route keeps the route beneath
/// it alive, so the search screen's own field is still in the tree while sign-in
/// is on top. An unscoped finder matches both and the test types into whichever
/// comes first — which is exactly the kind of test that passes while proving
/// nothing.
Finder _fieldOn(Type screen) => find.descendant(
      of: find.byType(screen),
      matching: find.byType(TextField),
    );

Finder _buttonOn(Type screen, String label) => find.descendant(
      of: find.byType(screen),
      matching: find.text(label),
    );

/// Drives the auth gate the way Supabase does, without Supabase.
class _FakeAuth {
  final _controller = StreamController<AuthState>.broadcast();
  Stream<AuthState> get stream => _controller.stream;

  void signedOut() =>
      _controller.add(const AuthState(AuthChangeEvent.signedOut, null));

  void signedIn() => _controller.add(AuthState(
        AuthChangeEvent.signedIn,
        Session(
          accessToken: 'test-token',
          tokenType: 'bearer',
          user: User(
            id: 'c1',
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: DateTime.utc(2026).toIso8601String(),
          ),
        ),
      ));

  Future<void> dispose() => _controller.close();
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  testWidgets('a Cook signs in with her phone and reaches her own screens',
      (tester) async {
    // THE JOURNEY THAT WAS BROKEN IN THE FOUNDER'S HAND. Every step below was
    // covered by a passing test on its own, and the path through them was not.
    final auth = _FakeAuth();
    addTearDown(auth.dispose);
    final account = FakeAccountRepository();
    final kitchen = FakeKitchenProfileRepository(existing: _profile);

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: account,
      kitchen: kitchen,
    ));
    auth.signedOut();
    await tester.pumpAndSettle();

    // 1. Signed out, a person sees FOOD and a way in — not a form. SC-001.
    expect(find.text(l10n.browseSignInEntry), findsOneWidget);

    // 2. Into sign-in.
    await tester.tap(find.text(l10n.browseSignInEntry));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);

    // 3. The number a Cook in Egypt actually types — local form, no +20.
    await tester.enterText(_fieldOn(SignInScreen), '01000000002');
    await tester.tap(_buttonOn(SignInScreen, l10n.signInContinue('other')));
    await tester.pumpAndSettle();

    expect(
      account.sentTo,
      ['+201000000002'],
      reason: 'The local form must be normalised before it is sent. Nobody in '
          'Egypt writes +20, and the service only accepts that form.',
    );
    expect(find.byType(CodeScreen), findsOneWidget);

    // 4. The code. This is where it broke: verifying succeeded and the screen
    //    stayed on top of the app forever.
    await tester.enterText(_fieldOn(CodeScreen), '000002');
    await tester.tap(_buttonOn(CodeScreen, l10n.signInContinue('other')));
    auth.signedIn();
    await tester.pumpAndSettle();

    expect(
      find.byType(CodeScreen),
      findsNothing,
      reason: 'THE BUG. A correct code left the code screen covering the app, '
          'so the Cook was signed in and could not tell.',
    );
    expect(find.byType(SignInScreen), findsNothing);

    // 5. And she is on her own screens, with every one of them reachable —
    //    which is the defect from earlier the same day.
    expect(find.byType(SignedInHome), findsOneWidget);
    expect(find.text(l10n.myMealsTitle), findsOneWidget);
    expect(find.text(l10n.newMealEntry), findsOneWidget);
    expect(find.text(l10n.kitchenViewTitle), findsOneWidget);
    // SC-011: leaving is one step from the first screen after signing in.
    expect(find.text(l10n.removeAccountEntry('other')), findsOneWidget);
  });

  testWidgets('a wrong code keeps her on the code screen', (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.dispose);
    final account = FakeAccountRepository()
      ..failVerifyWith = const AppError(messageKey: 'codeWrongCode');

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: account,
      kitchen: FakeKitchenProfileRepository(),
    ));
    auth.signedOut();
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.browseSignInEntry));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldOn(SignInScreen), '01000000002');
    await tester.tap(_buttonOn(SignInScreen, l10n.signInContinue('other')));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldOn(CodeScreen), '999999');
    await tester.tap(_buttonOn(CodeScreen, l10n.signInContinue('other')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.codeWrongCode('other')), findsOneWidget);
    expect(find.byType(CodeScreen), findsOneWidget);
    expect(find.byType(SignedInHome), findsNothing);
  });

  testWidgets('the app boots signed-out without throwing', (tester) async {
    // The `ProviderScope` defect in one line: browse became the signed-out home
    // as a ConsumerWidget, and the app threw on its first frame for anyone
    // without an account. `app_test` could not see it because it skipped the
    // root, which is the gap this file closes.
    final auth = _FakeAuth();
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: FakeKitchenProfileRepository(),
    ));
    auth.signedOut();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('the whole app renders through the design system',
      (tester) async {
    // The theme was rendered by NO test until this one. Asserting on the app's
    // own root means the design system cannot be silently bypassed again.
    final auth = _FakeAuth();
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: FakeKitchenProfileRepository(),
    ));
    auth.signedOut();
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.colorScheme.primary, KafooColors.primary);
    expect(app.theme?.textTheme.bodyMedium?.fontFamily, KafooType.fontFamily);
    // `ar` is the default locale, not the fallback.
    expect(app.locale, const Locale('ar'));
  });

  testWidgets('a Cook answers two questions about her food and moves on',
      (tester) async {
    // THE JOURNEY THAT WAS BROKEN IN THE FOUNDER'S HAND ON 2026-08-11. He made
    // his Kitchen Profile, started his first Meal, named it, typed what was in
    // it, and was told «مقدرناش نحفظ الأكلة». The Meal had saved. The app was
    // wrong about its own success.
    //
    // BE HONEST ABOUT WHAT THIS TEST DOES AND DOES NOT CATCH. The crash was in
    // the Supabase repository's row parsing, and this journey runs on a fake, so
    // it would NOT have found that bug. `meal_draft_row_test.dart` is what does,
    // by pinning the row a real Postgres returns. What this asserts is the thing
    // a fake CAN prove: the conversation moves from one question to the next,
    // and a Cook is never told a save failed while it succeeded.
    final auth = _FakeAuth();
    addTearDown(auth.dispose);
    final meals = FakeMealRepository();

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: FakeKitchenProfileRepository(existing: _profile),
      meals: meals,
    ));
    auth.signedIn();
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.newMealEntry));
    await tester.pumpAndSettle();

    // Question one: what is it called.
    expect(find.text(l10n.mealConvPromptDish), findsOneWidget);
    await tester.enterText(_fieldOn(MealConversationScreen), 'كشري');
    await tester.tap(_buttonOn(
      MealConversationScreen,
      l10n.convContinue('other'),
    ));
    await tester.pumpAndSettle();

    expect(meals.createdTitles, ['كشري']);

    // Question two: what is in it. This is where it stopped.
    expect(find.text(l10n.mealConvPromptDescription('other')), findsOneWidget);
    await tester.enterText(
      _fieldOn(MealConversationScreen),
      'عدس ورز ومكرونة، وبنحمر البصل فوقها',
    );
    await tester.tap(_buttonOn(
      MealConversationScreen,
      l10n.convContinue('other'),
    ));
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.mealSaveError('other')),
      findsNothing,
      reason: 'THE BUG. The description reached the database and the Cook was '
          'told it had not. Being wrong in this direction is the worst of the '
          'two: she retypes work that is already saved, or gives up.',
    );
    expect(
      meals.updateDraftArgs.last.description,
      'عدس ورز ومكرونة، وبنحمر البصل فوقها',
    );
    // And she has moved on. The departure matters as much as the arrival: with
    // the write reported as failed, the description question stayed on screen
    // with her own words still in the box.
    expect(find.text(l10n.mealConvPromptDescription('other')), findsNothing);
    expect(find.text(l10n.mealConvPromptPhoto), findsOneWidget);
  });

  testWidgets('a Cook prices her Meal in the digits her keyboard produces',
      (tester) async {
    // THE SECOND JOURNEY BROKEN IN THE FOUNDER'S HAND ON 2026-08-11, on the very
    // next question after the one above. He typed «١٢٠» and read «مقدرناش نحفظ
    // الأكلة» — we could not save the Meal.
    //
    // «١٢٠» is one hundred and twenty in Arabic-Indic digits, which is what an
    // Arabic keyboard produces. `price` is `numeric(10,2)` and the answer was
    // sent as the text the Cook typed, so Postgres refused it: `invalid input
    // syntax for type numeric`. Every Cook typing in Arabic, every price.
    //
    // **This journey WOULD have caught it**, unlike the one above, and the
    // difference is worth naming: the bug was in what the app SENDS, not in how
    // it reads the reply, and a fake records what it was sent. The reason no test
    // saw it is that every existing test typed `'35'` — the price question, in
    // the one product whose default locale is Egyptian Arabic, was only ever
    // answered the way a developer answers it.
    final auth = _FakeAuth();
    addTearDown(auth.dispose);
    final meals = FakeMealRepository();

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: FakeKitchenProfileRepository(existing: _profile),
      meals: meals,
    ));
    auth.signedIn();
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.newMealEntry));
    await tester.pumpAndSettle();

    await tester.enterText(_fieldOn(MealConversationScreen), 'كشري');
    await tester.tap(_buttonOn(
      MealConversationScreen,
      l10n.convContinue('other'),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(_fieldOn(MealConversationScreen), 'عدس ورز ومكرونة');
    await tester.tap(_buttonOn(
      MealConversationScreen,
      l10n.convContinue('other'),
    ));
    await tester.pumpAndSettle();

    // The photo is the one question a Cook may decline, and declining must not
    // cost her the conversation.
    expect(find.text(l10n.mealConvPromptPhoto), findsOneWidget);
    await tester.tap(_buttonOn(
      MealConversationScreen,
      l10n.mealConvPhotoSkip('other'),
    ));
    await tester.pumpAndSettle();

    // The price, typed the way she types it.
    expect(find.text(l10n.mealConvPromptPrice('other')), findsOneWidget);
    await tester.enterText(_fieldOn(MealConversationScreen), '١٢٠');
    await tester.tap(_buttonOn(
      MealConversationScreen,
      l10n.convContinue('other'),
    ));
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.mealSaveError('other')),
      findsNothing,
      reason: 'THE BUG. Arabic-Indic digits reached a numeric column as text.',
    );
    expect(
      find.text(l10n.mealPriceInvalid('other')),
      findsNothing,
      reason:
          '«١٢٠» IS a price. The new message exists for words and zero, and '
          'showing it here would be the same refusal wearing better copy.',
    );
    expect(
      meals.updateDraftArgs.last.price,
      '120',
      reason: 'What the database is sent, which is the whole defect. Latin '
          'digits, no currency word, unrounded, and the same string the '
          'conversation now holds in memory.',
    );
    // The departure. With the write reported as failed she stayed on the price
    // question with «١٢٠» still in the box, tapping «كمّل» and getting the same
    // sentence — which is exactly what the screenshot showed.
    expect(find.text(l10n.mealConvPromptPrice('other')), findsNothing);
  });

  testWidgets('the signed-in journey survives 200% text on a small phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = _FakeAuth();
    addTearDown(auth.dispose);

    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
      child: _app(
        auth: auth.stream,
        account: FakeAccountRepository(),
        kitchen: FakeKitchenProfileRepository(existing: _profile),
      ),
    ));
    auth.signedIn();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final leave = find.text(l10n.removeAccountEntry('other'));
    expect(leave, findsOneWidget);
    await tester.ensureVisible(leave);
  });
}
