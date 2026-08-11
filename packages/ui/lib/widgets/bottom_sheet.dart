import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The body of a Kafoo bottom sheet.
///
/// Shape, drag handle and scrim come from the theme. This is the layout, and it
/// exists to hold three rules that call sites otherwise get wrong:
///
/// **The committing action sits at the bottom and stays pinned** while the
/// content above it scrolls. It is within thumb reach, and the summary is above
/// it — so a Customer reading fast sees the total before the button, not after.
///
/// **Cancel is plain text, never a coloured button.** Retreat must be easy and
/// must not compete.
///
/// **The sheet never fills the screen.** Capped at 90% of the height, because
/// if nothing behind it is visible people do not know it can be dismissed.
///
/// Never nest one of these inside another. A sheet on a sheet means the flow is
/// wrong.
class KafooSheet extends StatelessWidget {
  const KafooSheet({
    required this.title,
    required this.child,
    this.action,
    this.cancel,
    super.key,
  });

  /// Already localized.
  final String title;

  /// The scrolling content.
  final Widget child;

  /// The committing action, pinned at the bottom.
  final Widget? action;

  /// Plain-text retreat, under the action.
  final Widget? cancel;

  /// Shows this sheet, with Kafoo's dismissal rules already applied.
  ///
  /// Drag-down, a scrim tap and an explicit action all close it — the first
  /// thing anyone does is try to drag the handle, so all three have to work.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) =>
      showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        builder: builder,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              KafooSpacing.lg,
              0,
              KafooSpacing.lg,
              KafooSpacing.md,
            ),
            child: Text(title, style: theme.textTheme.headlineSmall),
          ),
          // Scrolls, so 200% text scale lengthens the body instead of pushing
          // the action off the bottom.
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: KafooSpacing.lg,
              ),
              child: child,
            ),
          ),
          if (action != null || cancel != null)
            Padding(
              padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: KafooSpacing.sm,
                children: [
                  if (action != null) action!,
                  if (cancel != null)
                    DefaultTextStyle.merge(
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: KafooColors.textMuted),
                      child: cancel!,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
