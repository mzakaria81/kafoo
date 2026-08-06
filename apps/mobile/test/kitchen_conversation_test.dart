import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/conversation/application/voice_input.dart';
import 'package:kafoo_mobile/features/conversation/presentation/conversation_question.dart';
import 'package:kafoo_mobile/features/kitchen_profile/presentation/conversation.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';

import 'support/fake_kitchen_profile_repository.dart';

/// Recognition unavailable — the state a Cook on a handset with no `ar-EG`
/// engine lands in, and the one the conversation must survive by falling back
/// to typing (T034).
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

/// Answers whatever question is on screen, whether it is typed or chosen.
///
/// The last step offers two buttons instead of a text field, so a walk that
/// assumed a TextField at every step would stop one question short of the end
/// — and would have reported the conversation finished when it had not.
Future<void> _answerCurrentStep(WidgetTester tester, String text) async {
  if (find.byType(TextField).evaluate().isEmpty) {
    // The form-of-address step. Either button completes it; masculine is first.
    await tester.tap(find.byType(FilledButton).first);
  } else {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.byType(FilledButton));
  }
  await tester.pumpAndSettle();
}

Widget _testApp(Widget child) {
  return MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

void main() {
  // T040 / SC-006: the conversation asks one thing at a time. A form asks
  // four; this asserts the difference is real and not just visual.
  testWidgets('no screen in the conversation shows two unanswered questions',
      (tester) async {
    final repo = FakeKitchenProfileRepository();
    await tester.pumpWidget(_testApp(
      KitchenConversationScreen(
        repository: repo,
        pickPhoto: () async => null,
        voiceInput: _UnavailableVoiceInput(),
      ),
    ));
    await tester.pumpAndSettle();

    // Walk the whole conversation, asserting the invariant at every step.
    for (var step = 0; step < ConversationStepId.values.length; step++) {
      expect(
        find.byType(ConversationQuestion),
        findsOneWidget,
        reason: 'step $step showed more than one unanswered question',
      );
      // Exactly one way to answer, whichever kind of question it is: one text
      // field, or the two choices and no text field.
      final isChoice = step == ConversationStepId.values.length - 1;
      expect(find.byType(TextField), isChoice ? findsNothing : findsOneWidget);

      await _answerCurrentStep(tester, 'إجابة $step');
    }

    // All five answered — the conversation has handed off to the summary,
    // so no question remains on screen.
    expect(find.byType(ConversationQuestion), findsNothing);
  });

  // T041 / FR-013, FR-015: nothing is kept until the Cook confirms.
  testWidgets('an abandoned conversation writes nothing', (tester) async {
    final repo = FakeKitchenProfileRepository();
    await tester.pumpWidget(_testApp(
      KitchenConversationScreen(
        repository: repo,
        pickPhoto: () async => null,
        voiceInput: _UnavailableVoiceInput(),
      ),
    ));
    await tester.pumpAndSettle();

    // Answer two of the four questions, then walk away.
    for (var step = 0; step < 2; step++) {
      await tester.enterText(find.byType(TextField), 'إجابة $step');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    }

    // Tear the screen down mid-conversation, exactly as abandoning it does.
    await tester.pumpWidget(_testApp(const SizedBox()));
    await tester.pumpAndSettle();

    expect(repo.createCalls, 0);
    expect(repo.uploadCalls, 0);
  });

  // The summary is reached only after every question is answered, and even
  // then nothing is written until confirm is pressed.
  testWidgets('reaching the summary still writes nothing before confirming',
      (tester) async {
    final repo = FakeKitchenProfileRepository();
    await tester.pumpWidget(_testApp(
      KitchenConversationScreen(
        repository: repo,
        pickPhoto: () async => null,
        voiceInput: _UnavailableVoiceInput(),
      ),
    ));
    await tester.pumpAndSettle();

    for (var step = 0; step < ConversationStepId.values.length; step++) {
      await _answerCurrentStep(tester, 'إجابة $step');
    }

    // The summary is on screen; the Cook has not confirmed.
    expect(repo.createCalls, 0);
  });
}
