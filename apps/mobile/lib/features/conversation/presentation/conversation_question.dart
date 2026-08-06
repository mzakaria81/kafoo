import 'package:flutter/material.dart';
import 'package:kafoo_ui/ui.dart';

/// One question, rendered alone.
///
/// A distinct type so a test can assert that exactly one unanswered question
/// is on screen at any moment — an invariant that is otherwise only visible by
/// reading the layout. E1 proves it for the Kitchen Profile conversation
/// (SC-006); E2 proves the same thing for the Meal conversation (SC-002)
/// against this same widget, which is the point of it living here rather than
/// inside either feature.
class ConversationQuestion extends StatelessWidget {
  const ConversationQuestion({
    required this.prompt,
    required this.hint,
    super.key,
  });

  final String prompt;

  /// An example answer, or null for a question that offers its answers instead
  /// of inviting one. Nothing is rendered when it is null — an empty line of
  /// hint text under a question reads as a hint that failed to load.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = this.hint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(prompt, style: theme.textTheme.headlineSmall),
        if (hint != null) ...[
          const SizedBox(height: KafooSpacing.xs),
          Text(
            hint,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ],
    );
  }
}
