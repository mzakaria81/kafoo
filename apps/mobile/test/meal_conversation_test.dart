import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ai/ai.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/analytics/emit_event.dart';
import 'package:kafoo_mobile/features/analytics/event_names.dart';
import 'package:kafoo_mobile/features/conversation/application/voice_input.dart';
import 'package:kafoo_mobile/features/conversation/presentation/conversation_question.dart';
import 'package:kafoo_mobile/features/meal/application/meal_conversation_controller.dart';
import 'package:kafoo_mobile/features/meal/data/ai_provider.dart';
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

/// Voice available with Egyptian Arabic locale.
class _EgyptianVoiceInput extends VoiceInput {
  @override
  Future<bool> initialize() async => true;

  @override
  bool get isAvailable => true;

  @override
  String? get resolvedLocaleId => 'ar-EG';

  @override
  bool get isListening => false;

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

/// Completes only when a test releases each call — drives in-flight and race
/// cases that [StubAiProvider] cannot, because it answers immediately.
class _DeferredAiProvider implements AiProvider {
  final List<AiRequest> requests = [];
  final List<Completer<Result<AiResponse, AppError>>> completers = [];

  @override
  Future<Result<AiResponse, AppError>> complete(AiRequest request) {
    requests.add(request);
    final completer = Completer<Result<AiResponse, AppError>>();
    completers.add(completer);
    return completer.future;
  }
}

/// Minimal valid analysis JSON the parser accepts as non-empty.
const _analysisReply =
    '{"ingredients":["عدس","رز"],"calories":850,"allergens":["جلوتين"],'
    '"cuisine":"egyptian","category":"main",'
    '"basis":{"ingredients":"من وصف الكوك","calories":"تقدير لطبق كامل",'
    '"allergens":"المكرونة فيها قمح","cuisine":"كشري مصري",'
    '"category":"طبق رئيسي"}}';

AiProvider _stubAi([String reply = '{}']) => StubAiProvider({
      'meal-analysis': reply,
    });

Widget _testApp(
  Widget child, {
  FakeMealRepository? repo,
  AiProvider? ai,
}) {
  return ProviderScope(
    overrides: [
      if (repo != null) mealRepositoryProvider.overrideWithValue(repo),
      aiProviderProvider.overrideWithValue(ai ?? _stubAi()),
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

ProviderContainer _container({
  required FakeMealRepository repo,
  AiProvider? ai,
}) {
  final container = ProviderContainer(
    overrides: [
      mealRepositoryProvider.overrideWithValue(repo),
      aiProviderProvider.overrideWithValue(ai ?? _stubAi(_analysisReply)),
    ],
  );
  // Keep the autoDispose controller alive across async analysis completions.
  container.listen(mealConversationControllerProvider, (_, __) {});
  return container;
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
    expect(repo.updateDraftCalls, 2);
    expect(
      repo.updateDraftArgs.map((c) => c.description).whereType<String>(),
      ['عدس ورز ومكرونة'],
    );
    expect(
      repo.updateDraftArgs.map((c) => c.price).whereType<String>(),
      ['50'],
    );
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
    final container = _container(repo: repo);
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

  // --- T034 -----------------------------------------------------------------

  test('later answers persist description and price via updateDraft', () async {
    final repo = FakeMealRepository();
    final container = _container(repo: repo);
    addTearDown(container.dispose);
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    await controller.answer(MealStepId.dish, 'كشري');
    await controller.answer(MealStepId.description, 'عدس ورز ومكرونة');
    controller.declinePhoto();
    await controller.answer(MealStepId.price, '50');

    expect(repo.createDraftCalls, 1);
    expect(repo.updateDraftCalls, 2);
    expect(repo.updateDraftArgs[0].description, 'عدس ورز ومكرونة');
    expect(repo.updateDraftArgs[0].price, isNull);
    expect(repo.updateDraftArgs[1].price, '50');
    expect(repo.updateDraftArgs[1].description, isNull);
  });

  test('MealDrafted emits exactly once with no attributes', () async {
    final repo = FakeMealRepository();
    final events = <({String name, Map<String, Object> attributes})>[];
    debugEventRecorder = (name, attributes) {
      events.add((name: name, attributes: attributes));
    };
    addTearDown(() => debugEventRecorder = null);

    final container = _container(repo: repo);
    addTearDown(container.dispose);
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    await controller.answer(MealStepId.dish, 'كشري');
    await controller.answer(MealStepId.description, 'عدس ورز');
    controller.declinePhoto();
    await controller.answer(MealStepId.price, '40');

    final drafted =
        events.where((e) => e.name == EventNames.mealDrafted).toList();
    expect(drafted, hasLength(1));
    expect(drafted.single.attributes, isEmpty);
  });

  test('updateDraft failure surfaces error and does not advance the step',
      () async {
    final repo = FakeMealRepository();
    final container = _container(repo: repo);
    addTearDown(container.dispose);
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    await controller.answer(MealStepId.dish, 'كشري');
    expect(controller.currentStep?.id, MealStepId.description);

    repo.failOperations = true;
    final ok = await controller.answer(MealStepId.description, 'عدس ورز');

    expect(ok, isFalse);
    expect(controller.currentStep?.id, MealStepId.description);
    expect(
      container.read(mealConversationControllerProvider).error?.messageKey,
      'mealSaveError',
    );
    expect(
      container.read(mealConversationControllerProvider).draft.description,
      isNull,
    );
  });

  testWidgets(
      'updateDraft failure keeps typed answer and shows save error on screen',
      (tester) async {
    final repo = FakeMealRepository();
    await tester.pumpWidget(_testApp(
      MealConversationScreen(voiceInput: _UnavailableVoiceInput()),
      repo: repo,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'كشري');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    repo.failOperations = true;
    await tester.enterText(find.byType(TextField), 'عدس ورز ومكرونة');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealSaveError), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('عدس ورز ومكرونة'), findsOneWidget);
    expect(repo.updateDraftCalls, 1);
  });

  // --- T035 -----------------------------------------------------------------

  test('analysis starts after description, not after dish alone', () async {
    final repo = FakeMealRepository();
    final ai = _DeferredAiProvider();
    final container = _container(repo: repo, ai: ai);
    addTearDown(container.dispose);
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    await controller.answer(MealStepId.dish, 'كشري');
    expect(ai.requests, isEmpty);
    expect(
      container.read(mealConversationControllerProvider).analysisInFlight,
      isFalse,
    );

    await controller.answer(MealStepId.description, 'عدس ورز ومكرونة');
    expect(ai.requests, hasLength(1));
    expect(
      container.read(mealConversationControllerProvider).analysisInFlight,
      isTrue,
    );
    expect(ai.requests.single.promptId, 'meal-analysis');
    expect(ai.requests.single.tier, ModelTier.fast);
    expect(ai.requests.single.variables['said'], 'كشري. عدس ورز ومكرونة');
    expect(ai.requests.single.variables['meal_id'], repo.lastCreatedMealId);
    expect(ai.requests.single.variables.containsKey('photo_path'), isFalse);
  });

  test('Cook can keep answering while analysis is in flight', () async {
    final repo = FakeMealRepository();
    final ai = _DeferredAiProvider();
    final container = _container(repo: repo, ai: ai);
    addTearDown(container.dispose);
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    await controller.answer(MealStepId.dish, 'كشري');
    await controller.answer(MealStepId.description, 'عدس ورز');
    expect(
      container.read(mealConversationControllerProvider).analysisInFlight,
      isTrue,
    );

    // Analysis still pending — photo and price must still work.
    controller.declinePhoto();
    final priceOk = await controller.answer(MealStepId.price, '55');
    expect(priceOk, isTrue);
    expect(controller.currentStep, isNull);
    expect(repo.updateDraftArgs.last.price, '55');
    expect(
      container.read(mealConversationControllerProvider).analysisInFlight,
      isTrue,
    );
  });

  test('late reply from earlier analysis does not overwrite a newer one',
      () async {
    final repo = FakeMealRepository();
    final ai = _DeferredAiProvider();
    final container = _container(repo: repo, ai: ai);
    addTearDown(container.dispose);
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    await controller.answer(MealStepId.dish, 'كشري');
    await controller.answer(MealStepId.description, 'عدس ورز');
    expect(ai.completers, hasLength(1));

    await controller.answer(MealStepId.photo, 'meal-photos/uid/id.jpg');
    expect(ai.completers, hasLength(2));
    expect(ai.requests[1].variables['photo_path'], 'meal-photos/uid/id.jpg');

    const newerReply =
        '{"ingredients":["من الصورة"],"calories":900,"allergens":["جلوتين"],'
        '"cuisine":"egyptian","category":"main",'
        '"basis":{"ingredients":"شوفنا الصورة","calories":"أكبر",'
        '"allergens":"قمح","cuisine":"مصري","category":"رئيسي"}}';

    // Second (photo) analysis settles first.
    ai.completers[1].complete(
      const Success(AiResponse(text: newerReply, modelId: 'second')),
    );
    await pumpEventQueue();

    final afterNewer = container.read(mealConversationControllerProvider);
    expect(afterNewer.analysis?.modelId, 'second');
    expect(afterNewer.analysis?.ingredients?.value, ['من الصورة']);
    expect(afterNewer.analysisInFlight, isFalse);

    // First analysis lands late — must be dropped.
    ai.completers[0].complete(
      const Success(AiResponse(text: _analysisReply, modelId: 'first')),
    );
    await pumpEventQueue();

    final afterStale = container.read(mealConversationControllerProvider);
    expect(afterStale.analysis?.modelId, 'second');
    expect(afterStale.analysis?.ingredients?.value, ['من الصورة']);
  });

  test('analysis result is never written to the database', () async {
    final repo = FakeMealRepository();
    final container = _container(repo: repo, ai: _stubAi(_analysisReply));
    addTearDown(container.dispose);
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    await controller.answer(MealStepId.dish, 'كشري');
    await controller.answer(MealStepId.description, 'عدس ورز ومكرونة');
    await pumpEventQueue();

    final state = container.read(mealConversationControllerProvider);
    expect(state.analysis, isNotNull);
    expect(state.analysis!.isNotEmpty, isTrue);
    expect(state.analysisInFlight, isFalse);

    expect(repo.updateDraftArgs, isNotEmpty);
    for (final call in repo.updateDraftArgs) {
      expect(call.carriesAnalysedField, isFalse,
          reason: 'no analysed field may reach updateDraft');
    }
    expect(
      repo.updateDraftArgs.every((c) => c.cuisine == null),
      isTrue,
    );
    expect(
      repo.updateDraftArgs.every((c) => c.calories == null),
      isTrue,
    );
    expect(
      repo.updateDraftArgs.every((c) => c.allergens == null),
      isTrue,
    );
    expect(
      repo.updateDraftArgs.every((c) => c.ingredients == null),
      isTrue,
    );
    expect(
      repo.updateDraftArgs.every((c) => c.category == null),
      isTrue,
    );
  });

  test(
      'analysis failure leaves conversation usable and does not set save error',
      () async {
    final repo = FakeMealRepository();
    final ai = _DeferredAiProvider();
    final container = _container(repo: repo, ai: ai);
    addTearDown(container.dispose);
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    await controller.answer(MealStepId.dish, 'كشري');
    await controller.answer(MealStepId.description, 'عدس ورز');

    ai.completers.single.complete(
      const Failure(AppError(messageKey: 'analyzeMealTimeout')),
    );
    await pumpEventQueue();

    final state = container.read(mealConversationControllerProvider);
    expect(state.analysisError?.messageKey, 'analyzeMealTimeout');
    expect(state.error, isNull);
    expect(state.analysisInFlight, isFalse);
    expect(state.analysis, isNull);

    // Conversation still advances.
    controller.declinePhoto();
    final ok = await controller.answer(MealStepId.price, '60');
    expect(ok, isTrue);
    expect(controller.currentStep, isNull);
  });

  testWidgets('analysis failure does not show the save-error string on screen',
      (tester) async {
    final repo = FakeMealRepository();
    final ai = _DeferredAiProvider();
    await tester.pumpWidget(_testApp(
      MealConversationScreen(voiceInput: _UnavailableVoiceInput()),
      repo: repo,
      ai: ai,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'كشري');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'عدس ورز');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    ai.completers.single.complete(
      const Failure(AppError(messageKey: 'analyzeMealTimeout')),
    );
    await tester.pump();

    expect(find.text(l10n.mealSaveError), findsNothing);
    // Still on photo step — conversation usable.
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  // --- T036 -----------------------------------------------------------------

  testWidgets(
      'photo disclosure is on screen before the skip button at the photo step',
      (tester) async {
    final repo = FakeMealRepository();
    await tester.pumpWidget(_testApp(
      MealConversationScreen(voiceInput: _UnavailableVoiceInput()),
      repo: repo,
    ));
    await tester.pumpAndSettle();

    // Answer dish and description to reach the photo step.
    await tester.enterText(find.byType(TextField), 'كشري');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'عدس ورز');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // Disclosure is visible.
    expect(find.text(l10n.mealConvPhotoDisclosure), findsOneWidget);

    // Disclosure appears before the skip button in the widget tree — the first
    // Text with that string is an ancestor of a column whose later child is the
    // OutlinedButton (skip). Assert by finding both and checking that the
    // disclosure Text is hit-tested before the button.
    final disclosureFinder = find.text(l10n.mealConvPhotoDisclosure);
    final skipFinder = find.text(l10n.mealConvPhotoSkip);
    expect(disclosureFinder, findsOneWidget);
    expect(skipFinder, findsOneWidget);

    // The disclosure Text widget is positioned above the skip button: its
    // top-center is higher on screen than the button's top-center.
    final disclosureRect = tester.getRect(disclosureFinder);
    final skipRect = tester.getRect(skipFinder);
    expect(disclosureRect.top, lessThan(skipRect.top),
        reason: 'disclosure must appear above the skip control');
  });

  testWidgets('declining photo reaches price and completes the conversation',
      (tester) async {
    final repo = FakeMealRepository();
    await tester.pumpWidget(_testApp(
      MealConversationScreen(voiceInput: _UnavailableVoiceInput()),
      repo: repo,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'كشري');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'عدس ورز');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // Decline the photo.
    await tester.tap(find.text(l10n.mealConvPhotoSkip));
    await tester.pumpAndSettle();

    // Price step is on screen.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);

    // Answer price — conversation completes (no question left).
    await tester.enterText(find.byType(TextField), '50');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.byType(ConversationQuestion), findsNothing);
    expect(
        repo.updateDraftArgs.map((c) => c.price).whereType<String>(), ['50']);
  });

  test('declined photo still produces analysis from words alone', () async {
    final repo = FakeMealRepository();
    final container = _container(repo: repo, ai: _stubAi(_analysisReply));
    addTearDown(container.dispose);
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    await controller.answer(MealStepId.dish, 'كشري');
    await controller.answer(MealStepId.description, 'عدس ورز ومكرونة');
    await pumpEventQueue();

    // Analysis started after description, before photo was declined.
    expect(
      container.read(mealConversationControllerProvider).analysis,
      isNotNull,
      reason: 'analysis must exist even when photo is never supplied',
    );

    // Decline photo — analysis is not cleared.
    controller.declinePhoto();
    expect(
      container.read(mealConversationControllerProvider).analysis,
      isNotNull,
      reason: 'declining photo must not invalidate existing analysis',
    );

    // Complete the conversation.
    final ok = await controller.answer(MealStepId.price, '50');
    expect(ok, isTrue);
    expect(controller.currentStep, isNull);
  });

  test('no photo_path sent to AI when Cook declined the photo', () async {
    final repo = FakeMealRepository();
    final ai = _DeferredAiProvider();
    final container = _container(repo: repo, ai: ai);
    addTearDown(container.dispose);
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    await controller.answer(MealStepId.dish, 'كشري');
    await controller.answer(MealStepId.description, 'عدس ورز');

    // First analysis request (description) has no photo_path.
    expect(ai.requests, hasLength(1));
    expect(ai.requests.single.variables.containsKey('photo_path'), isFalse);

    // Decline photo — no second analysis request is made.
    controller.declinePhoto();
    expect(ai.requests, hasLength(1),
        reason: 'declining photo must not trigger a new analysis request');

    // Complete the conversation.
    final ok = await controller.answer(MealStepId.price, '50');
    expect(ok, isTrue);

    // Still only one request, and it never carried photo_path.
    expect(ai.requests, hasLength(1));
    expect(ai.requests.single.variables.containsKey('photo_path'), isFalse);
  });

  // --- T039: Meal conversation analytics -------------------------------------

  group('Meal conversation analytics (T039)', () {
    setUp(() {
      debugEventRecorder = (_, __) {};
    });
    tearDown(() => debugEventRecorder = null);

    testWidgets('ConversationStarted emitted once with voice available',
        (tester) async {
      final repo = FakeMealRepository();
      final events = <({String name, Map<String, Object> attributes})>[];
      debugEventRecorder = (name, attributes) {
        events.add((name: name, attributes: attributes));
      };

      await tester.pumpWidget(_testApp(
        MealConversationScreen(voiceInput: _EgyptianVoiceInput()),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      final started = events
          .where((e) => e.name == EventNames.conversationStarted)
          .toList();
      expect(started, hasLength(1));
      expect(started.single.attributes['kind'], 'meal');
      expect(started.single.attributes['input'], 'voice');
      expect(started.single.attributes['speech_locale'], 'ar-EG');
    });

    testWidgets('ConversationStarted carries typed/none when voice unavailable',
        (tester) async {
      final repo = FakeMealRepository();
      final events = <({String name, Map<String, Object> attributes})>[];
      debugEventRecorder = (name, attributes) {
        events.add((name: name, attributes: attributes));
      };

      await tester.pumpWidget(_testApp(
        MealConversationScreen(voiceInput: _UnavailableVoiceInput()),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      final started = events
          .where((e) => e.name == EventNames.conversationStarted)
          .toList();
      expect(started, hasLength(1));
      expect(started.single.attributes['kind'], 'meal');
      expect(started.single.attributes['input'], 'typed');
      expect(started.single.attributes['speech_locale'], 'none');
    });

    testWidgets(
        'ConversationStepCompleted emitted once per answered step with correct wire name',
        (tester) async {
      final repo = FakeMealRepository();
      final events = <({String name, Map<String, Object> attributes})>[];
      debugEventRecorder = (name, attributes) {
        events.add((name: name, attributes: attributes));
      };

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

      // Decline photo
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      // Answer price
      await tester.enterText(find.byType(TextField), '50');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      final completed = events
          .where((e) => e.name == EventNames.conversationStepCompleted)
          .toList();
      expect(completed, hasLength(4));
      expect(completed[0].attributes['step'], 'dish');
      expect(completed[1].attributes['step'], 'description');
      expect(completed[2].attributes['step'], 'photo');
      expect(completed[3].attributes['step'], 'price');
      expect(completed.every((e) => e.attributes['kind'] == 'meal'), isTrue);
    });

    testWidgets('declining photo emits ConversationStepCompleted',
        (tester) async {
      final repo = FakeMealRepository();
      final events = <({String name, Map<String, Object> attributes})>[];
      debugEventRecorder = (name, attributes) {
        events.add((name: name, attributes: attributes));
      };

      await tester.pumpWidget(_testApp(
        MealConversationScreen(voiceInput: _UnavailableVoiceInput()),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      // Reach photo step
      await tester.enterText(find.byType(TextField), 'كشري');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'عدس ورز');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Decline photo
      await tester.tap(find.text(l10n.mealConvPhotoSkip));
      await tester.pumpAndSettle();

      final photoEvents = events
          .where((e) =>
              e.name == EventNames.conversationStepCompleted &&
              e.attributes['step'] == 'photo')
          .toList();
      expect(photoEvents, hasLength(1));
      expect(photoEvents.single.attributes['input'], 'typed');
    });

    testWidgets('FR-037: no conversation event carries what the Cook typed',
        (tester) async {
      final repo = FakeMealRepository();
      final events = <({String name, Map<String, Object> attributes})>[];
      debugEventRecorder = (name, attributes) {
        events.add((name: name, attributes: attributes));
      };

      // Use distinctive values that would be easy to spot if leaked
      const dishAnswer = '🍲_SECRET_DISH_42';
      const descAnswer = '📝_SECRET_DESC_99';
      const priceAnswer = '🪙_SECRET_PRICE_77';

      await tester.pumpWidget(_testApp(
        MealConversationScreen(voiceInput: _UnavailableVoiceInput()),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), dishAnswer);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), descAnswer);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), priceAnswer);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      for (final event in events) {
        for (final value in event.attributes.values) {
          if (value is String) {
            expect(value.contains('SECRET_DISH'), isFalse,
                reason: '${event.name} leaked dish answer');
            expect(value.contains('SECRET_DESC'), isFalse,
                reason: '${event.name} leaked description answer');
            expect(value.contains('SECRET_PRICE'), isFalse,
                reason: '${event.name} leaked price answer');
          }
        }
      }
    });

    // --- T043: Abandoned conversation leaves draft, nothing on offer ---------

    testWidgets('T043: abandoned conversation leaves draft and never publishes',
        (tester) async {
      final repo = FakeMealRepository();
      final events = <({String name, Map<String, Object> attributes})>[];
      debugEventRecorder = (name, attributes) {
        events.add((name: name, attributes: attributes));
      };

      await tester.pumpWidget(_testApp(
        MealConversationScreen(voiceInput: _UnavailableVoiceInput()),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      // Answer dish and description only — then abandon
      await tester.enterText(find.byType(TextField), 'كشري');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'عدس ورز');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Do NOT answer photo or price — just leave

      // A draft was created
      expect(repo.createDraftCalls, 1);
      // Only description update (photo not yet reached)
      expect(repo.updateDraftCalls, 1);
      // Publish was NEVER called
      expect(repo.publishCalls, 0);

      // No MealPublished, no ConversationCompleted
      final published =
          events.where((e) => e.name == EventNames.mealPublished).toList();
      expect(published, isEmpty);
      final completed = events
          .where((e) => e.name == EventNames.conversationCompleted)
          .toList();
      expect(completed, isEmpty);
    });
  });
}
