import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../../conversation/application/assistant_voice.dart';
import '../application/meal_conversation_controller.dart';
import '../application/my_meals_controller.dart';

/// What the `···` on a Meal row opens.
///
/// The actions moved off the row and into a sheet because the row now leads
/// with a 34px price and a glance word — four text buttons underneath it would
/// undo the one thing the voice-first shape is for, which is that a Cook can
/// tell two Meals apart without reading.
///
/// **Which action needs confirming has not changed.** An ordinary reversible
/// change — off the menu, back on — acts immediately; a Cook trained to dismiss
/// dialogs will dismiss the one that mattered. Retiring a Meal, deleting a
/// draft, and taking the last Meal off the menu are the three that ask first.
///
/// **HOW they ask changed on 2026-08-11.** They were plain pop-up dialogs. The
/// rule in `.claude/rules/business-rules.md` is that an irreversible action is
/// read back aloud in full and waits for «أيوة», and that voice and tap both
/// answer — so a silent dialog on a screen that greets a Cook out loud and
/// reads her Meals to her was the app going quiet at the one moment it had
/// something worth saying. They now open [KafooConfirmationGate], which speaks
/// the read-back and accepts a tap. Answering by voice arrives with recognition
/// on this screen; the gate already takes both.
Future<void> showMyMealRowSheet({
  required BuildContext context,
  required WidgetRef ref,
  required CookMeal meal,
  required String title,
  void Function(CookMeal meal)? onResumeDraft,
  void Function(Meal meal)? onEdit,
}) {
  final l10n = AppLocalizations.of(context);
  final form = context.addressForm;
  final controller = ref.read(myMealsControllerProvider.notifier);

  // Editing needs a complete Meal, which a draft is not. `asMeal` is null
  // exactly when a required field is still unanswered, so the control is absent
  // rather than disabled for a Meal that cannot yet be edited.
  final editable = meal.asMeal;

  final actions = <_RowAction>[
    if (editable != null && onEdit != null)
      _RowAction(
        label: l10n.mealEditTitle(form),
        onSelected: () async => onEdit(editable),
      ),
    if (meal.status == MealStatus.published)
      _RowAction(
        label: l10n.mealMakeUnavailable(form),
        // Only when this is the Cook's last Meal on offer. Taking any other one
        // off the menu is ordinary and reversible.
        warning: controller.wouldCloseKitchen(meal)
            ? l10n.mealLastOnOfferWarning(form)
            : null,
        question: l10n.mealLastOnOfferQuestion(form),
        confirmLabel: l10n.mealLastOnOfferConfirm(form),
        cancelLabel: l10n.mealLastOnOfferCancel(form),
        onSelected: () => controller.setStatus(meal, MealStatus.unavailable),
      ),
    if (meal.status == MealStatus.unavailable)
      _RowAction(
        label: l10n.mealMakeAvailable(form),
        onSelected: () => controller.setStatus(meal, MealStatus.published),
      ),
    if (meal.status == MealStatus.draft) ...[
      _RowAction(
        label: l10n.mealResumeDraft(form),
        onSelected: () async {
          ref.read(mealConversationControllerProvider.notifier).resume(meal);
          onResumeDraft?.call(meal);
        },
      ),
      _RowAction(
        label: l10n.mealDeleteDraft(form),
        warning: l10n.mealDeleteDraftWarning(form),
        question: l10n.mealDeleteDraftQuestion(form),
        confirmLabel: l10n.mealDeleteDraftConfirm(form),
        cancelLabel: l10n.mealRetireCancel(form),
        destructive: true,
        onSelected: () => controller.deleteDraft(meal),
      ),
    ],
    if (meal.status != MealStatus.archived && meal.status != MealStatus.draft)
      _RowAction(
        label: l10n.mealRetire(form),
        // Retirement is always confirmed. It is the one action here that cannot
        // be undone by taking the same action again.
        warning: l10n.mealRetireWarning,
        question: l10n.mealRetireQuestion(form),
        confirmLabel: l10n.mealRetireConfirm(form),
        cancelLabel: l10n.mealRetireCancel(form),
        destructive: true,
        onSelected: () => controller.setStatus(meal, MealStatus.archived),
      ),
  ];

  // A retired Meal offers nothing. Not a sheet with nothing in it.
  if (actions.isEmpty) return Future<void>.value();

  return KafooSheet.show<void>(
    context: context,
    builder: (sheetContext) => KafooSheet(
      title: title,
      cancel: TextButton(
        onPressed: () => Navigator.of(sheetContext).pop(),
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
        ),
        child: Text(l10n.mealRetireCancel(form)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: KafooSpacing.sm,
        children: [
          for (final action in actions)
            KafooButton(
              label: action.label,
              fullWidth: true,
              variant: action.destructive
                  ? KafooButtonVariant.destructive
                  : KafooButtonVariant.secondary,
              onPressed: () => _run(sheetContext, ref, action),
            ),
        ],
      ),
    ),
  );
}

Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  _RowAction action,
) async {
  final navigator = Navigator.of(context);
  final readback = action.warning;
  if (readback != null) {
    final confirmed = await navigator.push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (gateContext) => _Gate(action: action, readback: readback),
      ),
    );
    // Silence never confirms, and neither does dismissing the gate: only the
    // yes answers it.
    if (confirmed != true) return;
  }
  navigator.pop();
  await action.onSelected();
}

/// The read-back gate for one destructive action.
///
/// Stateful only so the line is spoken once, on arrival, rather than on every
/// rebuild — the same reason the Meal list greets from a post-frame callback.
class _Gate extends ConsumerStatefulWidget {
  const _Gate({required this.action, required this.readback});

  final _RowAction action;
  final String readback;

  @override
  ConsumerState<_Gate> createState() => _GateState();
}

class _GateState extends ConsumerState<_Gate> {
  /// The rule, not a copy of it. `ConfirmationGate` holds "silence never
  /// confirms" and "ask once more, then wait" — and it lived in
  /// `packages/domain/`, fully tested and called by nothing, while this screen
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
      // Read back in full. Not quietly: this is the sentence a Cook is being
      // asked to agree to, and a decision she cannot undo is not the place to
      // protect her from being overheard.
      ref.read(assistantVoiceProvider.notifier).say(_gate.spokenReadback);
      _armReprompt();
    });
  }

  /// Asks once more, then waits indefinitely.
  ///
  /// A Cook steps away mid-sentence — flour on her hands, a pot going over —
  /// and comes back to a screen that has said nothing since. One repeat is the
  /// difference between waiting and abandoned. A third would be nagging, and
  /// nagging is how people learn to say yes to make it stop, which is the one
  /// outcome a gate exists to prevent.
  void _armReprompt() {
    _repromptTimer = Timer(_gate.repromptAfter, () {
      if (!mounted || !_gate.reprompt()) return;
      ref.read(assistantVoiceProvider.notifier).say(_gate.spokenReadback);
    });
  }

  void _answer(bool confirmed) {
    _gate.answer(confirmed: confirmed);
    _stopTalking();
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
      // The back gesture is an answer too, and it is «لأ». Left alone it
      // skipped the answer path entirely, so the assistant kept reading a
      // warning aloud over a screen that had already closed.
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
            spokenReadback: widget.readback,
            question: widget.action.question!,
            confirmLabel: widget.action.confirmLabel!,
            rejectLabel: widget.action.cancelLabel!,
            footnote: l10n.gateSilenceFootnote(form),
            onConfirm: () => _answer(true),
            onReject: () => _answer(false),
          ),
        ),
      ),
    );
  }
}

class _RowAction {
  _RowAction({
    required this.label,
    required this.onSelected,
    this.warning,
    this.question,
    this.confirmLabel,
    this.cancelLabel,
    this.destructive = false,
  });

  final String label;
  final Future<void> Function() onSelected;

  /// The sentence read back aloud and shown as quoted speech. Non-null makes
  /// this action pass through the gate.
  final String? warning;

  /// The verdict — «تشيليها خالص؟». Required whenever [warning] is set.
  final String? question;

  final String? confirmLabel;
  final String? cancelLabel;
  final bool destructive;
}
