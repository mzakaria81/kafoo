import 'package:flutter/material.dart';
import 'package:kafoo_ui/ui.dart';

/// One labelled value on the Meal summary, with its correct action.
///
/// SC-004 is "correctable in exactly one action", so the Change control is a
/// button on the row itself — not a menu, not an edit mode entered first. In
/// edit state the same row becomes a field, so the Cook never loses sight of
/// what they are changing.
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    required this.label,
    required this.value,
    required this.editing,
    required this.controller,
    required this.editLabel,
    required this.onEdit,
    required this.onCommit,
    this.multiline = false,
    super.key,
  });

  final String label;
  final String value;
  final bool editing;
  final TextEditingController controller;
  final String editLabel;
  final VoidCallback onEdit;
  final VoidCallback onCommit;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: KafooSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: KafooSpacing.xs),
          if (editing)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: multiline ? 4 : 1,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onCommit(),
                  ),
                ),
                IconButton(
                  onPressed: onCommit,
                  // The label names the row, so a Cook using a screen reader
                  // hears which value this confirms rather than "button".
                  tooltip: label,
                  icon: const Icon(Icons.check),
                  constraints: const BoxConstraints(
                    minWidth: KafooSpacing.minTapTarget,
                    minHeight: KafooSpacing.minTapTarget,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(value, style: theme.textTheme.bodyLarge),
                ),
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      KafooSpacing.minTapTarget,
                      KafooSpacing.minTapTarget,
                    ),
                  ),
                  child: Semantics(
                    button: true,
                    label: '$editLabel: $label',
                    child: Text(editLabel),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The photo row.
///
/// Read-only: choosing a photograph is T041. A Cook who declined sees the
/// "no photo" line rather than an empty row, because a blank space reads as
/// something that failed rather than something they chose.
class PhotoRow extends StatelessWidget {
  const PhotoRow({
    required this.label,
    required this.photoPath,
    required this.noPhotoLabel,
    super.key,
  });

  final String label;
  final String? photoPath;
  final String noPhotoLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: KafooSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: KafooSpacing.xs),
          Text(
            photoPath ?? noPhotoLabel,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: photoPath == null ? theme.colorScheme.outline : null,
            ),
          ),
        ],
      ),
    );
  }
}
