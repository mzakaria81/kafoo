import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../application/assistant_voice.dart';

/// The read-back that stands in front of anything irreversible.
///
/// **ONE GATE, NOT A GATE PER CALLER.** This lived inside
/// `my_meals_row_sheet.dart` as a private widget, so retiring a Meal got the
/// full DESIGN.md §10.6 treatment — read back aloud, repeated once after eight
/// seconds, «أيوة» at 72dp — and PUBLISHING a Meal, the single most irreversible
/// thing a Cook does in this product, got a plain `FilledButton` reading «تمام،
/// انشرها». The rule was implemented once and applied to the smaller case.
///
/// Every rule that makes a gate a gate lives here and cannot be forgotten by a
/// new caller:
///
/// - **The line is read back aloud in full**, on arrival, once — not quietly.
///   A decision she cannot undo is not the place to protect her from being
///   overheard.
/// - **Silence never confirms.** No timer answers this. `ConfirmationGate` in
///   `packages/domain` holds that rule and is tested without a screen.
/// - **It asks once more after eight seconds, then waits indefinitely.** A Cook
///   steps away mid-sentence; one repeat is the difference between waiting and
///   abandoned. A third would teach her to say yes to make it stop, which is
///   the one outcome a gate exists to prevent.
/// - **The back gesture is an answer, and it is «لأ».** Left alone it skipped
///   the answer path, so the assistant kept reading a warning aloud over a
///   screen that had already closed.
Future<bool> askReadBackGate({
  required BuildContext context,
  required String readback,
  required String question,
  required String confirmLabel,
  required String rejectLabel,
  String? amount,
  String? amountUnit,
  GlanceWord? glanceWord,
  String? glanceText,
  Widget? subject,
}) async {
  final confirmed = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => ReadBackGateScreen(
        readback: readback,
        question: question,
        confirmLabel: confirmLabel,
        rejectLabel: rejectLabel,
        amount: amount,
        amountUnit: amountUnit,
        glanceWord: glanceWord,
        glanceText: glanceText,
        subject: subject,
      ),
    ),
  );
  // Silence never confirms, and neither does dismissing the gate: only the yes
  // answers it.
  return confirmed == true;
}

/// The gate screen itself.
///
/// Stateful only so the line is spoken once, on arrival, rather than on every
/// rebuild — the same reason the Meal list greets from a post-frame callback.
class ReadBackGateScreen extends ConsumerStatefulWidget {
  const ReadBackGateScreen({
    required this.readback,
    required this.question,
    required this.confirmLabel,
    required this.rejectLabel,
    this.amount,
    this.amountUnit,
    this.glanceWord,
    this.glanceText,
    this.subject,
    this.onAnswered,
    this.error,
    this.busy = false,
    super.key,
  });

  final String readback;
  final String question;
  final String confirmLabel;
  final String rejectLabel;
  final String? amount;
  final String? amountUnit;
  final GlanceWord? glanceWord;
  final String? glanceText;
  final Widget? subject;

  /// Called with the answer INSTEAD of popping the route.
  ///
  /// **For a gate that IS a screen rather than one in front of a screen.**
  /// Leaving Kafoo is the case: FR-034 allows exactly one confirmation and no
  /// second «متأكد؟», so the read-back cannot be pushed on top of a screen that
  /// already asked — it has to BE that screen. Null keeps the ordinary
  /// behaviour, which is to pop with the answer.
  final void Function({required bool confirmed})? onAnswered;

  /// Shown above the answers when the action failed. The gate stays up, because
  /// a failure means nothing happened and she is still deciding.
  final String? error;

  /// Draws the answers inert while the action is running, so a second tap
  /// cannot start it twice.
  final bool busy;

  @override
  ConsumerState<ReadBackGateScreen> createState() => _ReadBackGateScreenState();
}

class _ReadBackGateScreenState extends ConsumerState<ReadBackGateScreen> {
  /// The rule, not a copy of it. `ConfirmationGate` holds "silence never
  /// confirms" and "ask once more, then wait" — and it lived in
  /// `packages/domain/`, fully tested and called by nothing, while the screen
  /// spoke the warning once and then waited forever. A tested class nobody
  /// instantiates makes a rule look met.
  late final ConfirmationGate _gate =
      ConfirmationGate(spokenReadback: widget.readback);

  Timer? _repromptTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(assistantVoiceProvider.notifier).say(_gate.spokenReadback);
      _armReprompt();
    });
  }

  void _armReprompt() {
    _repromptTimer = Timer(_gate.repromptAfter, () {
      if (!mounted || !_gate.reprompt()) return;
      ref.read(assistantVoiceProvider.notifier).say(_gate.spokenReadback);
    });
  }

  void _answer({required bool confirmed}) {
    _gate.answer(confirmed: confirmed);
    _stopTalking();
    final answered = widget.onAnswered;
    if (answered != null) {
      // READ THE ANSWER BEFORE REOPENING. `reopen()` clears it, so asking the
      // gate afterwards returns false — which turned every «أيوة» on a
      // screen-shaped gate into a «لأ» and left the action never running.
      final said = _gate.isConfirmed;
      // Re-armable: a failed action leaves her deciding, so the gate must be
      // able to take another answer rather than being spent by the first.
      _gate.reopen();
      answered(confirmed: said);
      return;
    }
    Navigator.of(context).pop(_gate.isConfirmed);
  }

  /// Stops mid-sentence. Continuing to read a warning she has already acted on
  /// is the assistant talking over her — and on a back-gesture dismissal the
  /// screen is gone while the voice carries on, which is worse.
  void _stopTalking() {
    _repromptTimer?.cancel();
    _repromptTimer = null;
    ref.read(assistantVoiceProvider.notifier).hush();
  }

  @override
  void dispose() {
    _repromptTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = context.addressForm;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Guarded, because this fires on EVERY pop — including the one a tap on
        // yes or no causes. Both calls happen to be idempotent today; the guard
        // is here so that adding anything that is not, an analytics event or a
        // haptic, does not silently fire twice on every ordinary answer.
        if (!didPop || _gate.isAnswered) return;
        _gate.answer(confirmed: false);
        _stopTalking();
      },
      child: Scaffold(
        backgroundColor: KafooColors.darkSurface,
        body: SafeArea(
          child: KafooConfirmationGate(
            error: widget.error,
            busy: widget.busy,
            spokenReadback: widget.readback,
            question: widget.question,
            confirmLabel: widget.confirmLabel,
            rejectLabel: widget.rejectLabel,
            footnote: l10n.gateSilenceFootnote(form),
            amount: widget.amount,
            amountUnit: widget.amountUnit,
            glanceWord: widget.glanceWord,
            glanceText: widget.glanceText,
            subject: widget.subject,
            onConfirm: () => _answer(confirmed: true),
            onReject: () => _answer(confirmed: false),
          ),
        ),
      ),
    );
  }
}
