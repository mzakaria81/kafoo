/// The Cook-authored fields of a Meal, named.
///
/// **THIS FILE USED TO HOLD A QUESTION SEQUENCE AND NO LONGER DOES (ADR-0015).**
/// `mealSteps()`, `nextUnansweredMealStep()` and the two fallback questions were
/// deleted on 2026-08-13 with the wizard they drove. What survives is the one
/// thing that was never about ordering: an identity for each field the Cook
/// speaks herself, used when she corrects one and when an analytics event names
/// which one she just gave.
///
/// **What is still missing lives in `meal_facts.dart`, as a set with no first
/// element.** If anything here grows a "next" or a "first", the wizard is
/// growing back.
library;

/// A field of a Meal that the Cook supplies in her own words.
///
/// Cuisine, category, ingredients, calories and allergens are deliberately
/// absent: they are inferred by the AI Assistant and approved by the Cook,
/// rather than asked for. A member added here is one the assistant failed to
/// save her.
enum MealStepId {
  /// What did you cook? Becomes the Meal's title.
  dish,

  /// Tell me about it. Becomes the description the AI Assistant drafts from,
  /// and the input every inferred field is derived from.
  description,

  /// A photograph. Optional, and the one step a Cook can decline — declining
  /// still leads to a working flow, with estimates made from the words alone.
  photo,

  /// What does it cost? The price of the whole Meal.
  price;

  /// The stable identifier this step reports as the `step` attribute on
  /// `ConversationStepCompleted`. Analytics names are never renamed, so this
  /// lives with the domain rule rather than with any screen.
  String get wireName => switch (this) {
        MealStepId.dish => 'dish',
        MealStepId.description => 'description',
        MealStepId.photo => 'photo',
        MealStepId.price => 'price',
      };

  /// Whether the conversation can reach a summary without this step.
  ///
  /// Only the photo. A Cook who will not send a photograph away to be looked
  /// at (FR-029) must still be able to offer their food.
  bool get isSkippable => this == MealStepId.photo;
}

/// The `kind` attribute shared by every conversation event in this flow.
/// Matches `docs/product/event-model.md`, which reserves `kind: meal`.
const String mealConversationKind = 'meal';

/// Whether the AI Assistant has enough to start analysing.
///
/// The analysis is started as soon as this is true and the Cook keeps
/// answering while it runs — the latency mitigation from research.md §3. It
/// deliberately does not wait for the photo: a Cook who is going to decline it
/// should not be paying for the wait, and a Cook who will supply one triggers
/// a second, better analysis when it arrives.
bool canBeginAnalysis({required String? dish, required String? description}) =>
    _isPresent(dish) && _isPresent(description);

bool _isPresent(String? value) => value != null && value.trim().isNotEmpty;
