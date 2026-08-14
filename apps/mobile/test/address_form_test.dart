import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ai/ai.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/analytics/emit_event.dart';
import 'package:kafoo_mobile/features/conversation/application/voice_input.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output_provider.dart';
import 'package:kafoo_mobile/features/kitchen_profile/application/kitchen_conversation_controller.dart';
import 'package:kafoo_mobile/features/kitchen_profile/presentation/conversation.dart';
import 'package:kafoo_mobile/features/meal/data/ai_provider.dart';
import 'package:kafoo_mobile/l10n/address_form.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';

import 'support/fake_kitchen_profile_repository.dart';

/// ADR-0010, T090 and T092: Kafoo addressed every Cook as a man because Arabic
/// conjugates the second person and the app never asked. These tests are the
/// proof that it now asks, that the answer is stored, and that the answer
/// changes the words on screen — a conversion of eighty-odd strings that
/// nothing renders in the feminine is a conversion nobody can trust.
///
/// The assertions look for the **verb ending**, which is the whole difference:
/// بتشتغل addresses a man, بتشتغلي a woman. Undiacritized Egyptian spells the
/// past tense and the possessive identically for both, so a test that picked one
/// of those strings would pass in either form and measure nothing.
///
/// **THE FIFTH QUESTION IS GONE AND THE FACT IS NOT.** It used to be a screen of
/// its own at the end of a wizard. It is now a row on the receipt with both
/// endings always offered, and she can also just say «أنا ست» — so the tests
/// below assert the fact reaches the database, not that a question was asked.
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

const _everythingButTheForm = '{"say":"تمام، كله واضح.","captured":{'
    '"display_name":"مطبخ أم علي",'
    '"story":"بنطبخ أكل بيتي",'
    '"area":"المعادي",'
    '"delivery_terms":"بنوصّل في ساعة"}}';

Widget _testApp(
  FakeKitchenProfileRepository repo, {
  String? form,
  AiProvider? ai,
}) {
  final screen = KitchenConversationScreen(
    pickPhoto: () async => null,
    voiceInput: _UnavailableVoiceInput(),
  );
  return ProviderScope(
    overrides: [
      kitchenProfileRepositoryProvider.overrideWithValue(repo),
      speechOutputProvider.overrideWithValue(FakeSpeechOutput()),
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
      home: form == null ? screen : AddressFormScope(form: form, child: screen),
    ),
  );
}

Future<void> _say(
  WidgetTester tester,
  String words,
  AppLocalizations l10n,
  String form,
) async {
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

/// Answers the read-back gate with «أيوة».
Future<void> _createAndConfirm(
  WidgetTester tester,
  AppLocalizations l10n,
  String form,
) async {
  final create = find.byKey(const ValueKey('kitchen-create'));
  await tester.ensureVisible(create);
  await tester.pumpAndSettle();
  await tester.tap(create);
  await tester.pumpAndSettle();
  await tester.tap(find.text(l10n.kitchenGateYes(form)));
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  group('icuAddressForm', () {
    test('feminine is the only value that leaves the other branch', () {
      expect(icuAddressForm(AddressForm.feminine), 'feminine');
      expect(icuAddressForm(AddressForm.masculine), 'other');
      // A Cook who was never asked, and anyone who is not a Cook at all.
      expect(icuAddressForm(null), 'other');
    });
  });

  testWidgets('with no scope in the tree, a Cook is addressed as a man',
      (tester) async {
    await tester.pumpWidget(_testApp(FakeKitchenProfileRepository()));
    await tester.pumpAndSettle();

    // The opening line, masculine: «بتطبخ إيه وانت فين؟»
    expect(find.textContaining('بتطبخ إيه'), findsOneWidget);
    expect(find.textContaining('بتطبخي إيه'), findsNothing);
  });

  testWidgets('under a feminine scope, the same screen conjugates for a woman',
      (tester) async {
    await tester.pumpWidget(_testApp(
      FakeKitchenProfileRepository(),
      form: 'feminine',
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('بتطبخي إيه'), findsOneWidget);

    // The orb's label too, so this is the placeholder being supplied rather
    // than one string that happened to be written in the feminine.
    expect(find.text(l10n.kitchenTalkPress('feminine')), findsOneWidget);
  });

  group('the form of address', () {
    // Creating writes, so it emits. Without this seam emitEvent reaches for
    // Supabase.instance and the test dies on the assertion instead of on the
    // thing it is measuring.
    setUp(() => debugEventRecorder = (_, __) {});
    tearDown(() => debugEventRecorder = null);

    testWidgets('both endings are offered on the receipt, always',
        (tester) async {
      await tester.pumpWidget(_testApp(FakeKitchenProfileRepository()));
      await tester.pumpAndSettle();

      // No edit button to press first: a mis-tap on this value follows her for
      // the life of her account, so changing it is always one tap.
      expect(find.text('كمّل'), findsOneWidget);
      expect(find.text('كمّلي'), findsOneWidget);
    });

    testWidgets('tapping an ending reaches the repository', (tester) async {
      final repo = FakeKitchenProfileRepository();
      await tester.pumpWidget(_testApp(
        repo,
        ai: StubAiProvider(
          const {'kitchen-conversation': _everythingButTheForm},
        ),
      ));
      await tester.pumpAndSettle();

      await _say(tester, 'أنا أم علي من المعادي', l10n, 'other');
      await tester.tap(find.text('كمّلي'));
      await tester.pumpAndSettle();

      // Nothing written yet (FR-015).
      expect(repo.createCalls, 0);

      await _createAndConfirm(tester, l10n, 'other');

      expect(repo.createCalls, 1);
      expect(repo.createdAddressForm, AddressForm.feminine);
    });

    testWidgets('saying it reaches the repository the same way tapping does',
        (tester) async {
      // ADR-0013: tap is a complete alternative to speaking, which means the
      // two paths must write the identical thing. This is the half nobody could
      // test while the answer was a screen with two buttons on it.
      final repo = FakeKitchenProfileRepository();
      await tester.pumpWidget(_testApp(
        repo,
        ai: StubAiProvider(const {
          'kitchen-conversation': '{"say":"تمام يا أم علي.","captured":{'
              '"display_name":"مطبخ أم علي",'
              '"story":"بنطبخ أكل بيتي",'
              '"area":"المعادي",'
              '"delivery_terms":"بنوصّل في ساعة",'
              '"address_form":"feminine"}}',
        }),
      ));
      await tester.pumpAndSettle();

      await _say(tester, 'أنا ست، أم علي من المعادي', l10n, 'other');
      await _createAndConfirm(tester, l10n, 'other');

      expect(repo.createdAddressForm, AddressForm.feminine);
    });

    testWidgets('changing the answer after saying it costs one tap',
        (tester) async {
      final repo = FakeKitchenProfileRepository();
      await tester.pumpWidget(_testApp(
        repo,
        ai: StubAiProvider(const {
          'kitchen-conversation': '{"say":"تمام.","captured":{'
              '"display_name":"مطبخ أم علي",'
              '"story":"بنطبخ أكل بيتي",'
              '"area":"المعادي",'
              '"delivery_terms":"بنوصّل في ساعة",'
              '"address_form":"masculine"}}',
        }),
      ));
      await tester.pumpAndSettle();

      await _say(tester, 'أنا أم علي من المعادي', l10n, 'other');
      await tester.tap(find.text('كمّلي'));
      await tester.pumpAndSettle();
      await _createAndConfirm(tester, l10n, 'other');

      expect(repo.createdAddressForm, AddressForm.feminine);
    });
  });
}
