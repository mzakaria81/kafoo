import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hosted_speech_output.dart';

/// How well the device's own voice matches Egyptian Arabic.
///
/// The same three-way answer [VoiceLocaleMatch] gives for recognition, and for
/// the same reason: a Cook being *spoken to* in Gulf or Levantine Arabic is a
/// different situation from silence, and until this distinction existed the two
/// were indistinguishable to every caller.
enum SpeechVoiceMatch {
  /// The device offers `ar-EG`.
  exact,

  /// No `ar-EG`, but some other Arabic voice. Understandable, wrong accent.
  fallback,

  /// No Arabic voice at all. The assistant stays silent and says so.
  none,
}

/// The assistant's voice, as an interface.
///
/// Kafoo reads itself aloud by default, because speech is the primary channel
/// rather than an accessibility add-on. This is the seam every spoken line goes
/// through.
///
/// **The seam exists because the engine behind it is expected to change.** The
/// founder chose the device's own voice to start — free, offline, no account,
/// available today — with a paid Cairene voice to follow once the flows are
/// settled and there are real sentences to audition. See
/// `decisions/0014-speak-with-the-devices-own-voice-first.md`. Swapping is
/// meant to be one line in `speech_output_provider.dart`, not a refactor, which
/// is the same shape ADR-0005 uses for model providers.
///
/// Three rules constrain any implementation:
///
/// - **Muting persists until reversed.** An app that starts talking again on
///   the next launch has overruled a decision somebody made deliberately,
///   probably in a room with other people in it.
/// - **Silence is never silent about itself.** An engine that cannot speak
///   Arabic reports [voiceMatch] `none` rather than accepting lines and
///   dropping them.
/// - **Money and addresses are spoken quietly.** Homes are shared and income is
///   private, so [speak] takes [quiet].
abstract interface class SpeechOutput {
  /// Prepares the engine and resolves a voice. Call once at startup.
  ///
  /// Returns whether anything can be said at all.
  Future<bool> initialize();

  /// How well the resolved voice matches Egyptian Arabic.
  SpeechVoiceMatch get voiceMatch;

  /// Whether a line spoken now would actually be heard.
  bool get canSpeak;

  /// Says [line] aloud, interrupting whatever is being said.
  ///
  /// [quiet] lowers the volume for money and addresses.
  Future<void> speak(String line, {bool quiet = false});

  /// Stops mid-sentence — what happens when the user starts talking.
  Future<void> stop();

  /// Whether the assistant is silenced.
  bool get isMuted;

  /// Silences or unsilences the assistant, and remembers the answer.
  Future<void> setMuted({required bool muted});

  /// Which of the two Cairene voices is talking.
  ///
  /// **§10.11: each account chooses for itself and the choice never switches on
  /// its own.** The machinery for this shipped on 2026-08-11 — two voices bought,
  /// a stored preference, a role passed to `speak` — and no screen ever offered
  /// the choice, so every Cook heard whichever one was the default. The design
  /// package draws the chooser (screenshot 06); this is the seam it needed.
  ///
  /// An engine with only one voice reports [AssistantVoiceRole.defaultRole] and
  /// ignores [setVoice], rather than pretending to switch.
  AssistantVoiceRole get voice;

  /// Whether this engine actually has two voices to choose between.
  ///
  /// **Asked of the engine, not inferred from its type.** A screen that decided
  /// by checking `is HostedSpeechOutput` would be a screen that knows which
  /// engine it is talking to, which is the one thing this interface exists to
  /// prevent — and it would go wrong silently the next time the seam is swapped.
  bool get hasVoiceChoice;

  /// Chooses a voice, and remembers the answer.
  Future<void> setVoice(AssistantVoiceRole role);
}

/// Everything about being muted, which no engine should reimplement.
///
/// Pulled out as a mixin rather than copied into each implementation: the
/// persistence rule is the part a swap must not lose, and the swap is the whole
/// point of the interface above.
mixin StoredMutePreference {
  /// The stored answer to "should the assistant talk".
  static const String preferenceKey = 'kafoo.voice.muted';

  SharedPreferences? _preferences;
  bool _muted = false;

  bool get isMuted => _muted;

  /// Reads the stored preference.
  ///
  /// A failure here leaves the assistant audible, which is the documented
  /// default — never silently muted, because a Cook who cannot hear the app and
  /// never chose that has no way to know why.
  Future<void> loadMutePreference() async {
    try {
      _preferences ??= await SharedPreferences.getInstance();
      _muted = _preferences?.getBool(preferenceKey) ?? false;
    } on Object catch (_) {
      _muted = false;
    }
  }

  Future<void> storeMutePreference({required bool muted}) async {
    _muted = muted;
    try {
      _preferences ??= await SharedPreferences.getInstance();
      await _preferences?.setBool(preferenceKey, muted);
    } on Object catch (_) {
      // The choice still holds for this session. Crashing over a preference
      // write is not a trade Kafoo makes.
    }
  }
}

/// The device's own text-to-speech engine.
///
/// Free, offline, no account, and it sounds like a machine. That was the
/// trade the founder took to get the voice system working end to end before
/// committing to a bill that grows with usage.
///
/// **It will not work on every Egyptian handset, and that is handled rather
/// than hoped.** Android ships text-to-speech language data separately from the
/// engine, so `ar-EG` is frequently absent — the same trap the speech
/// *recogniser* already fell into, documented in `voice_input.dart` and in the
/// manifest's `<queries>` block. [voiceMatch] reports which of the three
/// situations a Cook is actually in.
class DeviceSpeechOutput with StoredMutePreference implements SpeechOutput {
  DeviceSpeechOutput({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  /// **The device has whatever voice it has, and saying otherwise would be the
  /// lie the seam exists to prevent.** A handset's Arabic voice is chosen by the
  /// platform; there is no second one to swap to, so the choice is reported as
  /// the default and setting it does nothing rather than appearing to work.
  @override
  AssistantVoiceRole get voice => AssistantVoiceRole.defaultRole;

  @override
  bool get hasVoiceChoice => false;

  @override
  Future<void> setVoice(AssistantVoiceRole role) async {}

  final FlutterTts _tts;
  SpeechVoiceMatch _match = SpeechVoiceMatch.none;
  bool _ready = false;

  /// Egyptian first, then any Arabic. Matching is case-insensitive and accepts
  /// both `-` and `_`, because platforms disagree about the separator.
  static const String _egyptian = 'ar-eg';

  /// A tenth of the way down from the platform default. Slow enough for an
  /// older Cook without sounding like a fault.
  static const double _rate = 0.45;

  /// Money and addresses. Not silent — quieter, and routed to the earpiece
  /// when one is connected.
  static const double _quietVolume = 0.4;
  static const double _normalVolume = 1;

  @override
  SpeechVoiceMatch get voiceMatch => _match;

  @override
  bool get canSpeak => _ready && _match != SpeechVoiceMatch.none;

  @override
  Future<bool> initialize() async {
    await loadMutePreference();
    try {
      final resolved = await _resolveArabicVoice();
      if (resolved == null) {
        _match = SpeechVoiceMatch.none;
        return false;
      }
      await _tts.setLanguage(resolved);
      await _tts.setSpeechRate(_rate);
      await _tts.setVolume(_normalVolume);
      // Each line replaces the last. The assistant says one thing at a time,
      // and an interrupted sentence must not resume behind the next one.
      await _tts.setQueueMode(0);
      _ready = true;
      return true;
    } on Object catch (_) {
      // Catches Error as well as Exception deliberately: a missing plugin or a
      // platform channel returning nothing surfaces as a TypeError, and an
      // engine that will not start must leave the app usable by tap.
      _match = SpeechVoiceMatch.none;
      _ready = false;
      return false;
    }
  }

  Future<String?> _resolveArabicVoice() async {
    final languages = await _tts.getLanguages;
    if (languages is! List) return null;

    final available = languages
        .map((l) => l.toString().toLowerCase().replaceAll('_', '-'))
        .toList();

    for (final language in available) {
      if (language == _egyptian) {
        _match = SpeechVoiceMatch.exact;
        return language;
      }
    }
    for (final language in available) {
      if (language.startsWith('ar')) {
        // Understandable, wrong accent. Better than silence, and the caller is
        // told which it got.
        _match = SpeechVoiceMatch.fallback;
        return language;
      }
    }
    _match = SpeechVoiceMatch.none;
    return null;
  }

  @override
  Future<void> speak(String line, {bool quiet = false}) async {
    if (isMuted || !canSpeak || line.isEmpty) return;
    try {
      await _tts.setVolume(quiet ? _quietVolume : _normalVolume);
      // Stop first: `speak` on top of a sentence in progress queues on some
      // engines and truncates on others, and the assistant saying two things at
      // once is worse than either.
      await _tts.stop();
      await _tts.speak(line);
    } on Object catch (_) {
      // A line that will not play is not worth taking a screen down for. The
      // same words are on the screen.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object catch (_) {
      // Nothing to recover; the engine is already not talking, or is gone.
    }
  }

  @override
  Future<void> setMuted({required bool muted}) async {
    if (muted) await stop();
    await storeMutePreference(muted: muted);
  }
}

/// The assistant with no voice.
///
/// Kept after the device engine landed, and not as dead code: it is what a
/// handset with no Arabic speech data falls back to, and what tests use when
/// the subject is not the voice. **Named for its emptiness** so a silent app is
/// never mistaken for a working one.
class UnvoicedSpeechOutput with StoredMutePreference implements SpeechOutput {
  /// Reported, never chosen. Nothing here can say anything in either voice, so
  /// offering a choice would be the pretence this class is named against.
  @override
  AssistantVoiceRole get voice => AssistantVoiceRole.defaultRole;

  @override
  bool get hasVoiceChoice => false;

  @override
  Future<void> setVoice(AssistantVoiceRole role) async {}

  @override
  SpeechVoiceMatch get voiceMatch => SpeechVoiceMatch.none;

  @override
  bool get canSpeak => false;

  @override
  Future<bool> initialize() async {
    await loadMutePreference();
    return false;
  }

  @override
  Future<void> speak(String line, {bool quiet = false}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setMuted({required bool muted}) =>
      storeMutePreference(muted: muted);
}

/// Records what would have been said. For tests.
class FakeSpeechOutput with StoredMutePreference implements SpeechOutput {
  FakeSpeechOutput({this.voiceMatch = SpeechVoiceMatch.exact});

  final List<({String line, bool quiet})> spoken = [];
  bool stopped = false;

  @override
  AssistantVoiceRole voice = AssistantVoiceRole.defaultRole;

  /// Off by default, so a test that wants the chooser has to say so — the
  /// chooser must be ABSENT when there is one voice, and a fake that always
  /// offered it could not prove that.
  @override
  bool hasVoiceChoice = false;

  @override
  Future<void> setVoice(AssistantVoiceRole role) async => voice = role;

  @override
  final SpeechVoiceMatch voiceMatch;

  @override
  bool get canSpeak => voiceMatch != SpeechVoiceMatch.none;

  @override
  Future<bool> initialize() async {
    await loadMutePreference();
    return canSpeak;
  }

  @override
  Future<void> speak(String line, {bool quiet = false}) async {
    if (isMuted || !canSpeak) return;
    spoken.add((line: line, quiet: quiet));
  }

  @override
  Future<void> stop() async => stopped = true;

  @override
  Future<void> setMuted({required bool muted}) async {
    if (muted) await stop();
    await storeMutePreference(muted: muted);
  }
}
