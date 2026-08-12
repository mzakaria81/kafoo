import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kafoo_ui/ui.dart';

/// The microphone control shared by every conversation.
///
/// Lives here rather than inside a feature because both the Kitchen Profile
/// conversation and the Meal conversation need exactly this control, and a
/// second copy is a second place for the tap target or the semantic label to
/// drift out of line with the accessibility rules.
class VoiceButton extends StatelessWidget {
  const VoiceButton({
    required this.listening,
    required this.label,
    required this.onPressed,
    this.preparing = false,
    super.key,
  });

  final bool listening;
  final String label;
  final VoidCallback onPressed;

  /// The tap landed and the microphone is not open yet.
  ///
  /// **§10.3: acknowledge within 150 ms, and there is never a silent, still
  /// moment.** The assistant is silenced before the microphone opens and that
  /// wait is deliberately unbounded — so on a slow handset this button used to
  /// sit unchanged for as long as the stop took, which reads as "it didn't
  /// work". She taps again and cuts off her own first words, which is the exact
  /// failure §10.3 names. Found by accessibility-reviewer on #461, round seven:
  /// proving the wait was real is what made the silence during it visible.
  final bool preparing;

  @override
  Widget build(BuildContext context) {
    // §10.2 "Interrupted": one short pulse, and no spoken line — the assistant
    // is being silenced, so speaking over the moment would be the bug.
    void tapped() {
      unawaited(HapticFeedback.selectionClick());
      onPressed();
    }

    return Semantics(
      button: true,
      label: label,
      child: OutlinedButton.icon(
        onPressed: preparing ? null : tapped,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
        ),
        icon: Icon(
          preparing
              ? Icons.more_horiz
              : listening
                  ? Icons.stop
                  : Icons.mic,
        ),
        label: Text(label),
      ),
    );
  }
}
