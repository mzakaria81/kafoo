/// The question sequence for the Kitchen Profile conversation.
///
/// This is a domain rule: what a kitchen must say about itself, in what order.
/// The sequence is not a property of any screen or widget.
library;

import 'kitchen_profile.dart';

enum ConversationStepId {
  displayName,
  story,
  area,
  deliveryTerms,

  /// How Kafoo should address this Cook.
  ///
  /// A fifth question looks like a failure to infer, and Kafoo's product rules
  /// treat it that way by default. This one is the exception, and the reason is
  /// that it genuinely cannot be inferred: Arabic conjugates the second person
  /// with no neutral form, an Egyptian given name does not reliably carry the
  /// form (Nour, Malak, Sabah and many others are used for both), and the app
  /// must pick an ending on the very first sentence it says. Guessing wrong
  /// means addressing a woman as a man for the life of her account, which is a
  /// worse cost than one question. ADR-0010.
  ///
  /// It is also the only step answered by choosing rather than by speaking or
  /// typing, because the answer is one of exactly two values and there is
  /// nothing for a Cook to phrase.
  addressForm;

  /// The steps whose answer is text the Cook speaks or types.
  ///
  /// [addressForm] is not one of them: it is chosen from exactly two values, so
  /// anywhere that renders a text field per step must iterate this rather than
  /// [values]. Named here, in the domain, because "which questions have a free
  /// answer" is a property of the sequence and not of whichever screen happens
  /// to be drawing it.
  static const List<ConversationStepId> freeText = [
    displayName,
    story,
    area,
    deliveryTerms,
  ];

  /// The stable identifier this step reports as the `step` attribute on
  /// `ConversationStepCompleted`. Analytics names are never renamed, so this
  /// lives with the domain rule rather than with any screen.
  String get wireName => switch (this) {
        ConversationStepId.displayName => 'display_name',
        ConversationStepId.story => 'story',
        ConversationStepId.area => 'area',
        ConversationStepId.deliveryTerms => 'delivery_terms',
        ConversationStepId.addressForm => 'address_form',
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
  required AddressForm? addressForm,
}) {
  final answers = <({ConversationStepId id, Object? value})>[
    (id: ConversationStepId.displayName, value: displayName),
    (id: ConversationStepId.story, value: story),
    (id: ConversationStepId.area, value: area),
    (id: ConversationStepId.deliveryTerms, value: deliveryTerms),
    // Last on purpose: it is the one question that is about the conversation
    // itself rather than about the kitchen, so asking it first would open the
    // flow with grammar instead of with the Cook's own name.
    (id: ConversationStepId.addressForm, value: addressForm),
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
