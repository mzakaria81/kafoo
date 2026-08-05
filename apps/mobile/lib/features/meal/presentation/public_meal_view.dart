import 'package:flutter/material.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/app_localizations.dart';
import 'meal_enum_labels.dart';

/// The public face of a Meal, as seen by a Customer.
///
/// Pure presentation: takes a [Meal] and renders it. No fetching, no
/// repository. Nothing that identifies the Cook is rendered — no cookId,
/// no Meal id, no phone number, no publishedAt. This is authorization
/// contract case 30, restated in the client.
///
/// **It does not check [Meal.status], and that is deliberate.** The read
/// policy on `meals` is what stops a Customer seeing anything but a published
/// Meal, and it is proven by `supabase/tests/meals_rls_test.sql` cases 2, 3, 5
/// and 6 — a non-owner gets zero rows for a draft or an unavailable Meal, so
/// this widget can never be handed one. Refusing to render a non-published
/// Meal here would add no protection and would block the Cook's own "how does
/// this look" preview, which is a legitimate use of exactly this widget.
///
/// **Nothing routes here yet.** No Customer surface exists to browse Meals —
/// that is E3. This widget is the rule made concrete, the same way
/// `PublicKitchenView` was in E1.
class PublicMealView extends StatelessWidget {
  const PublicMealView({
    required this.meal,
    this.photoUrl,
    this.onOpenKitchen,
    super.key,
  });

  final Meal meal;

  /// Resolved public URL for [Meal.photoPath], or null when the Cook added no
  /// photograph. A Meal without one renders correctly.
  final String? photoUrl;

  /// Opens the Kitchen Profile of the Cook offering this Meal. Null until a
  /// caller supplies a route; the link is not rendered when it is null.
  final VoidCallback? onOpenKitchen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isEstimate = meal.nutritionSource.mustBeLabelledAnEstimate;

    return Scaffold(
      appBar: AppBar(title: Text(meal.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Photo.
              if (photoUrl != null) MealPhoto(url: photoUrl!),
              const SizedBox(height: KafooSpacing.lg),

              // 2. Title.
              Text(meal.title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: KafooSpacing.lg),

              // 3. Price.
              _PublicMealDetail(
                label: l10n.mealSummaryLabelPrice,
                value: l10n.publicMealPriceValue(meal.price),
              ),

              // 4. Description.
              _PublicMealDetail(
                label: l10n.mealSummaryLabelDescription,
                value: meal.description,
              ),

              // 5. Cuisine.
              _PublicMealDetail(
                label: l10n.mealSummaryLabelCuisine,
                value: cuisineLabel(l10n, meal.cuisine),
              ),

              // 6. Category.
              _PublicMealDetail(
                label: l10n.mealSummaryLabelCategory,
                value: mealCategoryLabel(l10n, meal.category),
              ),

              // 7. Ingredients (omitted when empty).
              if (meal.ingredients.isNotEmpty)
                _PublicMealDetail(
                  label: l10n.mealSummaryLabelIngredients,
                  value: meal.ingredients.join('، '),
                ),

              // 8. Nutrition block.
              _NutritionBlock(meal: meal, isEstimate: isEstimate),

              // 9. Kitchen Profile link.
              if (onOpenKitchen != null) ...[
                const SizedBox(height: KafooSpacing.lg),
                Semantics(
                  button: true,
                  label: l10n.publicMealOpenKitchen,
                  child: TextButton(
                    onPressed: onOpenKitchen,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(
                        KafooSpacing.minTapTarget,
                        KafooSpacing.minTapTarget,
                      ),
                    ),
                    child: Text(l10n.publicMealOpenKitchen),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The meal photo, named as its own widget so the "has a photo" branch can
/// be asserted in a test. [Image.network] cannot resolve under the test
/// binding, so a test that looked for the decoded image would be testing the
/// network rather than the layout.
class MealPhoto extends StatelessWidget {
  const MealPhoto({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(KafooSpacing.sm),
      child: Image.network(
        url,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

class _PublicMealDetail extends StatelessWidget {
  const _PublicMealDetail({
    required this.label,
    required this.value,
    this.showEstimateBadge = false,
  });

  final String label;
  final String value;
  final bool showEstimateBadge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: KafooSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: theme.textTheme.labelLarge),
              // The badge is its own Text rather than a Semantics wrapper
              // around one. A wrapper carrying the same label nests two
              // identical semantics nodes, and a screen reader reads the word
              // twice — text announces itself.
              if (showEstimateBadge) ...[
                const SizedBox(width: KafooSpacing.xs),
                Text(
                  l10n.mealSummaryEstimateBadge,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: KafooSpacing.xs),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _NutritionBlock extends StatelessWidget {
  const _NutritionBlock({required this.meal, required this.isEstimate});

  final Meal meal;
  final bool isEstimate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final caloriesValue = meal.calories != null
        ? l10n.mealSummaryCaloriesValue(meal.calories!)
        : l10n.publicMealCaloriesUnknown;

    final allergensValue = meal.allergens.isNotEmpty
        ? meal.allergens.join('، ')
        : l10n.publicMealAllergensUnknown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PublicMealDetail(
          label: l10n.mealSummaryLabelCalories,
          value: caloriesValue,
          showEstimateBadge: isEstimate,
        ),
        _PublicMealDetail(
          label: l10n.mealSummaryLabelAllergens,
          value: allergensValue,
          showEstimateBadge: isEstimate,
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: KafooSpacing.lg),
          child: Text(
            isEstimate
                ? l10n.aiEstimateNotice
                : l10n.publicMealNutritionFromCook,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }
}
