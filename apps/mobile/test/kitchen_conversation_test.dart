import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ai/ai.dart';
import 'package:kafoo_mobile/features/conversation/application/voice_input.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output_provider.dart';
import 'package:kafoo_mobile/features/kitchen_profile/application/kitchen_conversation_controller.dart';
import 'package:kafoo_mobile/features/kitchen_profile/presentation/conversation.dart';
import 'package:kafoo_mobile/features/meal/data/ai_provider.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';
import 'package:kafoo_ui/ui.dart';

import 'support/fake_kitchen_profile_repository.dart';

/// THE KITCHEN PROFILE CONVERSATION, WHICH WAS FIVE QUESTIONS UNTIL 2026-08-14.
///
/// Display name, then story, then area, then delivery terms, then how to
/// address her — one per screen, in that order, with a summary at the end. It
/// was the second thing a new Cook ever met, right after being told the product
/// talks to her.
///
/// The tests this file replaces asserted the sequence: that no screen showed two
/// unanswered questions, that question two followed question one. There is no
/// sequence left to assert. What survives is the part that was never about the
/// wizard — **nothing is written until she says «أيوة»** — plus the rules
/// ADR-0015 puts in its place.
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

/// One turn of the assistant, with whatever it captured.
StubAiProvider _talk(String json) =>
    StubAiProvider({'kitchen-conversation': json});

const _everything = '{"say":"تمام، كله واضح.","captured":{'
    '"display_name":"مطبخ أم علي",'
    '"story":"بنطبخ أكل بيتي على الطريقة القديمة",'
    '"area":"المعادي",'
    '"delivery_terms":"بنوصّل في ساعة",'
    '"address_form":"feminine"}}';

Widget _app({
  required FakeKitchenProfileRepository repo,
  AiProvider? ai,
  SpeechOutput? speech,
}) =>
    ProviderScope(
      overrides: [
        kitchenProfileRepositoryProvider.overrideWithValue(repo),
        speechOutputProvider.overrideWithValue(speech ?? FakeSpeechOutput()),
        aiProviderProvider.overrideWithValue(ai ?? StubAiProvider(const {})),
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
        home: KitchenConversationScreen(
          pickPhoto: () async => null,
          voiceInput: _UnavailableVoiceInput(),
        ),
      ),
    );

/// Says one thing, the way a Cook does: ask for the box, type, send.
Future<void> _say(
    WidgetTester tester, String words, AppLocalizations l10n) async {
  final typeButton = find.byKey(const ValueKey('kitchen-talk-type'));
  if (typeButton.evaluate().isNotEmpty) {
    await tester.ensureVisible(typeButton);
    await tester.pumpAndSettle();
    await tester.tap(typeButton);
    await tester.pumpAndSettle();
  }
  final box = find.byKey(const ValueKey('kitchen-talk-box'));
  await tester.ensureVisible(box);
  await tester.pumpAndSettle();
  await tester.enterText(box, words);
  final send = find.widgetWithText(FilledButton, l10n.kitchenTalkSend);
  await tester.ensureVisible(send);
  await tester.pumpAndSettle();
  await tester.tap(send);
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  testWidgets('the assistant opens by talking, not by asking question one',
      (tester) async {
    final repo = FakeKitchenProfileRepository();
    final speech = FakeSpeechOutput();
    await tester.pumpWidget(_app(repo: repo, speech: speech));
    await tester.pumpAndSettle();

    // Said aloud, because a Cook who does not read comfortably meets a screen
    // that talks first.
    expect(speech.spoken.map((s) => s.line),
        contains(l10n.kitchenTalkOpening('other')));
    expect(find.text(l10n.kitchenTalkOpening('other')), findsOneWidget);

    // The orb owns the screen, and typing is not on it until she asks.
    expect(find.byType(KafooTalkButton), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('everything she says in one sentence is kept, in any order',
      (tester) async {
    // THE WHOLE OF ADR-0015 IN ONE ASSERTION. The wizard would have taken five
    // screens to collect this; she says it once and the receipt fills in.
    final repo = FakeKitchenProfileRepository();
    await tester.pumpWidget(_app(repo: repo, ai: _talk(_everything)));
    await tester.pumpAndSettle();

    await _say(
      tester,
      'أنا أم علي من المعادي، بطبخ أكل بيتي وبوصّل في ساعة',
      l10n,
    );

    expect(find.text('مطبخ أم علي'), findsOneWidget);
    expect(find.text('المعادي'), findsOneWidget);
    expect(find.text('بنوصّل في ساعة'), findsOneWidget);
    // And still nothing in the database.
    expect(repo.createCalls, 0);
  });

  testWidgets('an abandoned conversation writes nothing', (tester) async {
    // Unchanged from the wizard, and the reason is unchanged too: a Kitchen
    // Profile has no draft state, so a Cook who walks away has told a stranger
    // about herself and Kafoo kept none of it.
    final repo = FakeKitchenProfileRepository();
    await tester.pumpWidget(_app(repo: repo, ai: _talk(_everything)));
    await tester.pumpAndSettle();

    await _say(tester, 'أنا أم علي من المعادي', l10n);

    expect(repo.createCalls, 0);
    expect(repo.updateCalls, 0);
  });

  testWidgets('the kitchen is created only after she hears it read back',
      (tester) async {
    final repo = FakeKitchenProfileRepository();
    await tester.pumpWidget(_app(repo: repo, ai: _talk(_everything)));
    await tester.pumpAndSettle();

    await _say(tester, 'أنا أم علي من المعادي', l10n);

    final create = find.byKey(const ValueKey('kitchen-create'));
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();

    // The gate is on screen and nothing has been written by reaching it.
    expect(find.byType(KafooConfirmationGate), findsOneWidget);
    expect(find.text(l10n.kitchenGateQuestion), findsOneWidget);
    expect(repo.createCalls, 0);
    // Silence never confirms, and the screen says so.
    expect(find.text(l10n.gateSilenceFootnote('other')), findsOneWidget);

    await tester.tap(find.text(l10n.kitchenGateYes('other')));
    await tester.pumpAndSettle();

    expect(repo.createCalls, 1);
  });

  testWidgets('«لأ» at the gate writes nothing and keeps what she said',
      (tester) async {
    final repo = FakeKitchenProfileRepository();
    await tester.pumpWidget(_app(repo: repo, ai: _talk(_everything)));
    await tester.pumpAndSettle();

    await _say(tester, 'أنا أم علي من المعادي', l10n);

    final create = find.byKey(const ValueKey('kitchen-create'));
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.gateAnswerNo));
    await tester.pumpAndSettle();

    expect(repo.createCalls, 0);
    expect(find.byType(KafooConfirmationGate), findsNothing);
    // Everything she said is still there. Refusing to create the kitchen is not
    // the same as losing the conversation.
    expect(find.text('مطبخ أم علي'), findsOneWidget);
  });

  testWidgets('creating is refused while anything is still missing',
      (tester) async {
    final repo = FakeKitchenProfileRepository();
    await tester.pumpWidget(_app(
      repo: repo,
      ai: _talk('{"say":"تمام.","captured":{"display_name":"مطبخ أم علي"}}'),
    ));
    await tester.pumpAndSettle();

    await _say(tester, 'مطبخ أم علي', l10n);

    final create = find.byKey(const ValueKey('kitchen-create'));
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(create).onPressed,
      isNull,
      reason: 'The database requires every column; a half-said kitchen cannot '
          'be created and the control must say so rather than failing later.',
    );
    expect(find.text(l10n.kitchenTalkMissingNote('other')), findsOneWidget);
  });

  testWidgets('the assistant paraphrases and never shows a transcript',
      (tester) async {
    // ADR-0013 rule 2. A transcript hides a misunderstanding from exactly the
    // person who cannot read it.
    final repo = FakeKitchenProfileRepository();
    await tester.pumpWidget(_app(repo: repo, ai: _talk(_everything)));
    await tester.pumpAndSettle();

    const said = 'أنا أم علي من المعادي، بطبخ أكل بيتي';
    await _say(tester, said, l10n);

    expect(find.text('تمام، كله واضح.'), findsOneWidget);
    expect(find.text(said), findsNothing);
  });

  testWidgets('a turn that fails keeps her words in the box', (tester) async {
    final repo = FakeKitchenProfileRepository();
    // No reply registered for this prompt id, so the turn fails the way a
    // dropped connection does.
    await tester.pumpWidget(_app(repo: repo, ai: StubAiProvider(const {})));
    await tester.pumpAndSettle();

    await _say(tester, 'أنا أم علي من المعادي', l10n);

    // Making her say it again because the network dropped is the cost this
    // product can least afford.
    expect(find.text('أنا أم علي من المعادي'), findsOneWidget);
  });
}
