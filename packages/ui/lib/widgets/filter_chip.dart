import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A filter chip.
///
/// **40dp visually, 48dp to a finger.** A row of 48dp-tall chips looks like a
/// row of buttons and dominates a screen it should merely qualify, so the
/// target is padded around the visual rather than the visual being grown to
/// match it. That padding comes from the theme's
/// `MaterialTapTargetSize.padded`.
///
/// **A chip must never look like a status badge.** A Cook who taps «مسودة»
/// expecting it to change state has been misled by the shape. Status is a
/// [KafooGlanceWord]; only this is tappable.
///
/// Unavailable chips say why — "حلويات — مفيش دلوقتي" — rather than vanishing.
/// A filter that disappears looks like a bug; one that explains itself is an
/// answer.
class KafooFilterChip extends StatelessWidget {
  const KafooFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.unavailable = false,
    super.key,
  });

  /// Already localized. For an unavailable chip this carries the reason.
  final String label;

  final bool selected;

  /// Null, or [unavailable], makes the chip inert.
  final ValueChanged<bool>? onSelected;

  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final enabled = onSelected != null && !unavailable;
    final theme = Theme.of(context);

    return FilterChip(
      label: Text(label, maxLines: 1),
      selected: selected,
      onSelected: enabled ? onSelected : null,
      showCheckmark: false,
      backgroundColor:
          unavailable ? KafooColors.surfaceSunken : KafooColors.surfaceRaised,
      selectedColor: KafooColors.primary,
      labelStyle: theme.chipTheme.labelStyle?.copyWith(
        color: switch ((selected, unavailable)) {
          (true, _) => KafooColors.onPrimary,
          (_, true) => KafooColors.textDisabled,
          _ => KafooColors.onSurface,
        },
      ),
      side: BorderSide(
        color: switch ((selected, unavailable)) {
          (true, _) => KafooColors.primary,
          (_, true) => KafooColors.border,
          _ => KafooColors.borderStrong,
        },
        width: 1.5,
      ),
      // 48dp of target around a 40dp visual.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );
  }
}

/// A horizontally scrolling row of [KafooFilterChip]s.
///
/// **One line, always — never wrapping to a second row.** A filter bar that
/// wraps reflows the list underneath it every time a filter changes, so the
/// content jumps while somebody is reading it. Off-screen chips are reached by
/// scrolling instead.
class KafooFilterBar extends StatelessWidget {
  const KafooFilterBar({required this.chips, super.key});

  final List<KafooFilterChip> chips;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsetsDirectional.symmetric(horizontal: KafooSpacing.lg),
        child: Row(
          spacing: KafooSpacing.row,
          children: chips,
        ),
      );
}
