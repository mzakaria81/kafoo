import 'package:speech_to_text/speech_to_text.dart';

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
  String? _arabicLocaleId;

  /// Whether recognition can be used at all. False means the conversation
  /// must offer typing with a plain explanation, never a dead microphone.
  bool get isAvailable => _available;

  bool get isListening => _speech.isListening;

  /// Initializes recognition and resolves an Egyptian Arabic locale.
  ///
  /// Returns false when recognition is unavailable for any reason — no
  /// permission, no engine, no Arabic locale installed.
  Future<bool> initialize() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      _available = await _speech.initialize();
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
    }
    return _available;
  }

  /// Prefers `ar-EG`, falls back to any Arabic locale the device offers.
  Future<String?> _resolveArabicLocale() async {
    final locales = await _speech.locales();
    for (final locale in locales) {
      final id = locale.localeId.toLowerCase().replaceAll('-', '_');
      if (id == 'ar_eg') return locale.localeId;
    }
    for (final locale in locales) {
      final id = locale.localeId.toLowerCase();
      if (id.startsWith('ar')) return locale.localeId;
    }
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
