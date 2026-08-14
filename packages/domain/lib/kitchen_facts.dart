/// What a Kitchen Profile still needs before it can exist, as a set rather than
/// a sequence.
///
/// **This replaces `conversation_step.dart`, and the deletion is the point.**
/// That file held an ORDER — display name, then story, then area, then delivery
/// terms, then the form of address — and a comment explaining why the fifth one
/// came last. ADR-0015 says Kafoo owns the list of facts still missing and the
/// model owns what to say next, so an order in the domain layer is a script,
/// and a script is the questionnaire that decision deleted.
///
/// The requirements themselves are unchanged. A Kitchen Profile still needs all
/// four text fields non-empty and still needs a form of address; the database
/// still enforces it. This file is what the assistant is TOLD. It is not what
/// decides whether a kitchen is allowed to exist.
library;

import 'kitchen_profile.dart';

/// One thing a Kitchen Profile must know about itself.
///
/// **Photo is deliberately absent**, the same way it is absent from
/// [MealFact]: it is optional, it never blocks the kitchen from existing, and
/// naming it here would make an optional thing look like a missing one to the model
/// — which is how an assistant starts nagging about a photograph.
enum KitchenFact {
  /// What the kitchen is called. «مطبخ أم علي».
  displayName,

  /// What she cooks and why. The sentence a Customer reads to decide whether to
  /// trust a stranger cooking at home.
  story,

  /// Where she is. «المعادي».
  area,

  /// How the food gets to people, and when.
  deliveryTerms,

  /// How Kafoo should address this Cook.
  ///
  /// **The one fact that is about the conversation rather than about the
  /// kitchen, and it stays because it genuinely cannot be inferred.** Arabic
  /// conjugates the second person with no neutral form; an Egyptian given name
  /// does not reliably carry it (Nour, Malak and Sabah are all used for both);
  /// and the app must pick an ending on the very first sentence it says.
  /// Guessing wrong means addressing a woman as a man for the life of her
  /// account. ADR-0010.
  ///
  /// **It no longer has a position.** It used to be pinned last so the flow did
  /// not open with grammar. In one open conversation there is no first and no
  /// last: she may say «أنا ست» in her opening sentence, or the assistant may
  /// ask once the rest is done, and neither is out of order.
  addressForm;

  /// The facts whose answer is free text the Cook speaks or types.
  ///
  /// [addressForm] is not one of them: it is one of exactly two values, so
  /// anywhere that renders a text field per fact iterates this rather than
  /// [values]. It is a property of what the facts ARE, not of whichever screen
  /// happens to be drawing them — and it carries no order, so a caller that
  /// wants one picks its own.
  static const List<KitchenFact> freeText = [
    displayName,
    story,
    area,
    deliveryTerms,
  ];

  /// Stable identifier used in the prompt and in analytics. Never renamed.
  ///
  /// These are the same strings `ConversationStepId.wireName` produced, so the
  /// `step` attribute on `ConversationStepCompleted` keeps its meaning across
  /// the rewrite. `docs/product/event-model.md`: analytics names are never
  /// renamed, and a rewrite is not an exception.
  String get wireName => switch (this) {
        KitchenFact.displayName => 'display_name',
        KitchenFact.story => 'story',
        KitchenFact.area => 'area',
        KitchenFact.deliveryTerms => 'delivery_terms',
        KitchenFact.addressForm => 'address_form',
      };
}

/// The `kind` attribute shared by every conversation event in this flow.
const String kitchenProfileConversationKind = 'kitchen_profile';

/// The facts a Kitchen Profile does not have yet.
///
/// Returned as an unmodifiable set, in no meaningful order. Callers that hand
/// it to a model hand over the whole set at once; nothing here picks a next
/// question, and if something ever does, the wizard is growing back.
Set<KitchenFact> kitchenFactsMissing({
  required String? displayName,
  required String? story,
  required String? area,
  required String? deliveryTerms,
  required AddressForm? addressForm,
}) =>
    Set.unmodifiable(<KitchenFact>{
      if (!_isPresent(displayName)) KitchenFact.displayName,
      if (!_isPresent(story)) KitchenFact.story,
      if (!_isPresent(area)) KitchenFact.area,
      if (!_isPresent(deliveryTerms)) KitchenFact.deliveryTerms,
      if (addressForm == null) KitchenFact.addressForm,
    });

bool _isPresent(String? value) => value != null && value.trim().isNotEmpty;
