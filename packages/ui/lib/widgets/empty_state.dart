import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'button.dart';

/// An empty or failed state.
///
/// **Reason → expectation → one action.** "مفيش مطابخ فاتحة جمبك دلوقتي /
/// الطباخين بيفتحوا من حوالي ١١ الصبح / نبّهني أول ما يفتح." Not an apology,
/// not a dead end, and not a large illustration — decoration where an answer is
/// needed, and the first thing to look wrong on a mid-range screen.
///
/// A failure must say what was *preserved*. A Cook on a dropped connection
/// needs to know her work survived, so [reassurance] carries "اللي قولتيه
/// محفوظ" and [cachedContent] shows the last good data underneath at reduced
/// opacity rather than showing nothing at all.
class KafooEmptyState extends StatelessWidget {
  const KafooEmptyState({
    required this.title,
    required this.body,
    required this.primaryAction,
    this.failure = false,
    this.reassurance,
    this.secondaryAction,
    this.cachedContent,
    this.cachedLabel,
    super.key,
  });

  /// Already localized. The reason, in one line.
  final String title;

  /// What to expect.
  final String body;

  /// The single way forward. At most one more may sit beside it.
  final KafooButton primaryAction;

  /// Whether this is a failure rather than an absence — changes the medallion
  /// from the primary tint to the error tint.
  final bool failure;

  /// What survived. Shown above the actions, only on a failure.
  final String? reassurance;

  final KafooButton? secondaryAction;

  /// The last good data, if any. Rendered at 0.45 opacity below everything
  /// else: present, clearly stale, and better than an empty screen.
  final Widget? cachedContent;

  /// When the cached data was fetched — "آخر نسخة محفوظة · ٩:٤٠ الصبح".
  final String? cachedLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = failure ? KafooColors.errorTint : KafooColors.primaryTint;
    final edge = failure ? KafooColors.errorBorder : KafooColors.primaryBorder;

    // A FAILURE ANNOUNCES ITSELF; AN EMPTY LIST DOES NOT NEED TO.
    //
    // The screen a Cook was on said «بحمّل أكلاتك» out loud. If loading then
    // fails and this panel replaces it in silence, a Cook using a screen reader
    // is left waiting for a load that already gave up. `liveRegion` is what
    // makes the swap speak. An absence is not the same event — she navigated
    // here and the screen reader reads the new screen anyway.
    return Semantics(
      liveRegion: failure,
      container: failure,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: KafooSpacing.md,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: tint,
                  shape: BoxShape.circle,
                  border: Border.all(color: edge, width: 1.5),
                ),
              ),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: KafooColors.textMuted),
            ),
            if (reassurance != null)
              Container(
                padding: const EdgeInsetsDirectional.all(KafooSpacing.md),
                decoration: BoxDecoration(
                  color: KafooColors.voiceTint,
                  borderRadius: BorderRadius.circular(KafooRadius.panel),
                  border: Border.all(color: KafooColors.voiceBorder),
                ),
                child: Text(
                  reassurance!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: KafooColors.voiceDeep),
                ),
              ),
            primaryAction,
            if (secondaryAction != null) secondaryAction!,
            if (cachedContent != null) ...[
              const SizedBox(height: KafooSpacing.sm),
              if (cachedLabel != null)
                Text(
                  cachedLabel!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: KafooColors.textMuted),
                ),
              Opacity(opacity: 0.45, child: cachedContent),
            ],
          ],
        ),
      ),
    );
  }
}
