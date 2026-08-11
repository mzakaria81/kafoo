import 'package:kafoo_domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('ConfirmationGate', () {
    test('silence never confirms', () {
      // The single most important rule in the voice system, and the reason this
      // class has no timeout, no default and no auto-resolve: there is no code
      // path that turns an unanswered gate into a yes.
      final gate = ConfirmationGate(spokenReadback: 'تنشر المحشي بمية وعشرين؟');
      expect(gate.isAnswered, isFalse);
      expect(gate.isConfirmed, isFalse);

      gate.reprompt();
      expect(gate.isAnswered, isFalse);
      expect(gate.isConfirmed, isFalse);
    });

    test('an explicit yes confirms and an explicit no does not', () {
      final yes = ConfirmationGate(spokenReadback: '...')
        ..answer(confirmed: true);
      final no = ConfirmationGate(spokenReadback: '...')
        ..answer(confirmed: false);

      expect(yes.isConfirmed, isTrue);
      expect(no.isConfirmed, isFalse);
      expect(no.isAnswered, isTrue, reason: 'a no is an answer, not silence');
    });

    test('the first answer stands', () {
      // A second «أيوة» while the Meal is already publishing must not publish a
      // second one.
      final gate = ConfirmationGate(spokenReadback: '...')
        ..answer(confirmed: false)
        ..answer(confirmed: true);
      expect(gate.isConfirmed, isFalse);
    });

    test('the question repeats exactly once', () {
      final gate = ConfirmationGate(spokenReadback: '...');
      expect(gate.reprompt(), isTrue);
      expect(gate.reprompt(), isFalse);
      expect(gate.hasReprompted, isTrue);
    });

    test('an answered gate does not go on asking', () {
      final gate = ConfirmationGate(spokenReadback: '...')
        ..answer(confirmed: true);
      expect(gate.reprompt(), isFalse);
    });

    test('the reprompt waits eight seconds by default', () {
      expect(
        ConfirmationGate(spokenReadback: '...').repromptAfter,
        const Duration(seconds: 8),
      );
    });
  });

  group('RecognitionLadder', () {
    test('descends exactly three rungs', () {
      final ladder = RecognitionLadder();
      expect(ladder.rung, RecognitionRung.askAgain);
      expect(ladder.descend(), RecognitionRung.narrowQuestion);
      expect(ladder.descend(), RecognitionRung.tapFallback);
    });

    test('never climbs back and never loops', () {
      // A fourth failure that returned to "say it again" would have a Cook
      // repeating herself to an app that has already failed three times.
      final ladder = RecognitionLadder()
        ..descend()
        ..descend();
      expect(ladder.isExhausted, isTrue);
      for (var i = 0; i < 5; i++) {
        expect(ladder.descend(), RecognitionRung.tapFallback);
      }
      expect(ladder.rung, RecognitionRung.tapFallback);
    });

    test('only being understood resets it', () {
      final ladder = RecognitionLadder()..descend();
      expect(ladder.rung, RecognitionRung.narrowQuestion);
      ladder.succeeded();
      expect(ladder.rung, RecognitionRung.askAgain);
      expect(ladder.isExhausted, isFalse);
    });

    test('the bottom rung is tapping, and there is nothing below it', () {
      // Never a keyboard. Typing Arabic on a phone is the hardest thing this
      // product could ask of a Cook, and it is never a consequence of failure.
      expect(RecognitionRung.values.last, RecognitionRung.tapFallback);
      expect(RecognitionRung.values, hasLength(3));
    });
  });

  group('VoiceState', () {
    test('all nine states exist', () {
      expect(VoiceState.values, hasLength(9));
    });

    test('every state that is not silent carries a haptic', () {
      // Every state reaches the user three ways, and any one alone must do.
      // Idle and thinking are the two that legitimately buzz nothing: idle is
      // the resting state, and thinking follows a press that already buzzed.
      for (final state in VoiceState.values) {
        if (state == VoiceState.idle || state == VoiceState.thinking) continue;
        expect(
          state.haptic,
          isNot(VoiceHaptic.none),
          reason: '$state must be perceivable with the screen face-down',
        );
      }
    });

    test('the assistant never talks while the microphone is live', () {
      // Otherwise the recogniser hears the assistant, and the user hears
      // themselves being talked over.
      for (final state in VoiceState.values) {
        expect(
          state.assistantIsSpeaking && state.microphoneIsLive,
          isFalse,
          reason: '$state has both the speaker and the microphone open',
        );
      }
    });

    test('exactly the states that record say they are recording', () {
      // What a recording indicator reads. There is no silent listening, so a
      // state that opens the microphone without reporting it is a privacy bug,
      // not a display bug.
      expect(
        VoiceState.values.where((s) => s.microphoneIsLive).toSet(),
        {VoiceState.listening, VoiceState.tooNoisy},
      );
    });
  });

  group('VoiceTiming', () {
    test('acknowledgement comes before the thinking state', () {
      expect(VoiceTiming.acknowledge, lessThan(VoiceTiming.thinkingVisible));
    });

    test('there is never a silent, still moment after a press', () {
      // 150ms is the threshold at which a press stops feeling connected to its
      // effect; 400ms is where an unexplained pause starts reading as broken.
      expect(VoiceTiming.acknowledge.inMilliseconds, lessThanOrEqualTo(150));
      expect(
          VoiceTiming.thinkingVisible.inMilliseconds, lessThanOrEqualTo(400));
    });

    test('a slipped thumb does not end a recording', () {
      expect(VoiceTiming.releaseGrace.inMilliseconds, greaterThan(0));
      expect(VoiceTiming.slipExtension, greaterThan(VoiceTiming.releaseGrace));
    });
  });

  test('undo outlives the gate', () {
    // The gate stops a mistake; undo forgives one that got through. Two
    // minutes, even for actions the product calls irreversible.
    expect(voiceUndoWindow, const Duration(minutes: 2));
  });
}
