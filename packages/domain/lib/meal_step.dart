/// The question sequence for the Meal conversation.
///
/// This is a domain rule — what a Meal must say about itself, in what order —
/// not a property of any screen. Same shape as `conversation_step.dart`, which
/// serves the Kitchen Profile conversation, because these are the same family
/// of thing and a second idea here would be a second idea to keep in step.
///
/// **A Meal has seven values and this list has four steps.** That gap is the
/// design. Cuisine, category, ingredients, calories and allergens are inferred
/// by the AI Assistant from what the Cook already said, and the Cook approves
/// them at the summary rather than being asked for them. If this list ever
/// grows to cover all seven, the AI Assistant has failed and the feature needs
/// revisiting rather than shipping.
library;

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

/// A single step in the Meal conversation, paired with whether it has been
/// resolved. The answer itself is held in `MealDraft`.
final class MealStep {
  const MealStep({required this.id, required this.answered});

  final MealStepId id;
  final bool answered;
}

/// Returns the ordered sequence of steps, based on which answers are present.
///
/// [photoResolved] is separate from a photo path being present, because
/// declining the photo resolves the step without producing an answer. Treating
/// "no photo" as "not yet asked" would trap a Cook who said no in a loop back
/// to the question they just answered.
List<MealStep> mealSteps({
  required String? dish,
  required String? description,
  required bool photoResolved,
  required String? price,
}) {
  final answers = <({MealStepId id, bool answered})>[
    (id: MealStepId.dish, answered: _isPresent(dish)),
    (id: MealStepId.description, answered: _isPresent(description)),
    (id: MealStepId.photo, answered: photoResolved),
    (id: MealStepId.price, answered: _isPresent(price)),
  ];

  return [for (final a in answers) MealStep(id: a.id, answered: a.answered)];
}

/// Returns the next unanswered [MealStep], or null when all are done.
///
/// Exactly one step is unanswered at a time on any screen (SC-002): the first
/// whose answer is absent.
MealStep? nextUnansweredMealStep(List<MealStep> steps) {
  for (final step in steps) {
    if (!step.answered) return step;
  }
  return null;
}

/// Whether the AI Assistant has enough to start analysing.
///
/// The analysis is started as soon as this is true and the Cook keeps
/// answering while it runs — the latency mitigation from research.md §3. It
/// deliberately does not wait for the photo: a Cook who is going to decline it
/// should not be paying for the wait, and a Cook who will supply one triggers
/// a second, better analysis when it arrives.
bool canBeginAnalysis({required String? dish, required String? description}) =>
    _isPresent(dish) && _isPresent(description);

/// The questions asked only when the AI Assistant could not supply the
/// answer. Deliberately separate from [MealStepId]: the Meal conversation
/// is four questions long, and these two exist because a fallback was
/// needed, not because the sequence grew.
enum MealFallbackStepId {
  cuisine,
  category;

  /// Stable identifier for `ConversationStepCompleted.step`.
  String get wireName => switch (this) {
        MealFallbackStepId.cuisine => 'cuisine',
        MealFallbackStepId.category => 'category',
      };
}

/// Next fallback question, or null when neither is needed.
///
/// The caller decides what "needed" means — that depends on the analysis,
/// which is not a domain-package concept. Cuisine before category.
MealFallbackStepId? nextUnansweredMealFallbackStep({
  required bool cuisineNeeded,
  required bool categoryNeeded,
}) {
  if (cuisineNeeded) return MealFallbackStepId.cuisine;
  if (categoryNeeded) return MealFallbackStepId.category;
  return null;
}

bool _isPresent(String? value) => value != null && value.trim().isNotEmpty;
