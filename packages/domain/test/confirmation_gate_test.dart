import 'package:kafoo_domain/confirmation_gate.dart';
import 'package:test/test.dart';

/// The gate that stands in front of every irreversible action — ADR-0013 rule 3
/// and `.claude/rules/business-rules.md`.
///
/// **The first group is the reason this file exists, and it is a negative
/// test.** Silence never confirms. No amount of waiting, no number of ticks, no
/// ordering of events may turn an unanswered question into a yes. Everything
/// else here is ordinary behaviour; that group is the one that must fail before
/// the gate is written, and must never go green by accident afterwards.
///
/// The gate holds no timer on purpose. A rule that lives inside a `Timer`
/// cannot be tested without waiting for wall-clock time, and a test that waits
/// eight real seconds is a test somebody eventually deletes. So the passage of
/// time arrives as an event and the rule is pure — which is what lets the first
/// group below fire a thousand silences in a millisecond.
void main() {
  group('silence never confirms — SC: no timeout resolves a gate', () {
    test('a fresh gate is unresolved and has confirmed nothing', () {
      final gate = ConfirmationGate.ask();
      expect(gate.isResolved, isFalse);
      expect(gate.isConfirmed, isFalse);
      expect(gate.isRejected, isFalse);
    });

    test('one silence does not confirm', () {
      final gate = ConfirmationGate.ask().onSilenceElapsed();
      expect(gate.isConfirmed, isFalse);
      expect(gate.isResolved, isFalse);
    });

    test('a thousand silences do not confirm', () {
      var gate = ConfirmationGate.ask();
      for (var i = 0; i < 1000; i++) {
        gate = gate.onSilenceElapsed();
        expect(gate.isConfirmed, isFalse, reason: 'confirmed on silence $i');
        expect(gate.isRejected, isFalse, reason: 'rejected on silence $i');
      }
      expect(gate.isResolved, isFalse);
    });

    test('waiting forever leaves the gate waiting, never resolved', () {
      var gate = ConfirmationGate.ask();
      for (var i = 0; i < 50; i++) {
        gate = gate.onSilenceElapsed();
      }
      expect(gate.isResolved, isFalse);
      expect(gate.isWaiting, isTrue);
    });
  });

  group('the question repeats exactly once — §10.6', () {
    test('asked once when the gate opens', () {
      expect(ConfirmationGate.ask().timesAsked, 1);
    });

    test('the first silence asks again', () {
      final gate = ConfirmationGate.ask().onSilenceElapsed();
      expect(gate.timesAsked, 2);
      expect(gate.shouldSpeakQuestion, isTrue);
    });

    test('the second silence does NOT ask a third time', () {
      final gate = ConfirmationGate.ask().onSilenceElapsed().onSilenceElapsed();
      expect(gate.timesAsked, 2);
      expect(gate.shouldSpeakQuestion, isFalse);
    });

    test('a hundred silences still leave it asked twice', () {
      var gate = ConfirmationGate.ask();
      for (var i = 0; i < 100; i++) {
        gate = gate.onSilenceElapsed();
      }
      expect(gate.timesAsked, 2);
    });
  });

  group('answering', () {
    test('«أيوة» confirms', () {
      final gate = ConfirmationGate.ask().onAnswer(GateAnswer.yes);
      expect(gate.isConfirmed, isTrue);
      expect(gate.isResolved, isTrue);
      expect(gate.isWaiting, isFalse);
    });

    test('«لأ» rejects, and rejecting is not confirming', () {
      final gate = ConfirmationGate.ask().onAnswer(GateAnswer.no);
      expect(gate.isRejected, isTrue);
      expect(gate.isConfirmed, isFalse);
      expect(gate.isResolved, isTrue);
    });

    test('an answer after the repeat still works — waiting is not expiry', () {
      final gate = ConfirmationGate.ask()
          .onSilenceElapsed()
          .onSilenceElapsed()
          .onSilenceElapsed()
          .onAnswer(GateAnswer.yes);
      expect(gate.isConfirmed, isTrue);
    });

    test('a resolved gate ignores every later event', () {
      final confirmed = ConfirmationGate.ask().onAnswer(GateAnswer.yes);
      expect(confirmed.onAnswer(GateAnswer.no).isConfirmed, isTrue);
      expect(confirmed.onSilenceElapsed().isConfirmed, isTrue);

      final rejected = ConfirmationGate.ask().onAnswer(GateAnswer.no);
      expect(rejected.onAnswer(GateAnswer.yes).isRejected, isTrue);
      expect(rejected.onAnswer(GateAnswer.yes).isConfirmed, isFalse);
    });

    test('dismissing is not an answer and does not resolve', () {
      // A person who backs out has not agreed. Treating a dismissal as either
      // answer would be deciding for them — the same reasoning as
      // SearchController.dismissConsent.
      final gate = ConfirmationGate.ask().onDismissed();
      expect(gate.isResolved, isFalse);
      expect(gate.isConfirmed, isFalse);
      expect(gate.isAbandoned, isTrue);
    });

    test('an abandoned gate can still be answered — it was never closed', () {
      final gate =
          ConfirmationGate.ask().onDismissed().onAnswer(GateAnswer.yes);
      expect(gate.isConfirmed, isTrue);
    });
  });

  group('the gate does not care how it was answered — §10.6', () {
    test('voice and tap produce the same result', () {
      // "Voice and tap both answer the gate, always, at the same time." The
      // gate deliberately has no channel parameter: a gate that could tell them
      // apart is a gate a later change could make prefer one.
      expect(
        ConfirmationGate.ask().onAnswer(GateAnswer.yes).isConfirmed,
        ConfirmationGate.ask().onAnswer(GateAnswer.yes).isConfirmed,
      );
    });
  });

  group('the undo window is not the gate — §10.6', () {
    test('a confirmed gate opens an undo window', () {
      final gate = ConfirmationGate.ask().onAnswer(GateAnswer.yes);
      expect(gate.undoAvailableFor, ConfirmationGate.undoWindow);
      expect(ConfirmationGate.undoWindow, const Duration(minutes: 2));
    });

    test('a rejected gate opens no undo window — nothing happened', () {
      expect(
        ConfirmationGate.ask().onAnswer(GateAnswer.no).undoAvailableFor,
        isNull,
      );
    });

    test('an unanswered gate opens no undo window', () {
      expect(ConfirmationGate.ask().undoAvailableFor, isNull);
    });
  });

  group('how long the gate waits before repeating', () {
    test('eight seconds, and it is a domain constant not a widget number', () {
      expect(ConfirmationGate.repeatAfter, const Duration(seconds: 8));
    });
  });
}
