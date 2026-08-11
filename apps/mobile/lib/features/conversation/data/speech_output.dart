import 'package:shared_preferences/shared_preferences.dart';

/// The assistant's voice, as an interface.
///
/// Kafoo reads itself aloud by default, because speech is the primary channel
/// rather than an accessibility add-on. This is the seam every spoken line goes
/// through, so the engine underneath can change without a single call site
/// moving — the same reason model calls go through the provider abstraction in
/// `packages/ai/`.
///
/// **There is no always-on text-to-speech engine wired up yet, and that is a
/// pending decision rather than an oversight.** DESIGN.md §10.13 leaves the
/// assistant's voice casting open, and the choice behind it costs money: an
/// on-device engine is free and sounds like a machine, a cloud Egyptian voice
/// sounds like a person and is billed per sentence. Picking one is the
/// founder's call. [AnnouncingSpeechOutput] is what ships until then.
abstract interface class SpeechOutput {
  /// Says [line] aloud. Does nothing while muted.
  Future<void> speak(String line);

  /// Stops mid-sentence — what happens when the user starts talking.
  Future<void> stop();

  /// Whether the assistant is silenced.
  bool get isMuted;

  /// Silences or unsilences the assistant, and remembers the answer.
  Future<void> setMuted({required bool muted});
}

/// The assistant with no voice yet.
///
/// **Named for what it is, so the gap cannot hide.** It carries the real mute
/// preference and the real interface, and says nothing, because no engine has
/// been chosen. A class called `SpeechOutput` that silently did nothing would
/// let every screen claim a spoken line while nobody ever heard one — and the
/// design's whole point is that a component without a spoken line is
/// unfinished, which is a fact somebody has to be able to see.
///
/// Routing lines through the platform screen reader was considered and
/// rejected: it is only audible to someone who already has TalkBack or
/// VoiceOver switched on, and the widgets already carry semantics labels that
/// those readers announce. It would have added a second, redundant path while
/// looking like the voice system was working.
class UnvoicedSpeechOutput implements SpeechOutput {
  UnvoicedSpeechOutput({SharedPreferences? preferences})
      : _preferences = preferences;

  /// The stored answer to "should the assistant talk".
  ///
  /// Persisted because muting **persists until reversed** — an app that starts
  /// talking again on the next launch has overruled a decision somebody made
  /// deliberately, probably in a room with other people in it.
  static const String preferenceKey = 'kafoo.voice.muted';

  SharedPreferences? _preferences;
  bool _muted = false;

  @override
  bool get isMuted => _muted;

  /// Reads the stored preference. Call once at startup.
  ///
  /// A failure here leaves the assistant audible, which is the documented
  /// default — never silently muted, because a Cook who cannot hear the app and
  /// never chose that has no way to know why.
  Future<void> load() async {
    try {
      _preferences ??= await SharedPreferences.getInstance();
      _muted = _preferences?.getBool(preferenceKey) ?? false;
    } on Object catch (_) {
      _muted = false;
    }
  }

  @override
  Future<void> speak(String line) async {
    // Nothing is said, because nothing can say it yet. See the class comment.
  }

  @override
  Future<void> stop() async {
    // Nothing to stop.
  }

  @override
  Future<void> setMuted({required bool muted}) async {
    _muted = muted;
    try {
      _preferences ??= await SharedPreferences.getInstance();
      await _preferences?.setBool(preferenceKey, muted);
    } on Object catch (_) {
      // The choice still holds for this session. Losing it at the next launch
      // is worse than crashing here would be, but only slightly — and crashing
      // over a preference write is not a trade Kafoo makes.
    }
  }
}

/// Records what would have been said. For tests.
class FakeSpeechOutput implements SpeechOutput {
  final List<String> spoken = [];
  bool stopped = false;
  bool _muted = false;

  @override
  bool get isMuted => _muted;

  @override
  Future<void> speak(String line) async {
    if (_muted) return;
    spoken.add(line);
  }

  @override
  Future<void> stop() async => stopped = true;

  @override
  Future<void> setMuted({required bool muted}) async => _muted = muted;
}
