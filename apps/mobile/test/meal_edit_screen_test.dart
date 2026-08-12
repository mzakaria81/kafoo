import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/analytics/emit_event.dart';
import 'package:kafoo_mobile/features/analytics/event_names.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output_provider.dart';
import 'package:kafoo_mobile/features/meal/data/meal_repository.dart';
import 'package:kafoo_mobile/features/meal/presentation/meal_edit_screen.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';

import 'support/fake_meal_repository.dart';

const _published = Meal(
  id: 'm-pub',
  cookId: 'c1',
  title: 'كشري',
  description: 'عدس ورز',
  price: '35',
  cuisine: Cuisine.egyptian,
  category: MealCategory.main,
  status: MealStatus.published,
  nutritionSource: NutritionSource.ai,
);

Widget _app(FakeMealRepository repo, {Meal? meal}) => ProviderScope(
      overrides: [
        // Recorded rather than spoken. Left real, this screen reaches Kafoo's
        // `speak` function — and a paid provider — from a widget test, and its
        // timeouts leave pending timers the test framework rejects.
        speechOutputProvider.overrideWithValue(FakeSpeechOutput()),
        mealRepositoryProvider.overrideWithValue(repo),
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
        home: MealEditScreen(meal: meal ?? _published),
      ),
    );

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

  testWidgets(
      'nothing is written while an edit is in progress — updateDraftArgs is empty before commit',
      (tester) async {
    final repo = FakeMealRepository(existing: _published);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Open the dish row by tapping the Change button.
    await tester.tap(find.text(l10n.convEdit('other')).first);
    await tester.pumpAndSettle();

    // Type a new value.
    await tester.enterText(
      find.byType(TextField),
      'كشري بلدي',
    );
    await tester.pump();

    // Nothing has been written yet.
    expect(repo.updateDraftArgs, isEmpty);

    // Now commit.
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(repo.updateDraftArgs, hasLength(1));
  });

  testWidgets('a commit writes only the field that changed', (tester) async {
    final repo = FakeMealRepository(existing: _published);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Open the dish row and change the title.
    await tester.tap(find.text(l10n.convEdit('other')).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'كشري بلدي');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(repo.updateDraftArgs, hasLength(1));
    final call = repo.updateDraftArgs.single;
    expect(call.mealId, _published.id);
    expect(call.title, 'كشري بلدي');
    expect(call.description, isNull);
    expect(call.price, isNull);
    expect(call.cuisine, isNull);
    expect(call.category, isNull);
    expect(call.ingredients, isNull);
    expect(call.calories, isNull);
    expect(call.allergens, isNull);
    expect(call.photoPath, isNull);
  });

  testWidgets('no write from this screen ever carries an analysed field',
      (tester) async {
    final repo = FakeMealRepository(existing: _published);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Commit title change.
    await tester.tap(find.text(l10n.convEdit('other')).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'كشري بلدي');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(repo.updateDraftArgs.last.carriesAnalysedField, isFalse);

    // Commit description change.
    await tester.tap(find.text(l10n.convEdit('other')).at(1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'عدس ورز ومكرونة');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(repo.updateDraftArgs.last.carriesAnalysedField, isFalse);

    // Commit price change.
    await tester.tap(find.text(l10n.convEdit('other')).at(2));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '40');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(repo.updateDraftArgs.last.carriesAnalysedField, isFalse);
  });

  group('re-pricing a published Meal in Arabic digits', () {
    // The same defect as the conversation's price question, on the screen a Cook
    // reaches AFTER her Meal is on offer — which is the one where getting it
    // wrong costs her a sale rather than a first attempt. 2026-08-11.

    Future<void> commitPrice(WidgetTester tester, String typed) async {
      await tester.tap(find.text(l10n.convEdit('other')).at(2));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), typed);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();
    }

    testWidgets('«١٤٠» is written as 140', (tester) async {
      final repo = FakeMealRepository(existing: _published);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await commitPrice(tester, '١٤٠');

      expect(repo.updateDraftArgs.last.price, '140');
      expect(find.text(l10n.mealSaveError('other')), findsNothing);
      expect(find.text(l10n.mealPriceInvalid('other')), findsNothing);
    });

    testWidgets('a price the column cannot hold says so, and writes nothing',
        (tester) async {
      final repo = FakeMealRepository(existing: _published);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await commitPrice(tester, 'ببلاش');

      expect(repo.updateDraftArgs, isEmpty);
      // THE MESSAGE, not just the refusal. This screen hardcoded
      // `mealSaveError` for every error its controller produced until
      // `mealErrorText` replaced it — so a Cook could not tell a price she can
      // retype from a network she cannot.
      expect(find.text(l10n.mealPriceInvalid('other')), findsOneWidget);
      expect(find.text(l10n.mealSaveError('other')), findsNothing);
    });
  });

  testWidgets(
      'a price change and a title change are distinguishable in the analytics',
      (tester) async {
    final repo = FakeMealRepository(existing: _published);
    final events = <({String name, Map<String, Object> attributes})>[];
    debugEventRecorder = (name, attributes) {
      events.add((name: name, attributes: attributes));
    };

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Commit a price change.
    await tester.tap(find.text(l10n.convEdit('other')).at(2));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '40');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final priceEvents =
        events.where((e) => e.name == EventNames.mealUpdated).toList();
    expect(priceEvents, hasLength(1));
    expect(priceEvents.single.attributes['changed'], 'price');

    // Commit a title change.
    await tester.tap(find.text(l10n.convEdit('other')).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'كشري بلدي');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final titleEvents =
        events.where((e) => e.name == EventNames.mealUpdated).toList();
    expect(titleEvents, hasLength(2));
    expect(titleEvents.last.attributes['changed'], 'title');
  });

  testWidgets(
      'closing a row without changing anything writes nothing and emits nothing',
      (tester) async {
    final repo = FakeMealRepository(existing: _published);
    final events = <({String name, Map<String, Object> attributes})>[];
    debugEventRecorder = (name, attributes) {
      events.add((name: name, attributes: attributes));
    };

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Open the dish row and commit the identical value.
    await tester.tap(find.text(l10n.convEdit('other')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(repo.updateDraftArgs, isEmpty);
    expect(events, isEmpty);
  });

  testWidgets('an empty value is not a change', (tester) async {
    final repo = FakeMealRepository(existing: _published);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Open the dish row, clear it, commit.
    await tester.tap(find.text(l10n.convEdit('other')).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(repo.updateDraftArgs, isEmpty);
  });

  testWidgets('opening a second row abandons the first without writing it',
      (tester) async {
    final repo = FakeMealRepository(existing: _published);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Begin editing dish.
    await tester.tap(find.text(l10n.convEdit('other')).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'كشري بلدي');
    await tester.pump();

    // Now begin editing price — this should abandon the dish edit.
    // With dish in edit mode, only 2 Change buttons remain (description, price),
    // so the price is at(1).
    await tester.tap(find.text(l10n.convEdit('other')).at(1));
    await tester.pumpAndSettle();

    // Nothing has been written.
    expect(repo.updateDraftArgs, isEmpty);
  });

  testWidgets('a failed write tells the Cook, in Arabic', (tester) async {
    final repo = FakeMealRepository(existing: _published);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Open the dish row and type a new value.
    await tester.tap(find.text(l10n.convEdit('other')).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'كشري بلدي');
    await tester.pump();

    // Now flip the fail flag so the updateDraft call fails.
    repo.failOperations = true;

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealSaveError('other')), findsOneWidget);
  });

  // The bug this catches shipped once: feedback used a plain `??` in copyWith,
  // so passing null could not clear it. A failed write left the previous
  // "changed" line on screen beside the error, telling the Cook their
  // correction had both saved and not saved.
  testWidgets('a failure clears the previous success line', (tester) async {
    final repo = FakeMealRepository(existing: _published);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.convEdit('other')).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'كشري بالعدس');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.text(l10n.mealEditSaved), findsOneWidget);

    repo.failOperations = true;
    await tester.tap(find.text(l10n.convEdit('other')).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'كشري بالحمص');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealSaveError('other')), findsOneWidget);
    expect(find.text(l10n.mealEditSaved), findsNothing);
  });

  // Feedback that outlives what it refers to is decoration. Opening a row
  // clears the previous commit's line.
  testWidgets('opening a row clears the previous success line', (tester) async {
    final repo = FakeMealRepository(existing: _published);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.convEdit('other')).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'كشري بلدي');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.text(l10n.mealEditSaved), findsOneWidget);

    await tester.tap(find.text(l10n.convEdit('other')).first);
    await tester.pumpAndSettle();
    expect(find.text(l10n.mealEditSaved), findsNothing);
  });
}
