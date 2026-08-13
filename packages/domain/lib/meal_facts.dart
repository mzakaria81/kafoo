/// What a Meal still needs before it can be published, as a set rather than a
/// sequence.
///
/// **This replaces the ordering in `meal_step.dart`, not the requirements.**
/// ADR-0015: Kafoo owns the list of facts still missing and the model owns what
/// to say next. A list with an order in it is a script, and a script is the
/// questionnaire this decision deleted — so the answer to "what now?" is a set
/// with no first element, and nothing here can be read as an order.
///
/// The requirements themselves are unchanged and are still enforced by the
/// database on the way out of `draft`. This file is what the assistant is told;
/// it is not what decides whether a Meal is allowed to exist.
library;

import 'meal.dart';

/// One thing a Meal must know about itself.
///
/// **Photo is deliberately absent.** It is not required, it never blocks
/// publishing, and putting it here would make an optional thing look like a
/// missing one to the model — which is how an assistant starts nagging about a
/// photograph a Cook has already declined to send (FR-029).
enum MealFact {
  dish,
  description,
  price,
  cuisine,
  category;

  /// Stable identifier used in the prompt and in analytics. Never renamed.
  String get wireName => switch (this) {
        MealFact.dish => 'dish',
        MealFact.description => 'description',
        MealFact.price => 'price',
        MealFact.cuisine => 'cuisine',
        MealFact.category => 'category',
      };
}

/// The facts a Meal does not have yet.
///
/// Returned as an unmodifiable set, in no meaningful order. Callers that want
/// to display them pick their own order; callers that hand them to a model hand
/// over the whole set at once.
///
/// [cuisine] and [category] arrive here as values rather than as estimates on
/// purpose: an AI estimate that nobody has approved is not a fact the Meal has.
/// It becomes one when the Cook approves or corrects it and it reaches the
/// draft — which is the approval step, unchanged by ADR-0015.
Set<MealFact> mealFactsMissing({
  required String? dish,
  required String? description,
  required String? price,
  required Cuisine? cuisine,
  required MealCategory? category,
}) =>
    Set.unmodifiable(<MealFact>{
      if (!_isPresent(dish)) MealFact.dish,
      if (!_isPresent(description)) MealFact.description,
      if (!_isPresent(price)) MealFact.price,
      if (cuisine == null) MealFact.cuisine,
      if (category == null) MealFact.category,
    });

bool _isPresent(String? value) => value != null && value.trim().isNotEmpty;
