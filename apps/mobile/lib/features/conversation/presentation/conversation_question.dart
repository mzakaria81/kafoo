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
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(prompt, style: theme.textTheme.headlineSmall),
        const SizedBox(height: KafooSpacing.xs),
        Text(
          hint,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }
}
