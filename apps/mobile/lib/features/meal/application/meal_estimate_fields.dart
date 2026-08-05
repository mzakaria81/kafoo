import 'package:kafoo_domain/domain.dart';

/// Keys in [MealConversationState.approvals] for AI-derived Meal fields.
///
/// Only fields the analysis actually produced appear here. A missing suggestion
/// is not something a Cook must approve.
abstract final class MealEstimateFields {
  static const cuisine = 'cuisine';
  static const category = 'category';
  static const ingredients = 'ingredients';
  static const calories = 'calories';
  static const allergens = 'allergens';

  /// Every estimate the analysis produced, in display order.
  static List<String> presentIn(MealAnalysis analysis) => [
        if (analysis.cuisine != null) cuisine,
        if (analysis.category != null) category,
        if (analysis.ingredients != null) ingredients,
        if (analysis.calories != null) calories,
        if (analysis.allergens != null) allergens,
      ];
}
