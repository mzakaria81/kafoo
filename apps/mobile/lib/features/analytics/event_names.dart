// Event names from docs/product/event-model.md.
// Never invent a name at a call site — always use a constant from this class.
// Never rename an event (a rename silently breaks historical comparisons).
abstract final class EventNames {
  // Level 1 — core events (constitutional, Principle VI).
  static const String accountCreated = 'AccountCreated';
  static const String accountRemoved = 'AccountRemoved';
  static const String kitchenProfileCreated = 'KitchenProfileCreated';
  static const String mealPublished = 'MealPublished';
  static const String mealArchived = 'MealArchived';
  static const String orderPlaced = 'OrderPlaced';
  static const String orderAccepted = 'OrderAccepted';
  static const String orderRejected = 'OrderRejected';
  static const String orderCancelled = 'OrderCancelled';
  static const String orderCompleted = 'OrderCompleted';
  static const String reviewSubmitted = 'ReviewSubmitted';

  // Level 2 — product analytics events used in E1.
  static const String signInStarted = 'SignInStarted';
  static const String signInCompleted = 'SignInCompleted';
  static const String signInFailed = 'SignInFailed';
  static const String conversationStarted = 'ConversationStarted';
  static const String conversationStepCompleted = 'ConversationStepCompleted';
  static const String conversationCompleted = 'ConversationCompleted';
  static const String recoveryEmailOffered = 'RecoveryEmailOffered';
  static const String recoveryEmailDeclined = 'RecoveryEmailDeclined';
  static const String recoveryEmailAttached = 'RecoveryEmailAttached';
  static const String phoneNumberChanged = 'PhoneNumberChanged';

  // Level 2 — product analytics events added in E2.
  // MealPublished and MealArchived are above, with the core events.
  static const String mealDrafted = 'MealDrafted';
  static const String mealUpdated = 'MealUpdated';
}
