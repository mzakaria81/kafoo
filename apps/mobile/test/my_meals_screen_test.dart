import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ai/ai.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/analytics/emit_event.dart';
import 'package:kafoo_mobile/features/analytics/event_names.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output_provider.dart';
import 'package:kafoo_mobile/features/meal/application/my_meals_controller.dart';
import 'package:kafoo_mobile/features/meal/data/ai_provider.dart';
import 'package:kafoo_mobile/features/meal/data/meal_repository.dart';
import 'package:kafoo_mobile/features/meal/presentation/my_meals_screen.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';
import 'package:kafoo_ui/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_meal_repository.dart';

const _draft = CookMeal(
  id: 'm-draft',
  cookId: 'c1',
  title: 'كشري مسودة',
  description: 'مسودة',
  price: '30',
  cuisine: Cuisine.egyptian,
  category: MealCategory.main,
  status: MealStatus.draft,
  nutritionSource: NutritionSource.ai,
);

const _halfDraft = CookMeal(
  id: 'm-half',
  cookId: 'c1',
  title: 'ملوخية نص',
  status: MealStatus.draft,
  nutritionSource: NutritionSource.ai,
);

const _photographed = CookMeal(
  id: 'm-photo',
  cookId: 'c1',
  title: 'ملوخية',
  description: 'بالأرانب',
  price: '80',
  photoPath: 'c1/m-photo.jpg',
  cuisine: Cuisine.egyptian,
  category: MealCategory.main,
  status: MealStatus.published,
  nutritionSource: NutritionSource.ai,
);

const _published = CookMeal(
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

const _unavailable = CookMeal(
  id: 'm-unavail',
  cookId: 'c1',
  title: 'محشي',
  description: 'ورق عنب',
  price: '50',
  cuisine: Cuisine.egyptian,
  category: MealCategory.main,
  status: MealStatus.unavailable,
  nutritionSource: NutritionSource.ai,
);

const _archived = CookMeal(
  id: 'm-arch',
  cookId: 'c1',
  title: 'فتة',
  description: 'فتة باللحمة',
  price: '60',
  cuisine: Cuisine.egyptian,
  category: MealCategory.main,
  status: MealStatus.archived,
  nutritionSource: NutritionSource.ai,
);

const _publishedSecond = CookMeal(
  id: 'm-pub-2',
  cookId: 'c1',
  title: 'محشي',
  description: 'ورق عنب',
  price: '50',
  cuisine: Cuisine.egyptian,
  category: MealCategory.main,
  status: MealStatus.published,
  nutritionSource: NutritionSource.ai,
);

Widget _app(
  FakeMealRepository repo, {
  void Function(CookMeal meal)? onResumeDraft,
  SpeechOutput? speech,
}) =>
    ProviderScope(
      overrides: [
        mealRepositoryProvider.overrideWithValue(repo),
        if (speech != null) speechOutputProvider.overrideWithValue(speech),
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
        home: MyMealsScreen(onResumeDraft: onResumeDraft),
      ),
    );

/// Opens the `···` sheet on one Meal row.
///
/// The actions moved off the row and into a bottom sheet when the list became
/// voice-first: a row led by a 34px price and a glance word cannot also carry
/// four text buttons without undoing the thing that shape is for. **What each
/// action does, and which ones confirm first, did not change** — which is why
/// these tests were rewritten around the new gesture rather than replaced.
Future<void> _openActions(WidgetTester tester, {int row = 0}) async {
  await tester.tap(
    find.descendant(
      of: find.byType(MyMealRow).at(row),
      matching: find.byIcon(Icons.more_horiz),
    ),
  );
  await tester.pumpAndSettle();
}

/// Dismisses the row sheet.
///
/// Scoped to the sheet on purpose: «سيبها زي ما هي» is also the word on two of
/// the confirmation dialogs, so an unscoped finder matches both surfaces and
/// the tap becomes ambiguous.
Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(KafooSheet),
      matching: find.byType(TextButton),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  setUp(() {
    debugEventRecorder = null;
    // The voice reads its mute preference on startup. Without a mock store the
    // read throws, the engine still reports ready, and the greeting is spoken
    // one frame later than a test expects.
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    debugEventRecorder = null;
  });

  // The bug this catches shipped once: with no loading state, "no Meals yet,
  // start one" renders for the whole of the first load. A Cook with a full
  // menu is told their work is gone, every time they open the screen.
  testWidgets('while loading, does not claim the Cook has no Meals',
      (tester) async {
    final repo = FakeMealRepository(meals: [_published])
      ..myMealsDelay = const Duration(milliseconds: 100);

    await tester.pumpWidget(_app(repo));
    await tester.pump(const Duration(milliseconds: 20));

    // A skeleton at the Meal-row footprint, not a spinner. "No Meals yet" and
    // "not answered yet" are opposite messages and must not share a screen.
    expect(find.byType(KafooSkeletonList), findsOneWidget);
    expect(find.text(l10n.myMealsEmptyInvitation), findsNothing);

    await tester.pumpAndSettle();

    expect(find.text(l10n.myMealsEmptyInvitation), findsNothing);
    expect(find.text(_published.title!), findsOneWidget);
  });

  testWidgets('a Cook with no Meals is told so, once the load has answered',
      (tester) async {
    final repo = FakeMealRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text(l10n.myMealsEmptyInvitation), findsOneWidget);
    expect(find.byType(KafooSkeletonList), findsNothing);
  });

  group('the assistant greets once', () {
    // THE CLAIM THE SCREEN IS BUILT ON, AND NOTHING ASSERTED IT. The greeting
    // is an event: said on arrival, and said again only when a Cook asks. A
    // screen that re-reads its own summary every time a Meal changes status
    // turns the assistant into a nag, and the guard against that is one bool
    // that a refactor could drop without any test noticing.
    testWidgets('on arrival, and not again when a Meal changes',
        (tester) async {
      final speech = FakeSpeechOutput();
      final repo = FakeMealRepository(meals: [_published, _unavailable]);
      await tester.pumpWidget(_app(repo, speech: speech));
      await tester.pumpAndSettle();

      expect(speech.spoken, hasLength(1));
      final greeting = speech.spoken.single.line;

      // Take a Meal off the menu — the list rebuilds with a new summary.
      await _openActions(tester, row: 0);
      await tester.tap(find.text(l10n.mealMakeUnavailable('other')));
      await tester.pumpAndSettle();

      expect(
        speech.spoken.where((s) => s.line == greeting),
        hasLength(1),
        reason: 'the assistant re-announced itself on a status change',
      );
    });

    testWidgets('and says it again when she asks', (tester) async {
      final speech = FakeSpeechOutput();
      await tester.pumpWidget(
        _app(FakeMealRepository(meals: [_published]), speech: speech),
      );
      await tester.pumpAndSettle();
      final greeting = speech.spoken.single.line;

      await tester.tap(find.byTooltip(l10n.myMealsHearAgain('other')));
      await tester.pumpAndSettle();

      expect(speech.spoken.where((s) => s.line == greeting), hasLength(2));
    });
  });

  group('an irreversible action is read back aloud', () {
    // `.claude/rules/business-rules.md`: an irreversible action is read back in
    // full and waits for «أيوة»; voice and tap both answer. These three were
    // silent pop-up dialogs until 2026-08-11 — on a screen that greets a Cook
    // out loud and reads her Meals to her, which made the silence at the one
    // moment worth speaking louder rather than quieter.
    testWidgets('retiring a Meal says the warning out loud', (tester) async {
      final speech = FakeSpeechOutput();
      await tester.pumpWidget(
        _app(FakeMealRepository(meals: [_published]), speech: speech),
      );
      await tester.pumpAndSettle();

      await _openActions(tester);
      await tester.tap(find.text(l10n.mealRetire('other')));
      await tester.pumpAndSettle();

      expect(
        speech.spoken.map((s) => s.line),
        contains(l10n.mealRetireWarning),
      );
      // Full volume, not the quiet used for money: this is the sentence she is
      // being asked to agree to.
      expect(
        speech.spoken.firstWhere((s) => s.line == l10n.mealRetireWarning).quiet,
        isFalse,
      );
    });

    testWidgets('deleting a draft says its warning out loud', (tester) async {
      // Confirmed for retire and asserted nowhere for the other two, which is
      // how a rule ends up half-kept.
      final speech = FakeSpeechOutput();
      await tester.pumpWidget(
        _app(FakeMealRepository(meals: [_draft]), speech: speech),
      );
      await tester.pumpAndSettle();

      await _openActions(tester);
      await tester.tap(find.text(l10n.mealDeleteDraft('other')));
      await tester.pumpAndSettle();

      expect(
        speech.spoken.map((s) => s.line),
        contains(l10n.mealDeleteDraftWarning('other')),
      );
    });

    testWidgets('so does closing the kitchen', (tester) async {
      final speech = FakeSpeechOutput();
      await tester.pumpWidget(
        _app(FakeMealRepository(meals: [_published]), speech: speech),
      );
      await tester.pumpAndSettle();

      await _openActions(tester);
      await tester.tap(find.text(l10n.mealMakeUnavailable('other')));
      await tester.pumpAndSettle();

      expect(
        speech.spoken.map((s) => s.line),
        contains(l10n.mealLastOnOfferWarning('other')),
      );
    });

    testWidgets('it asks once more after eight seconds, and then waits',
        (tester) async {
      // A Cook steps away mid-sentence — flour on her hands, a pot going over.
      // One repeat is the difference between waiting and abandoned; a third
      // would be nagging, and nagging is how people learn to say yes to make it
      // stop.
      final speech = FakeSpeechOutput();
      await tester.pumpWidget(
        _app(FakeMealRepository(meals: [_published]), speech: speech),
      );
      await tester.pumpAndSettle();

      await _openActions(tester);
      await tester.tap(find.text(l10n.mealRetire('other')));
      await tester.pumpAndSettle();
      final said = () =>
          speech.spoken.where((s) => s.line == l10n.mealRetireWarning).length;
      expect(said(), 1);

      await tester.pump(const Duration(seconds: 9));
      expect(said(), 2);

      // And never a third.
      await tester.pump(const Duration(seconds: 30));
      expect(said(), 2);

      await tester.tap(
        find.descendant(
          of: find.byType(KafooConfirmationGate),
          matching: find.text(l10n.mealRetireCancel('other')),
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('backing out of it is a no, and the voice stops',
        (tester) async {
      // THE PATH FOUND BY HAND TWICE AND BY NO TEST. A back gesture skips the
      // buttons entirely, so the answer path and the hush that goes with it
      // were never reached — the assistant kept reading a warning aloud over a
      // screen that had already closed.
      final speech = FakeSpeechOutput();
      final repo = FakeMealRepository(meals: [_published]);
      await tester.pumpWidget(_app(repo, speech: speech));
      await tester.pumpAndSettle();

      await _openActions(tester);
      await tester.tap(find.text(l10n.mealRetire('other')));
      await tester.pumpAndSettle();
      expect(find.byType(KafooConfirmationGate), findsOneWidget);

      // The system back gesture, not a button.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(KafooConfirmationGate), findsNothing);
      expect(speech.stopped, isTrue);
      // And nothing was written. Backing out is never a yes.
      expect(repo.setStatusArgs, isEmpty);
    });

    testWidgets('answering stops it mid-sentence', (tester) async {
      final speech = FakeSpeechOutput();
      await tester.pumpWidget(
        _app(FakeMealRepository(meals: [_published]), speech: speech),
      );
      await tester.pumpAndSettle();

      await _openActions(tester);
      await tester.tap(find.text(l10n.mealRetire('other')));
      await tester.pumpAndSettle();
      expect(speech.stopped, isFalse);

      await tester.tap(
        find.descendant(
          of: find.byType(KafooConfirmationGate),
          matching: find.text(l10n.mealRetireCancel('other')),
        ),
      );
      await tester.pumpAndSettle();

      expect(speech.stopped, isTrue);
    });

    testWidgets('a reversible change is not gated at all', (tester) async {
      // Off the menu and back on is ordinary. A Cook trained to dismiss a gate
      // will dismiss the one that mattered.
      final repo = FakeMealRepository(meals: [_published, _publishedSecond]);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await _openActions(tester);
      await tester.tap(find.text(l10n.mealMakeUnavailable('other')));
      await tester.pumpAndSettle();

      expect(find.byType(KafooConfirmationGate), findsNothing);
      expect(repo.setStatusArgs, hasLength(1));
    });
  });

  group('a failed load says what actually failed', () {
    // «مفيش نت» is a claim about her connection, and it was made for every
    // failure — an auth problem, a refused read, a row that would not parse.
    // A Cook was sent to check her WiFi over something that had nothing to do
    // with it. Nothing covered this panel's words at all.
    testWidgets('a dropped connection blames the connection', (tester) async {
      final repo = FakeMealRepository()
        ..myMealsError = const AppError(messageKey: 'mealOfflineError');
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      expect(find.text(l10n.glanceOffline), findsOneWidget);
      expect(find.text(l10n.myMealsOfflineReassurance), findsOneWidget);
    });

    testWidgets('anything else does not', (tester) async {
      final repo = FakeMealRepository()
        ..myMealsError = const AppError(messageKey: 'mealLoadError');
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      expect(find.text(l10n.myMealsFailedTitle), findsOneWidget);
      expect(find.text(l10n.glanceOffline), findsNothing);
      // Still reassured — her Meals are safe either way — just not told a
      // cause that was not the cause.
      expect(find.text(l10n.myMealsFailedReassurance), findsOneWidget);
    });
  });

  group('a Cook sees her own photograph', () {
    // THE ROW NEVER ASKED FOR IT. `photo_path` was in the data, the repository
    // could turn it into a URL, and this row simply did not pass one — so a
    // Cook who photographed her food opened her list and read «مفيش صورة للأكلة
    // دي لسه» over every Meal. No test built a Meal with a photo, which is why
    // nothing caught it.
    testWidgets('a Meal with a photo does not claim to have none',
        (tester) async {
      await tester.pumpWidget(_app(FakeMealRepository(meals: [_photographed])));
      await tester.pumpAndSettle();

      expect(find.byType(KafooPhotoPlaceholder), findsNothing);
      expect(find.text(l10n.mealNoPhotoYet), findsNothing);
    });

    testWidgets('a Meal with none shows the quiet slot, not the hazard one',
        (tester) async {
      await tester.pumpWidget(_app(FakeMealRepository(meals: [_published])));
      await tester.pumpAndSettle();

      final placeholder = tester.widget<KafooPhotoPlaceholder>(
        find.byType(KafooPhotoPlaceholder),
      );
      // `semanticsLabel`, not `label`: at an 80px thumbnail no words fit
      // legibly, so the slot carries its sentence for a screen reader only.
      expect(placeholder.semanticsLabel, l10n.mealNoPhotoYet);
      // Not the hazard register. A Cook may publish without a photograph, so
      // hazard stripes over real food make the same accusation the wording was
      // already fixed to stop making.
      expect(placeholder.mock, isFalse);
      // Its own spoken label is deliberately swallowed by the row's composed
      // sentence — the row reads as one sentence rather than four stops, which
      // is what `excludeSemantics` on the photo-and-text block is for.
    });
  });

  group('an action that changed something says so', () {
    // The rule: a reversible action executes immediately and is ANNOUNCED, and
    // a gated one is announced once it has executed. Taking a Meal off the menu
    // and putting it back happened without a word — on a screen that greets a
    // Cook aloud and reads her Meals to her.
    testWidgets('taking a Meal off the menu is announced', (tester) async {
      final speech = FakeSpeechOutput();
      // Two Meals, so this is an ordinary reversible change rather than the
      // gated last-one-on-offer case.
      await tester.pumpWidget(
        _app(
          FakeMealRepository(meals: [_published, _publishedSecond]),
          speech: speech,
        ),
      );
      await tester.pumpAndSettle();

      await _openActions(tester);
      await tester.tap(find.text(l10n.mealMakeUnavailable('other')));
      await tester.pumpAndSettle();

      expect(
        speech.spoken.map((s) => s.line),
        contains(l10n.mealSpokenTakenOffMenu),
      );
    });

    testWidgets('putting it back on is announced too', (tester) async {
      final speech = FakeSpeechOutput();
      await tester.pumpWidget(
        _app(FakeMealRepository(meals: [_unavailable]), speech: speech),
      );
      await tester.pumpAndSettle();

      await _openActions(tester);
      await tester.tap(find.text(l10n.mealMakeAvailable('other')));
      await tester.pumpAndSettle();

      expect(
        speech.spoken.map((s) => s.line),
        contains(l10n.mealSpokenBackOnMenu),
      );
    });

    testWidgets('so is retiring, once she has confirmed it', (tester) async {
      // The gated actions announce themselves AFTER they execute, which the
      // design asks for separately from the warning before. Untested when it
      // landed, and an untested announcement is one a refactor drops quietly.
      final speech = FakeSpeechOutput();
      await tester.pumpWidget(
        _app(FakeMealRepository(meals: [_published]), speech: speech),
      );
      await tester.pumpAndSettle();

      await _openActions(tester);
      await tester.tap(find.text(l10n.mealRetire('other')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(KafooConfirmationGate),
          matching: find.text(l10n.mealRetireConfirm('other')),
        ),
      );
      await tester.pumpAndSettle();

      expect(
          speech.spoken.map((s) => s.line), contains(l10n.mealSpokenRetired));
    });

    testWidgets('and deleting a draft', (tester) async {
      final speech = FakeSpeechOutput();
      await tester.pumpWidget(
        _app(FakeMealRepository(meals: [_draft]), speech: speech),
      );
      await tester.pumpAndSettle();

      await _openActions(tester);
      await tester.tap(find.text(l10n.mealDeleteDraft('other')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(KafooConfirmationGate),
          matching: find.text(l10n.mealDeleteDraftConfirm('other')),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        speech.spoken.map((s) => s.line),
        contains(l10n.mealSpokenDraftDeleted),
      );
    });

    testWidgets('a change that failed is not announced as done',
        (tester) async {
      // Announcing something that did not happen is worse than silence, and the
      // screen already puts the failure on the screen in words.
      final speech = FakeSpeechOutput();
      final repo = FakeMealRepository(meals: [_unavailable]);
      await tester.pumpWidget(_app(repo, speech: speech));
      await tester.pumpAndSettle();
      // Set AFTER the first load: the same flag fails reads, and a screen with
      // no list on it has no row to open.
      repo.failOperations = true;

      await _openActions(tester);
      await tester.tap(find.text(l10n.mealMakeAvailable('other')));
      await tester.pumpAndSettle();

      expect(
        speech.spoken.map((s) => s.line),
        isNot(contains(l10n.mealSpokenBackOnMenu)),
      );
    });
  });

  testWidgets('shows every status, including drafts', (tester) async {
    final repo = FakeMealRepository(
      meals: [_draft, _published, _unavailable, _archived],
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Scrolled, not asserted in place: four rows led by a 34px price do not
    // fit above the talk dock on a 600px test surface, and a status hidden by
    // the fold is still a status the list shows.
    for (final glance in [
      l10n.glanceDraft,
      l10n.glancePublished,
      l10n.glanceUnavailable,
      l10n.glanceArchived,
    ]) {
      // Scoped to the Meal list: the talk dock scrolls inside its own cap at
      // large text sizes, so an unscoped finder now sees two scrollables and
      // gives up rather than choosing.
      await tester.scrollUntilVisible(
        find.text(glance),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(glance), findsOneWidget);
    }
  });

  testWidgets(
      'a published Meal offers to come off the menu; an unavailable one offers to go back on',
      (tester) async {
    final repo = FakeMealRepository(meals: [_published, _unavailable]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _openActions(tester, row: 0);
    expect(find.text(l10n.mealMakeUnavailable('other')), findsOneWidget);
    expect(find.text(l10n.mealMakeAvailable('other')), findsNothing);
    await _closeSheet(tester);

    await _openActions(tester, row: 1);
    expect(find.text(l10n.mealMakeAvailable('other')), findsOneWidget);
    expect(find.text(l10n.mealMakeUnavailable('other')), findsNothing);
  });

  testWidgets('a retired Meal offers no action at all', (tester) async {
    final repo = FakeMealRepository(meals: [_archived]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Inert rather than absent: the row keeps its shape, and the control
    // cannot open an empty sheet.
    final more = find.descendant(
      of: find.byType(MyMealRow).first,
      matching: find.byIcon(Icons.more_horiz),
    );
    expect(more, findsOneWidget);
    await tester.tap(more);
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text(l10n.mealMakeUnavailable('other')), findsNothing);
    expect(find.text(l10n.mealMakeAvailable('other')), findsNothing);
  });

  testWidgets(
      'taking an ordinary Meal off the menu writes the new status and nothing else',
      (tester) async {
    final repo = FakeMealRepository(
      meals: [_published, _publishedSecond],
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // The first Meal row (كشري), not the second.
    await _openActions(tester);
    await tester.tap(find.text(l10n.mealMakeUnavailable('other')));
    await tester.pumpAndSettle();

    expect(repo.setStatusArgs, hasLength(1));
    expect(repo.setStatusArgs.single.mealId, _published.id);
    expect(repo.setStatusArgs.single.next, MealStatus.unavailable);
    expect(repo.updateDraftArgs, isEmpty);
  });

  testWidgets(
      'taking the LAST Meal off the menu warns first, and writes nothing until confirmed',
      (tester) async {
    final repo = FakeMealRepository(meals: [_published]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _openActions(tester);
    await tester.tap(find.text(l10n.mealMakeUnavailable('other')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealLastOnOfferWarning('other')), findsOneWidget);
    expect(repo.setStatusArgs, isEmpty);

    await tester.tap(
      find.descendant(
        of: find.byType(KafooConfirmationGate),
        matching: find.text(l10n.mealLastOnOfferCancel('other')),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.setStatusArgs, isEmpty);

    await tester.tap(find.text(l10n.mealMakeUnavailable('other')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.mealLastOnOfferConfirm('other')));
    await tester.pumpAndSettle();

    expect(repo.setStatusArgs, hasLength(1));
    expect(repo.setStatusArgs.single.next, MealStatus.unavailable);
  });

  testWidgets(
      'the availability change emits MealUpdated with changed = availability',
      (tester) async {
    final repo = FakeMealRepository(
      meals: [_published, _publishedSecond],
    );
    final events = <({String name, Map<String, Object> attributes})>[];
    debugEventRecorder = (name, attributes) {
      events.add((name: name, attributes: attributes));
    };

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _openActions(tester);
    await tester.tap(find.text(l10n.mealMakeUnavailable('other')));
    await tester.pumpAndSettle();

    final updated =
        events.where((e) => e.name == EventNames.mealUpdated).toList();
    expect(updated, hasLength(1));
    expect(updated.single.attributes['changed'], 'availability');
  });

  testWidgets('a failed change tells the Cook, in Arabic', (tester) async {
    final repo = FakeMealRepository(
      meals: [_published, _publishedSecond],
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Now flip the fail flag so the setStatus call fails.
    repo.failOperations = true;

    await _openActions(tester);
    await tester.tap(find.text(l10n.mealMakeUnavailable('other')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealAvailabilityError('other')), findsOneWidget);
  });

  testWidgets(
      'retiring takes one confirmation, and writes nothing until it is given',
      (tester) async {
    final repo = FakeMealRepository(meals: [_published]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _openActions(tester);
    await tester.tap(find.text(l10n.mealRetire('other')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealRetireWarning), findsOneWidget);
    expect(repo.setStatusArgs, isEmpty);

    // The dialog's cancel, not the sheet's — both carry the same word.
    await tester.tap(
      find.descendant(
        of: find.byType(KafooConfirmationGate),
        matching: find.text(l10n.mealRetireCancel('other')),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.setStatusArgs, isEmpty);

    await tester.tap(find.text(l10n.mealRetire('other')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(KafooConfirmationGate),
        matching: find.text(l10n.mealRetireConfirm('other')),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.setStatusArgs, hasLength(1));
    expect(repo.setStatusArgs.single.mealId, _published.id);
    expect(repo.setStatusArgs.single.next, MealStatus.archived);
  });

  testWidgets('retiring emits MealArchived, and does not emit MealUpdated',
      (tester) async {
    final repo = FakeMealRepository(
      meals: [_published, _publishedSecond],
    );
    final events = <({String name, Map<String, Object> attributes})>[];
    debugEventRecorder = (name, attributes) {
      events.add((name: name, attributes: attributes));
    };

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _openActions(tester);
    await tester.tap(find.text(l10n.mealRetire('other')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(KafooConfirmationGate),
        matching: find.text(l10n.mealRetireConfirm('other')),
      ),
    );
    await tester.pumpAndSettle();

    final archived =
        events.where((e) => e.name == EventNames.mealArchived).toList();
    expect(archived, hasLength(1));
    expect(archived.single.attributes, isEmpty);

    final updated =
        events.where((e) => e.name == EventNames.mealUpdated).toList();
    expect(updated, isEmpty);
  });

  testWidgets('a retired Meal offers no route back', (tester) async {
    final repo = FakeMealRepository(meals: [_archived]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(MyMealRow).first,
        matching: find.byIcon(Icons.more_horiz),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealMakeUnavailable('other')), findsNothing);
    expect(find.text(l10n.mealMakeAvailable('other')), findsNothing);
    expect(find.text(l10n.mealRetire('other')), findsNothing);
    expect(find.text(l10n.mealDeleteDraft('other')), findsNothing);
  });

  test(
      'the controller refuses an illegal transition without calling the repository',
      () async {
    final repo = FakeMealRepository(meals: [_archived]);
    final container = ProviderContainer(
      overrides: [mealRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final controller = container.read(myMealsControllerProvider.notifier);
    final result = await controller.setStatus(_archived, MealStatus.published);

    expect(result, isFalse);
    expect(repo.setStatusArgs, isEmpty);
  });

  testWidgets('only a draft offers deletion', (tester) async {
    // Two Meals rather than four: the claim is about status, and four rows led
    // by a 34px price do not fit above the talk dock on a test surface.
    final repo = FakeMealRepository(meals: [_draft, _published]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _openActions(tester, row: 0);
    expect(find.text(l10n.mealDeleteDraft('other')), findsOneWidget);
    await _closeSheet(tester);

    await _openActions(tester, row: 1);
    expect(find.text(l10n.mealDeleteDraft('other')), findsNothing);
  });

  testWidgets(
      'deleting a draft takes one confirmation and deletes the right one',
      (tester) async {
    final repo = FakeMealRepository(meals: [_draft]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(repo.lastDeletedMealId, isNull);

    await _openActions(tester);
    await tester.tap(find.text(l10n.mealDeleteDraft('other')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mealDeleteDraftWarning('other')), findsOneWidget);
    expect(repo.lastDeletedMealId, isNull);

    await tester.tap(find.text(l10n.mealDeleteDraftConfirm('other')));
    await tester.pumpAndSettle();

    expect(repo.lastDeletedMealId, _draft.id);
  });

  testWidgets('deleting a draft emits no event at all', (tester) async {
    final repo = FakeMealRepository(meals: [_draft]);
    final events = <({String name, Map<String, Object> attributes})>[];
    debugEventRecorder = (name, attributes) {
      events.add((name: name, attributes: attributes));
    };

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _openActions(tester);
    await tester.tap(find.text(l10n.mealDeleteDraft('other')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.mealDeleteDraftConfirm('other')));
    await tester.pumpAndSettle();

    expect(events, isEmpty);
  });

  // The defect this catches: a half-answered draft used to throw inside
  // _fromRow, turn the whole load into mealLoadError, and hide every Meal.
  testWidgets('a half-answered draft renders instead of breaking the list',
      (tester) async {
    final repo = FakeMealRepository(meals: [_halfDraft, _published]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text(_halfDraft.title!), findsOneWidget);
    expect(find.text(_published.title!), findsOneWidget);
    expect(find.text(l10n.glanceDraft), findsOneWidget);
    expect(find.text(l10n.glancePublished), findsOneWidget);
    expect(find.text(l10n.mealLoadError('other')), findsNothing);
    expect(find.byType(MyMealRow), findsNWidgets(2));
  });

  testWidgets('a draft with no price says so rather than rendering "null"',
      (tester) async {
    final repo = FakeMealRepository(meals: [_halfDraft]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text(l10n.myMealsNoPriceYet), findsOneWidget);

    final texts = tester.widgetList<Text>(find.byType(Text));
    for (final text in texts) {
      final data = text.data ?? text.textSpan?.toPlainText() ?? '';
      expect(data.contains('null'), isFalse, reason: 'found "null" in: $data');
    }
  });

  testWidgets(
      'a half-answered draft offers deletion but no availability action',
      (tester) async {
    final repo = FakeMealRepository(meals: [_halfDraft]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _openActions(tester);
    expect(find.text(l10n.mealDeleteDraft('other')), findsOneWidget);
    expect(find.text(l10n.mealMakeUnavailable('other')), findsNothing);
    expect(find.text(l10n.mealMakeAvailable('other')), findsNothing);
    expect(find.text(l10n.mealRetire('other')), findsNothing);
    // Editing needs a complete Meal, which a half-answered draft is not.
    expect(find.text(l10n.mealEditTitle('other')), findsNothing);
  });

  // The schema dropped NOT NULL from title along with the other four answers,
  // so a title-less row is possible even though today's only insert path always
  // supplies one. The row mapper must not be able to throw on ANY column: it
  // runs over every row, so one bad cast takes down the Cook's whole list
  // rather than the single entry it could not read.
  testWidgets('a draft with no title yet is named, not left blank',
      (tester) async {
    const untitled = CookMeal(
      id: 'm-untitled',
      cookId: 'c1',
      status: MealStatus.draft,
      nutritionSource: NutritionSource.ai,
    );
    final repo = FakeMealRepository(meals: [untitled, _published]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text(l10n.myMealsUntitledDraft), findsOneWidget);
    expect(find.text(l10n.mealLoadError('other')), findsNothing);
    expect(find.byType(MyMealRow), findsNWidgets(2));

    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(rendered, isNot(contains('null')));
  });

  // --- T097: Resume a draft from the list ------------------------------------

  testWidgets('only a draft offers to be carried on', (tester) async {
    final repo = FakeMealRepository(meals: [_draft, _published]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _openActions(tester, row: 0);
    expect(find.text(l10n.mealResumeDraft('other')), findsOneWidget);
    await _closeSheet(tester);

    await _openActions(tester, row: 1);
    expect(find.text(l10n.mealResumeDraft('other')), findsNothing);
  });

  testWidgets('tapping it hands the draft to the caller and seeds nothing',
      (tester) async {
    // THIS TEST USED TO ASSERT THE BUG, AND ITS OWN SETUP SAID SO.
    //
    // It was called "tapping it seeds the conversation and calls back", and to
    // make that pass it wrapped the screen in a `Consumer` that did nothing but
    //
    //     // Keep the controller alive so resume does not dispose it.
    //     ref.watch(mealConversationControllerProvider);
    //
    // The conversation controller is autoDispose. That line is a listener the
    // real app does not have, added so the seeding would survive long enough to
    // be asserted. In `home.dart` nothing watches the provider at that moment,
    // so the seeded draft was disposed before the conversation route was built
    // and the Cook was asked the first question again — 2026-08-11, on a Meal
    // whose answers were all still in the database.
    //
    // A test that props up the code under test is worse than no test: it reports
    // green about a world it built for itself. The draft travels as an argument
    // now, and `MealConversationScreen` seeds from it inside the route that
    // watches the provider.
    CookMeal? callbackMeal;
    final repo = FakeMealRepository(meals: [_draft]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(repo),
          aiProviderProvider.overrideWithValue(StubAiProvider({})),
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
          // NO Consumer keeping anything alive. This is the tree the app has.
          home: MyMealsScreen(
            onResumeDraft: (meal) => callbackMeal = meal,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _openActions(tester);
    await tester.tap(find.text(l10n.mealResumeDraft('other')));
    await tester.pumpAndSettle();

    expect(callbackMeal, isNotNull);
    expect(
      callbackMeal!.id,
      _draft.id,
      reason: 'the whole draft travels, because the caller is what carries it '
          'into the route that can hold it',
    );
    expect(
      repo.updateDraftCalls,
      0,
      reason: 'resuming reads; it writes nothing',
    );
  });
}
