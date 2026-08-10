import 'package:speech_to_text/speech_to_text.dart';

/// How well the resolved speech locale matches Egyptian Arabic.
///
/// A `fallback` conversation is one where an Egyptian Cook is being transcribed
/// by a model trained on a different dialect, and until this field existed that
/// was indistinguishable from success.
enum VoiceLocaleMatch {
  /// The device offered `ar-EG` (case-insensitive, `-` and `_` both accepted).
  exact,

  /// No `ar-EG`, but some other Arabic locale was used.
  fallback,

  /// No Arabic locale at all, so recognition is unavailable.
  none,
}

/// On-device speech recognition for the Kitchen Profile conversation.
///
/// Recognition failing is the likeliest real-world outcome, not the exceptional
/// one (research.md §3): `ar-EG` is missing on many Egyptian handsets. Every
/// method here reports unavailability plainly so the conversation can fall back
/// to typing rather than breaking.
///
/// Voice recordings are transcribed and discarded. No audio is persisted.
class VoiceInput {
  VoiceInput({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  bool _available = false;
  bool _engineAvailable = false;
  String? _arabicLocaleId;
  VoiceLocaleMatch _localeMatch = VoiceLocaleMatch.none;

  /// Whether recognition can be used at all. False means the conversation
  /// must offer typing with a plain explanation, never a dead microphone.
  bool get isAvailable => _available;

  /// Whether the device has a working recogniser, regardless of language.
  ///
  /// TRUE HERE WITH [isAvailable] FALSE MEANS ONE SPECIFIC THING: the microphone
  /// works, permission was granted, and the device simply has no Arabic speech
  /// language installed. That is a different sentence to a person — one they can
  /// act on in their phone's settings — and until 2026-08-10 both cases produced
  /// the same message, so the founder granted the microphone permission, was
  /// told voice does not work on this phone, and had no way to know why.
  bool get engineAvailable => _engineAvailable;

  bool get isListening => _speech.isListening;

  /// The locale id actually passed to the recogniser, or null when recognition
  /// is unavailable.
  String? get resolvedLocaleId => _arabicLocaleId;

  /// How well the resolved locale matches Egyptian Arabic.
  VoiceLocaleMatch get localeMatch => _localeMatch;

  /// Initializes recognition and resolves an Egyptian Arabic locale.
  ///
  /// Returns false when recognition is unavailable for any reason — no
  /// permission, no engine, no Arabic locale installed.
  Future<bool> initialize() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      _available = await _speech.initialize();
      _engineAvailable = _available;
      if (_available) {
        _arabicLocaleId = await _resolveArabicLocale();
        // An engine with no Arabic locale cannot serve an Arabic-first
        // conversation. Treat that as unavailable rather than transcribing
        // Egyptian Arabic through an English model.
        _available = _arabicLocaleId != null;
      }
    } on Object catch (_) {
      // Catches Error as well as Exception deliberately: a missing plugin or a
      // platform channel returning nothing surfaces as a TypeError, and an
      // unavailable microphone must degrade to typing, never crash the flow.
      _available = false;
      _engineAvailable = false;
    }
    return _available;
  }

  /// Prefers `ar-EG`, falls back to any Arabic locale the device offers.
  Future<String?> _resolveArabicLocale() async {
    final locales = await _speech.locales();
    for (final locale in locales) {
      final id = locale.localeId.toLowerCase().replaceAll('-', '_');
      if (id == 'ar_eg') {
        _localeMatch = VoiceLocaleMatch.exact;
        return locale.localeId;
      }
    }
    for (final locale in locales) {
      final id = locale.localeId.toLowerCase();
      if (id.startsWith('ar')) {
        _localeMatch = VoiceLocaleMatch.fallback;
        return locale.localeId;
      }
    }
    _localeMatch = VoiceLocaleMatch.none;
    return null;
  }

  /// Starts listening. [onTranscript] receives partial and final transcripts;
  /// [isFinal] marks the last one. The caller shows the transcript back to the
  /// Cook before accepting it (FR-012).
  Future<void> listen({
    required void Function(String transcript, bool isFinal) onTranscript,
  }) async {
    if (!_available) return;
    await _speech.listen(
      onResult: (result) =>
          onTranscript(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: _arabicLocaleId,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> stop() async {
    if (_speech.isListening) await _speech.stop();
  }

  Future<void> cancel() async {
    if (_speech.isListening) await _speech.cancel();
  }
}
