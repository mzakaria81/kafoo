import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// What the assistant just said, shown on the screen.
///
/// **This is the most important element on any voice screen, and it is not a
/// notification.** Kafoo's screens are the receipt of a spoken exchange: the
/// assistant says a line, and this is where that line stays so it can be
/// re-read by someone who missed it, glanced at by someone who could not hear
/// it, and checked by someone who is not sure the app understood.
///
/// Teal, because teal means the machine is talking. A human's words never
/// appear on this background.
class KafooSpokenBanner extends StatelessWidget {
  const KafooSpokenBanner({
    required this.line,
    this.speaking = false,
    this.onHearAgain,
    this.hearAgainLabel,
    super.key,
  });

  /// The sentence, already localized and already said.
  final String line;

  /// Whether the assistant is saying it right now. Drives the dot.
  final bool speaking;

  /// Says it again. Null renders the control disabled rather than absent — a
  /// missing button is a design that changed; a disabled one is a capability
  /// that has not arrived.
  final VoidCallback? onHearAgain;

  /// Required whenever the button is drawn, enabled or not, because a disabled
  /// control still has to say what it is.
  final String? hearAgainLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      // A live region: the assistant's line arriving silently for a screen
      // reader user defeats the point of showing it at all.
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.all(KafooSpacing.md),
        decoration: BoxDecoration(
          color: KafooColors.voiceTint,
          borderRadius: BorderRadius.circular(KafooRadius.panel),
          border: Border.all(color: KafooColors.voiceBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: KafooSpacing.row,
          children: [
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsetsDirectional.only(top: KafooSpacing.xs),
              decoration: BoxDecoration(
                color: speaking ? KafooColors.voice : KafooColors.voiceBorder,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                line,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: KafooColors.voiceDeep),
              ),
            ),
            if (hearAgainLabel != null)
              SizedBox(
                width: KafooSpacing.minTapTarget,
                height: KafooSpacing.minTapTarget,
                child: IconButton(
                  onPressed: onHearAgain,
                  // Kept for a sighted long-press; the label a screen reader
                  // announces is on the icon. A tooltip alone lands on the
                  // semantics node as a `tooltip` rather than a `label`, which
                  // is the same gap the Meal row's actions had.
                  tooltip: hearAgainLabel,
                  icon: Icon(Icons.replay, semanticLabel: hearAgainLabel),
                  style: IconButton.styleFrom(
                    foregroundColor: KafooColors.voiceDeep,
                    disabledForegroundColor: KafooColors.textDisabled,
                    backgroundColor: KafooColors.surfaceRaised,
                    shape: const CircleBorder(
                      side: BorderSide(color: KafooColors.voiceBorder),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
