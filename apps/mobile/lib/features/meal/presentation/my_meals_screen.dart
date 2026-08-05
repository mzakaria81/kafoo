import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/app_localizations.dart';
import '../application/my_meals_controller.dart';
import 'meal_enum_labels.dart';

class MyMealsScreen extends ConsumerWidget {
  const MyMealsScreen({super.key});

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
                                return MyMealRow(meal: meal);
                              },
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

/// The Cook-facing text for an [AppError] this screen can produce.
///
/// One function rather than a copy in each of the two widgets that render an
/// error: a second switch is a second place to forget a key, and the fallback
/// shows the raw key to the Cook, which is the failure this must not have.
String _errorMessage(AppLocalizations l10n, AppError error) =>
    switch (error.messageKey) {
      'mealLoadError' => l10n.mealLoadError,
      'mealAvailabilityError' => l10n.mealAvailabilityError,
      'mealDeleteError' => l10n.mealDeleteError,
      _ => l10n.mealLoadError,
    };

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
            _errorMessage(l10n, error),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: KafooSpacing.md),
          FilledButton(
            onPressed: () => ref.invalidate(myMealsControllerProvider),
            child: Text(l10n.mealLoadRetry),
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
      child:
          Text(l10n.myMealsEmpty, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.error});

  final AppError error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = _errorMessage(l10n, error);
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
  const MyMealRow({required this.meal, super.key});

  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(myMealsControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: KafooSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(meal.title, style: theme.textTheme.bodyLarge),
          const SizedBox(height: KafooSpacing.xs),
          Text(
            l10n.publicMealPriceValue(meal.price),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: KafooSpacing.xs),
          Text(
            mealStatusLabel(l10n, meal.status),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: KafooSpacing.xs),
          _buildAction(context, controller, l10n),
        ],
      ),
    );
  }

  Widget _buildAction(
    BuildContext context,
    MyMealsController controller,
    AppLocalizations l10n,
  ) {
    return switch (meal.status) {
      MealStatus.published => _AvailabilityAction(
          meal: meal,
          label: l10n.mealMakeUnavailable,
          next: MealStatus.unavailable,
          isLast: controller.wouldCloseKitchen(meal),
        ),
      MealStatus.unavailable => _AvailabilityAction(
          meal: meal,
          label: l10n.mealMakeAvailable,
          next: MealStatus.published,
          isLast: false,
        ),
      MealStatus.draft || MealStatus.archived => const SizedBox.shrink(),
    };
  }
}

class _AvailabilityAction extends ConsumerWidget {
  const _AvailabilityAction({
    required this.meal,
    required this.label,
    required this.next,
    required this.isLast,
  });

  final Meal meal;
  final String label;
  final MealStatus next;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(myMealsControllerProvider.notifier);

    return TextButton(
      onPressed: () => _onTap(context, controller),
      style: TextButton.styleFrom(
        minimumSize: const Size(
          KafooSpacing.minTapTarget,
          KafooSpacing.minTapTarget,
        ),
      ),
      child: Semantics(
        button: true,
        label: '$label: ${meal.title}',
        child: Text(label),
      ),
    );
  }

  Future<void> _onTap(
    BuildContext context,
    MyMealsController controller,
  ) async {
    if (isLast) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(l10n.mealLastOnOfferWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.mealLastOnOfferCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.mealLastOnOfferConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    await controller.setStatus(meal, next);
  }
}
