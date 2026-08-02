/// What the AI Assistant proposed about a Meal, before any of it is approved.
///
/// **This is deliberately not a [Meal].** A suggestion is not a Meal, and
/// giving them the same type is how one becomes the other without anyone
/// deciding. There is no `toMeal()` here and there must never be one: the only
/// route from a suggestion into the database runs through a Cook approving a
/// field, one field at a time.
///
/// The repository takes a [Meal]. This type cannot be persisted, which is
/// Principle II expressed in the type system rather than in a code review.
library;

import 'meal.dart';

/// One thing the AI Assistant proposed, and why.
///
/// [basis] is not decoration. `.claude/rules/ai.md` requires the UI to show
/// why a field was filled — "I set the cuisine to Egyptian because this
/// contains molokhia and rice" — because silent inference destroys trust. A
/// suggestion whose basis is empty is one the Cook has no reason to believe.
final class MealSuggestion<T> {
  const MealSuggestion({required this.value, required this.basis});

  final T value;

  /// One short sentence, in Egyptian Arabic, saying what this was based on.
  /// Shown on the screen beside the value, not in a tooltip.
  final String basis;
}

/// The AI Assistant's proposals for one Meal.
///
/// Every field is optional. The AI Assistant may be unreachable (FR-014), the
/// Cook may refuse the photo (FR-029), and the model may honestly have nothing
/// to say about a field. A missing suggestion means the Cook fills it in
/// themselves, which is a working flow rather than an error.
final class MealAnalysis {
  const MealAnalysis({
    this.ingredients,
    this.calories,
    this.allergens,
    this.cuisine,
    this.category,
    this.description,
    this.modelId,
    this.usedPhoto = false,
  });

  /// Nothing was suggested. Returned when the AI Assistant could not be
  /// reached, when the Cook said nothing a model could work from, or when
  /// every proposal failed validation.
  const MealAnalysis.empty() : this();

  final MealSuggestion<List<String>>? ingredients;

  /// Calories for the **whole Meal**, matching what the price covers.
  final MealSuggestion<int>? calories;

  final MealSuggestion<List<String>>? allergens;
  final MealSuggestion<Cuisine>? cuisine;
  final MealSuggestion<MealCategory>? category;

  /// A drafted description in the Cook's register, from `meal-description.md`.
  /// The Cook approves, edits, or replaces it.
  final MealSuggestion<String>? description;

  /// Which model produced this, for evals and logs. Not shown to the Cook.
  final String? modelId;

  /// Whether the photo was actually looked at. False when the Cook refused it
  /// or there was none — and it changes what the estimates are worth, so it is
  /// recorded rather than assumed.
  final bool usedPhoto;

  /// Whether there is anything here for a Cook to approve.
  bool get isEmpty =>
      ingredients == null &&
      calories == null &&
      allergens == null &&
      cuisine == null &&
      category == null &&
      description == null;

  bool get isNotEmpty => !isEmpty;
}
