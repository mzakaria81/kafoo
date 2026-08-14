import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'glance_word.dart';

/// The read-back that stands in front of anything irreversible.
///
/// The assistant says the whole thing out loud, shows it, and then waits. What
/// this widget is responsible for is the waiting being visible and the two
/// answers being unmissable.
///
/// **Silence never confirms, and there is no code here that could let it.**
/// This widget has no timer, no default action and no auto-dismiss; both
/// callbacks come from a person. The rule itself lives in
/// `ConfirmationGate` in `packages/domain`, which is tested without a screen.
///
/// **«أيوة» is 72dp and solid; «لأ» is 56dp and outline only.** Green is bigger
/// because agreeing is the common case, not because Kafoo wants the yes — both
/// are far past the 48dp floor, and the no is never hidden, greyed, or made
/// slower to reach.
///
/// It renders on the dark voice panel, because the assistant is talking and
/// teal-on-dark is how the machine's own voice looks everywhere in Kafoo.
class KafooConfirmationGate extends StatelessWidget {
  const KafooConfirmationGate({
    required this.spokenReadback,
    required this.question,
    required this.confirmLabel,
    required this.rejectLabel,
    required this.footnote,
    required this.onConfirm,
    required this.onReject,
    this.amount,
    this.amountUnit,
    this.glanceWord,
    this.glanceText,
    this.subject,
    this.error,
    this.busy = false,
    super.key,
  });

  /// Exactly what the assistant said, shown in full. Not a summary — the
  /// read-back is what the person is agreeing to.
  final String spokenReadback;

  /// The question as a verdict — «تنشر؟».
  final String question;

  /// «أيوة، انشريها».
  final String confirmLabel;

  /// «لأ، استنى».
  final String rejectLabel;

  /// The line that says waiting is safe — that nothing happens if she says
  /// nothing.
  final String footnote;

  final VoidCallback onConfirm;
  final VoidCallback onReject;

  /// The number the decision turns on, if there is one — a price, a count.
  /// Set as the largest thing on the screen.
  final String? amount;
  final String? amountUnit;

  /// The status this action produces, from the closed set.
  final GlanceWord? glanceWord;
  final String? glanceText;

  /// A card describing what is being acted on — the Meal, the Order.
  final Widget? subject;

  /// Shown above the answers when the action failed.
  ///
  /// **The gate stays up.** A failure means nothing happened, so she is still
  /// deciding — closing the gate on a failed action would look exactly like a
  /// successful one.
  final String? error;

  /// Draws both answers inert while the action is running.
  final bool busy;

  @override
  Widget build(BuildContext context) => Semantics(
        // A live region: a gate that appears silently to a screen reader is a
        // gate that gets answered by accident.
        liveRegion: true,
        child: ColoredBox(
          color: KafooColors.darkSurface,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: KafooSpacing.md,
                children: [
                  Text(
                    spokenReadback,
                    style: KafooType.bodyLarge(arabic: true).copyWith(
                      height: 1.75,
                      color: KafooColors.quotedText,
                    ),
                  ),
                  if (subject != null) subject!,
                  if (amount != null)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: KafooSpacing.sm,
                      children: [
                        Text(
                          amount!,
                          style: KafooType.numeralVerdict
                              .copyWith(color: KafooColors.surface),
                        ),
                        if (amountUnit != null)
                          Text(
                            amountUnit!,
                            style: KafooType.body(arabic: true)
                                .copyWith(color: KafooColors.quotedText),
                          ),
                      ],
                    ),
                  if (glanceWord != null && glanceText != null)
                    KafooGlanceWord(
                      word: glanceWord!,
                      text: glanceText!,
                      size: GlanceWordSize.verdict,
                    ),
                  Text(
                    question,
                    style: KafooType.glanceWordVerdict
                        .copyWith(color: KafooColors.success),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: KafooType.body(arabic: true)
                          .copyWith(color: KafooColors.errorBorder),
                    ),
                  const SizedBox(height: KafooSpacing.sm),
                  _Answer(
                    label: confirmLabel,
                    enabled: !busy,
                    onPressed: onConfirm,
                    height: KafooSpacing.confirmYes,
                    background: KafooColors.success,
                    foreground: KafooColors.onPrimary,
                  ),
                  _Answer(
                    label: rejectLabel,
                    enabled: !busy,
                    onPressed: onReject,
                    height: KafooSpacing.confirmNo,
                    background: Colors.transparent,
                    foreground: KafooColors.surface,
                    border: KafooColors.surface,
                  ),
                  Text(
                    footnote,
                    textAlign: TextAlign.center,
                    style: KafooType.bodySmall(arabic: true)
                        .copyWith(color: KafooColors.quotedText),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _Answer extends StatelessWidget {
  const _Answer({
    required this.label,
    required this.onPressed,
    required this.height,
    required this.background,
    required this.foreground,
    this.border,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final double height;
  final Color background;
  final Color foreground;
  final Color? border;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          // `minimumSize`, not a fixed height, so the answer still grows when
          // text is scaled up. An answer that clips is an answer nobody reads.
          minimumSize: Size(double.infinity, height),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: KafooSpacing.lg,
            vertical: KafooSpacing.row,
          ),
          side: border == null
              ? BorderSide.none
              : BorderSide(color: border!, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KafooRadius.control),
          ),
          textStyle: KafooType.section(arabic: true)
              .copyWith(fontWeight: FontWeight.w700),
        ),
        child: Text(label, textAlign: TextAlign.center),
      );
}
