import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/conversation/application/voice_input.dart';
import 'package:kafoo_mobile/features/conversation/presentation/conversation_question.dart';
import 'package:kafoo_mobile/features/meal/application/meal_conversation_controller.dart';
import 'package:kafoo_mobile/features/meal/data/meal_repository.dart';
import 'package:kafoo_mobile/features/meal/presentation/meal_conversation.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';

import 'support/fake_meal_repository.dart';

/// Recognition unavailable — the state a Cook on a handset with no `ar-EG`
/// engine lands in, and the one the conversation must survive by falling back
/// to typing.
class _UnavailableVoiceInput extends VoiceInput {
  @override
  Future<bool> initialize() async => false;

  @override
  bool get isAvailable => false;

  @override
  bool get isListening => false;

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

Widget _testApp(Widget child, {FakeMealRepository? repo}) {
  return ProviderScope(
    overrides: [
      if (repo != null) mealRepositoryProvider.overrideWithValue(repo),
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
}

void main() {
  // Asserting on a hand-typed substring of a localized string is how a test
  // passes in the wrong language, or fails when copy is reworded. Load the
  // real Arabic strings and assert against those.
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  // SC-002: exactly one unanswered question on screen at any moment.
  // Walks all four steps (dish, description, photo, price) and asserts the
  // invariant holds at each one — then that no question remains when all are
  // answered.
  testWidgets('no screen in the conversation shows two unanswered questions',
      (tester) async {
    final repo = FakeMealRepository();
    await tester.pumpWidget(_testApp(
      MealConversationScreen(voiceInput: _UnavailableVoiceInput()),
      repo: repo,
    ));
    await tester.pumpAndSettle();

    // Step 0: dish
    expect(find.byType(ConversationQuestion), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'كشري');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // Step 1: description
    expect(find.byType(ConversationQuestion), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'عدس ورز ومكرونة');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // Step 2: photo — no TextField, skip button instead
    expect(find.byType(ConversationQuestion), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(OutlinedButton), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();

    // Step 3: price
    expect(find.byType(ConversationQuestion), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '50');
    await tester.tap(find.byType(FilledButton));
    // pump, not pumpAndSettle: with every step answered the screen shows the
    // T037 placeholder spinner, which animates forever and never settles.
    await tester.pump();

    // All four answered — no question left on screen.
    expect(find.byType(ConversationQuestion), findsNothing);
    expect(repo.createDraftCalls, 1);
  });

  // Declining the photo must advance to the price step, not loop back to
  // asking for a photo again.
  testWidgets('declining photo advances to price rather than looping',
      (tester) async {
    final repo = FakeMealRepository();
    await tester.pumpWidget(_testApp(
      MealConversationScreen(voiceInput: _UnavailableVoiceInput()),
      repo: repo,
    ));
    await tester.pumpAndSettle();

    // Answer dish
    await tester.enterText(find.byType(TextField), 'كشري');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // Answer description
    await tester.enterText(find.byType(TextField), 'عدس ورز');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // Photo step: TextField absent, skip button present
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(OutlinedButton), findsOneWidget);

    // Decline the photo
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();

    // Price step: TextField back, skip button gone — NOT the photo step again
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  // A createDraft failure must surface the localized error string and must
  // not crash the conversation.
  testWidgets('createDraft failure surfaces localized error and does not crash',
      (tester) async {
    final repo = FakeMealRepository(failOperations: true);
    await tester.pumpWidget(_testApp(
      MealConversationScreen(voiceInput: _UnavailableVoiceInput()),
      repo: repo,
    ));
    await tester.pumpAndSettle();

    // Attempt the first answer — triggers createDraft, which fails.
    await tester.enterText(find.byType(TextField), 'كشري');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // The error message is visible and the conversation is still alive
    // (TextField still present so the Cook can retry).
    expect(find.text(l10n.mealSaveError), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(repo.createDraftCalls, 1);
  });

  // When voice recognition is unavailable the conversation must still work
  // by typing — the likeliest real-world outcome on Egyptian handsets
  // (research.md §3).
  testWidgets('voice unavailable still yields a working typing flow',
      (tester) async {
    final repo = FakeMealRepository();
    await tester.pumpWidget(_testApp(
      MealConversationScreen(voiceInput: _UnavailableVoiceInput()),
      repo: repo,
    ));
    await tester.pumpAndSettle();

    // Voice unavailable message is shown
    expect(find.text(l10n.convVoiceUnavailable), findsOneWidget);

    // But typing works and advances the conversation
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'كشري');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // Advanced to the description step
    expect(find.byType(ConversationQuestion), findsOneWidget);
    expect(repo.createDraftCalls, 1);
  });

  // The photo step is not reachable through the UI yet — supplying a photo is
  // T041 — so this drives the controller directly. Without it the rule below is
  // enforced and untested, which is the state a later cleanup quietly breaks.
  //
  // mealSteps() reads photoResolved, never photoPath. Recording a path without
  // resolving the step leaves the photo question unanswered, so the Cook who
  // just supplied a photograph is asked for one again, forever.
  test('supplying a photo resolves the photo step, not just the path',
      () async {
    final repo = FakeMealRepository();
    final container = ProviderContainer(
      overrides: [mealRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final controller =
        container.read(mealConversationControllerProvider.notifier);

    await controller.answer(MealStepId.dish, 'كشري');
    await controller.answer(MealStepId.description, 'عدس ورز ومكرونة');

    expect(controller.currentStep?.id, MealStepId.photo);

    await controller.answer(MealStepId.photo, 'meal-photos/uid/id.jpg');

    expect(controller.currentStep?.id, MealStepId.price,
        reason: 'a supplied photo must advance the conversation, not loop it');
  });
}
