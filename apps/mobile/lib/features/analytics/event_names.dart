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

  // Level 2 — product analytics events added in E3.
  //
  // SearchPerformed carries `result_count`, `top_cuisine`, `top_category` and `area_narrowed`, and
  // NEVER WHAT WAS SEARCHED FOR. FR-029 and SC-011. The obvious attribute to add here is the
  // phrase, and it is the one thing this event must never carry.
  //
  // The three beyond the count were added on 2026-08-08, and every one of them is a value Kafoo
  // chose rather than a word a Customer typed:
  //
  //   `top_cuisine` / `top_category` — the fixed enums from packages/domain/lib/meal.dart, taken
  //   off the FIRST RESULT, or `none` when there were none. **This is what Kafoo SERVED, not what
  //   the Customer asked for**, and the difference is not pedantic: matching by meaning always
  //   returns something, so a request the corpus cannot answer still has a top result. Read beside
  //   SearchFailed, which is the judgement that nothing answered.
  //
  //   `area_narrowed` — a boolean, and NEVER THE AREA ITSELF, which is a phrase the Customer said.
  //   With `result_count: 0` it separates "no Cooks near this person" from "nothing like this on
  //   the menu". Those are different problems with different fixes and they arrive identical.
  //
  // Why it was worth adding then rather than later: none of it is recoverable. A search leaves no
  // trace in any table, so a question asked in six months about the first six months has no data to
  // ask it of. docs/product/business-questions.md.
  static const String searchPerformed = 'SearchPerformed';

  // SearchFailed is emitted when the JUDGEMENT says nothing answers, not when the database returns
  // no rows. Those are different facts: retrieval returning rows is not the same as those rows
  // answering the question, and conflating them is what a score threshold tried and failed to do.
  //
  // It carries NOTHING AT ALL. Not the phrase, and not a count either — a count of results that
  // did not answer is a number nobody can act on, and the phrase is the thing FR-029 names.
  static const String searchFailed = 'SearchFailed';

  // RecommendationAccepted is emitted when a Customer opens a Meal the AI Assistant named instead.
  // It carries `rank`, which is where that Meal already sat in the results — never the phrase, and
  // never the Meal's id, which would let a search be reconstructed from two rows.
  static const String recommendationAccepted = 'RecommendationAccepted';

  // MealOpened is emitted when a Customer opens a Meal, from anywhere in discovery. It carries
  // `source` (`browse` or `search`), `cuisine` and `category`.
  //
  // **The strongest demand signal Kafoo can have before Orders exist**, because it records what
  // somebody CHOSE rather than what the ranker returned. `source` is also the only way to answer
  // whether search is worth what it costs — an embedding call and an AI judgement per query, and
  // nothing until now said whether anybody arrives through it.
  //
  // NO `rank`, deliberately. RecommendationAccepted already carries it for the one case where
  // position is the question, and a rank on every open is a number nobody has a decision waiting
  // on — which is the registry's own test for not adding an attribute.
  //
  // Never the Meal's id: an id and a timestamp together are a search somebody could reconstruct,
  // and the reasoning that keeps it off RecommendationAccepted keeps it off this.
  static const String mealOpened = 'MealOpened';
}
