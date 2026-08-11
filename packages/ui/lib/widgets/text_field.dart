import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Kafoo's text input.
///
/// **Deliberately demoted.** Typing Arabic on a phone keyboard is the hardest
/// thing this product asks of a Cook, so an input is a choice she makes, never
/// the consequence of the assistant failing to understand her. It keeps a full
/// specification because it has to work perfectly when it *is* chosen.
///
/// Two rules are enforced here rather than left to call sites:
///
/// **[helperText] is required and always occupies its row.** An error message
/// replaces the helper instead of pushing the form down; a form that jumps
/// makes people lose their place mid-entry. Passing an empty string still
/// reserves the row.
///
/// **[latinNumerals] flips one field inside a right-to-left form.** Phone
/// numbers, one-time codes and address numerals are typed on a Latin numeric
/// keypad and copy-pasted, so the text runs left-to-right while the label and
/// the field's position stay right-to-left.
class KafooTextField extends StatelessWidget {
  const KafooTextField({
    required this.label,
    required this.helperText,
    this.controller,
    this.errorText,
    this.hintText,
    this.enabled = true,
    this.latinNumerals = false,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    super.key,
  });

  /// Above the field, always visible. A placeholder is not a label — it
  /// disappears exactly when someone needs to check what they are filling in.
  final String label;

  /// Below the field, always occupying its row. Empty string for "nothing to
  /// say here", never null.
  final String helperText;

  final TextEditingController? controller;

  /// Replaces [helperText] when set. Say what to do, with the number — "الرقم
  /// ناقص رقمين. لازم ١١ رقم." — never "Invalid input".
  final String? errorText;

  final String? hintText;
  final bool enabled;
  final bool latinNumerals;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      // The field's own direction, not the form's. See the class comment.
      textDirection: latinNumerals ? TextDirection.ltr : null,
      textAlign: latinNumerals ? TextAlign.left : TextAlign.start,
      // 16px minimum: anything smaller triggers iOS zoom-on-focus and is hard
      // to proof-read in sun.
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        // Both rows are reserved whatever the message length, so a two-line
        // error does not shift the fields under it either.
        helperMaxLines: 2,
        errorMaxLines: 2,
        filled: true,
        fillColor: switch ((enabled, errorText != null)) {
          (false, _) => KafooColors.surfaceSunken,
          (_, true) => KafooColors.errorTint,
          _ => KafooColors.surfaceRaised,
        },
      ),
    );
  }
}
