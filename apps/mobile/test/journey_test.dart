import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ai/ai.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output_provider.dart';
import 'package:kafoo_mobile/features/discovery/data/discovery_repository.dart';
import 'package:kafoo_mobile/features/identity/presentation/code_screen.dart';
import 'package:kafoo_mobile/features/identity/presentation/sign_in_screen.dart';
import 'package:kafoo_mobile/features/meal/data/ai_provider.dart';
import 'package:kafoo_mobile/features/meal/data/meal_repository.dart';
import 'package:kafoo_mobile/features/meal/presentation/meal_conversation.dart';
import 'package:kafoo_mobile/features/meal/presentation/meal_receipt.dart';
import 'package:kafoo_mobile/features/meal/presentation/my_meals_screen.dart';
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
  FakeSpeechOutput? speech,
  AiProvider? ai,
}) =>
    ProviderScope(
      overrides: [
        // The assistant's voice, recorded rather than spoken. Left real it
        // reaches Kafoo's `speak` function — and therefore a paid provider —
        // from a widget test.
        speechOutputProvider.overrideWithValue(speech ?? FakeSpeechOutput()),
        discoveryRepositoryProvider.overrideWithValue(
          FakeDiscoveryRepository(onOffer: _onOffer),
        ),
        if (meals != null) mealRepositoryProvider.overrideWithValue(meals),
        // The Meal conversation starts an analysis as soon as a description
        // arrives. Left real it reaches a model provider from a test.
        aiProviderProvider.overrideWithValue(ai ?? StubAiProvider(const {})),
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

  testWidgets('«أضيف بإيدي» reaches the Meal creation flow, not the way out',
      (tester) async {
    // 2026-08-11, found in review: the button promised the creation flow and
    // called `maybePop`. It closed the Meal list and put a Cook back on Home
    // with nothing started — and because Home is what sits underneath, the
    // screen it left looked like a screen it had arrived at.
    //
    // THE DEPARTURE IS HALF THE ASSERTION. `findsOneWidget` on the destination
    // passes for a route that was pushed on top of a list nobody popped; only
    // `findsNothing` on the list proves the Cook actually went somewhere.
    final auth = _FakeAuth();
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      // No Kitchen Profile: the creation flow's first screen then asks her to
      // make one, which is a stable thing to assert on and is the branch a new
      // Cook actually meets.
      kitchen: FakeKitchenProfileRepository(),
      meals: FakeMealRepository(),
    ));
    auth.signedIn();
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.myMealsTitle).last);
    await tester.pumpAndSettle();

    // The empty list's own version of the button.
    await tester.tap(find.text(l10n.myMealsEmptyByHand('other')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealNeedsKitchenTitle), findsOneWidget);
    expect(find.text(l10n.myMealsEmptyInvitation), findsNothing);
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

  // ───────────────────────────────────────────────────────────────────────────
  // ADR-0015. The journeys these replaced walked four questions and asserted
  // that question two followed question one. There is no sequence left to walk.
  //
  // What a journey test must still prove is the same thing it always proved:
  // the step BETWEEN screens works. Here that is the step between the Meal list
  // and the conversation, and between saying something and it being written.
  // ───────────────────────────────────────────────────────────────────────────

  testWidgets('a Cook talks a Meal into being on one screen', (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.dispose);
    final meals = FakeMealRepository();

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: FakeKitchenProfileRepository(existing: _profile),
      meals: meals,
      ai: StubAiProvider(const {
        'conversation': '{"say":"تمام، كشري بمية وعشرين.",'
            '"captured":{"dish":"كشري",'
            '"description":"عدس ورز ومكرونة، وبنحمر البصل فوقها",'
            '"price":"١٢٠"}}',
      }),
    ));
    auth.signedIn();
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.newMealEntry));
    await tester.pumpAndSettle();

    // ONE SCREEN. The Meal list is behind it and the conversation is on it.
    expect(find.byType(MealConversationScreen), findsOneWidget);
    expect(find.byType(MyMealsScreen), findsNothing);

    // Typing, because no recogniser exists in a widget test — and typing is a
    // complete alternative, so the journey has to work through it.
    final typeButton = find.byKey(const ValueKey('meal-talk-type'));
    await tester.ensureVisible(typeButton);
    await tester.pumpAndSettle();
    await tester.tap(typeButton);
    await tester.pumpAndSettle();

    // WHAT AN EGYPTIAN COOK ACTUALLY TYPES, INCLUDING THE DIGITS. On
    // 2026-08-11 «١٢٠» reached a numeric column as that exact text and every
    // Cook was told her Meal could not be saved.
    final box = find.byKey(const ValueKey('meal-talk-box'));
    await tester.ensureVisible(box);
    await tester.pumpAndSettle();
    await tester.enterText(
      box,
      'عملت كشري، عدس ورز ومكرونة، وبنحمر البصل فوقها. بـ١٢٠ جنيه.',
    );
    final send = _buttonOn(MealConversationScreen, l10n.convContinue('other'));
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(meals.createdTitles, ['كشري']);
    expect(
      meals.updateDraftArgs.map((c) => c.price).whereType<String>(),
      contains('120'),
      reason: 'Arabic-Indic digits must reach the database as digits Postgres '
          'reads, whichever side of the conversation produced them.',
    );

    // The assistant answered, and the answer is on the screen as the receipt of
    // what was said — not as a transcript of what she typed.
    expect(find.text('تمام، كشري بمية وعشرين.'), findsOneWidget);
    expect(
      find.text('عملت كشري، عدس ورز ومكرونة، وبنحمر البصل فوقها. بـ١٢٠ جنيه.'),
      findsNothing,
      reason:
          'The assistant paraphrases. A transcript hides a misunderstanding '
          'from exactly the person who cannot read it — ADR-0013 rule 2.',
    );

    // Nothing went on offer. Publishing is a gate, and nobody answered it.
    expect(meals.publishCalls, 0);
  });

  testWidgets('the app SAYS what it understood, not only shows it',
      (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.dispose);
    final speech = FakeSpeechOutput();

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: FakeKitchenProfileRepository(existing: _profile),
      meals: FakeMealRepository(),
      speech: speech,
    ));
    auth.signedIn();
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.newMealEntry));
    await tester.pumpAndSettle();

    // A Cook who does not read comfortably meets a screen that talks first.
    expect(speech.spoken, isNotEmpty);
    expect(speech.spoken.first.line, l10n.mealTalkOpening('other'));
  });

  testWidgets('the opening line is said once, not on every keystroke',
      (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.dispose);
    final speech = FakeSpeechOutput();

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: FakeKitchenProfileRepository(existing: _profile),
      meals: FakeMealRepository(),
      speech: speech,
    ));
    auth.signedIn();
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.newMealEntry));
    await tester.pumpAndSettle();

    final typeButton = find.byKey(const ValueKey('meal-talk-type'));
    await tester.ensureVisible(typeButton);
    await tester.pumpAndSettle();
    await tester.tap(typeButton);
    await tester.pumpAndSettle();

    final box = find.byKey(const ValueKey('meal-talk-box'));
    for (final partial in ['ك', 'كش', 'كشري']) {
      await tester.enterText(box, partial);
      await tester.pump();
    }

    // An assistant that repeats itself over her while she answers is worse
    // than one that never spoke.
    expect(
      speech.spoken
          .where((l) => l.line == l10n.mealTalkOpening('other'))
          .length,
      1,
    );
  });

  testWidgets('a Cook comes back to a half-finished Meal and sees her answers',
      (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.dispose);
    const half = CookMeal(
      id: 'half',
      cookId: 'c1',
      title: 'محشي ورق عنب',
      description: 'ورق عنب وأرز ولحمة مفرومة',
      status: MealStatus.draft,
      nutritionSource: NutritionSource.ai,
    );
    final meals = FakeMealRepository(meals: const [half]);

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: FakeKitchenProfileRepository(existing: _profile),
      meals: meals,
    ));
    auth.signedIn();
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.myMealsTitle).last);
    await tester.pumpAndSettle();

    // The row's actions live in a bottom sheet since the Meal list became
    // voice-first. The handover this test guards is unchanged; only the gesture
    // that reaches it.
    await tester.tap(find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.mealResumeDraft('other')));
    await tester.pumpAndSettle();

    // THE DEFECT THIS PINS: he saved a half-finished Meal, came back, and was
    // asked the first question again while every answer sat in the database.
    // The receipt is where those answers are now, so this is where it shows.
    expect(find.text('محشي ورق عنب'), findsWidgets);
    expect(find.byType(MealReceipt), findsOneWidget);
  });
}
