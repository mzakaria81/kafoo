import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/analytics/emit_event.dart';
import 'package:kafoo_mobile/features/conversation/application/voice_input.dart';
import 'package:kafoo_mobile/features/kitchen_profile/presentation/conversation.dart';
import 'package:kafoo_mobile/features/kitchen_profile/presentation/conversation_summary.dart';
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
/// past tense and the possessive identically for both, so a test that picked
/// one of those strings would pass in either form and measure nothing.
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

Widget _testApp(Widget child, {String? form}) {
  final scoped =
      form == null ? child : AddressFormScope(form: form, child: child);
  return MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: scoped,
  );
}

Widget _conversation(FakeKitchenProfileRepository repo) =>
    KitchenConversationScreen(
      repository: repo,
      pickPhoto: () async => null,
      voiceInput: _UnavailableVoiceInput(),
    );

/// Scrolls the summary down to its confirm button and taps it.
///
/// The form-of-address row made the summary taller than one screen, and a
/// ListView does not build what is below the fold — so a plain find.text on the
/// confirm label reports zero widgets rather than a widget it cannot reach.
Future<void> _confirmSummary(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(find.text(label), 100);
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
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
    await tester.pumpWidget(_testApp(_conversation(
      FakeKitchenProfileRepository(),
    )));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'مطبخ أم علي');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // Second question, masculine: "قولّي عن طبخك. بتعمل إيه وبتعمله إزاي؟"
    expect(find.textContaining('بتعمل إيه'), findsOneWidget);
    expect(find.textContaining('بتعملي إيه'), findsNothing);
  });

  testWidgets('under a feminine scope, the same screen conjugates for a woman',
      (tester) async {
    await tester.pumpWidget(_testApp(
      _conversation(FakeKitchenProfileRepository()),
      form: 'feminine',
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'مطبخ أم علي');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // "قوليلي عن طبخك. بتعملي إيه وبتعمليه إزاي؟"
    expect(find.textContaining('بتعملي إيه'), findsOneWidget);

    // The third question too, so this is the placeholder being supplied rather
    // than one string that happened to be written in the feminine.
    await tester.enterText(find.byType(TextField), 'بنطبخ أكل بيتي');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('في أنهي منطقة بتشتغلي؟'), findsOneWidget);
  });

  testWidgets('the fifth question is asked, and offers both endings',
      (tester) async {
    await tester.pumpWidget(_testApp(_conversation(
      FakeKitchenProfileRepository(),
    )));
    await tester.pumpAndSettle();

    for (final answer in ['مطبخ أم علي', 'أكل بيتي', 'المعادي', 'توصيل']) {
      await tester.enterText(find.byType(TextField), answer);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    }

    // The question is built from first-person verbs, so it is the same
    // sentence whoever is reading it. Nothing to switch on, by design.
    expect(find.text('عشان أكلمك صح — أقولّك "كمّل" ولا "كمّلي"؟'),
        findsOneWidget);
    expect(find.text('كمّل'), findsOneWidget);
    expect(find.text('كمّلي'), findsOneWidget);
    // Chosen, not spoken or typed: there is nothing for a Cook to phrase.
    expect(find.byType(TextField), findsNothing);
  });

  group('the summary', () {
    // The summary writes, so it emits. Without this seam emitEvent reaches for
    // Supabase.instance and the test dies on the assertion instead of on the
    // thing it is measuring.
    setUp(() => debugEventRecorder = (_, __) {});
    tearDown(() => debugEventRecorder = null);

    KitchenProfileDraft draft(AddressForm form) => KitchenProfileDraft()
      ..displayName = 'مطبخ أم علي'
      ..story = 'بنطبخ أكل بيتي'
      ..area = 'المعادي'
      ..deliveryTerms = 'توصيل في نص ساعة'
      ..addressForm = form;

    testWidgets('carries the chosen form into the row it renders',
        (tester) async {
      await tester.pumpWidget(_testApp(KitchenConversationSummary(
        draft: draft(AddressForm.feminine),
        repository: FakeKitchenProfileRepository(),
        pickPhoto: () async => null,
      )));
      await tester.pumpAndSettle();

      // Both endings are offered, always — there is no edit button to press
      // first, because a mis-tap on the last question of the conversation is
      // the likeliest way this value goes in wrong.
      expect(find.text('كمّل'), findsOneWidget);
      expect(find.text('كمّلي'), findsOneWidget);
    });

    testWidgets('the chosen form reaches the repository on confirm',
        (tester) async {
      final repo = FakeKitchenProfileRepository();
      await tester.pumpWidget(_testApp(KitchenConversationSummary(
        draft: draft(AddressForm.feminine),
        repository: repo,
        pickPhoto: () async => null,
      )));
      await tester.pumpAndSettle();

      // Nothing written yet (FR-015).
      expect(repo.createCalls, 0);

      await _confirmSummary(tester, 'تمام، احفظ');

      expect(repo.createCalls, 1);
      expect(repo.createdAddressForm, AddressForm.feminine);
    });

    testWidgets('changing the answer here costs one tap', (tester) async {
      final repo = FakeKitchenProfileRepository();
      await tester.pumpWidget(_testApp(KitchenConversationSummary(
        draft: draft(AddressForm.masculine),
        repository: repo,
        pickPhoto: () async => null,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('كمّلي'));
      await tester.pumpAndSettle();
      await _confirmSummary(tester, 'تمام، احفظ');

      expect(repo.createdAddressForm, AddressForm.feminine);
    });
  });
}
