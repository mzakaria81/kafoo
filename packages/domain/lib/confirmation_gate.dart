/// The gate that stands in front of every irreversible action.
///
/// No Flutter, no Supabase, and **no timer** — see [onSilenceElapsed].
///
/// ADR-0013 rule 3 and `.claude/rules/business-rules.md`: a reversible action
/// executes immediately and is announced; an irreversible one is read back in
/// full and waits for «أيوة». Publishing a Meal, accepting or rejecting an
/// Order, cancelling, changing the price of a published Meal, sending a Message
/// and posting a Review are all irreversible.
///
/// **This type exists so that rule has one home.** Left to each screen it
/// becomes twenty-seven `if` statements that each remember it slightly
/// differently, and the one that forgets is invisible — it looks like a screen
/// that simply went ahead.
library;

/// How a person answered the gate.
///
/// **There is deliberately no third value and no channel.** §10.6: "Voice and
/// tap both answer the gate, always, at the same time." A gate that could tell
/// a spoken «أيوة» from a tapped one is a gate a later change could make prefer
/// one of them, and the tap path is a complete alternative rather than a
/// degraded one.
enum GateAnswer {
  /// «أيوة». The 72dp target, solid `success` — larger because agreeing is the
  /// common case.
  yes,

  /// «لأ». The 56dp target, outline only. Both are unmissable.
  no,
}

/// What has happened to the question so far.
enum _Outcome { waiting, confirmed, rejected }

/// An irreversible action, read back, waiting for an answer.
///
/// Immutable: every event returns a new gate. That is what lets a test fire a
/// thousand silences in a millisecond and assert that none of them confirmed
/// anything.
final class ConfirmationGate {
  const ConfirmationGate._({
    required _Outcome outcome,
    required this.timesAsked,
    required this.isAbandoned,
    required this.shouldSpeakQuestion,
  }) : _outcome = outcome;

  /// Opens a gate: the action has been read back once, and Kafoo is waiting.
  ///
  /// `timesAsked` starts at 1 rather than 0 because reading the action back
  /// *is* asking. A gate that opened silently would be a gate that executed
  /// without the person hearing what they were agreeing to.
  factory ConfirmationGate.ask() => const ConfirmationGate._(
        outcome: _Outcome.waiting,
        timesAsked: 1,
        isAbandoned: false,
        shouldSpeakQuestion: true,
      );

  /// How long Kafoo waits before repeating the question — §10.6.
  ///
  /// A domain constant and not a widget number: the same eight seconds governs
  /// the spoken repeat and anything drawn beside it, and two copies of it would
  /// drift.
  static const Duration repeatAfter = Duration(seconds: 8);

  /// How long an undo stays available after an irreversible action ran — §10.6.
  ///
  /// "Even for nominally irreversible actions." A Meal published by mistake is
  /// a Cook's food shown to strangers; two minutes is the design's answer to
  /// that, and it is measured from the moment the action executed rather than
  /// from the answer.
  static const Duration undoWindow = Duration(minutes: 2);

  final _Outcome _outcome;

  /// How many times the action has been read back. Never more than 2 — §10.6.
  final int timesAsked;

  /// Whether the person backed out of the question without answering it.
  ///
  /// **Not an answer, and it does not resolve the gate.** A Cook who dismisses
  /// has not agreed and has not refused; nothing executes and nothing is
  /// recorded. Treating a dismissal as either answer would be deciding for her
  /// — the same reasoning `SearchController.dismissConsent` already follows for
  /// the search-consent question.
  final bool isAbandoned;

  /// Whether the caller should speak the question now.
  ///
  /// True when the gate opens and again on the first silence. False forever
  /// after, because "the question repeats once after eight seconds, then waits
  /// indefinitely" — a third identical prompt makes the app feel stupid, which
  /// is the same reasoning behind the failure ladder in §10.7.
  final bool shouldSpeakQuestion;

  /// Whether «أيوة» was given. **The only route to true.**
  bool get isConfirmed => _outcome == _Outcome.confirmed;

  /// Whether «لأ» was given.
  bool get isRejected => _outcome == _Outcome.rejected;

  /// Whether the question has been answered either way.
  bool get isResolved => _outcome != _Outcome.waiting;

  /// Whether Kafoo is still waiting. Waiting is not expiry — a gate waits
  /// indefinitely and an answer arriving an hour later is still an answer.
  bool get isWaiting => !isResolved;

  /// How long an undo remains available, or null when nothing ran.
  ///
  /// Null on a rejected gate for the plain reason that nothing happened, so
  /// there is nothing to undo.
  Duration? get undoAvailableFor => isConfirmed ? undoWindow : null;

  /// [repeatAfter] has passed with no answer.
  ///
  /// **THIS NEVER RESOLVES THE GATE, AND THAT IS THE WHOLE POINT.** Silence
  /// never confirms; no timeout accepts. The first silence asks again, and
  /// every silence after it changes nothing at all.
  ///
  /// **The passage of time arrives as an event rather than from a `Timer`
  /// inside this class**, and that is a testability decision with a real
  /// consequence. A rule sealed inside a timer can only be tested by waiting
  /// eight real seconds, and a suite that waits is a suite somebody eventually
  /// deletes or weakens. Here `confirmation_gate_test.dart` fires a thousand
  /// silences instantly — which is how the deliberately-broken first version of
  /// this method, one that confirmed on the second tick, was caught on an
  /// assertion rather than by review.
  ConfirmationGate onSilenceElapsed() {
    if (isResolved) return this;
    final askAgain = timesAsked < 2;
    return ConfirmationGate._(
      outcome: _Outcome.waiting,
      timesAsked: askAgain ? timesAsked + 1 : timesAsked,
      isAbandoned: isAbandoned,
      shouldSpeakQuestion: askAgain,
    );
  }

  /// A person answered, by voice or by tap.
  ///
  /// An answer is accepted whatever the gate has been through — repeated,
  /// waited out, dismissed and returned to. The only thing that closes a gate
  /// is an answer, so a resolved gate ignores everything after it: a second
  /// «لأ» cannot un-publish a Meal that a «أيوة» already published, and undoing
  /// is [undoAvailableFor]'s job rather than this method's.
  ConfirmationGate onAnswer(GateAnswer answer) {
    if (isResolved) return this;
    return ConfirmationGate._(
      outcome:
          answer == GateAnswer.yes ? _Outcome.confirmed : _Outcome.rejected,
      timesAsked: timesAsked,
      isAbandoned: false,
      shouldSpeakQuestion: false,
    );
  }

  /// The person backed out without answering.
  ///
  /// Leaves the gate waiting and marks it [isAbandoned], so a screen can stop
  /// speaking without Kafoo having decided anything. Answering later still
  /// works, because backing out of a question is not the same as refusing it.
  ConfirmationGate onDismissed() {
    if (isResolved) return this;
    return ConfirmationGate._(
      outcome: _Outcome.waiting,
      timesAsked: timesAsked,
      isAbandoned: true,
      shouldSpeakQuestion: false,
    );
  }
}
