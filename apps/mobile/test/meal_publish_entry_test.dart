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
import 'package:kafoo_mobile/features/meal/data/ai_provider.dart';
import 'package:kafoo_mobile/features/meal/data/meal_repository.dart';
import 'package:kafoo_mobile/features/meal/presentation/meal_publish_entry.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';

import 'support/fake_kitchen_profile_repository.dart';
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

Widget _testApp(
  Widget child, {
  FakeMealRepository? mealRepo,
  AiProvider? ai,
}) {
  return ProviderScope(
    overrides: [
      if (mealRepo != null) mealRepositoryProvider.overrideWithValue(mealRepo),
      if (ai != null) aiProviderProvider.overrideWithValue(ai),
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
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  // 1. No Kitchen Profile — the Cook is asked to make one, not asked about a
  //    Meal.
  testWidgets(
      'no kitchen profile shows the make-a-kitchen screen, not a Meal question',
      (tester) async {
    final kitchenRepo = FakeKitchenProfileRepository(existing: null);
    final mealRepo = FakeMealRepository();

    await tester.pumpWidget(_testApp(
      MealPublishEntry(
        kitchenProfileRepository: kitchenRepo,
        voiceInput: _UnavailableVoiceInput(),
      ),
      mealRepo: mealRepo,
    ));
    await tester.pumpAndSettle();

    // The body text asking the Cook to create a kitchen is on screen.
    expect(find.text(l10n.mealNeedsKitchenBody('other')), findsOneWidget);

    // No conversation question is rendered — the Meal has not started.
    expect(find.byType(ConversationQuestion), findsNothing);
  });

  // 2. No Kitchen Profile — nothing is written and nothing is emitted.
  testWidgets('no kitchen profile writes nothing and emits nothing',
      (tester) async {
    final kitchenRepo = FakeKitchenProfileRepository(existing: null);
    final mealRepo = FakeMealRepository();

    final events = <({String name, Map<String, Object> attributes})>[];
    debugEventRecorder = (name, attributes) {
      events.add((name: name, attributes: attributes));
    };
    addTearDown(() => debugEventRecorder = null);

    await tester.pumpWidget(_testApp(
      MealPublishEntry(
        kitchenProfileRepository: kitchenRepo,
        voiceInput: _UnavailableVoiceInput(),
      ),
      mealRepo: mealRepo,
    ));
    await tester.pumpAndSettle();

    // No draft was created.
    expect(mealRepo.createDraftCalls, 0);

    // No ConversationStarted was emitted — the conversation never began.
    final started =
        events.where((e) => e.name == EventNames.conversationStarted).toList();
    expect(started, isEmpty);
  });

  // 3. A Cook with a Kitchen Profile reaches the first question.
  testWidgets('Cook with a kitchen profile reaches the first Meal question',
      (tester) async {
    final kitchenRepo = FakeKitchenProfileRepository(
      existing: const KitchenProfile(
        id: 'kp-1',
        cookId: 'cook-1',
        displayName: 'مطبخ أم علي',
        story: 'أكل بيتي على الطريقة القديمة',
        area: 'المعادي',
        deliveryTerms: 'توصيل خلال ساعة',
      ),
    );
    final mealRepo = FakeMealRepository();

    await tester.pumpWidget(_testApp(
      MealPublishEntry(
        kitchenProfileRepository: kitchenRepo,
        voiceInput: _UnavailableVoiceInput(),
      ),
      mealRepo: mealRepo,
    ));
    await tester.pumpAndSettle();

    // The first conversation question is on screen.
    expect(find.byType(ConversationQuestion), findsOneWidget);

    // The "make a kitchen" body is NOT on screen.
    expect(find.text(l10n.mealNeedsKitchenBody('other')), findsNothing);
  });

  // 4. A failed check does not send the Cook to make a second kitchen.
  testWidgets('failed check shows error, not the make-a-kitchen screen',
      (tester) async {
    final kitchenRepo = FakeKitchenProfileRepository(failFindMine: true);
    final mealRepo = FakeMealRepository();

    await tester.pumpWidget(_testApp(
      MealPublishEntry(
        kitchenProfileRepository: kitchenRepo,
        voiceInput: _UnavailableVoiceInput(),
      ),
      mealRepo: mealRepo,
    ));
    await tester.pumpAndSettle();

    // The check-failed error is on screen.
    expect(find.text(l10n.mealKitchenCheckError('other')), findsOneWidget);

    // The "make a kitchen" body is NOT on screen — a failed check is not
    // treated as "no kitchen".
    expect(find.text(l10n.mealNeedsKitchenBody('other')), findsNothing);
  });
}
