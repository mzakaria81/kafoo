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
    this.editing = false,
    this.controller,
    this.editLabel,
    this.onEdit,
    this.onCommit,
    this.multiline = false,
    super.key,
  });

  final String label;
  final String value;
  final bool editing;
  final TextEditingController? controller;
  final String? editLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onCommit;
  final bool multiline;

  bool get _editable => onEdit != null;

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
                ?.copyWith(color: KafooColors.textMuted),
          ),
          const SizedBox(height: KafooSpacing.xs),
          if (editing && controller != null && onCommit != null)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: multiline ? 4 : 1,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onCommit!(),
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
                if (_editable)
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
                      label: '${editLabel!}: $label',
                      child: Text(editLabel!),
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
    required this.photoUrl,
    required this.noPhotoLabel,
    required this.photoSemanticsLabel,
    super.key,
  });

  final String label;

  /// A URL to render, or null when the Cook added no photograph.
  ///
  /// **A URL, NOT A STORAGE PATH, AND THAT IS THE FIX.** This took
  /// `photoPath` and rendered it as text, so a Cook who had just photographed
  /// her food saw `7a38f558-.../69d0e03e-....jpg` on the screen where she checks
  /// the Meal before putting it on offer. The path is an address inside a
  /// bucket; it was never something to show a person.
  final String? photoUrl;

  final String noPhotoLabel;

  /// Spoken in place of the photograph. Confirms it is attached, which is the
  /// question the Cook is on this screen to answer.
  final String photoSemanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: KafooSpacing.md),
      // MERGED EXPLICITLY, RATHER THAN RELYING ON WHAT THE SCROLL VIEW HAPPENED
      // TO DO. A screen reader must read «الصورة، اللي اخترتها، موجودة» as one
      // thing — the field name and the confirmation belong together, and the
      // confirmation alone does not say what it is confirming. This used to
      // merge because the receipt was a `ListView`; the receipt became a panel
      // (ADR-0015) and the label silently stopped being read.
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: KafooColors.textMuted),
            ),
            const SizedBox(height: KafooSpacing.xs),
            if (photoUrl case final url?)
              MealPhoto(url: url, semanticsLabel: photoSemanticsLabel)
            else
              Text(
                noPhotoLabel,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: KafooColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}
