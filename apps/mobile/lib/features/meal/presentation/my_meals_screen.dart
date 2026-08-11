import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../application/meal_conversation_controller.dart';
import '../application/my_meals_controller.dart';
import 'meal_edit_screen.dart';
import 'meal_enum_labels.dart';
import 'meal_error_text.dart';

class MyMealsScreen extends ConsumerWidget {
  const MyMealsScreen({this.onResumeDraft, super.key});

  /// Called after [MealConversationController.resume] seeds the conversation
  /// from a stored draft. Navigation is the caller's concern, exactly as
  /// [MealSummaryScreen.onPublished] works.
  final void Function(CookMeal meal)? onResumeDraft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(myMealsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myMealsTitle)),
      body: SafeArea(
        // Loading is checked FIRST and before emptiness. "No Meals yet" and
        // "not answered yet" look identical in the data and mean opposite
        // things to the Cook reading them.
        child: state.loading
            ? const Center(child: CircularProgressIndicator())
            : state.error != null && state.meals.isEmpty
                ? _ErrorState(error: state.error!)
                : state.meals.isEmpty
                    ? const _EmptyState()
                    : Column(
                        children: [
                          if (state.error != null)
                            _InlineError(error: state.error!),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsetsDirectional.all(
                                  KafooSpacing.lg),
                              itemCount: state.meals.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: KafooSpacing.sm),
                              itemBuilder: (context, index) {
                                final meal = state.meals[index];
                                return MyMealRow(
                                  meal: meal,
                                  onResumeDraft: onResumeDraft,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _ErrorState extends ConsumerWidget {
  const _ErrorState({required this.error});

  final AppError error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mealErrorText(context, error),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: KafooSpacing.md),
          FilledButton(
            onPressed: () => ref.invalidate(myMealsControllerProvider),
            child: Text(l10n.mealLoadRetry(context.addressForm)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Text(l10n.myMealsEmpty(context.addressForm),
          style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.error});

  final AppError error;

  @override
  Widget build(BuildContext context) {
    final message = mealErrorText(context, error);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: KafooSpacing.lg,
        end: KafooSpacing.lg,
        top: KafooSpacing.md,
      ),
      child: Text(message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              )),
    );
  }
}

class MyMealRow extends ConsumerWidget {
  const MyMealRow({required this.meal, this.onResumeDraft, super.key});

  final CookMeal meal;
  final void Function(CookMeal meal)? onResumeDraft;

  /// The dish name, or what to call a draft that has none.
  ///
  /// The schema permits a title-less row, so the list names one rather than
  /// rendering a blank that reads as something broken. Also used as the
  /// screen-reader suffix on every action, so a Cook hears which Meal an
  /// action applies to even before the first question is answered.
  String _title(AppLocalizations l10n) =>
      meal.title ?? l10n.myMealsUntitledDraft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(myMealsControllerProvider.notifier);
    final price = meal.price;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: KafooSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_title(l10n), style: theme.textTheme.bodyLarge),
          const SizedBox(height: KafooSpacing.xs),
          Text(
            price == null
                ? l10n.myMealsNoPriceYet
                : l10n.publicMealPriceValue(price),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: KafooSpacing.xs),
          Text(
            mealStatusLabel(l10n, meal.status),
            style: theme.textTheme.labelMedium?.copyWith(
              color: KafooColors.textMuted,
            ),
          ),
          const SizedBox(height: KafooSpacing.xs),
          _buildAction(context, ref, controller, l10n),
        ],
      ),
    );
  }

  Widget _buildAction(
    BuildContext context,
    WidgetRef ref,
    MyMealsController controller,
    AppLocalizations l10n,
  ) {
    final retire = _MealAction(
      label: l10n.mealRetire(context.addressForm),
      mealTitle: _title(l10n),
      // Retirement is always confirmed. It is the one action on this screen
      // that cannot be undone by taking the same action again.
      warning: l10n.mealRetireWarning,
      confirmLabel: l10n.mealRetireConfirm(context.addressForm),
      cancelLabel: l10n.mealRetireCancel(context.addressForm),
      onConfirmed: () => controller.setStatus(meal, MealStatus.archived),
    );

    // Editing needs a complete [Meal], which a draft is not. `asMeal` is null
    // exactly when a required field is still unanswered, so the control is
    // absent rather than disabled for a Meal that cannot yet be edited — and
    // absent for an archived one, which offers nothing at all.
    final editable = meal.asMeal;
    final edit = editable == null
        ? null
        : _MealAction(
            label: l10n.mealEditTitle(context.addressForm),
            mealTitle: _title(l10n),
            // Editing opens a screen rather than changing anything, so there is
            // nothing here to confirm.
            warning: null,
            confirmLabel: l10n.mealRetireConfirm(context.addressForm),
            cancelLabel: l10n.mealRetireCancel(context.addressForm),
            onConfirmed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MealEditScreen(meal: editable),
              ),
            ),
          );

    final actions = switch (meal.status) {
      MealStatus.published => [
          if (edit != null) edit,
          _MealAction(
            label: l10n.mealMakeUnavailable(context.addressForm),
            mealTitle: _title(l10n),
            // Only when this is the Cook's last Meal on offer. Taking any
            // other one off the menu is ordinary and reversible, and putting a
            // dialog in front of it teaches Cooks to dismiss dialogs.
            warning: controller.wouldCloseKitchen(meal)
                ? l10n.mealLastOnOfferWarning(context.addressForm)
                : null,
            confirmLabel: l10n.mealLastOnOfferConfirm(context.addressForm),
            cancelLabel: l10n.mealLastOnOfferCancel(context.addressForm),
            onConfirmed: () =>
                controller.setStatus(meal, MealStatus.unavailable),
          ),
          retire,
        ],
      MealStatus.unavailable => [
          if (edit != null) edit,
          _MealAction(
            label: l10n.mealMakeAvailable(context.addressForm),
            mealTitle: _title(l10n),
            // Putting a Meal back on the menu never closes a kitchen.
            warning: null,
            confirmLabel: l10n.mealLastOnOfferConfirm(context.addressForm),
            cancelLabel: l10n.mealLastOnOfferCancel(context.addressForm),
            onConfirmed: () => controller.setStatus(meal, MealStatus.published),
          ),
          retire,
        ],
      MealStatus.draft => [
          _MealAction(
            label: l10n.mealResumeDraft(context.addressForm),
            mealTitle: _title(l10n),
            warning: null,
            confirmLabel: l10n.mealRetireConfirm(context.addressForm),
            cancelLabel: l10n.mealRetireCancel(context.addressForm),
            onConfirmed: () async {
              ref
                  .read(mealConversationControllerProvider.notifier)
                  .resume(meal);
              onResumeDraft?.call(meal);
            },
          ),
          _MealAction(
            label: l10n.mealDeleteDraft(context.addressForm),
            mealTitle: _title(l10n),
            warning: l10n.mealDeleteDraftWarning(context.addressForm),
            confirmLabel: l10n.mealDeleteDraftConfirm(context.addressForm),
            cancelLabel: l10n.mealRetireCancel(context.addressForm),
            onConfirmed: () => controller.deleteDraft(meal),
          ),
        ],
      // A retired Meal offers nothing. Not a disabled control — an absent one.
      MealStatus.archived => const <Widget>[],
    };

    return actions.isEmpty
        ? const SizedBox.shrink()
        : Wrap(
            spacing: KafooSpacing.sm,
            runSpacing: KafooSpacing.xs,
            children: actions,
          );
  }
}

/// One action on a Meal row: a button, and the confirmation it does or does
/// not need.
///
/// One widget rather than three near-identical ones. The three actions on this
/// screen — take off the menu, put back on, retire, delete a draft — differ
/// only in their words and in what they finally call, and a copy per action is
/// three places to forget the 48dp floor or the screen-reader label.
///
/// [warning] is what decides whether a confirmation appears at all. Null means
/// act immediately: an ordinary reversible change must not be gated behind a
/// dialog, because a Cook trained to dismiss dialogs will dismiss the one that
/// mattered.
class _MealAction extends StatelessWidget {
  const _MealAction({
    required this.label,
    required this.mealTitle,
    required this.warning,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirmed,
  });

  final String label;
  final String mealTitle;
  final String? warning;
  final String confirmLabel;
  final String cancelLabel;
  final Future<void> Function() onConfirmed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => _onTap(context),
      style: TextButton.styleFrom(
        minimumSize: const Size(
          KafooSpacing.minTapTarget,
          KafooSpacing.minTapTarget,
        ),
      ),
      child: Semantics(
        button: true,
        // Names the Meal, so a Cook using a screen reader hears which one this
        // acts on rather than four identical "take it off the menu" buttons.
        label: '$label: $mealTitle',
        child: Text(label),
      ),
    );
  }

  Future<void> _onTap(BuildContext context) async {
    final message = warning;
    if (message != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await onConfirmed();
  }
}
