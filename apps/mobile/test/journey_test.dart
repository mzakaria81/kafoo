import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ai/ai.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output_provider.dart';
import 'package:kafoo_mobile/features/discovery/data/discovery_repository.dart';
import 'package:kafoo_mobile/features/discovery/presentation/opened_meal.dart';
import 'package:kafoo_mobile/features/identity/presentation/change_phone_screen.dart';
import 'package:kafoo_mobile/features/identity/presentation/code_screen.dart';
import 'package:kafoo_mobile/features/identity/presentation/email_sign_in_screen.dart';
import 'package:kafoo_mobile/features/identity/presentation/remove_account_screen.dart';
import 'package:kafoo_mobile/features/identity/presentation/sign_in_screen.dart';
import 'package:kafoo_mobile/features/kitchen_profile/application/kitchen_conversation_controller.dart';
import 'package:kafoo_mobile/features/kitchen_profile/presentation/conversation.dart';
import 'package:kafoo_mobile/features/kitchen_profile/presentation/public_kitchen_view.dart';
import 'package:kafoo_mobile/features/meal/application/meal_conversation_controller.dart';
import 'package:kafoo_mobile/features/meal/application/meal_estimate_fields.dart';
import 'package:kafoo_mobile/features/meal/data/ai_provider.dart';
import 'package:kafoo_mobile/features/meal/data/meal_repository.dart';
import 'package:kafoo_mobile/features/meal/presentation/meal_conversation.dart';
import 'package:kafoo_mobile/features/meal/presentation/meal_edit_screen.dart';
import 'package:kafoo_mobile/features/meal/presentation/meal_receipt.dart';
import 'package:kafoo_mobile/features/meal/presentation/my_meals_screen.dart';
import 'package:kafoo_mobile/features/settings/presentation/settings_screen.dart';
import 'package:kafoo_mobile/home.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';
import 'package:kafoo_mobile/main.dart';
import 'package:kafoo_ui/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// One Meal of her own, so the signed-in home renders its loaded state.
const _hers = CookMeal(
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
        speechOutputProvider.overrideWithValue(
          // Two voices, so Settings renders the chooser the design draws. A
          // one-voice fake would make that screen's main section vanish and the
          // journey would pass over an empty page.
          speech ?? (FakeSpeechOutput()..hasVoiceChoice = true),
        ),
        discoveryRepositoryProvider.overrideWithValue(
          FakeDiscoveryRepository(onOffer: _onOffer),
        ),
        if (meals != null) mealRepositoryProvider.overrideWithValue(meals),
        // OVERRIDDEN AS WELL AS PASSED TO `KafooApp`, and both are needed. The
        // home reads its own copy to decide where the kitchen entry points; the
        // Kitchen Profile CONVERSATION reads the provider, because a controller
        // has no parent to be handed anything by. Overriding only one leaves the
        // conversation writing to a real Supabase from a widget test.
        kitchenProfileRepositoryProvider.overrideWithValue(kitchen),
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

  // WITHOUT THIS THE VOICE NEVER FINISHES STARTING UP, AND SILENTLY. The
  // assistant reads a stored mute preference on its first frame; with no mock
  // the platform channel throws, `AssistantVoice._start` never completes, and
  // every journey ran against a voice that reported itself not ready, could not
  // choose a voice, and drew its controls inert. Speaking still worked, which is
  // why nothing failed and nothing was true.
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
      // She has a Meal, so the home she lands on is the loaded list rather than
      // the invitation — the state the design package calls canonical.
      meals: FakeMealRepository(meals: const [_hers]),
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

    // 5. And she lands ON HER OWN MEALS — the design package's canonical
    //    screen — rather than on a menu of places she could go. The menu that
    //    used to be here was the 2026-08-14 redesign's starting point.
    expect(find.byType(SignedInHome), findsOneWidget);
    expect(find.text(l10n.myMealsTitle), findsOneWidget);
    expect(find.byType(KafooTalkButton), findsOneWidget);

    // 6. Everything the menu carried is one tap away, leaving included.
    //    SC-011 asks for no more steps than joining took, and joining was the
    //    five steps above.
    await tester.tap(find.byTooltip(l10n.accountEntry));
    await tester.pumpAndSettle();
    expect(find.text(l10n.kitchenViewTitle), findsOneWidget);
    expect(find.text(l10n.changePhoneEntry('other')), findsOneWidget);
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

    // She is already ON the empty list — it is the home now, so there is no
    // menu step between signing in and this button.
    await tester.tap(find.text(l10n.myMealsEmptyByHand('other')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealNeedsKitchenTitle), findsOneWidget);
    expect(find.text(l10n.myMealsEmptyInvitation), findsNothing);
  });

  testWidgets('the empty list\'s orb opens the conversation, not an apology',
      (tester) async {
    // THE 120dp ORB ON THE ONE SCREEN WHOSE PURPOSE IS TO INVITE SPEAKING was
    // drawn disabled reading «الكلام لسه مش شغال». So the first thing a Cook
    // with no Meals ever saw was the product saying its main idea did not work.
    final auth = _FakeAuth();
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: FakeKitchenProfileRepository(existing: _profile),
      meals: FakeMealRepository(),
    ));
    auth.signedIn();
    await tester.pumpAndSettle();

    expect(find.text(l10n.voiceNotReadyYet('other')), findsNothing);
    await tester.tap(find.byType(KafooTalkButton));
    await tester.pumpAndSettle();

    // Arrived at the conversation, and the invitation behind it is gone.
    expect(find.byType(MealConversationScreen), findsOneWidget);
    expect(find.text(l10n.myMealsEmptyInvitation), findsNothing);
  });

  testWidgets('the signed-in journey survives 200% text on a small phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // SET ON THE VIEW, NOT BY WRAPPING IN A `MediaQuery`. Replacing the whole
    // `MediaQueryData` to change one field zeroes the screen size inside it,
    // and anything sizing itself off that — the account sheet caps its height
    // at 90% of the screen — then lays out against nothing.
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final auth = _FakeAuth();
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: FakeKitchenProfileRepository(existing: _profile),
      meals: FakeMealRepository(meals: const [_hers]),
    ));
    auth.signedIn();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The orb is the control a Cook must never lose, and it is the last child
    // of a Column — the position a layout that cannot fit drops first.
    expect(find.byType(KafooTalkButton), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.accountEntry));
    await tester.pumpAndSettle();
    final leave = find.text(l10n.removeAccountEntry('other'));
    expect(leave, findsOneWidget);
    await tester.ensureVisible(leave);
    expect(tester.takeException(), isNull);
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

    // THE ORB, WHICH IS HOW A COOK STARTS A MEAL NOW. The «أكلة جديدة» menu
    // entry it replaced no longer exists — the Meal list is the home and the
    // orb owns the bottom of it.
    await tester.tap(find.byType(KafooTalkButton));
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

  testWidgets('a Cook publishes only after hearing the Meal read back',
      (tester) async {
    // THE WHOLE JOURNEY, END TO END, THROUGH THE STEP THAT WAS MISSING. Every
    // screen below had its own passing test and the transition between the
    // receipt and the gate did not exist — publishing was a plain button, so
    // the most irreversible act in the product had no read-back at all.
    final auth = _FakeAuth();
    addTearDown(auth.dispose);
    final meals = FakeMealRepository();
    final speech = FakeSpeechOutput();

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: FakeKitchenProfileRepository(existing: _profile),
      meals: meals,
      speech: speech,
      ai: StubAiProvider(const {
        'conversation': '{"say":"تمام، كشري بمية وعشرين.",'
            '"captured":{"dish":"كشري",'
            '"description":"عدس ورز ومكرونة، وبنحمر البصل فوقها",'
            '"price":"١٢٠","cuisine":"egyptian","category":"main"}}',
      }),
    ));
    auth.signedIn();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(KafooTalkButton));
    await tester.pumpAndSettle();

    final typeButton = find.byKey(const ValueKey('meal-talk-type'));
    await tester.ensureVisible(typeButton);
    await tester.pumpAndSettle();
    await tester.tap(typeButton);
    await tester.pumpAndSettle();

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

    // She skips the photo, which is a complete answer rather than a gap.
    final skipPhoto = _buttonOn(
      MealConversationScreen,
      l10n.mealConvPhotoSkip('other'),
    );
    await tester.ensureVisible(skipPhoto);
    await tester.pumpAndSettle();
    await tester.tap(skipPhoto);
    await tester.pumpAndSettle();

    // Every AI estimate approved through the receipt, because none of them may
    // reach the database without her.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MealReceipt)),
    );
    final controller =
        container.read(mealConversationControllerProvider.notifier);
    for (final field in MealEstimateFields.presentIn(
      container.read(mealConversationControllerProvider).analysis ??
          const MealAnalysis.empty(),
    )) {
      await controller.approveEstimate(field);
    }
    await tester.pumpAndSettle();

    final publish = _buttonOn(
      MealReceipt,
      l10n.mealSummaryConfirm('other'),
    );
    await tester.ensureVisible(publish);
    await tester.pumpAndSettle();
    await tester.tap(publish);
    await tester.pumpAndSettle();

    // THE STEP THAT DID NOT EXIST. The gate is on screen, it has said the whole
    // sentence out loud, and nothing is on offer yet.
    expect(find.byType(KafooConfirmationGate), findsOneWidget);
    expect(meals.publishCalls, 0);
    expect(
      speech.spoken.map((s) => s.line),
      contains(contains('كشري')),
      reason: 'The read-back is spoken, not merely drawn. A Cook who does not '
          'read comfortably cannot be asked to agree to something silent.',
    );

    await tester.tap(find.text(l10n.publishGateYes('other')));
    await tester.pumpAndSettle();

    // Only now.
    expect(meals.publishCalls, 1);
    expect(find.byType(KafooConfirmationGate), findsNothing);
    expect(find.text(l10n.mealPublishedConfirmation), findsOneWidget);
  });

  // ──────────────────────────────────────────────────────────────────────────
  // EVERY STEP BETWEEN TWO SCREENS, WALKED. Founder's instruction, 2026-08-14.
  //
  // This is the class of defect the whole file exists for: on 2026-08-10 five
  // reached his phone in a day and the last one is the shape to remember — the
  // code screen worked, the Cook home worked, and the step between them did not
  // exist. A widget test of each side proves both and proves nothing about the
  // step, so each journey below taps its way from one screen to the next and
  // asserts BOTH the arrival and the departure.
  // ──────────────────────────────────────────────────────────────────────────

  testWidgets('a new Cook talks her kitchen into being, in one conversation',
      (tester) async {
    // THE SECOND THING A NEW COOK EVER MEETS, AND IT WAS A FORM UNTIL
    // 2026-08-14. Five questions, one per screen, in a fixed order, with a
    // summary at the end. She signed in, was told the product talks to her, and
    // was handed a wizard.
    //
    // This walks the whole thing: no kitchen, press the orb, be told a kitchen
    // comes first, say everything in ONE sentence, hear it read back, and only
    // then does anything reach the database.
    final auth = _FakeAuth();
    addTearDown(auth.dispose);
    final kitchen = FakeKitchenProfileRepository();
    final speech = FakeSpeechOutput();

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: kitchen,
      meals: FakeMealRepository(),
      speech: speech,
      ai: StubAiProvider(const {
        'kitchen-conversation': '{"say":"تمام يا أم علي، مطبخ أم علي في '
            'المعادي.","captured":{'
            '"display_name":"مطبخ أم علي",'
            '"story":"بنطبخ أكل بيتي على الطريقة القديمة",'
            '"area":"المعادي",'
            '"delivery_terms":"بنوصّل في ساعة",'
            '"address_form":"feminine"}}',
      }),
    ));
    auth.signedIn();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(KafooTalkButton));
    await tester.pumpAndSettle();

    // FR-017: a kitchen comes before a Meal.
    expect(find.text(l10n.mealNeedsKitchenTitle), findsOneWidget);
    await tester.tap(find.text(l10n.mealNeedsKitchenAction('other')));
    await tester.pumpAndSettle();

    // And it opens SPEAKING, not asking question one of five.
    expect(find.byType(KitchenConversationScreen), findsOneWidget);
    expect(
      speech.spoken.map((s) => s.line),
      contains(l10n.kitchenTalkOpening('other')),
    );

    // Typing, because no recogniser exists in a widget test — and typing is a
    // complete alternative, so the journey has to work through it.
    final typeButton = find.byKey(const ValueKey('kitchen-talk-type'));
    await tester.ensureVisible(typeButton);
    await tester.pumpAndSettle();
    await tester.tap(typeButton);
    await tester.pumpAndSettle();

    final box = find.byKey(const ValueKey('kitchen-talk-box'));
    await tester.ensureVisible(box);
    await tester.pumpAndSettle();
    // ONE SENTENCE. The wizard needed five screens for this.
    await tester.enterText(
      box,
      'أنا أم علي من المعادي، بطبخ أكل بيتي وبوصّل في ساعة',
    );
    final send = find.descendant(
      of: find.byType(KitchenConversationScreen),
      matching: find.widgetWithText(FilledButton, l10n.kitchenTalkSend),
    );
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pumpAndSettle();

    // Everything landed on the receipt, and nothing landed in the database.
    expect(find.text('مطبخ أم علي'), findsOneWidget);
    expect(find.text('المعادي'), findsOneWidget);
    expect(kitchen.createCalls, 0);

    final create = find.byKey(const ValueKey('kitchen-create'));
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();

    // THE STEP THAT DID NOT EXIST. What she said is read back before it becomes
    // the page a Customer reads to decide whether to trust a stranger cooking
    // at home — so she hears it before anybody else does.
    expect(find.byType(KafooConfirmationGate), findsOneWidget);
    expect(kitchen.createCalls, 0);

    await tester.tap(find.text(l10n.kitchenGateYes('other')));
    await tester.pumpAndSettle();

    expect(kitchen.createCalls, 1);
    expect(kitchen.createdAddressForm, AddressForm.feminine);
    // And the conversation closed behind her, into the Meal she pressed the orb
    // for in the first place.
    expect(find.byType(KitchenConversationScreen), findsNothing);
  });

  testWidgets('the account sheet reaches the Kitchen Profile and comes back',
      (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: FakeKitchenProfileRepository(existing: _profile),
      meals: FakeMealRepository(meals: const [_hers]),
    ));
    auth.signedIn();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(l10n.accountEntry));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.kitchenViewTitle));
    await tester.pumpAndSettle();

    // Arrived on HER kitchen, and the sheet closed behind her — a sheet left
    // open sits above the screen it pushed and greets her again on the way
    // back.
    expect(find.text(_profile.displayName), findsWidgets);
    expect(find.byType(KafooSheet), findsNothing);

    // The app bar's own back, tapped rather than popped in code: `pageBack()`
    // hunts for a Cupertino chrome this app does not use.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // And back on her Meals, with the orb where she left it.
    expect(find.text(_hers.title!), findsOneWidget);
    expect(find.byType(KafooTalkButton), findsOneWidget);
  });

  testWidgets('the account sheet reaches changing the phone number',
      (tester) async {
    // FR-026: a lost or recycled number is recoverable rather than terminal.
    // It was one of the four Cook screens with no route into them on
    // 2026-08-10, so the step into it is the part worth pinning.
    final auth = _FakeAuth();
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: FakeKitchenProfileRepository(existing: _profile),
      meals: FakeMealRepository(meals: const [_hers]),
    ));
    auth.signedIn();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(l10n.accountEntry));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.changePhoneEntry('other')));
    await tester.pumpAndSettle();

    expect(find.byType(ChangePhoneScreen), findsOneWidget);
    expect(find.byType(KafooSheet), findsNothing);
  });

  testWidgets('leaving is reachable in one step and actually opens',
      (tester) async {
    // SC-011. The old home put «امسح حسابي» on the first screen; the redesign
    // put it in the account sheet, and the whole risk of that move is the sheet
    // becoming a place to bury it. So this walks the step rather than asserting
    // the label exists.
    final auth = _FakeAuth();
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: FakeKitchenProfileRepository(existing: _profile),
      meals: FakeMealRepository(meals: const [_hers]),
    ));
    auth.signedIn();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(l10n.accountEntry));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.removeAccountEntry('other')));
    await tester.pumpAndSettle();

    expect(find.byType(RemoveAccountScreen), findsOneWidget);
    expect(find.byType(KafooSheet), findsNothing);
  });

  testWidgets('a Cook with no kitchen is asked for one before a Meal',
      (tester) async {
    // FR-017. The orb is the first thing a brand-new Cook presses, and what it
    // must not do is drop her into a Meal she cannot publish.
    final auth = _FakeAuth();
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: FakeKitchenProfileRepository(),
      meals: FakeMealRepository(),
    ));
    auth.signedIn();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(KafooTalkButton));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealNeedsKitchenTitle), findsOneWidget);
    expect(find.text(l10n.myMealsEmptyInvitation), findsNothing);
  });

  testWidgets('the row menu reaches editing a Meal', (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: FakeKitchenProfileRepository(existing: _profile),
      meals: FakeMealRepository(meals: const [_hers]),
    ));
    auth.signedIn();
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(MyMealRow).first,
      matching: find.byIcon(Icons.more_horiz),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.mealEditTitle('other')));
    await tester.pumpAndSettle();

    expect(find.byType(MealEditScreen), findsOneWidget);
    expect(find.byType(KafooSheet), findsNothing);
  });

  testWidgets('a Customer opens a Meal and then the Kitchen behind it',
      (tester) async {
    // Two steps on the Customer side, neither of which any journey walked. The
    // second one matters most: the Kitchen is how a Customer decides whether to
    // trust a stranger cooking at home, and it sits two routes deep.
    final auth = _FakeAuth();
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: FakeKitchenProfileRepository(),
    ));
    auth.signedOut();
    await tester.pumpAndSettle();

    await tester.tap(find.text('كشري').first);
    await tester.pumpAndSettle();
    expect(find.byType(OpenedMeal), findsOneWidget);

    final openKitchen = find.text(l10n.publicMealOpenKitchen);
    await tester.ensureVisible(openKitchen);
    await tester.pumpAndSettle();
    await tester.tap(openKitchen);
    await tester.pumpAndSettle();

    expect(find.byType(PublicKitchenView), findsOneWidget);
    expect(find.text(_profile.displayName), findsWidgets);
  });

  testWidgets('browse reaches settings', (tester) async {
    // The one screen carrying the search-consent switch, so a Customer who
    // wants to turn search off has to be able to get there.
    final auth = _FakeAuth();
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: FakeKitchenProfileRepository(),
    ));
    auth.signedOut();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(l10n.settingsTitle));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    // AND THE VOICE CHOOSER IS ON IT. Kafoo bought two Cairene voices on
    // 2026-08-11 and no screen ever offered the choice, so every Cook heard
    // whichever one was the default — a feature finished in every layer except
    // the one a person can reach.
    expect(find.text(l10n.settingsVoiceFemale), findsWidgets);
    expect(find.text(l10n.settingsVoiceMale), findsWidgets);
  });

  testWidgets('sign-in offers the email way in when the phone will not do',
      (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.dispose);

    await tester.pumpWidget(_app(
      auth: auth.stream,
      account: FakeAccountRepository(),
      kitchen: FakeKitchenProfileRepository(),
    ));
    auth.signedOut();
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.browseSignInEntry));
    await tester.pumpAndSettle();

    final emailEntry = _buttonOn(SignInScreen, l10n.signInLostNumber('other'));
    await tester.ensureVisible(emailEntry);
    await tester.pumpAndSettle();
    await tester.tap(emailEntry);
    await tester.pumpAndSettle();

    expect(find.byType(EmailSignInScreen), findsOneWidget);
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

    // THE ORB, WHICH IS HOW A COOK STARTS A MEAL NOW. The «أكلة جديدة» menu
    // entry it replaced no longer exists — the Meal list is the home and the
    // orb owns the bottom of it.
    await tester.tap(find.byType(KafooTalkButton));
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
    // THE ORB, WHICH IS HOW A COOK STARTS A MEAL NOW. The «أكلة جديدة» menu
    // entry it replaced no longer exists — the Meal list is the home and the
    // orb owns the bottom of it.
    await tester.tap(find.byType(KafooTalkButton));
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
