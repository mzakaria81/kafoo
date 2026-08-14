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
import 'package:kafoo_mobile/features/conversation/data/speech_output.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output_provider.dart';
import 'package:kafoo_mobile/features/meal/application/meal_conversation_controller.dart';
import 'package:kafoo_mobile/features/meal/application/meal_estimate_fields.dart';
import 'package:kafoo_mobile/features/meal/data/ai_provider.dart';
import 'package:kafoo_mobile/features/meal/data/meal_repository.dart';
import 'package:kafoo_mobile/features/meal/presentation/meal_conversation.dart';
import 'package:kafoo_mobile/features/meal/presentation/meal_receipt.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';
import 'package:kafoo_ui/ui.dart';

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

/// Voice available, listening, and recording WHEN it was stopped.
///
/// Exists for one test: that the microphone closes before the next question is
/// spoken. The ordering is the whole assertion, so both this and the speech fake
/// append to the same log.
class _ListeningVoiceInput extends VoiceInput {
  _ListeningVoiceInput(this.log);

  final List<String> log;
  bool _listening = false;

  @override
  Future<bool> initialize() async => true;

  @override
  bool get isAvailable => true;

  @override
  String? get resolvedLocaleId => 'ar-EG';

  @override
  bool get isListening => _listening;

  @override
  Future<void> listen({
    required void Function(String transcript, bool isFinal) onTranscript,
    Duration? pauseFor,
  }) async {
    _listening = true;
    // A partial transcript, the way a real recogniser delivers one: she is
    // mid-sentence and the words are already in the box.
    onTranscript('كشري', false);
  }

  @override
  Future<void> stop() async {
    _listening = false;
    log.add('microphone stopped');
  }

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

/// Throws instead of returning a [Failure], which is what the real transport
/// does and what no other double here models.
///
/// `client.functions.invoke` throws a `FunctionException` on every non-2xx
/// reply, so `analyze-meal` answering 500 — an unset provider key, a function
/// not deployed — arrives as an exception rather than the `Result` the interface
/// promises. Every double in this file returned a well-behaved `Failure`, so the
/// suite proved the controller handles failures it is TOLD about and nothing
/// about the failure it actually meets.
class _ThrowingAiProvider implements AiProvider {
  int calls = 0;

  @override
  Future<Result<AiResponse, AppError>> complete(AiRequest request) async {
    calls++;
    throw StateError(
        'the transport threw, as Supabase functions do on non-2xx');
  }
}

/// Minimal valid analysis JSON the parser accepts as non-empty.
const _analysisReply =
    '{"ingredients":["عدس","رز"],"calories":850,"allergens":["جلوتين"],'
    '"cuisine":"egyptian","category":"main",'
    '"basis":{"ingredients":"من وصف الطباخ","calories":"تقدير لطبق كامل",'
    '"allergens":"المكرونة فيها قمح","cuisine":"كشري مصري",'
    '"category":"طبق رئيسي"}}';

AiProvider _stubAi([String reply = '{}']) => StubAiProvider({
      'meal-analysis': reply,
    });

Widget _testApp(
  Widget child, {
  FakeMealRepository? repo,
  AiProvider? ai,
  SpeechOutput? speech,
}) {
  return ProviderScope(
    overrides: [
      if (repo != null) mealRepositoryProvider.overrideWithValue(repo),
      aiProviderProvider.overrideWithValue(ai ?? _stubAi()),
      // Recorded rather than spoken. Without this every test here leans on the
      // real engine's error handling to avoid reaching a paid provider, which
      // is isolation by accident rather than by design.
      speechOutputProvider.overrideWithValue(speech ?? FakeSpeechOutput()),
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
  setUpAll(() async {
    // Loaded so a failure here is a localization failure rather than a silent
    // fallback to English inside a widget test.
    await AppLocalizations.delegate.load(const Locale('ar'));
  });

  // SC-002: exactly one unanswered question on screen at any moment.
  // Walks all four steps (dish, description, photo, price) and asserts the
  // invariant holds at each one — then that no question remains when all are
  // answered.

  // Declining the photo must advance to the price step, not loop back to
  // asking for a photo again.

  // A createDraft failure must surface the localized error string and must
  // not crash the conversation.

  // When voice recognition is unavailable the conversation must still work
  // by typing — the likeliest real-world outcome on Egyptian handsets
  // (research.md §3).

  // The photo step is not reachable through the UI yet — supplying a photo is
  // T041 — so this drives the controller directly. Without it the rule below is
  // enforced and untested, which is the state a later cleanup quietly breaks.
  //
  // mealSteps() reads photoResolved, never photoPath. Recording a path without
  // resolving the step leaves the photo question unanswered, so the Cook who
  // just supplied a photograph is asked for one again, forever.

  // --- T034 -----------------------------------------------------------------

  test('later answers persist description and price via updateDraft', () async {
    final repo = FakeMealRepository();
    final container = _container(repo: repo);
    addTearDown(container.dispose);
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    await controller.correct(MealStepId.dish, 'كشري');
    await controller.correct(MealStepId.description, 'عدس ورز ومكرونة');
    controller.declinePhoto();
    await controller.correct(MealStepId.price, '50');

    expect(repo.createDraftCalls, 1);
    expect(repo.updateDraftCalls, 2);
    expect(repo.updateDraftArgs[0].description, 'عدس ورز ومكرونة');
    expect(repo.updateDraftArgs[0].price, isNull);
    expect(repo.updateDraftArgs[1].price, '50');
    expect(repo.updateDraftArgs[1].description, isNull);
  });

  group('the price as the Cook types it', () {
    // 2026-08-11: «١٢٠» from an Arabic keyboard reached a `numeric(10,2)` column
    // as that text and Postgres refused it. The Cook read «مقدرناش نحفظ الأكلة»
    // about a Meal that was fine. `parseMealPrice` holds the rule;
    // `packages/domain/test/meal_price_test.dart` covers its cases. These two
    // pin the two things the CONTROLLER owns: what it sends, and what it does
    // when the answer is not a price at all.

    test('Arabic-Indic digits reach the database as digits Postgres reads',
        () async {
      final repo = FakeMealRepository();
      final container = _container(repo: repo);
      addTearDown(container.dispose);
      final controller =
          container.read(mealConversationControllerProvider.notifier);

      await controller.correct(MealStepId.dish, 'كشري');
      controller.declinePhoto();
      final ok = await controller.correct(MealStepId.price, '١٢٠ جنيه');

      expect(ok, isTrue);
      expect(repo.updateDraftArgs.last.price, '120');
      // The same string in memory as in the row. Two representations of one
      // price is how a summary comes to disagree with what it summarises.
      expect(container.read(mealConversationControllerProvider).draft.price,
          '120');
    });

    test('an answer that is not a price is refused without a write', () async {
      final repo = FakeMealRepository();
      final container = _container(repo: repo);
      addTearDown(container.dispose);
      final controller =
          container.read(mealConversationControllerProvider.notifier);

      await controller.correct(MealStepId.dish, 'كشري');
      controller.declinePhoto();
      final ok = await controller.correct(MealStepId.price, 'مية وعشرين');

      expect(ok, isFalse);
      expect(
        repo.updateDraftArgs.where((c) => c.price != null),
        isEmpty,
        reason: 'Nothing is sent. The database would refuse it with a message '
            'the Cook cannot act on, so the refusal happens here instead.',
      );
      expect(
        container.read(mealConversationControllerProvider).error?.messageKey,
        'mealPriceInvalid',
        reason: 'NOT mealSaveError. She can fix this one, and only if the '
            'sentence tells her what to fix.',
      );
    });
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

    await controller.correct(MealStepId.dish, 'كشري');
    await controller.correct(MealStepId.description, 'عدس ورز');
    controller.declinePhoto();
    await controller.correct(MealStepId.price, '40');

    final drafted =
        events.where((e) => e.name == EventNames.mealDrafted).toList();
    expect(drafted, hasLength(1));
    expect(drafted.single.attributes, isEmpty);
  });

  // --- T035 -----------------------------------------------------------------

  test('analysis starts after description, not after dish alone', () async {
    final repo = FakeMealRepository();
    final ai = _DeferredAiProvider();
    final container = _container(repo: repo, ai: ai);
    addTearDown(container.dispose);
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    await controller.correct(MealStepId.dish, 'كشري');
    expect(ai.requests, isEmpty);
    expect(
      container.read(mealConversationControllerProvider).analysisInFlight,
      isFalse,
    );

    await controller.correct(MealStepId.description, 'عدس ورز ومكرونة');
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

  test('late reply from earlier analysis does not overwrite a newer one',
      () async {
    final repo = FakeMealRepository();
    final ai = _DeferredAiProvider();
    final container = _container(repo: repo, ai: ai);
    addTearDown(container.dispose);
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    await controller.correct(MealStepId.dish, 'كشري');
    await controller.correct(MealStepId.description, 'عدس ورز');
    expect(ai.completers, hasLength(1));

    // `{uid}/{mealId}.jpg` — the shape `SupabaseMealRepository.uploadPhoto`
    // builds and the only shape `meals.photo_path` ever holds. This literal used
    // to read `meal-photos/uid/id.jpg`, and `analyze-meal` required that form,
    // so both halves agreed on a format no upload produces and every analysis of
    // a Meal with a photograph was refused. 2026-08-11.
    await controller.correct(MealStepId.photo, 'uid/id.jpg');
    expect(ai.completers, hasLength(2));
    expect(ai.requests[1].variables['photo_path'], 'uid/id.jpg');

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

    await controller.correct(MealStepId.dish, 'كشري');
    await controller.correct(MealStepId.description, 'عدس ورز ومكرونة');
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

  // --- T036 -----------------------------------------------------------------

  test('no photo_path sent to AI when Cook declined the photo', () async {
    final repo = FakeMealRepository();
    final ai = _DeferredAiProvider();
    final container = _container(repo: repo, ai: ai);
    addTearDown(container.dispose);
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    await controller.correct(MealStepId.dish, 'كشري');
    await controller.correct(MealStepId.description, 'عدس ورز');

    // First analysis request (description) has no photo_path.
    expect(ai.requests, hasLength(1));
    expect(ai.requests.single.variables.containsKey('photo_path'), isFalse);

    // Decline photo — no second analysis request is made.
    controller.declinePhoto();
    expect(ai.requests, hasLength(1),
        reason: 'declining photo must not trigger a new analysis request');

    // Complete the conversation.
    final ok = await controller.correct(MealStepId.price, '50');
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

    // --- T043: Abandoned conversation leaves draft, nothing on offer ---------
  });

  // SC-002: exactly one unanswered question on screen at any moment.
  // Walks all four steps (dish, description, photo, price) and asserts the
  // invariant holds at each one — then that no question remains when all are
  // answered.

  // Declining the photo must advance to the price step, not loop back to
  // asking for a photo again.

  // A createDraft failure must surface the localized error string and must
  // not crash the conversation.

  // When voice recognition is unavailable the conversation must still work
  // by typing — the likeliest real-world outcome on Egyptian handsets
  // (research.md §3).

  // The photo step is not reachable through the UI yet — supplying a photo is
  // T041 — so this drives the controller directly. Without it the rule below is
  // enforced and untested, which is the state a later cleanup quietly breaks.
  //
  // mealSteps() reads photoResolved, never photoPath. Recording a path without
  // resolving the step leaves the photo question unanswered, so the Cook who
  // just supplied a photograph is asked for one again, forever.

  // --- T034 -----------------------------------------------------------------

  test('later answers persist description and price via updateDraft', () async {
    final repo = FakeMealRepository();
    final container = _container(repo: repo);
    addTearDown(container.dispose);
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    await controller.correct(MealStepId.dish, 'كشري');
    await controller.correct(MealStepId.description, 'عدس ورز ومكرونة');
    controller.declinePhoto();
    await controller.correct(MealStepId.price, '50');

    expect(repo.createDraftCalls, 1);
    expect(repo.updateDraftCalls, 2);
    expect(repo.updateDraftArgs[0].description, 'عدس ورز ومكرونة');
    expect(repo.updateDraftArgs[0].price, isNull);
    expect(repo.updateDraftArgs[1].price, '50');
    expect(repo.updateDraftArgs[1].description, isNull);
  });

  group('the price as the Cook types it', () {
    // 2026-08-11: «١٢٠» from an Arabic keyboard reached a `numeric(10,2)` column
    // as that text and Postgres refused it. The Cook read «مقدرناش نحفظ الأكلة»
    // about a Meal that was fine. `parseMealPrice` holds the rule;
    // `packages/domain/test/meal_price_test.dart` covers its cases. These two
    // pin the two things the CONTROLLER owns: what it sends, and what it does
    // when the answer is not a price at all.

    test('Arabic-Indic digits reach the database as digits Postgres reads',
        () async {
      final repo = FakeMealRepository();
      final container = _container(repo: repo);
      addTearDown(container.dispose);
      final controller =
          container.read(mealConversationControllerProvider.notifier);

      await controller.correct(MealStepId.dish, 'كشري');
      controller.declinePhoto();
      final ok = await controller.correct(MealStepId.price, '١٢٠ جنيه');

      expect(ok, isTrue);
      expect(repo.updateDraftArgs.last.price, '120');
      // The same string in memory as in the row. Two representations of one
      // price is how a summary comes to disagree with what it summarises.
      expect(container.read(mealConversationControllerProvider).draft.price,
          '120');
    });

    test('an answer that is not a price is refused without a write', () async {
      final repo = FakeMealRepository();
      final container = _container(repo: repo);
      addTearDown(container.dispose);
      final controller =
          container.read(mealConversationControllerProvider.notifier);

      await controller.correct(MealStepId.dish, 'كشري');
      controller.declinePhoto();
      final ok = await controller.correct(MealStepId.price, 'مية وعشرين');

      expect(ok, isFalse);
      expect(
        repo.updateDraftArgs.where((c) => c.price != null),
        isEmpty,
        reason: 'Nothing is sent. The database would refuse it with a message '
            'the Cook cannot act on, so the refusal happens here instead.',
      );
      expect(
        container.read(mealConversationControllerProvider).error?.messageKey,
        'mealPriceInvalid',
        reason: 'NOT mealSaveError. She can fix this one, and only if the '
            'sentence tells her what to fix.',
      );
    });
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

    await controller.correct(MealStepId.dish, 'كشري');
    await controller.correct(MealStepId.description, 'عدس ورز');
    controller.declinePhoto();
    await controller.correct(MealStepId.price, '40');

    final drafted =
        events.where((e) => e.name == EventNames.mealDrafted).toList();
    expect(drafted, hasLength(1));
    expect(drafted.single.attributes, isEmpty);
  });

  // --- T035 -----------------------------------------------------------------

  test('analysis starts after description, not after dish alone', () async {
    final repo = FakeMealRepository();
    final ai = _DeferredAiProvider();
    final container = _container(repo: repo, ai: ai);
    addTearDown(container.dispose);
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    await controller.correct(MealStepId.dish, 'كشري');
    expect(ai.requests, isEmpty);
    expect(
      container.read(mealConversationControllerProvider).analysisInFlight,
      isFalse,
    );

    await controller.correct(MealStepId.description, 'عدس ورز ومكرونة');
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

  test('late reply from earlier analysis does not overwrite a newer one',
      () async {
    final repo = FakeMealRepository();
    final ai = _DeferredAiProvider();
    final container = _container(repo: repo, ai: ai);
    addTearDown(container.dispose);
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    await controller.correct(MealStepId.dish, 'كشري');
    await controller.correct(MealStepId.description, 'عدس ورز');
    expect(ai.completers, hasLength(1));

    // `{uid}/{mealId}.jpg` — the shape `SupabaseMealRepository.uploadPhoto`
    // builds and the only shape `meals.photo_path` ever holds. This literal used
    // to read `meal-photos/uid/id.jpg`, and `analyze-meal` required that form,
    // so both halves agreed on a format no upload produces and every analysis of
    // a Meal with a photograph was refused. 2026-08-11.
    await controller.correct(MealStepId.photo, 'uid/id.jpg');
    expect(ai.completers, hasLength(2));
    expect(ai.requests[1].variables['photo_path'], 'uid/id.jpg');

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

    await controller.correct(MealStepId.dish, 'كشري');
    await controller.correct(MealStepId.description, 'عدس ورز ومكرونة');
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

  // --- T036 -----------------------------------------------------------------

  test('no photo_path sent to AI when Cook declined the photo', () async {
    final repo = FakeMealRepository();
    final ai = _DeferredAiProvider();
    final container = _container(repo: repo, ai: ai);
    addTearDown(container.dispose);
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    await controller.correct(MealStepId.dish, 'كشري');
    await controller.correct(MealStepId.description, 'عدس ورز');

    // First analysis request (description) has no photo_path.
    expect(ai.requests, hasLength(1));
    expect(ai.requests.single.variables.containsKey('photo_path'), isFalse);

    // Decline photo — no second analysis request is made.
    controller.declinePhoto();
    expect(ai.requests, hasLength(1),
        reason: 'declining photo must not trigger a new analysis request');

    // Complete the conversation.
    final ok = await controller.correct(MealStepId.price, '50');
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

    // --- T043: Abandoned conversation leaves draft, nothing on offer ---------
  });

  // --- T097: Resume a draft -------------------------------------------------

  group('T097: resume a draft', () {
    const _fullDraft = CookMeal(
      id: 'm-full',
      cookId: 'c1',
      title: 'كشري',
      description: 'عدس ورز ومكرونة',
      price: '40',
      cuisine: Cuisine.egyptian,
      category: MealCategory.main,
      status: MealStatus.draft,
      nutritionSource: NutritionSource.ai,
      ingredients: ['عدس', 'رز'],
      calories: 850,
      allergens: ['جلوتين'],
      photoPath: 'meal-photos/c1/m-full.jpg',
    );

    const _titleOnlyDraft = CookMeal(
      id: 'm-title',
      cookId: 'c1',
      title: 'ملوخية',
      status: MealStatus.draft,
      nutritionSource: NutritionSource.ai,
    );

    const _titleDescDraft = CookMeal(
      id: 'm-td',
      cookId: 'c1',
      title: 'فتة',
      description: 'فتة باللحمة',
      status: MealStatus.draft,
      nutritionSource: NutritionSource.ai,
    );

    test('resuming seeds every stored answer', () async {
      final repo = FakeMealRepository();
      final container = _container(repo: repo, ai: _stubAi('{}'));
      addTearDown(container.dispose);
      final controller =
          container.read(mealConversationControllerProvider.notifier);

      controller.resume(_fullDraft);

      final draft = container.read(mealConversationControllerProvider).draft;
      expect(draft.mealId, _fullDraft.id);
      expect(draft.title, _fullDraft.title);
      expect(draft.description, _fullDraft.description);
      expect(draft.price, _fullDraft.price);
      expect(draft.cuisine, _fullDraft.cuisine);
      expect(draft.category, _fullDraft.category);
      expect(draft.ingredients, _fullDraft.ingredients);
      expect(draft.calories, _fullDraft.calories);
      expect(draft.allergens, _fullDraft.allergens);
      expect(draft.photoPath, _fullDraft.photoPath);
      expect(draft.photoResolved, isTrue);
    });

    test('resuming does not carry over approvals or a previous analysis',
        () async {
      final repo = FakeMealRepository();
      final ai = _DeferredAiProvider();
      final container = _container(repo: repo, ai: ai);
      addTearDown(container.dispose);
      final controller =
          container.read(mealConversationControllerProvider.notifier);

      // Build up through the normal flow — analysis is in flight but not yet
      // completed.
      await controller.correct(MealStepId.dish, 'كشري');
      await controller.correct(MealStepId.description, 'عدس ورز');

      final inFlight = container.read(mealConversationControllerProvider);
      expect(inFlight.analysisInFlight, isTrue);
      expect(inFlight.analysis, isNull);

      // Manually set approvals and corrections as though a prior analysis had
      // landed and been approved.
      controller.state = inFlight.copyWith(
        approvals: {MealEstimateFields.cuisine: true},
        corrections: {MealEstimateFields.calories},
      );

      // Resume a different draft — clears everything.
      controller.resume(_titleOnlyDraft);

      final afterState = container.read(mealConversationControllerProvider);
      expect(afterState.approvals, isEmpty);
      expect(afterState.corrections, isEmpty);
      expect(afterState.analysis, isNull);
      expect(afterState.analysisError, isNull);
      expect(afterState.error, isNull);

      // Now let the old analysis complete — it must not overwrite the cleared
      // state because the request id has advanced.
      ai.completers[0].complete(
        const Success(AiResponse(text: _analysisReply, modelId: 'stale')),
      );
      await pumpEventQueue();

      final finalState = container.read(mealConversationControllerProvider);
      expect(finalState.analysis, isNull,
          reason: 'a stale analysis must not land after resume');
      expect(finalState.approvals, isEmpty);
    });

    test('resume refuses a Meal that is not a draft', () async {
      final repo = FakeMealRepository();
      final container = _container(repo: repo, ai: _stubAi('{}'));
      addTearDown(container.dispose);
      final controller =
          container.read(mealConversationControllerProvider.notifier);

      final beforeDraft =
          container.read(mealConversationControllerProvider).draft;

      // Published
      controller.resume(const CookMeal(
        id: 'm-pub',
        cookId: 'c1',
        title: 'كشري',
        description: 'عدس ورز',
        price: '35',
        cuisine: Cuisine.egyptian,
        category: MealCategory.main,
        status: MealStatus.published,
        nutritionSource: NutritionSource.ai,
      ));
      expect(
        container.read(mealConversationControllerProvider).draft.mealId,
        isNull,
        reason: 'published Meal must not seed the conversation',
      );
      expect(
        container.read(mealConversationControllerProvider).draft.mealId,
        beforeDraft.mealId,
        reason: 'state must be unchanged for a published Meal',
      );

      // Unavailable
      controller.resume(const CookMeal(
        id: 'm-unavail',
        cookId: 'c1',
        title: 'محشي',
        description: 'ورق عنب',
        price: '50',
        cuisine: Cuisine.egyptian,
        category: MealCategory.main,
        status: MealStatus.unavailable,
        nutritionSource: NutritionSource.ai,
      ));
      expect(
        container.read(mealConversationControllerProvider).draft.mealId,
        isNull,
        reason: 'unavailable Meal must not seed the conversation',
      );

      // Archived
      controller.resume(const CookMeal(
        id: 'm-arch',
        cookId: 'c1',
        title: 'فتة',
        description: 'فتة باللحمة',
        price: '60',
        cuisine: Cuisine.egyptian,
        category: MealCategory.main,
        status: MealStatus.archived,
        nutritionSource: NutritionSource.ai,
      ));
      expect(
        container.read(mealConversationControllerProvider).draft.mealId,
        isNull,
        reason: 'archived Meal must not seed the conversation',
      );
    });

    test('resuming a draft that has a description starts analysis', () async {
      final repo = FakeMealRepository();
      final ai = _DeferredAiProvider();
      final container = _container(repo: repo, ai: ai);
      addTearDown(container.dispose);
      final controller =
          container.read(mealConversationControllerProvider.notifier);

      controller.resume(_titleDescDraft);

      expect(ai.requests, hasLength(1));
      expect(ai.requests.single.promptId, 'meal-analysis');
      expect(
        container.read(mealConversationControllerProvider).analysisInFlight,
        isTrue,
      );
    });
  });

  // The clear that was not a clear.
  //
  // resume() asked copyWith to drop the previous Meal's analysis, and copyWith
  // read `analysis ?? this.analysis` — so passing null kept the old one. The
  // approvals beside it WERE cleared, which made the failure worse rather than
  // visible: the Cook would be shown another dish's suggested allergens as
  // estimates awaiting approval, and approving them writes those guesses onto
  // this Meal.
  //
  // Resumed with a draft that has NO description, because that is the case the
  // bug survived: with a description, resume starts a fresh analysis and the
  // stale one is overwritten before anyone could see it.
  test("resuming drops the previous Meal's estimates", () async {
    final repo = FakeMealRepository();
    final container = _container(repo: repo);
    addTearDown(container.dispose);
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    // A real analysis for one dish.
    await controller.correct(MealStepId.dish, 'ملوخية');
    await controller.correct(MealStepId.description, 'ملوخية بالفراخ');
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(mealConversationControllerProvider).analysis,
      isNotNull,
      reason: 'the test needs a stale analysis to exist before resuming',
    );

    // Now carry on with a different, barely-started draft.
    const titleOnlyDraft = CookMeal(
      id: 'draft-with-no-description',
      cookId: 'c1',
      title: 'كشري',
      status: MealStatus.draft,
      nutritionSource: NutritionSource.ai,
    );
    controller.resume(titleOnlyDraft);

    final state = container.read(mealConversationControllerProvider);
    expect(state.analysis, isNull);
    expect(state.approvals, isEmpty);
    expect(state.draft.mealId, 'draft-with-no-description');
  });

  // ───────────────────────────────────────────────────────────────────────────
  // ADR-0015: one conversation, not a questionnaire.
  //
  // The wizard tests these replaced asserted an ORDER — which question comes
  // after which. There is no order left to assert. What is worth asserting is
  // the boundary: what the assistant is allowed to write, what it must refuse,
  // and that a failed turn never costs the Cook her sentence.
  // ───────────────────────────────────────────────────────────────────────────
  group('ADR-0015: the open conversation', () {
    AiProvider talk(String reply) => StubAiProvider({'conversation': reply});

    test('what she said is written; what she did not say is not', () async {
      final repo = FakeMealRepository();
      final container = _container(
        repo: repo,
        ai: talk('{"say":"تمام، كشري.","captured":{"dish":"كشري"}}'),
      );
      addTearDown(container.dispose);
      final controller =
          container.read(mealConversationControllerProvider.notifier);

      await controller.hear('عملت كشري النهاردة');

      expect(repo.createdTitles, ['كشري']);
      final state = container.read(mealConversationControllerProvider);
      expect(state.draft.title, 'كشري');
      // Kafoo knows a Meal needs a cuisine. She did not say one, so it was not
      // written — an inferred cuisine reaches the draft only through the
      // estimate approval path, which is the whole AI write boundary.
      expect(state.draft.cuisine, isNull);
      expect(controller.missingFacts, contains(MealFact.cuisine));
    });

    test('the assistant answers a question without writing anything', () async {
      final repo = FakeMealRepository();
      final container = _container(
        repo: repo,
        ai: talk('{"say":"المحشي بيتباع كويس في الشتا.","captured":{}}'),
      );
      addTearDown(container.dispose);
      final controller =
          container.read(mealConversationControllerProvider.notifier);

      await controller.hear('إيه اللي تنفع أطبخه بكرة؟');

      // ADVICE IS NOT DATA. She asked what to cook, the assistant suggested
      // something, and no Meal came into being from a suggestion.
      expect(repo.createDraftCalls, 0);
      expect(repo.updateDraftCalls, 0);
      expect(
        container.read(mealConversationControllerProvider).lines.last,
        'المحشي بيتباع كويس في الشتا.',
      );
    });

    test(
        'a price the model writes in Arabic-Indic digits reaches the database '
        'as digits Postgres reads', () async {
      final repo = FakeMealRepository();
      final container = _container(
        repo: repo,
        ai: talk(
          '{"say":"تمام، بمية وعشرين.",'
          '"captured":{"dish":"كشري","price":"١٢٠"}}',
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(mealConversationControllerProvider.notifier)
          .hear('بمية وعشرين جنيه');

      final prices = repo.updateDraftArgs
          .map((c) => c.price)
          .where((p) => p != null)
          .toList();
      expect(prices, ['120']);
    });

    test('a reply with nothing to say is a failure, never a silent turn',
        () async {
      final repo = FakeMealRepository();
      final container = _container(repo: repo, ai: talk('{"captured":{}}'));
      addTearDown(container.dispose);
      final controller =
          container.read(mealConversationControllerProvider.notifier);

      final ok = await controller.hear('كشري');

      expect(ok, isFalse);
      final state = container.read(mealConversationControllerProvider);
      expect(state.lines, isEmpty);
      // «معلش، مافهمتش» — the app's fault, never hers.
      expect(state.error?.messageKey, 'aiConversationInvalid');
      expect(state.turnInFlight, isFalse);
    });

    test('a transport that THROWS does not leave the turn hanging', () async {
      final repo = FakeMealRepository();
      final container = _container(repo: repo, ai: _ThrowingAiProvider());
      addTearDown(container.dispose);
      final controller =
          container.read(mealConversationControllerProvider.notifier);

      final ok = await controller.hear('كشري');

      expect(ok, isFalse);
      final state = container.read(mealConversationControllerProvider);
      expect(state.turnInFlight, isFalse,
          reason: 'A stuck flag is a Cook staring at a screen that will never '
              'answer — the 2026-08-11 defect, arriving through the '
              'conversation instead of the estimates.');
      expect(state.error, isNotNull);
    });

    test('nothing a Cook says can publish a Meal', () async {
      final repo = FakeMealRepository();
      final container = _container(
        repo: repo,
        // The model doing the worst thing it could: claiming a publish.
        ai: talk('{"say":"تمام، نشرتها.","captured":{"dish":"كشري"}}'),
      );
      addTearDown(container.dispose);

      await container
          .read(mealConversationControllerProvider.notifier)
          .hear('انشريها دلوقتي وماتسأليش');

      // A SENTENCE IS NOT A PUBLISH. There is no path from `hear` to the
      // publish call — the gate is the only one, and it needs «أيوة».
      expect(repo.publishCalls, 0);
      expect(repo.existing?.status, isNot(MealStatus.published));
    });

    test('the missing set shrinks as she talks, and holds no order', () async {
      final repo = FakeMealRepository();
      final container = _container(
        repo: repo,
        ai: talk(
          '{"say":"تمام.","captured":{"dish":"كشري","price":"٥٠",'
          '"cuisine":"egyptian"}}',
        ),
      );
      addTearDown(container.dispose);
      final controller =
          container.read(mealConversationControllerProvider.notifier);

      expect(controller.missingFacts, hasLength(5));
      await controller.hear('كشري بخمسين، أكل مصري');
      expect(
        controller.missingFacts,
        equals({MealFact.description, MealFact.category}),
      );
    });
  });

  group('ADR-0015: the conversation screen', () {
    testWidgets(
        'the talk button is the screen, and typing is a choice she '
        'makes', (tester) async {
      final repo = FakeMealRepository();
      await tester.pumpWidget(_testApp(
        MealConversationScreen(voiceInput: _ListeningVoiceInput([])),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(KafooTalkButton), findsOneWidget);
      // §10.7 rung 3 falls back to TAPPING, never to typing. The box is not on
      // screen until she asks for it, so it can never be what the app offers
      // her after failing to understand.
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.byKey(const ValueKey('meal-talk-type')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets(
        'the orb is drawn on a handset with no Egyptian Arabic language '
        'pack', (tester) async {
      // THE DEFECT THE FOUNDER PHOTOGRAPHED ON 2026-08-14. The orb was hidden
      // behind `VoiceInput.initialize()` — the ON-DEVICE recogniser — which
      // returns false on the many Egyptian handsets that ship without an
      // `ar-EG` language pack. Nothing on this screen has listened on-device
      // since ADR-0017; the orb opens a hosted conversation that brings its own
      // recognition. So the one handset property that has nothing to do with
      // this control was deciding whether the control existed, and the voice
      // journey arrived as a form.
      final repo = FakeMealRepository();
      await tester.pumpWidget(_testApp(
        MealConversationScreen(voiceInput: _UnavailableVoiceInput()),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(KafooTalkButton), findsOneWidget);
      // And typing is still hers to ask for, not what the screen fell back to.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('the assistant opens the conversation and the line is spoken',
        (tester) async {
      final repo = FakeMealRepository();
      final speech = FakeSpeechOutput();
      await tester.pumpWidget(_testApp(
        MealConversationScreen(voiceInput: _ListeningVoiceInput([])),
        repo: repo,
        speech: speech,
      ));
      await tester.pumpAndSettle();

      // Rendered AND said. A line only on screen is invisible to the person
      // this product exists for.
      expect(find.byType(KafooSpokenBanner), findsOneWidget);
      expect(speech.spoken, isNotEmpty);
    });

    testWidgets('the receipt is present from the first turn', (tester) async {
      final repo = FakeMealRepository();
      await tester.pumpWidget(_testApp(
        MealConversationScreen(voiceInput: _ListeningVoiceInput([])),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      // It used to appear only once the questions ran out. It now sits under
      // the conversation from the start and fills in as she talks.
      expect(find.byType(MealReceipt), findsOneWidget);
    });
  });
}
