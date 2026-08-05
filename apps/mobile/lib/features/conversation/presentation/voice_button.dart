import 'package:flutter/material.dart';
import 'package:kafoo_ui/ui.dart';

/// The microphone control shared by every conversation.
///
/// Lives here rather than inside a feature because both the Kitchen Profile
/// conversation and the Meal conversation need exactly this control, and a
/// second copy is a second place for the tap target or the semantic label to
/// drift out of line with the accessibility rules.
class VoiceButton extends StatelessWidget {
  const VoiceButton({
    required this.listening,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final bool listening;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
        ),
        icon: Icon(listening ? Icons.stop : Icons.mic),
        label: Text(label),
      ),
    );
  }
}
