import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/kitchen_profile/application/voice_input.dart';
import 'package:kafoo_mobile/features/kitchen_profile/data/kitchen_profile_repository.dart';
import 'package:kafoo_mobile/features/kitchen_profile/presentation/conversation.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';

/// Records every write it is asked to make, so a test can assert that an
/// abandoned conversation asked for none.
class _RecordingRepository implements KitchenProfileRepository {
  int createCalls = 0;
  int uploadCalls = 0;

  @override
  Future<Result<KitchenProfile?, AppError>> findMine() async =>
      const Success(null);

  @override
  Future<Result<KitchenProfile, AppError>> create({
    required String displayName,
    required String story,
    required String area,
    required String deliveryTerms,
    String? photoPath,
  }) async {
    createCalls++;
    return Success(KitchenProfile(
      id: 'test-id',
      cookId: 'test-cook',
      displayName: displayName,
      story: story,
      area: area,
      deliveryTerms: deliveryTerms,
      photoPath: photoPath,
    ));
  }

  @override
  Future<Result<String, AppError>> uploadPhoto(Uint8List bytes) async {
    uploadCalls++;
    return const Success('test-cook/kitchen.jpg');
  }
}

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
    final repo = _RecordingRepository();
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
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'إجابة $step');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    }

    // All four answered — the conversation has handed off to the summary,
    // so no question remains on screen.
    expect(find.byType(ConversationQuestion), findsNothing);
  });

  // T041 / FR-013, FR-015: nothing is kept until the Cook confirms.
  testWidgets('an abandoned conversation writes nothing', (tester) async {
    final repo = _RecordingRepository();
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
    final repo = _RecordingRepository();
    await tester.pumpWidget(_testApp(
      KitchenConversationScreen(
        repository: repo,
        pickPhoto: () async => null,
        voiceInput: _UnavailableVoiceInput(),
      ),
    ));
    await tester.pumpAndSettle();

    for (var step = 0; step < ConversationStepId.values.length; step++) {
      await tester.enterText(find.byType(TextField), 'إجابة $step');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    }

    // The summary is on screen; the Cook has not confirmed.
    expect(repo.createCalls, 0);
  });
}
