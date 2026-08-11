import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'glance_word.dart';
import 'photo_placeholder.dart';

/// A Meal in the Cook's own list.
///
/// **This is the voice-first shape, and it inverts the old one.** DESIGN.md
/// §6.3 describes a row led by the Meal's name at 17px with a small status
/// badge beside it; §10 supersedes that, and the handoff marks the tap-first
/// version of this screen as replaced. What changed and why:
///
/// - **The price is the largest thing in the row** — 34px, because numbers are
///   read by nearly everyone and words are not.
/// - **Status is a glance word at 20px**, from the closed set, recognised by
///   silhouette. The small badge is gone; a badge that looks like a filter chip
///   invites a Cook to tap «مسودة» expecting it to change.
/// - **The Meal name drops to 14px muted.** Present, and spoken aloud on tap —
///   but never the only thing distinguishing two Meals. If the only difference
///   between two choices is set in small text, the screen has failed.
class KafooMealRow extends StatelessWidget {
  const KafooMealRow({
    required this.name,
    required this.price,
    this.priceUnit,
    required this.status,
    required this.statusText,
    required this.semanticsLabel,
    required this.placeholderLabel,
    this.photoUrl,
    this.onHear,
    this.hearLabel,
    this.onMore,
    this.moreLabel,
    this.onTap,
    super.key,
  });

  /// What the Cook called it, already localized where it is not her own words.
  final String name;

  /// The numeral alone, already formatted — Arabic-Indic, never abbreviated.
  final String price;

  /// "جنيه", one step down from the numeral. Optional: a caller holding one
  /// combined money string still renders correctly, just without the size
  /// difference between the number and the word.
  final String? priceUnit;

  final GlanceWord status;

  /// The localized word matching [status], from the closed set.
  final String statusText;

  /// How the whole row reads aloud, already composed and localized.
  final String semanticsLabel;

  /// How an empty photo slot reads aloud.
  final String placeholderLabel;

  final String? photoUrl;

  /// Reads this row aloud. Null hides the control — there is no text-to-speech
  /// service in Kafoo yet, and a button that does nothing is worse than no
  /// button.
  final VoidCallback? onHear;
  final String? hearLabel;

  /// Opens the row's bottom sheet.
  final VoidCallback? onMore;
  final String? moreLabel;

  final VoidCallback? onTap;

  static const double _thumb = 80;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final faded =
        status == GlanceWord.unavailable || status == GlanceWord.archived;

    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: Opacity(
        // Present, but clearly not selling.
        opacity: faded ? 0.6 : 1,
        child: Material(
          color: KafooColors.surfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KafooRadius.panel),
            side: const BorderSide(color: KafooColors.border),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(KafooRadius.panel),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(KafooSpacing.row),
              // Wrap, not Row: at 200% text scale the controls drop below the
              // price instead of squeezing a 34px numeral into nothing.
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: KafooSpacing.row,
                runSpacing: KafooSpacing.row,
                children: [
                  SizedBox(
                    width: _thumb,
                    height: _thumb,
                    child: photoUrl == null
                        ? KafooPhotoPlaceholder(
                            semanticsLabel: placeholderLabel,
                          )
                        : ClipRRect(
                            borderRadius:
                                BorderRadius.circular(KafooRadius.thumbnail),
                            child: Image.network(
                              photoUrl!,
                              excludeFromSemantics: true,
                              width: _thumb,
                              height: _thumb,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const ColoredBox(
                                color: KafooColors.surfaceSunken,
                              ),
                            ),
                          ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: KafooSpacing.xs,
                      children: [
                        KafooGlanceWord(word: status, text: statusText),
                        // Wrap, not Row: a 34px numeral at 200% scale is
                        // 68px, and a price is never truncated or shrunk to
                        // fit. It moves onto its own line instead.
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: KafooSpacing.xs,
                          children: [
                            Text(
                              price,
                              style: KafooType.numeralRow
                                  .copyWith(color: KafooColors.onSurface),
                            ),
                            if (priceUnit != null)
                              Text(
                                priceUnit!,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontSize: 15,
                                  color: KafooColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          name,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: KafooColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: KafooSpacing.sm,
                    children: [
                      if (onHear != null)
                        _RoundAction(
                          icon: Icons.volume_up_outlined,
                          label: hearLabel ?? '',
                          background: KafooColors.voiceTint,
                          foreground: KafooColors.voiceDeep,
                          onPressed: onHear!,
                        ),
                      if (onMore != null)
                        _RoundAction(
                          icon: Icons.more_horiz,
                          label: moreLabel ?? '',
                          background: KafooColors.surfaceSunken,
                          foreground: KafooColors.onSurface,
                          onPressed: onMore!,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: KafooSpacing.minTapTarget,
        height: KafooSpacing.minTapTarget,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          // An icon-only control with no label is unusable with a screen
          // reader, and this one sits inside a row whose semantics are
          // excluded — so the label has to be here.
          tooltip: label.isEmpty ? null : label,
          style: IconButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            shape: const CircleBorder(),
          ),
        ),
      );
}
