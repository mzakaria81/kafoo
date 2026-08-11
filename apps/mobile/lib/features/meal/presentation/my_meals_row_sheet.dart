import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
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
              onPressed: () => _run(sheetContext, action),
            ),
        ],
      ),
    ),
  );
}

Future<void> _run(BuildContext context, _RowAction action) async {
  final navigator = Navigator.of(context);
  final warning = action.warning;
  if (warning != null) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(warning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(action.cancelLabel!),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action.confirmLabel!),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
  }
  navigator.pop();
  await action.onSelected();
}

class _RowAction {
  _RowAction({
    required this.label,
    required this.onSelected,
    this.warning,
    this.confirmLabel,
    this.cancelLabel,
    this.destructive = false,
  });

  final String label;
  final Future<void> Function() onSelected;
  final String? warning;
  final String? confirmLabel;
  final String? cancelLabel;
  final bool destructive;
}
