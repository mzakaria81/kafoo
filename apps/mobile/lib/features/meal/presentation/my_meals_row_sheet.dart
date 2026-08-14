import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../../conversation/application/assistant_voice.dart';
import '../../conversation/presentation/read_back_gate.dart';
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
        // Navigation, not a write, so there is nothing to announce as done.
        // The screen it opens is silent, which is its own gap and not this
        // sheet's to close — see `docs/design/backend-gaps.md`.
        onSelected: () async {
          onEdit(editable);
          return true;
        },
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
        spokenDone: l10n.mealSpokenTakenOffMenu,
        onSelected: () => controller.setStatus(meal, MealStatus.unavailable),
      ),
    if (meal.status == MealStatus.unavailable)
      _RowAction(
        label: l10n.mealMakeAvailable(form),
        spokenDone: l10n.mealSpokenBackOnMenu,
        onSelected: () => controller.setStatus(meal, MealStatus.published),
      ),
    if (meal.status == MealStatus.draft) ...[
      _RowAction(
        label: l10n.mealResumeDraft(form),
        // NOT ANNOUNCED, AND THE SCREEN IT OPENS DOES NOT SPEAK EITHER. This
        // comment used to claim the conversation greets her on arrival. It
        // does not: `assistantVoiceProvider` is read in exactly two files and
        // neither is that screen. So a Cook taps «كمّل» on a half-finished Meal
        // and hears nothing at all, which is a real gap rather than a handled
        // one, and belongs to the conversation screen rather than to this
        // sheet. Recorded in `docs/design/backend-gaps.md`; a "done" line said
        // here would be a lie about arriving somewhere that then says nothing.
        onSelected: () async {
          ref.read(mealConversationControllerProvider.notifier).resume(meal);
          onResumeDraft?.call(meal);
          return true;
        },
      ),
      _RowAction(
        label: l10n.mealDeleteDraft(form),
        warning: l10n.mealDeleteDraftWarning(form),
        question: l10n.mealDeleteDraftQuestion(form),
        confirmLabel: l10n.mealDeleteDraftConfirm(form),
        cancelLabel: l10n.mealRetireCancel(form),
        spokenDone: l10n.mealSpokenDraftDeleted,
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
        spokenDone: l10n.mealSpokenRetired,
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
    final confirmed = await askReadBackGate(
      context: context,
      readback: readback,
      question: action.question!,
      confirmLabel: action.confirmLabel!,
      rejectLabel: action.cancelLabel!,
    );
    if (!confirmed) return;
  }
  navigator.pop();
  final succeeded = await action.onSelected();

  // ANNOUNCED, NOT SILENT. The rule is that a reversible action executes
  // immediately and is said out loud, and a gated one is announced once it has
  // executed. Taking a Meal off the menu and putting it back happened without a
  // word — on a screen that greets a Cook aloud and reads her Meals to her,
  // which makes the silence at the moment something actually changed louder,
  // not quieter.
  //
  // Only on success. Announcing a change that did not happen is worse than
  // saying nothing, and the screen already shows the failure in words.
  final done = action.spokenDone;
  if (succeeded && done != null) {
    await ref.read(assistantVoiceProvider.notifier).say(done);
  }
}

class _RowAction {
  _RowAction({
    required this.label,
    required this.onSelected,
    this.spokenDone,
    this.warning,
    this.question,
    this.confirmLabel,
    this.cancelLabel,
    this.destructive = false,
  });

  final String label;

  /// Returns whether it actually happened. A write that failed must not be
  /// announced as done.
  final Future<bool> Function() onSelected;

  /// Said aloud after [onSelected] succeeds. Null for an action that navigates
  /// rather than writes — the screen it opens does its own talking.
  final String? spokenDone;

  /// The sentence read back aloud and shown as quoted speech. Non-null makes
  /// this action pass through the gate.
  final String? warning;

  /// The verdict — «تشيليها خالص؟». Required whenever [warning] is set.
  final String? question;

  final String? confirmLabel;
  final String? cancelLabel;
  final bool destructive;
}
