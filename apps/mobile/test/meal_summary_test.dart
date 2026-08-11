import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ai/ai.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/analytics/emit_event.dart';
import 'package:kafoo_mobile/features/analytics/event_names.dart';
import 'package:kafoo_mobile/features/conversation/application/voice_input.dart';
import 'package:kafoo_mobile/features/meal/application/meal_conversation_controller.dart';
import 'package:kafoo_mobile/features/meal/application/meal_estimate_fields.dart';
import 'package:kafoo_mobile/features/meal/data/ai_provider.dart';
import 'package:kafoo_mobile/features/meal/data/meal_repository.dart';
import 'package:kafoo_mobile/features/meal/presentation/meal_conversation.dart';
import 'package:kafoo_mobile/features/meal/presentation/meal_estimate_rows.dart';
import 'package:kafoo_mobile/features/meal/presentation/meal_summary.dart';
import 'package:kafoo_mobile/features/meal/presentation/meal_summary_rows.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';

import 'support/fake_meal_repository.dart';

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

const _dish = 'كشري';
const _description = 'عدس ورز ومكرونة';
const _price = '50';

/// Full analysis the parser accepts — five estimates with basis sentences.
const _fullAnalysisReply =
    '{"ingredients":["عدس","رز","مكرونة"],"calories":850,"allergens":["جلوتين"],'
    '"cuisine":"egyptian","category":"main",'
    '"basis":{"ingredients":"من وصف الطباخ","calories":"تقدير لطبق كامل",'
    '"allergens":"المكرونة فيها قمح","cuisine":"كشري مصري",'
    '"category":"طبق رئيسي"}}';

/// Same as full, but no allergens — that estimate must not be required.
const _noAllergensReply = '{"ingredients":["عدس","رز"],"calories":850,'
    '"cuisine":"egyptian","category":"main",'
    '"basis":{"ingredients":"من وصف الطباخ","calories":"تقدير لطبق كامل",'
    '"cuisine":"كشري مصري","category":"طبق رئيسي"}}';

/// Parse the JSON analysis fixture so tests read values from it, never retype.
Map<String, Object?> _parseAnalysis(String json) =>
    jsonDecode(json) as Map<String, Object?>;

AiProvider _stubAi([String? reply]) => StubAiProvider({
      if (reply != null) 'meal-analysis': reply,
    });

Widget _app(FakeMealRepository repo, {AiProvider? ai}) => ProviderScope(
      overrides: [
        mealRepositoryProvider.overrideWithValue(repo),
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
        home: MealConversationScreen(voiceInput: _UnavailableVoiceInput()),
      ),
    );

/// Walks the whole conversation, so the summary is reached the way a Cook
/// reaches it. When the analysis left cuisine/category blank, answers the
/// fallback questions so the summary is actually on screen.
Future<void> _reachSummary(
  WidgetTester tester,
  FakeMealRepository repo, {
  AiProvider? ai,
  AppLocalizations? l10n,
}) async {
  await tester.pumpWidget(_app(repo, ai: ai));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), _dish);
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), _description);
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();

  // Decline the photo — supplying one is T041.
  await tester.tap(find.byType(OutlinedButton));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), _price);
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();

  // Fallback path (T096): analysis missing cuisine/category.
  if (l10n != null &&
      find.text(l10n.mealConvPromptCuisine).evaluate().isNotEmpty) {
    final choice = find.widgetWithText(OutlinedButton, l10n.cuisineEgyptian);
    await tester.ensureVisible(choice);
    await tester.pumpAndSettle();
    await tester.tap(choice);
    await tester.pumpAndSettle();
  }
  if (l10n != null &&
      find.text(l10n.mealConvPromptCategory).evaluate().isNotEmpty) {
    final choice = find.widgetWithText(OutlinedButton, l10n.categoryMain);
    await tester.ensureVisible(choice);
    await tester.pumpAndSettle();
    await tester.tap(choice);
    await tester.pumpAndSettle();
  }
}

Finder _rowFor(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(SummaryRow),
    );

Finder _estimateRowFor(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(EstimateRow),
    );

/// Tap Change on a Cook-answer row, type a value, confirm it.
Future<void> _correct(
  WidgetTester tester,
  String label,
  String value,
) async {
  await tester.tap(
    find.descendant(of: _rowFor(label), matching: find.byType(TextButton)),
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), value);
  await tester.tap(find.byType(IconButton));
  await tester.pumpAndSettle();
}

/// Approves every estimate currently on screen, scrolling each into view.
Future<void> _approveAllEstimates(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  var guard = 0;
  while (find
          .widgetWithText(TextButton, l10n.mealSummaryApprove)
          .evaluate()
          .isNotEmpty &&
      guard < 10) {
    final button =
        find.widgetWithText(TextButton, l10n.mealSummaryApprove).first;
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    guard++;
  }
}

/// Approves every produced estimate through the controller.
///
/// Prefer this when the test is about publishing, not about the approve
/// control itself — the summary is taller than the default test surface.
Future<void> _approveAllViaController(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MealSummaryScreen)),
  );
  final controller =
      container.read(mealConversationControllerProvider.notifier);
  final analysis = container.read(mealConversationControllerProvider).analysis;
  expect(analysis, isNotNull);
  for (final field in MealEstimateFields.presentIn(analysis!)) {
    final ok = await controller.approveEstimate(field);
    expect(ok, isTrue, reason: 'approveEstimate($field) must succeed');
  }
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  setUp(() {
    debugEventRecorder = null;
  });

  tearDown(() {
    debugEventRecorder = null;
  });

  // The estimate section makes the summary taller than the default 600px
  // surface. A missed ensureVisible looks like a logic bug.
  Future<void> _tallSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('the summary shows every answer the Cook gave', (tester) async {
    final repo = FakeMealRepository();
    await _reachSummary(tester, repo, l10n: l10n);

    expect(find.byType(MealSummaryScreen), findsOneWidget);
    expect(find.text(l10n.mealSummaryTitle), findsOneWidget);
    expect(find.text(_dish), findsOneWidget);
    expect(find.text(_description), findsOneWidget);
    expect(find.text(_price), findsOneWidget);
  });

  testWidgets('a declined photo reads as a choice, not an empty row',
      (tester) async {
    final repo = FakeMealRepository();
    await _reachSummary(tester, repo, l10n: l10n);

    expect(find.text(l10n.mealSummaryNoPhoto), findsOneWidget);
  });

  // SC-004: every value is correctable in EXACTLY one action. That the control
  // exists is not the requirement — the count of taps to reach editing is.
  testWidgets('each value is one tap from being editable (SC-004)',
      (tester) async {
    final repo = FakeMealRepository();
    await _reachSummary(tester, repo, l10n: l10n);

    // Three editable Cook-answer rows (dish/description/price). Fallback
    // cuisine/category are display-only — they are not free text.
    expect(find.byType(SummaryRow), findsNWidgets(5));
    expect(find.byType(PhotoRow), findsOneWidget);

    expect(find.byType(TextField), findsNothing);
    await tester.tap(
      find.descendant(
        of: _rowFor(l10n.mealSummaryLabelDish),
        matching: find.widgetWithText(TextButton, l10n.convEdit('other')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('correcting the dish persists it', (tester) async {
    final repo = FakeMealRepository();
    await _reachSummary(tester, repo, l10n: l10n);
    final before = repo.updateDraftCalls;

    await _correct(tester, l10n.mealSummaryLabelDish, 'كشري بالعدس');

    expect(repo.updateDraftCalls, before + 1);
    expect(repo.updateDraftArgs.last.title, 'كشري بالعدس');
    expect(find.text('كشري بالعدس'), findsOneWidget);
  });

  testWidgets('correcting the description persists it', (tester) async {
    final repo = FakeMealRepository();
    await _reachSummary(tester, repo, l10n: l10n);
    final before = repo.updateDraftCalls;

    await _correct(tester, l10n.mealSummaryLabelDescription, 'عدس ورز وبصل');

    expect(repo.updateDraftCalls, before + 1);
    expect(repo.updateDraftArgs.last.description, 'عدس ورز وبصل');
  });

  testWidgets('correcting the price persists it', (tester) async {
    final repo = FakeMealRepository();
    await _reachSummary(tester, repo, l10n: l10n);
    final before = repo.updateDraftCalls;

    await _correct(tester, l10n.mealSummaryLabelPrice, '65');

    expect(repo.updateDraftCalls, before + 1);
    expect(repo.updateDraftArgs.last.price, '65');
    expect(find.text('65'), findsOneWidget);
  });

  // The defect this file exists downstream of. The first version of the summary
  // kept its own copies of the answers and wrote corrections straight to the
  // repository, leaving the controller holding the values the Cook had just
  // replaced. Nothing looked wrong — until T038 publishes from the controller
  // and ships the uncorrected Meal.
  testWidgets('a correction reaches the controller, not only the database',
      (tester) async {
    final repo = FakeMealRepository();
    await _reachSummary(tester, repo, l10n: l10n);

    await _correct(tester, l10n.mealSummaryLabelPrice, '65');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MealSummaryScreen)),
    );
    expect(
      container.read(mealConversationControllerProvider).draft.price,
      '65',
      reason: 'the controller owns the draft, and T038 publishes from it',
    );
  });

  // Reaching the summary never auto-publishes — the Cook must confirm.
  testWidgets('reaching the summary puts nothing on offer', (tester) async {
    await _tallSurface(tester);
    final repo = FakeMealRepository();
    await _reachSummary(tester, repo, l10n: l10n);

    expect(repo.publishCalls, 0);
    expect(find.byType(MealSummaryScreen), findsOneWidget);
    expect(find.text(l10n.mealSummaryNoEstimates('other')), findsOneWidget);

    // Confirm is now ENABLED, and that is the point of T096: before the
    // fallback questions existed this assertion was `isNull`, because a Meal
    // with no cuisine and no category could not go on offer at all. It is
    // enabled because the Cook supplied both, not because a default was
    // invented — and it is still the Cook's tap that publishes, which is why
    // publishCalls is asserted on either side of it (FR-014, SC-005).
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l10n.mealSummaryConfirm('other')),
    );
    expect(button.onPressed, isNotNull,
        reason: 'a Cook who answered the fallback questions can publish');

    expect(repo.publishCalls, 0);
  });

  // FR-005 makes a value correctable, not erasable. An empty correction is a
  // slip, so it closes the row and keeps what was there.
  testWidgets('an empty correction writes nothing and keeps the value',
      (tester) async {
    final repo = FakeMealRepository();
    await _reachSummary(tester, repo, l10n: l10n);
    final before = repo.updateDraftCalls;

    await tester.tap(
      find.descendant(
        of: _rowFor(l10n.mealSummaryLabelPrice),
        matching: find.byType(TextButton),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(repo.updateDraftCalls, before);
    expect(find.text(_price), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  // --- Estimates and publishing (T038 + estimate half of T045/US2) ------------

  testWidgets('every estimate shows its badge and its basis sentence (FR-013)',
      (tester) async {
    await _tallSurface(tester);
    final repo = FakeMealRepository();
    await _reachSummary(
      tester,
      repo,
      ai: _stubAi(_fullAnalysisReply),
    );

    expect(find.text(l10n.mealSummaryEstimatesTitle), findsOneWidget);
    expect(find.text(l10n.mealSummaryEstimatesNotice('other')), findsOneWidget);

    // Five estimates, each with the badge while unapproved.
    expect(find.text(l10n.mealSummaryEstimateBadge), findsNWidgets(5));
    expect(find.byType(EstimateRow), findsNWidgets(5));

    // Basis sentences on screen — a value without its reason fails FR-013.
    // "طبق رئيسي" is both the category display name and its basis in this
    // fixture, so assert the unique basis strings and that the category row
    // carries the shared phrase at least once.
    expect(find.text('كشري مصري'), findsOneWidget);
    expect(find.text('من وصف الطباخ'), findsOneWidget);
    expect(find.text('تقدير لطبق كامل'), findsOneWidget);
    expect(find.text('المكرونة فيها قمح'), findsOneWidget);
    expect(find.text('طبق رئيسي'), findsWidgets);

    // Localized enum values, never wire identifiers.
    expect(find.text(l10n.cuisineEgyptian), findsOneWidget);
    expect(find.text(l10n.categoryMain), findsWidgets);
    expect(find.text(l10n.mealSummaryCaloriesValue(850)), findsOneWidget);
    expect(find.text('egyptian'), findsNothing);
    expect(find.text('main'), findsNothing);
  });

  testWidgets('publishing is refused while any estimate is unapproved',
      (tester) async {
    await _tallSurface(tester);
    final repo = FakeMealRepository();
    await _reachSummary(
      tester,
      repo,
      ai: _stubAi(_fullAnalysisReply),
    );

    expect(find.text(l10n.mealSummaryNeedsApproval), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l10n.mealSummaryConfirm('other')),
    );
    expect(button.onPressed, isNull);

    // Disabled control — assert the repository saw nothing.
    expect(repo.publishCalls, 0);
  });

  testWidgets(
      'approving every estimate enables publishing once and emits MealPublished',
      (tester) async {
    await _tallSurface(tester);
    final repo = FakeMealRepository();
    final events = <({String name, Map<String, Object> attributes})>[];
    debugEventRecorder = (name, attributes) {
      events.add((name: name, attributes: attributes));
    };

    await _reachSummary(
      tester,
      repo,
      ai: _stubAi(_fullAnalysisReply),
    );

    // Nothing AI-derived reached the repository during the conversation.
    expect(
      repo.updateDraftArgs.where((c) => c.carriesAnalysedField),
      isEmpty,
      reason: 'AI values must not reach the database before approval',
    );

    // UI path: each approve is a real tap.
    await _approveAllEstimates(tester, l10n);

    expect(find.text(l10n.mealSummaryNeedsApproval), findsNothing);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l10n.mealSummaryConfirm('other')),
    );
    expect(button.onPressed, isNotNull);

    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, l10n.mealSummaryConfirm('other')),
    );

    expect(repo.publishCalls, 1);
    expect(repo.lastPublishedMealId, isNotNull);
    expect(find.text(l10n.mealPublishedConfirmation), findsOneWidget);

    final published =
        events.where((e) => e.name == EventNames.mealPublished).toList();
    expect(published, hasLength(1));
    expect(published.single.attributes, isEmpty);
  });

  testWidgets('editing an estimate counts as approving it', (tester) async {
    await _tallSurface(tester);
    final repo = FakeMealRepository();
    await _reachSummary(
      tester,
      repo,
      ai: _stubAi(_fullAnalysisReply),
    );

    // Approve everything except calories via the controller, then edit calories.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MealSummaryScreen)),
    );
    final controller =
        container.read(mealConversationControllerProvider.notifier);
    for (final field in [
      MealEstimateFields.cuisine,
      MealEstimateFields.category,
      MealEstimateFields.ingredients,
      MealEstimateFields.allergens,
    ]) {
      expect(await controller.approveEstimate(field), isTrue);
    }
    await tester.pumpAndSettle();

    // Still blocked — calories unapproved.
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, l10n.mealSummaryConfirm('other')),
          )
          .onPressed,
      isNull,
    );

    await _tapVisible(
      tester,
      find.descendant(
        of: _estimateRowFor(l10n.mealSummaryLabelCalories),
        matching: find.widgetWithText(TextButton, l10n.convEdit('other')),
      ),
    );
    await tester.enterText(find.byType(TextField), '900');
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(
      repo.updateDraftArgs.where((c) => c.calories == 900),
      isNotEmpty,
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l10n.mealSummaryConfirm('other')),
    );
    expect(button.onPressed, isNotNull,
        reason: 'editing calories must count as approving it');
  });

  testWidgets('an estimate the analysis did not produce is not required',
      (tester) async {
    await _tallSurface(tester);
    final repo = FakeMealRepository();
    await _reachSummary(
      tester,
      repo,
      ai: _stubAi(_noAllergensReply),
    );

    expect(find.text(l10n.mealSummaryLabelAllergens), findsNothing);
    expect(find.byType(EstimateRow), findsNWidgets(4));

    await _approveAllViaController(tester);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l10n.mealSummaryConfirm('other')),
    );
    expect(button.onPressed, isNotNull,
        reason: 'missing allergens must not block publishing');
  });

  testWidgets(
      'a failed publish shows the error and does not emit MealPublished',
      (tester) async {
    await _tallSurface(tester);
    final repo = FakeMealRepository();
    final events = <({String name, Map<String, Object> attributes})>[];
    debugEventRecorder = (name, attributes) {
      events.add((name: name, attributes: attributes));
    };

    await _reachSummary(
      tester,
      repo,
      ai: _stubAi(_fullAnalysisReply),
    );
    await _approveAllViaController(tester);

    repo.failOperations = true;

    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, l10n.mealSummaryConfirm('other')),
    );

    expect(find.text(l10n.mealPublishError('other')), findsOneWidget);
    expect(find.text(l10n.mealPublishedConfirmation), findsNothing);
    expect(
      events.where((e) => e.name == EventNames.mealPublished),
      isEmpty,
    );
    // Fake still counts the attempt; the Meal must not look published.
    expect(repo.publishCalls, 1);
    expect(find.widgetWithText(FilledButton, l10n.mealSummaryConfirm('other')),
        findsOneWidget);
  });

  testWidgets(
      'approving writes that value through updateDraft, and nothing before',
      (tester) async {
    await _tallSurface(tester);
    final repo = FakeMealRepository();
    await _reachSummary(
      tester,
      repo,
      ai: _stubAi(_fullAnalysisReply),
    );

    final beforeApprove =
        repo.updateDraftArgs.where((c) => c.carriesAnalysedField).length;
    expect(beforeApprove, 0);

    await _tapVisible(
      tester,
      find.descendant(
        of: _estimateRowFor(l10n.mealSummaryLabelCuisine),
        matching: find.widgetWithText(TextButton, l10n.mealSummaryApprove),
      ),
    );

    final analysed = repo.updateDraftArgs.where((c) => c.carriesAnalysedField);
    expect(analysed, hasLength(1));
    expect(analysed.single.cuisine?.name, 'egyptian');
    expect(analysed.single.category, isNull);
    expect(analysed.single.calories, isNull);
    expect(analysed.single.ingredients, isNull);
    expect(analysed.single.allergens, isNull);
  });

  testWidgets('a double tap on publish results in exactly one publish call',
      (tester) async {
    await _tallSurface(tester);
    final repo = FakeMealRepository();
    final events = <({String name, Map<String, Object> attributes})>[];
    debugEventRecorder = (name, attributes) {
      events.add((name: name, attributes: attributes));
    };

    await _reachSummary(
      tester,
      repo,
      ai: _stubAi(_fullAnalysisReply),
    );
    await _approveAllViaController(tester);

    final publishButton =
        find.widgetWithText(FilledButton, l10n.mealSummaryConfirm('other'));
    await tester.ensureVisible(publishButton);
    await tester.pumpAndSettle();
    await tester.tap(publishButton);
    await tester.tap(publishButton);
    await tester.pumpAndSettle();

    expect(repo.publishCalls, 1);
    expect(
      events.where((e) => e.name == EventNames.mealPublished),
      hasLength(1),
    );
  });

  testWidgets(
      'MealEstimateFields.presentIn only lists what the analysis produced',
      (tester) async {
    // Keep this next to the UI tests so a field-list drift fails here first.
    expect(
      MealEstimateFields.presentIn(const MealAnalysis.empty()),
      isEmpty,
    );
  });

  // The widget has its own _published flag, so the double-tap widget test above
  // passes even with the controller's guard removed — it is testing the screen,
  // not the rule. Publishing twice is the kind of thing that reaches a Customer,
  // so the guard that survives a UI rewrite needs its own test.
  testWidgets('the controller refuses a second publish even if asked directly',
      (tester) async {
    await _tallSurface(tester);
    final repo = FakeMealRepository();
    await _reachSummary(tester, repo, ai: _stubAi(_fullAnalysisReply));
    await _approveAllViaController(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MealSummaryScreen)),
    );
    final controller =
        container.read(mealConversationControllerProvider.notifier);

    expect(await controller.publish(), isTrue);
    expect(await controller.publish(), isFalse,
        reason: 'a Meal already on offer must not be published again');
    expect(repo.publishCalls, 1);
  });

  // ConversationCompleted closes the funnel that ConversationStarted opens, and
  // it is asserted here rather than with the other conversation events because
  // the emission lives in this screen: publishing is the confirmation the whole
  // conversation was leading to.
  testWidgets('ConversationCompleted is emitted once when a Meal goes on offer',
      (tester) async {
    await _tallSurface(tester);
    final repo = FakeMealRepository();
    final events = <({String name, Map<String, Object> attributes})>[];
    debugEventRecorder = (name, attributes) {
      events.add((name: name, attributes: attributes));
    };

    await _reachSummary(tester, repo, ai: _stubAi(_fullAnalysisReply));
    await _approveAllViaController(tester);

    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, l10n.mealSummaryConfirm('other')),
    );

    final completed = events
        .where((e) => e.name == EventNames.conversationCompleted)
        .toList();
    expect(completed, hasLength(1));
    expect(completed.single.attributes['kind'], mealConversationKind);
    expect(completed.single.attributes['input'], 'mixed');
  });

  // A conversation that ended in a failure did not complete. Emitting it anyway
  // would report a publish rate higher than the one Cooks actually experience,
  // and the number would be wrong in the flattering direction.
  testWidgets('ConversationCompleted is not emitted when the publish fails',
      (tester) async {
    await _tallSurface(tester);
    final repo = FakeMealRepository();
    final events = <({String name, Map<String, Object> attributes})>[];
    debugEventRecorder = (name, attributes) {
      events.add((name: name, attributes: attributes));
    };

    await _reachSummary(tester, repo, ai: _stubAi(_fullAnalysisReply));
    await _approveAllViaController(tester);

    // Fails only at the publish, so the summary is reached exactly as it is on
    // the working path — the failure under test is the publish, not the setup.
    repo.failOperations = true;

    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, l10n.mealSummaryConfirm('other')),
    );

    expect(
      events.where((e) => e.name == EventNames.conversationCompleted),
      isEmpty,
    );
    expect(find.text(l10n.mealPublishError('other')), findsOneWidget);
  });

  // --- T096: fallback answers on the summary --------------------------------

  testWidgets(
      'fallback cuisine and category on summary are not labelled as estimates',
      (tester) async {
    await _tallSurface(tester);
    final repo = FakeMealRepository();
    // Unstubbed AI → analysis fails → fallback path.
    await _reachSummary(tester, repo, l10n: l10n);
    await tester.pumpAndSettle();

    expect(find.byType(MealSummaryScreen), findsOneWidget);
    expect(find.text(l10n.mealSummaryLabelCuisine), findsOneWidget);
    expect(find.text(l10n.mealSummaryLabelCategory), findsOneWidget);
    expect(find.text(l10n.cuisineEgyptian), findsOneWidget);
    expect(find.text(l10n.categoryMain), findsOneWidget);

    // Badge must not appear on those Cook-owned rows. With no analysis there
    // are no estimate rows at all, so the badge must be entirely absent.
    expect(find.text(l10n.mealSummaryEstimateBadge), findsNothing);

    final cuisineRow = find.ancestor(
      of: find.text(l10n.mealSummaryLabelCuisine),
      matching: find.byType(SummaryRow),
    );
    final categoryRow = find.ancestor(
      of: find.text(l10n.mealSummaryLabelCategory),
      matching: find.byType(SummaryRow),
    );
    expect(
      find.descendant(
        of: cuisineRow,
        matching: find.text(l10n.mealSummaryEstimateBadge),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: categoryRow,
        matching: find.text(l10n.mealSummaryEstimateBadge),
      ),
      findsNothing,
    );
  });

  // --- T047 + T050: nutrition source — estimate vs Cook-owned ---------------
  //
  // The trigger `derive_nutrition_source` decides who owns the figure by
  // comparing what arrives against what is stored. If the app ever sent the
  // estimate on a correction, or a different value on an approval, the
  // database would label it correctly for the wrong write. These tests pin
  // the app's half of that contract.

  // T050 — an approved estimate is still an estimate after publishing.
  testWidgets('approved estimates keep their badge and notice after publish',
      (tester) async {
    await _tallSurface(tester);
    final repo = FakeMealRepository();
    await _reachSummary(
      tester,
      repo,
      ai: _stubAi(_fullAnalysisReply),
    );

    await _approveAllViaController(tester);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l10n.mealSummaryConfirm('other')),
    );
    expect(button.onPressed, isNotNull);
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, l10n.mealSummaryConfirm('other')),
    );

    expect(find.text(l10n.mealPublishedConfirmation), findsOneWidget);

    final caloriesRow = _estimateRowFor(l10n.mealSummaryLabelCalories);
    expect(
      find.descendant(
        of: caloriesRow,
        matching: find.text(l10n.mealSummaryEstimateBadge),
      ),
      findsOneWidget,
      reason: 'approved calories must still read as an estimate, not verified',
    );

    final allergensRow = _estimateRowFor(l10n.mealSummaryLabelAllergens);
    expect(
      find.descendant(
        of: allergensRow,
        matching: find.text(l10n.mealSummaryEstimateBadge),
      ),
      findsOneWidget,
      reason: 'approved allergens must still read as an estimate, not verified',
    );

    expect(find.text(l10n.mealSummaryEstimatesNotice('other')), findsOneWidget);
  });

  // The other half of the same claim, and the one that stops the badge being
  // unconditional. A badge that never disappears is not carrying information:
  // it would keep saying "estimate" over a figure the Cook typed themselves.
  testWidgets('a corrected estimate stops reading as one', (tester) async {
    await _tallSurface(tester);
    final repo = FakeMealRepository();
    await _reachSummary(
      tester,
      repo,
      ai: _stubAi(_fullAnalysisReply),
    );

    final caloriesRow = _estimateRowFor(l10n.mealSummaryLabelCalories);
    expect(
      find.descendant(
        of: caloriesRow,
        matching: find.text(l10n.mealSummaryEstimateBadge),
      ),
      findsOneWidget,
      reason: 'the estimate is badged before the Cook touches it',
    );

    await _tapVisible(
      tester,
      find.descendant(
        of: _estimateRowFor(l10n.mealSummaryLabelCalories),
        matching: find.widgetWithText(TextButton, l10n.convEdit('other')),
      ),
    );
    await tester.enterText(find.byType(TextField), '950');
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: _estimateRowFor(l10n.mealSummaryLabelCalories),
        matching: find.text(l10n.mealSummaryEstimateBadge),
      ),
      findsNothing,
      reason: 'a figure the Cook replaced is theirs and is not an estimate',
    );

    // The allergens row was neither approved nor corrected, so it is untouched
    // — a correction must not clear the badge on every other row at once.
    expect(
      find.descendant(
        of: _estimateRowFor(l10n.mealSummaryLabelAllergens),
        matching: find.text(l10n.mealSummaryEstimateBadge),
      ),
      findsOneWidget,
    );
  });

  // T047 — a correction reaches the database as a changed value.
  group('nutrition write carries the right value', () {
    testWidgets('approving calories sends the AI value unchanged',
        (tester) async {
      await _tallSurface(tester);
      final repo = FakeMealRepository();
      await _reachSummary(
        tester,
        repo,
        ai: _stubAi(_fullAnalysisReply),
      );

      await _tapVisible(
        tester,
        find.descendant(
          of: _estimateRowFor(l10n.mealSummaryLabelCalories),
          matching: find.widgetWithText(TextButton, l10n.mealSummaryApprove),
        ),
      );

      final aiCalories = _parseAnalysis(_fullAnalysisReply)['calories'] as int;
      final calCall =
          repo.updateDraftArgs.where((c) => c.calories != null).last;
      expect(
        calCall.calories,
        aiCalories,
        reason:
            'approval must send the AI Assistant value, not a different one',
      );
    });

    testWidgets('correcting calories sends the Cook value, not the estimate',
        (tester) async {
      await _tallSurface(tester);
      final repo = FakeMealRepository();
      await _reachSummary(
        tester,
        repo,
        ai: _stubAi(_fullAnalysisReply),
      );

      await _tapVisible(
        tester,
        find.descendant(
          of: _estimateRowFor(l10n.mealSummaryLabelCalories),
          matching: find.widgetWithText(TextButton, l10n.convEdit('other')),
        ),
      );
      await tester.enterText(find.byType(TextField), '950');
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      const cookCalories = 950;
      final calCall =
          repo.updateDraftArgs.where((c) => c.calories != null).last;
      expect(
        calCall.calories,
        cookCalories,
        reason: 'a correction must send the Cook number, not the estimate',
      );
    });

    testWidgets('a calorie correction typed in Arabic digits is not discarded',
        (tester) async {
      // «٩٥٠» is nine hundred and fifty on an Arabic keyboard, and
      // `int.tryParse` returns null for it. The correction was therefore thrown
      // away in silence: the row closed, the AI Assistant's 850 came back, and
      // the Cook could publish a figure she believed she had changed. Same cause
      // as the price defect the founder hit on 2026-08-11, quieter symptom.
      await _tallSurface(tester);
      final repo = FakeMealRepository();
      await _reachSummary(
        tester,
        repo,
        ai: _stubAi(_fullAnalysisReply),
      );

      await _tapVisible(
        tester,
        find.descendant(
          of: _estimateRowFor(l10n.mealSummaryLabelCalories),
          matching: find.widgetWithText(TextButton, l10n.convEdit('other')),
        ),
      );
      await tester.enterText(find.byType(TextField), '٩٥٠');
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      final calCall =
          repo.updateDraftArgs.where((c) => c.calories != null).last;
      expect(
        calCall.calories,
        950,
        reason: 'her number, in the digits she typed it in — not the estimate',
      );
    });

    testWidgets('the calorie field accepts Arabic digits and refuses letters',
        (tester) async {
      // The mechanism, pinned at the field itself.
      // `FilteringTextInputFormatter.digitsOnly` allows `[0-9]` and nothing
      // else, so «٩٥٠» was deleted keystroke by keystroke and the box stayed
      // empty — no error, no rejection, just a field that would not accept the
      // digits of the app's own default locale. The filter is still a filter:
      // letters in a calorie count remain a mistake.
      await _tallSurface(tester);
      final repo = FakeMealRepository();
      await _reachSummary(
        tester,
        repo,
        ai: _stubAi(_fullAnalysisReply),
      );

      await _tapVisible(
        tester,
        find.descendant(
          of: _estimateRowFor(l10n.mealSummaryLabelCalories),
          matching: find.widgetWithText(TextButton, l10n.convEdit('other')),
        ),
      );

      final field = find.byType(TextField);
      await tester.enterText(field, '٩٥٠');
      await tester.pump();
      expect(
        tester.widget<TextField>(field).controller?.text,
        '٩٥٠',
        reason: 'THE BUG. This was empty: her keystrokes were filtered out.',
      );

      await tester.enterText(field, 'كتير');
      await tester.pump();
      expect(
        tester.widget<TextField>(field).controller?.text,
        isEmpty,
        reason: 'a calorie count is a number, and letters are still refused',
      );
    });

    testWidgets('approving allergens sends the AI list unchanged',
        (tester) async {
      await _tallSurface(tester);
      final repo = FakeMealRepository();
      await _reachSummary(
        tester,
        repo,
        ai: _stubAi(_fullAnalysisReply),
      );

      final aiAllergens =
          (_parseAnalysis(_fullAnalysisReply)['allergens'] as List)
              .cast<String>();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MealSummaryScreen)),
      );
      final controller =
          container.read(mealConversationControllerProvider.notifier);
      for (final field in [
        MealEstimateFields.cuisine,
        MealEstimateFields.category,
        MealEstimateFields.ingredients,
        MealEstimateFields.calories,
      ]) {
        expect(
          await controller.approveEstimate(field),
          isTrue,
        );
      }
      await tester.pumpAndSettle();

      await _tapVisible(
        tester,
        find.descendant(
          of: _estimateRowFor(l10n.mealSummaryLabelAllergens),
          matching: find.widgetWithText(TextButton, l10n.mealSummaryApprove),
        ),
      );

      final allergenCall =
          repo.updateDraftArgs.where((c) => c.allergens != null).last;
      expect(
        allergenCall.allergens,
        aiAllergens,
        reason: 'approval must send the AI Assistant list unchanged',
      );
    });

    testWidgets('correcting allergens sends the Cook list, using Arabic comma',
        (tester) async {
      await _tallSurface(tester);
      final repo = FakeMealRepository();
      await _reachSummary(
        tester,
        repo,
        ai: _stubAi(_fullAnalysisReply),
      );

      await _tapVisible(
        tester,
        find.descendant(
          of: _estimateRowFor(l10n.mealSummaryLabelAllergens),
          matching: find.widgetWithText(TextButton, l10n.convEdit('other')),
        ),
      );
      await tester.enterText(find.byType(TextField), 'قمح،سمسم');
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      final cookAllergens = ['قمح', 'سمسم'];
      final allergenCall =
          repo.updateDraftArgs.where((c) => c.allergens != null).last;
      expect(
        allergenCall.allergens,
        cookAllergens,
        reason:
            'a correction must send the Cook list, split on Arabic comma too',
      );
    });
  });
}
