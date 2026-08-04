import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ai/ai.dart';
import 'package:kafoo_mobile/features/conversation/application/voice_input.dart';
import 'package:kafoo_mobile/features/meal/application/meal_conversation_controller.dart';
import 'package:kafoo_mobile/features/meal/data/ai_provider.dart';
import 'package:kafoo_mobile/features/meal/data/meal_repository.dart';
import 'package:kafoo_mobile/features/meal/presentation/meal_conversation.dart';
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

Widget _app(FakeMealRepository repo) => ProviderScope(
      overrides: [
        mealRepositoryProvider.overrideWithValue(repo),
        aiProviderProvider.overrideWithValue(StubAiProvider(const {})),
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
/// reaches it.
///
/// Constructing the screen directly with prepared values would exercise a path
/// nobody travels — and would not have caught the draft living in two places,
/// which is the defect this file exists downstream of.
Future<void> _reachSummary(
  WidgetTester tester,
  FakeMealRepository repo,
) async {
  await tester.pumpWidget(_app(repo));
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
}

Finder _rowFor(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(SummaryRow),
    );

/// Tap Change on a row, type a value, confirm it.
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

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  testWidgets('the summary shows every answer the Cook gave', (tester) async {
    final repo = FakeMealRepository();
    await _reachSummary(tester, repo);

    expect(find.byType(MealSummaryScreen), findsOneWidget);
    expect(find.text(l10n.mealSummaryTitle), findsOneWidget);
    expect(find.text(_dish), findsOneWidget);
    expect(find.text(_description), findsOneWidget);
    expect(find.text(_price), findsOneWidget);
  });

  testWidgets('a declined photo reads as a choice, not an empty row',
      (tester) async {
    final repo = FakeMealRepository();
    await _reachSummary(tester, repo);

    expect(find.text(l10n.mealSummaryNoPhoto), findsOneWidget);
  });

  // SC-004: every value is correctable in EXACTLY one action. That the control
  // exists is not the requirement — the count of taps to reach editing is.
  testWidgets('each value is one tap from being editable (SC-004)',
      (tester) async {
    final repo = FakeMealRepository();
    await _reachSummary(tester, repo);

    // Three correctable rows, one Change control each. The photo row has none:
    // supplying a photograph is T041.
    expect(find.widgetWithText(TextButton, l10n.convEdit), findsNWidgets(3));
    expect(find.byType(SummaryRow), findsNWidgets(3));
    expect(find.byType(PhotoRow), findsOneWidget);

    // One tap and that row is a field — no menu, no edit mode entered first.
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, l10n.convEdit).first);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('correcting the dish persists it', (tester) async {
    final repo = FakeMealRepository();
    await _reachSummary(tester, repo);
    final before = repo.updateDraftCalls;

    await _correct(tester, l10n.mealSummaryLabelDish, 'كشري بالعدس');

    expect(repo.updateDraftCalls, before + 1);
    expect(repo.updateDraftArgs.last.title, 'كشري بالعدس');
    expect(find.text('كشري بالعدس'), findsOneWidget);
  });

  testWidgets('correcting the description persists it', (tester) async {
    final repo = FakeMealRepository();
    await _reachSummary(tester, repo);
    final before = repo.updateDraftCalls;

    await _correct(tester, l10n.mealSummaryLabelDescription, 'عدس ورز وبصل');

    expect(repo.updateDraftCalls, before + 1);
    expect(repo.updateDraftArgs.last.description, 'عدس ورز وبصل');
  });

  testWidgets('correcting the price persists it', (tester) async {
    final repo = FakeMealRepository();
    await _reachSummary(tester, repo);
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
    await _reachSummary(tester, repo);

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

  // FR-004: nothing is on offer until the Cook confirms — and confirming is
  // T038, so right now nothing goes on offer at all.
  testWidgets('reaching the summary puts nothing on offer', (tester) async {
    final repo = FakeMealRepository();
    await _reachSummary(tester, repo);

    expect(repo.publishCalls, 0);

    await tester
        .tap(find.widgetWithText(FilledButton, l10n.mealSummaryConfirm));
    await tester.pumpAndSettle();

    expect(repo.publishCalls, 0,
        reason: 'publishing is T038; confirm must not put a Meal on offer yet');
  });

  // FR-005 makes a value correctable, not erasable. An empty correction is a
  // slip, so it closes the row and keeps what was there.
  testWidgets('an empty correction writes nothing and keeps the value',
      (tester) async {
    final repo = FakeMealRepository();
    await _reachSummary(tester, repo);
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
}
