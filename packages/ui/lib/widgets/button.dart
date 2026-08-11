import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Which of the three button roles this is.
enum KafooButtonVariant {
  /// The one committing action on a screen. If two things look primary,
  /// neither is.
  primary,

  /// Connected to primary without competing with it.
  secondary,

  /// Irreversible. Rests as an outline and only fills solid under the finger,
  /// so it cannot be hit by muscle memory — but it still confirms with full
  /// colour while pressed.
  destructive,
}

/// Kafoo's button.
///
/// The resting appearance of each variant comes from the theme, not from here.
/// This widget exists for the two things a theme cannot express:
///
/// **Loading keeps the footprint identical.** The label is replaced by a
/// spinner and an Egyptian-Arabic present continuous ("بيتبعت...") at the same
/// size, so the screen does not shift under a finger that is already moving.
///
/// **Destructive fills solid only while pressed.** See [KafooButtonVariant].
///
/// A disabled button states the reason in its own label — "المطبخ مقفول
/// دلوقتي" rather than a grey rectangle. That is why [label] is what changes
/// when the button is inert, and why there is no separate "disabled label"
/// parameter: a disabled button with no explanation is a dead end, so the
/// caller is made to write the sentence.
class KafooButton extends StatefulWidget {
  const KafooButton({
    required this.label,
    required this.onPressed,
    this.variant = KafooButtonVariant.primary,
    this.loading = false,
    this.loadingLabel,
    this.committing = false,
    this.fullWidth = false,
    super.key,
  });

  /// Already localized. When [onPressed] is null this should say *why*.
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  final KafooButtonVariant variant;

  final bool loading;

  /// Shown in place of [label] while [loading]. Egyptian-Arabic present
  /// continuous. Falls back to [label] so a caller who has not written one yet
  /// gets a stable footprint rather than an empty button.
  final String? loadingLabel;

  /// Whether this is the screen's single committing action, which is taller
  /// (56dp) and sets its label one step larger.
  final bool committing;

  final bool fullWidth;

  @override
  State<KafooButton> createState() => _KafooButtonState();
}

class _KafooButtonState extends State<KafooButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final minHeight = widget.committing ? 56.0 : KafooSpacing.minTapTarget;

    final (background, foreground, border) = switch (widget.variant) {
      KafooButtonVariant.primary => (
          _pressed ? KafooColors.primaryDeep : KafooColors.primary,
          KafooColors.onPrimary,
          null,
        ),
      KafooButtonVariant.secondary => (
          _pressed ? const Color(0xFFFDE7D3) : KafooColors.primaryTint,
          KafooColors.primaryDeep,
          _pressed ? KafooColors.primary : KafooColors.primaryBorder,
        ),
      KafooButtonVariant.destructive => (
          _pressed ? KafooColors.error : KafooColors.errorTint,
          _pressed ? KafooColors.onPrimary : KafooColors.error,
          KafooColors.errorBorder,
        ),
    };

    final style = ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(
        enabled || widget.loading ? background : KafooColors.disabledFill,
      ),
      foregroundColor: WidgetStatePropertyAll(
        enabled || widget.loading ? foreground : KafooColors.textDisabled,
      ),
      side: WidgetStatePropertyAll(
        border == null
            ? BorderSide.none
            : BorderSide(
                color: enabled ? border : KafooColors.border,
                width: 1.5,
              ),
      ),
      elevation: const WidgetStatePropertyAll(0),
      // Padding rather than a fixed height, so the button grows with scaled
      // text instead of clipping it.
      padding: const WidgetStatePropertyAll(
        EdgeInsetsDirectional.symmetric(
          horizontal: KafooSpacing.lg,
          vertical: KafooSpacing.md,
        ),
      ),
      minimumSize: WidgetStatePropertyAll(
        Size(widget.fullWidth ? double.infinity : 0, minHeight),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KafooRadius.control),
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: widget.committing ? 20 : 16,
            ),
      ),
    );

    final text =
        widget.loading ? (widget.loadingLabel ?? widget.label) : widget.label;

    return Semantics(
      button: true,
      enabled: enabled,
      // A loading button is busy, not broken. Saying so is the only way a
      // screen reader user learns the tap landed.
      label: text,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: KafooMotion.exit,
        curve: KafooMotion.exitCurve,
        child: ElevatedButton(
          onPressed: enabled ? widget.onPressed : null,
          style: style,
          // Press state is tracked by hand rather than through WidgetState
          // because the treatment changes fill, border and label together, and
          // destructive inverts all three at once.
          child: _PressTracker(
            onChanged: (v) => setState(() => _pressed = v),
            enabled: enabled,
            child: Row(
              mainAxisSize:
                  widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.loading) ...[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(width: KafooSpacing.sm),
                ],
                Flexible(child: Text(text, textAlign: TextAlign.center)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reports press state up, without swallowing the button's own tap.
class _PressTracker extends StatelessWidget {
  const _PressTracker({
    required this.onChanged,
    required this.enabled,
    required this.child,
  });

  final ValueChanged<bool> onChanged;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: enabled ? (_) => onChanged(true) : null,
        onPointerUp: enabled ? (_) => onChanged(false) : null,
        onPointerCancel: enabled ? (_) => onChanged(false) : null,
        child: child,
      );
}
