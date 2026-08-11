import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/speech_output.dart';
import '../data/speech_output_provider.dart';

part 'assistant_voice.g.dart';

/// What a screen needs to know about the assistant's voice.
class AssistantVoiceState {
  const AssistantVoiceState({
    this.muted = false,
    this.canSpeak = false,
    this.voiceMatch = SpeechVoiceMatch.none,
    this.ready = false,
  });

  /// Whether the Cook silenced it. Persists across launches.
  final bool muted;

  /// Whether a line spoken now would be heard — false while muted, and false
  /// on a handset with no Arabic speech data installed.
  final bool canSpeak;

  final SpeechVoiceMatch voiceMatch;

  /// Whether the engine has finished starting up. Screens draw the controls
  /// inert until it has, rather than drawing them live and dropping the first
  /// line into a half-started engine.
  final bool ready;

  AssistantVoiceState copyWith({
    bool? muted,
    bool? canSpeak,
    SpeechVoiceMatch? voiceMatch,
    bool? ready,
  }) =>
      AssistantVoiceState(
        muted: muted ?? this.muted,
        canSpeak: canSpeak ?? this.canSpeak,
        voiceMatch: voiceMatch ?? this.voiceMatch,
        ready: ready ?? this.ready,
      );
}

/// The assistant's voice, for screens.
///
/// Wraps [SpeechOutput] so a widget never holds the engine directly and never
/// has to know which engine it is. Swapping the device voice for a paid one is
/// a change in `speech_output_provider.dart` and nothing here moves.
@Riverpod(keepAlive: true)
class AssistantVoice extends _$AssistantVoice {
  SpeechOutput get _speech => ref.read(speechOutputProvider);

  @override
  AssistantVoiceState build() {
    _start();
    return const AssistantVoiceState();
  }

  Future<void> _start() async {
    await _speech.initialize();
    if (!ref.mounted) return;
    state = AssistantVoiceState(
      muted: _speech.isMuted,
      canSpeak: _speech.canSpeak && !_speech.isMuted,
      voiceMatch: _speech.voiceMatch,
      ready: true,
    );
  }

  /// Says [line] aloud, if anything can.
  ///
  /// [quiet] for money and addresses: homes are shared and income is private.
  Future<void> say(String line, {bool quiet = false}) =>
      _speech.speak(line, quiet: quiet);

  /// Stops mid-sentence. What happens when the user starts talking.
  Future<void> hush() => _speech.stop();

  /// Silences or restores the assistant. The answer outlives the session.
  Future<void> setMuted({required bool muted}) async {
    await _speech.setMuted(muted: muted);
    if (!ref.mounted) return;
    state = state.copyWith(
      muted: muted,
      canSpeak: _speech.canSpeak && !muted,
    );
  }
}
