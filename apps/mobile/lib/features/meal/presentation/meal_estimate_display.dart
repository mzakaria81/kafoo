import 'package:kafoo_domain/domain.dart';

import '../../../l10n/app_localizations.dart';
import '../application/meal_conversation_controller.dart';
import '../application/meal_estimate_fields.dart';
import 'meal_enum_labels.dart';

/// Label, value and basis text for one AI estimate on the summary.
String estimateLabel(AppLocalizations l10n, String field) => switch (field) {
      MealEstimateFields.cuisine => l10n.mealSummaryLabelCuisine,
      MealEstimateFields.category => l10n.mealSummaryLabelCategory,
      MealEstimateFields.ingredients => l10n.mealSummaryLabelIngredients,
      MealEstimateFields.calories => l10n.mealSummaryLabelCalories,
      MealEstimateFields.allergens => l10n.mealSummaryLabelAllergens,
      _ => field,
    };

String estimateBasis(MealAnalysis analysis, String field) => switch (field) {
      MealEstimateFields.cuisine => analysis.cuisine!.basis,
      MealEstimateFields.category => analysis.category!.basis,
      MealEstimateFields.ingredients => analysis.ingredients!.basis,
      MealEstimateFields.calories => analysis.calories!.basis,
      MealEstimateFields.allergens => analysis.allergens!.basis,
      _ => '',
    };

String estimateDisplay(
  AppLocalizations l10n,
  MealConversationState state,
  String field,
) {
  final analysis = state.analysis!;
  final draft = state.draft;
  return switch (field) {
    MealEstimateFields.cuisine => cuisineLabel(
        l10n,
        draft.cuisine ?? analysis.cuisine!.value,
      ),
    MealEstimateFields.category => mealCategoryLabel(
        l10n,
        draft.category ?? analysis.category!.value,
      ),
    MealEstimateFields.ingredients => (draft.ingredients.isNotEmpty
            ? draft.ingredients
            : analysis.ingredients!.value)
        .join('، '),
    MealEstimateFields.calories => l10n.mealSummaryCaloriesValue(
        draft.calories ?? analysis.calories!.value,
      ),
    MealEstimateFields.allergens =>
      (draft.allergens.isNotEmpty ? draft.allergens : analysis.allergens!.value)
          .join('، '),
    _ => '',
  };
}

String estimateEditText(
  AppLocalizations l10n,
  MealConversationState state,
  String field,
) {
  final analysis = state.analysis!;
  final draft = state.draft;
  return switch (field) {
    MealEstimateFields.ingredients => (draft.ingredients.isNotEmpty
            ? draft.ingredients
            : analysis.ingredients!.value)
        .join('، '),
    MealEstimateFields.calories =>
      '${draft.calories ?? analysis.calories!.value}',
    MealEstimateFields.allergens =>
      (draft.allergens.isNotEmpty ? draft.allergens : analysis.allergens!.value)
          .join('، '),
    _ => '',
  };
}
