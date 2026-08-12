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
    // §10.2 "Interrupted": one short pulse. That state's silence covers the
    // pulse, and the first version of this comment stretched it to cover the
    // whole wait as well, which it does not — «Interrupted» assumes an instant,
    // and this wait is unbounded by design. Raised by conversation-designer on
    // #461, round eight, and the citation was wrong.
    //
    // **The wait is silent for a reason of its own, not by that citation.** The
    // microphone opens the moment `hush()` returns, so a line spoken while
    // waiting can still be playing when it does — the assistant talking into a
    // live microphone, which is the exact defect six rounds of this PR went to
    // close. §10.2 "Thinking" speaks after two seconds because nothing is about
    // to listen; here something is.
    //
    // **What that leaves unanswered is a Cook who does not read**, on the rare
    // tap where the wait runs long: she feels one pulse and then nothing.
    // Silence is the safe answer, not a complete one, and the honest fix is a
    // second pulse rather than a sentence. Not built — it is the founder's call
    // whether an unmeasured, normally-imperceptible wait is worth a new
    // behaviour in a voice flow.
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
