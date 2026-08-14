import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/hosted_speech_output.dart';
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
    this.voice = AssistantVoiceRole.defaultRole,
    this.canChooseVoice = false,
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

  /// Which of the two Cairene voices is talking.
  final AssistantVoiceRole voice;

  /// Whether this engine actually has two voices to choose between.
  ///
  /// False on the device's own engine, which has whatever the platform gave it.
  /// A chooser drawn over one voice is a control that does nothing.
  final bool canChooseVoice;

  AssistantVoiceState copyWith({
    bool? muted,
    bool? canSpeak,
    SpeechVoiceMatch? voiceMatch,
    bool? ready,
    AssistantVoiceRole? voice,
    bool? canChooseVoice,
  }) =>
      AssistantVoiceState(
        muted: muted ?? this.muted,
        canSpeak: canSpeak ?? this.canSpeak,
        voiceMatch: voiceMatch ?? this.voiceMatch,
        ready: ready ?? this.ready,
        voice: voice ?? this.voice,
        canChooseVoice: canChooseVoice ?? this.canChooseVoice,
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
      voice: _speech.voice,
      // Asked of the engine rather than inferred from its type, so a swap back
      // to the device voice hides the chooser instead of leaving a control that
      // does nothing.
      canChooseVoice: _speech.hasVoiceChoice,
    );
  }

  /// Says [line] aloud, if anything can.
  ///
  /// [quiet] for money and addresses: homes are shared and income is private.
  Future<void> say(String line, {bool quiet = false}) =>
      _speech.speak(line, quiet: quiet);

  /// Stops mid-sentence. What happens when the user starts talking.
  Future<void> hush() => _speech.stop();

  /// Chooses which of the two Cairene voices talks. Outlives the session.
  ///
  /// **Says one line in the new voice immediately**, because the whole point of
  /// choosing is hearing the difference — and a choice whose effect is only
  /// audible on the next screen is a choice made blind.
  Future<void> setVoice(AssistantVoiceRole role, {String? preview}) async {
    await _speech.setVoice(role);
    if (!ref.mounted) return;
    state = state.copyWith(voice: role);
    if (preview != null) await _speech.speak(preview);
  }

  /// Says one line in [role] WITHOUT choosing it.
  ///
  /// Hearing a voice must not commit anyone to it. §10.11 says the choice never
  /// changes on its own, so the engine is put back exactly as it was — including
  /// when the preview fails, which is why the restore is in a `finally`.
  Future<void> preview(AssistantVoiceRole role, String line) async {
    final was = _speech.voice;
    try {
      await _speech.setVoice(role);
      await _speech.speak(line);
    } finally {
      await _speech.setVoice(was);
    }
  }

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
