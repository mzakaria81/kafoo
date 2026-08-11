/// The voice system's rules, with no screen and no speaker attached.
///
/// Kafoo is voice-first: the assistant speaks, the user speaks back, and the
/// screen is the receipt of that exchange. Everything in this file is the part
/// of that which must be true regardless of how it looks or which engine says
/// it — so it can be tested without a phone, a microphone, or a voice.
library;

/// What the phone does in your hand, alongside what it shows and says.
///
/// Every voice state reaches the user three ways — visual, spoken, haptic —
/// and any one of them alone has to be enough. A kitchen is noisy, a street is
/// bright, and a phone may be face-down.
enum VoiceHaptic {
  none,

  /// One short pulse.
  short,

  /// Two short pulses.
  twoShort,

  /// One long pulse.
  long,
}

/// The nine states of the voice system.
///
/// Each one owes four things: a visual treatment, a spoken line in Egyptian
/// Arabic, a haptic, and a tap fallback. The haptic lives here because it is
/// the same on every screen. The spoken line lives in the ARB files, because it
/// is a string and Kafoo has no strings outside localization. The visual lives
/// in the design system.
enum VoiceState {
  /// «أنا معاك. دوسي واتكلمي.» — said once on arrival.
  idle(VoiceHaptic.none),

  /// Expanding rings and five amplitude bars, driven by the real microphone
  /// level. The assistant is silent; the user is talking.
  listening(VoiceHaptic.short),

  /// Three blinking dots. Silent, and after two seconds «لسه معاك، ثانية.»
  thinking(VoiceHaptic.none),

  /// The reply, at most three sentences, shown as well as said.
  speaking(VoiceHaptic.twoShort),

  /// «معلش، مافهمتش. قوليها تاني؟» — the failure belongs to the app.
  notHeard(VoiceHaptic.long),

  /// Only the changed value animates, and the new value is always repeated
  /// aloud.
  correcting(VoiceHaptic.twoShort),

  /// Speech stopped mid-sentence because the user started talking. No message,
  /// no apology — just back to listening.
  interrupted(VoiceHaptic.short),

  /// «مفيش نت. اللي اتكتب على الشاشة محفوظ، بس الكلام مش هيتسجل لحد ما النت
  /// يرجع.»
  ///
  /// **It does not promise that her words were kept.** Kafoo queues the
  /// transcript rather than the audio, and on-device Arabic recognition is
  /// frequently unavailable offline, so there may be nothing to keep. This
  /// comment quoted the older sentence — the one `.claude/rules/` names as the
  /// thing never to say — and whoever wires this state up reads it here.
  offlineQueued(VoiceHaptic.long),

  /// «الدوشة عالية — قرّبي الموبايل من بوقك وقولي تاني.»
  tooNoisy(VoiceHaptic.long);

  const VoiceState(this.haptic);

  /// What the phone does in your hand when this state begins.
  final VoiceHaptic haptic;

  /// Whether the assistant's own voice is audible in this state.
  ///
  /// The microphone must not be recording the assistant, and the assistant must
  /// not be talking over the user.
  bool get assistantIsSpeaking =>
      this == VoiceState.speaking || this == VoiceState.correcting;

  /// Whether the microphone is live.
  ///
  /// Recording is always visibly indicated; there is no silent listening, not
  /// even for a wake word. This is what a recording indicator reads.
  bool get microphoneIsLive =>
      this == VoiceState.listening || this == VoiceState.tooNoisy;
}

/// How much of the interface an action can undo by itself.
enum VoiceActionRisk {
  /// Search, filter, navigation, drafting. Happens immediately and is announced
  /// aloud — asking permission for a reversible action teaches people to say
  /// yes without listening, which is exactly what must not happen at a gate.
  reversible,

  /// Publishing a Meal, accepting or rejecting an Order, cancelling an Order,
  /// changing the price of a published Meal, sending a Message, posting a
  /// Review. Read back in full, then waits.
  irreversible,
}

/// The read-back that stands between the assistant and anything irreversible.
///
/// **Silence never confirms.** There is deliberately no method on this class
/// that resolves a gate by the passage of time: no timeout accepts, no default
/// answer exists, and a gate that is never answered stays open forever. The
/// question repeats once after [repromptAfter] and then waits.
///
/// The same gate answers to voice and to tap, always, at the same time — a
/// Cook with a sleeping baby taps, a Cook with flour on her hands speaks.
class ConfirmationGate {
  ConfirmationGate({
    required this.spokenReadback,
    this.repromptAfter = const Duration(seconds: 8),
  });

  /// The whole thing, in Egyptian Arabic, as it will be said out loud. Not a
  /// summary — the read-back is what the person is agreeing to.
  final String spokenReadback;

  /// How long before the question is asked a second time.
  ///
  /// Once. A third identical prompt makes the app feel like it is nagging, and
  /// nagging is how people learn to say yes to make it stop.
  final Duration repromptAfter;

  bool _reprompted = false;
  bool? _answer;

  /// Whether the question has already been repeated.
  bool get hasReprompted => _reprompted;

  /// Whether an explicit answer has been given.
  bool get isAnswered => _answer != null;

  /// True only after an explicit yes. Never true through inaction.
  bool get isConfirmed => _answer ?? false;

  /// Repeats the question. Returns false if it has already been repeated once,
  /// or if the gate has been answered.
  bool reprompt() {
    if (_reprompted || isAnswered) return false;
    _reprompted = true;
    return true;
  }

  /// Answers the gate. [confirmed] comes from «أيوة» or «لأ», spoken or tapped.
  ///
  /// Answering twice does nothing: the first answer stands, so a repeated «أيوة»
  /// while the action is already running cannot publish a second Meal.
  void answer({required bool confirmed}) => _answer ??= confirmed;
}

/// How long an executed action stays undoable.
///
/// DESIGN.md keeps an undo visible for two minutes *even for nominally
/// irreversible actions*. The gate is what stops a mistake; this is what
/// forgives one that got through, and the two are not the same protection.
const Duration voiceUndoWindow = Duration(minutes: 2);

/// Which rung of the recognition failure ladder the conversation is on.
///
/// Egyptian Arabic recognition will fail on names and household words. The
/// ladder descends exactly three rungs and never climbs back, because a second
/// identical prompt is a nuisance and a third makes the app feel stupid.
enum RecognitionRung {
  /// «معلش، مافهمتش. قوليها تاني؟» — asked once, and only once.
  askAgain,

  /// «الأكلة اسمها محشي ورق عنب؟ قولي أيوة أو لأ.» A two-word answer is
  /// recognised far more reliably than open speech.
  narrowQuestion,

  /// «خلاص، هوريكي الاختيارات وانتي دوسي على اللي عايزاه.» Photographs, large
  /// numerals and glance words.
  ///
  /// **Never a keyboard.** Typing Arabic on a phone is the hardest thing this
  /// product could ask of a Cook; it stays available as a choice she makes and
  /// is never the consequence of the app failing to understand her.
  tapFallback,
}

/// Walks the recognition failure ladder.
///
/// It cannot loop, and that is the whole point of it being a class rather than
/// a counter at a call site. A conversation that re-asks after reaching the tap
/// fallback has started the ladder over, which is how a Cook ends up repeating
/// herself four times to an app that never understood her the first three.
class RecognitionLadder {
  RecognitionRung _rung = RecognitionRung.askAgain;
  bool _exhausted = false;

  /// The rung the conversation is on now.
  RecognitionRung get rung => _rung;

  /// Whether the ladder has reached the bottom. From here the only move is to
  /// show tappable options.
  bool get isExhausted => _exhausted;

  /// Records another failure and returns the rung to use next.
  ///
  /// Calling it after the bottom rung keeps returning the bottom rung.
  RecognitionRung descend() {
    _rung = switch (_rung) {
      RecognitionRung.askAgain => RecognitionRung.narrowQuestion,
      RecognitionRung.narrowQuestion ||
      RecognitionRung.tapFallback =>
        RecognitionRung.tapFallback,
    };
    if (_rung == RecognitionRung.tapFallback) _exhausted = true;
    return _rung;
  }

  /// Starts over, because the user was understood.
  ///
  /// Only success resets the ladder. Another failure never does.
  void succeeded() {
    _rung = RecognitionRung.askAgain;
    _exhausted = false;
  }
}

/// The timing the talk button has to hold to, whatever is happening underneath.
///
/// These are not animation preferences. Half a second of silence after a press
/// reads as "the button didn't work", so the user presses again and cuts off
/// their own speech — and the recording they lost is the one they had just
/// finished composing in their head.
abstract final class VoiceTiming {
  /// The press must be acknowledged — haptic and visible growth — within this.
  static const Duration acknowledge = Duration(milliseconds: 150);

  /// Thinking must be visible before this, even if recognition takes seconds.
  static const Duration thinkingVisible = Duration(milliseconds: 400);

  /// A release shorter than this does not end recording; it continues for one
  /// more second, because thumbs slip.
  static const Duration releaseGrace = Duration(milliseconds: 300);

  /// How much longer recording continues after a slipped thumb.
  static const Duration slipExtension = Duration(seconds: 1);

  /// How long thinking runs before «لسه معاك، ثانية.»
  static const Duration stillHereAfter = Duration(seconds: 2);
}
