import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// How the talk orb looks right now.
///
/// Seven cases, not the voice system's nine. Two of the nine states do not
/// change the orb: *correcting* animates the value that changed somewhere else
/// on the screen, and *interrupted* simply returns to listening. The mapping
/// from the nine belongs to the caller, because this package is the design
/// system and does not depend on `packages/domain`.
enum TalkOrbState {
  /// Teal, a microphone, at rest. «أنا معاك. دوسي واتكلمي.»
  idle,

  /// Expanding rings and five amplitude bars.
  listening,

  /// Three blinking dots.
  thinking,

  /// A light ring while the assistant talks.
  speaking,

  /// Deep terracotta. The app did not understand — and the failure belongs to
  /// the app, never to the speaker.
  notHeard,

  /// A dashed outline. Nothing is lost; it is queued.
  offlineQueued,

  /// All five bars high and static.
  tooNoisy;

  /// Whether the microphone is open in this state.
  bool get isRecording =>
      this == TalkOrbState.listening || this == TalkOrbState.tooNoisy;
}

/// The talk button.
///
/// **88dp, bottom centre, and nothing else within 24dp of it.** Larger than the
/// 48dp floor because it is found by thumb without looking, sometimes with wet
/// hands, and bottom *centre* rather than inline-end because it is not part of
/// the reading order and hand preference varies.
///
/// **Hold to talk; a single tap locks recording** for a long description. There
/// is no always-listening mode — kitchens are shared spaces and an open
/// microphone frightens people, reasonably.
///
/// **The press is acknowledged within 150ms**, by growth and by haptic, even
/// when recognition takes seconds. Half a second of silence reads as "the
/// button didn't work", so the user presses again and cuts off their own
/// speech. That is why [onPressStart] fires immediately and the orb grows
/// before anything else has happened.
///
/// **[amplitude] must come from the real microphone.** A bar that moves while
/// the microphone is muted or broken destroys trust in every other state — so
/// it is a required parameter with no default, and a caller has to decide where
/// the number comes from rather than getting a plausible animation for free.
class KafooTalkButton extends StatelessWidget {
  const KafooTalkButton({
    required this.state,
    required this.amplitude,
    required this.label,
    required this.onPressStart,
    required this.onPressEnd,
    this.onLockToggle,
    this.locked = false,
    this.enabled = true,
    this.size = KafooSpacing.talkButton,
    super.key,
  });

  final TalkOrbState state;

  /// The live microphone level, 0 to 1. Ignored unless the orb is recording.
  final double amplitude;

  /// The spoken invitation, already localized — "دوسي واتكلمي".
  final String label;

  /// Fires on pointer down, before anything else. This is the 150ms promise.
  final VoidCallback onPressStart;

  /// Fires on release. The caller applies the grace period: a release under
  /// 300ms does not end recording, because thumbs slip.
  final VoidCallback onPressEnd;

  /// A single tap locks recording on, for a long description.
  final VoidCallback? onLockToggle;

  final bool locked;

  /// Whether the orb responds.
  ///
  /// False draws it exactly as designed and inert, because the design is not
  /// wrong — the engine behind it has not arrived. [label] must then say so, in
  /// the same way every other disabled control in Kafoo states its reason.
  final bool enabled;

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (fill, ring) = switch (state) {
      TalkOrbState.notHeard => (KafooColors.primaryDeep, KafooColors.primary),
      TalkOrbState.offlineQueued => (KafooColors.surface, KafooColors.voice),
      _ => (KafooColors.voice, KafooColors.voiceDeep),
    };

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      // A recording indicator that cannot be switched off. There is no silent
      // listening in Kafoo, not even for a wake word, so the state reaches a
      // blind user the same way it reaches a sighted one.
      value: state.isRecording ? label : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: KafooSpacing.row,
        children: [
          Listener(
            onPointerDown: enabled ? (_) => onPressStart() : null,
            onPointerUp: enabled ? (_) => onPressEnd() : null,
            onPointerCancel: enabled ? (_) => onPressEnd() : null,
            child: GestureDetector(
              onTap: enabled ? onLockToggle : null,
              child: AnimatedContainer(
                duration: KafooMotion.enter,
                curve: KafooMotion.enterCurve,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: switch ((enabled, state)) {
                    (false, _) => KafooColors.disabledFill,
                    (_, TalkOrbState.offlineQueued) => KafooColors.surface,
                    _ => fill,
                  },
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ring,
                    // The dashed outline of the offline state cannot be drawn
                    // with a BorderSide, so the queued orb is marked by its
                    // inverted fill and its glance word instead — never by a
                    // solid edge pretending to be dashed.
                    width: state == TalkOrbState.offlineQueued ? 2.5 : 0,
                  ),
                  boxShadow: state.isRecording
                      ? [
                          BoxShadow(
                            color: KafooElevation.talkOrbHalo,
                            blurRadius: 0,
                            spreadRadius: locked ? 12 : 10,
                          ),
                        ]
                      : null,
                ),
                child: Center(child: _face(state, ring)),
              ),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: KafooColors.voiceDeep,
            ),
          ),
        ],
      ),
    );
  }

  Widget _face(TalkOrbState state, Color ring) => switch (state) {
        TalkOrbState.listening ||
        TalkOrbState.tooNoisy =>
          _AmplitudeBars(level: state == TalkOrbState.tooNoisy ? 1 : amplitude),
        TalkOrbState.thinking => const _ThinkingDots(),
        TalkOrbState.offlineQueued => Icon(Icons.cloud_off, color: ring),
        _ => Icon(
            state == TalkOrbState.speaking ? Icons.graphic_eq : Icons.mic,
            color: KafooColors.onPrimary,
            size: size * 0.4,
          ),
      };
}

/// Identifies one of the five amplitude bars, counting from the inline start.
Key amplitudeBarKey(int index) => ValueKey('kafoo.amplitude.$index');

/// Five bars driven by the real microphone level.
///
/// Never an animation of its own. See the note on [KafooTalkButton.amplitude].
class _AmplitudeBars extends StatelessWidget {
  const _AmplitudeBars({required this.level});

  /// 0 to 1, from the microphone.
  final double level;

  @override
  Widget build(BuildContext context) {
    final clamped = level.clamp(0.0, 1.0);
    // The middle bars react most, the outer ones least, so a quiet voice still
    // moves something and a loud one fills the orb.
    const weights = [0.45, 0.75, 1.0, 0.75, 0.45];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: KafooSpacing.xs,
      children: [
        for (final (index, weight) in weights.indexed)
          Container(
            // Keyed so a test can measure a bar rather than guessing which
            // Container in the orb is one — and so five identical siblings
            // keep their identity across rebuilds.
            key: amplitudeBarKey(index),
            width: 4,
            height: 8 + (clamped * weight * 28),
            decoration: BoxDecoration(
              color: KafooColors.onPrimary,
              borderRadius: BorderRadius.circular(KafooRadius.pill),
            ),
          ),
      ],
    );
  }
}

class _ThinkingDots extends StatelessWidget {
  const _ThinkingDots();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        spacing: KafooSpacing.xs,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: KafooColors.onPrimary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      );
}

/// The mute control that sits on every screen.
///
/// **48dp, top inline-end, and it persists until reversed.** Kafoo reads itself
/// aloud by default, because speech is the primary channel rather than an
/// accessibility add-on — so turning it off is a decision the app must never
/// quietly undo on the next launch.
class KafooMuteButton extends StatelessWidget {
  const KafooMuteButton({
    required this.muted,
    required this.label,
    required this.onChanged,
    super.key,
  });

  final bool muted;

  /// Already localized, and it must describe the *result* of pressing — a
  /// speaker glyph alone does not say which way it is about to go.
  final String label;

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        toggled: muted,
        label: label,
        child: SizedBox(
          width: KafooSpacing.minTapTarget,
          height: KafooSpacing.minTapTarget,
          child: IconButton(
            onPressed: () => onChanged(!muted),
            tooltip: label,
            icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
            style: IconButton.styleFrom(
              backgroundColor: KafooColors.voiceTint,
              foregroundColor: KafooColors.voiceDeep,
              shape: const CircleBorder(
                side: BorderSide(color: KafooColors.voiceBorder, width: 1.5),
              ),
            ),
          ),
        ),
      );
}
