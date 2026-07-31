/// The question sequence for the Kitchen Profile conversation.
///
/// This is a domain rule: what a kitchen must say about itself, in what order.
/// The sequence is not a property of any screen or widget.
library;

enum ConversationStepId {
  displayName,
  story,
  area,
  deliveryTerms;

  /// The stable identifier this step reports as the `step` attribute on
  /// `ConversationStepCompleted`. Analytics names are never renamed, so this
  /// lives with the domain rule rather than with any screen.
  String get wireName => switch (this) {
        ConversationStepId.displayName => 'display_name',
        ConversationStepId.story => 'story',
        ConversationStepId.area => 'area',
        ConversationStepId.deliveryTerms => 'delivery_terms',
      };
}

/// The `kind` attribute shared by every conversation event in this flow.
const String kitchenProfileConversationKind = 'kitchen_profile';

/// A single step in a conversation, pairing a step identifier with whether
/// it has been answered. The answer itself is held in [KitchenProfileDraft].
final class ConversationStep {
  const ConversationStep({required this.id, required this.answered});

  final ConversationStepId id;
  final bool answered;
}

/// Returns the ordered sequence of steps for the Kitchen Profile conversation,
/// based on which fields in [answered] are non-null.
///
/// Exactly one step is unanswered at a time (SC-006): the first step whose
/// answer is absent. All preceding steps are marked answered.
List<ConversationStep> kitchenProfileSteps({
  required String? displayName,
  required String? story,
  required String? area,
  required String? deliveryTerms,
}) {
  final answers = [
    (id: ConversationStepId.displayName, value: displayName),
    (id: ConversationStepId.story, value: story),
    (id: ConversationStepId.area, value: area),
    (id: ConversationStepId.deliveryTerms, value: deliveryTerms),
  ];

  return [
    for (final a in answers)
      ConversationStep(id: a.id, answered: a.value != null),
  ];
}

/// Returns the next unanswered [ConversationStep], or null when all are done.
ConversationStep? nextUnansweredStep(List<ConversationStep> steps) {
  for (final step in steps) {
    if (!step.answered) return step;
  }
  return null;
}
