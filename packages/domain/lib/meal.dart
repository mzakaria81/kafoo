/// Meal entity. No Flutter, no Supabase.
///
/// A Meal is an *offer*, not a recipe and not inventory. It belongs to exactly
/// one Cook, permanently, and its price covers the whole Meal rather than a
/// portion of it.
///
/// The rules expressed here are also enforced in the database, deliberately.
/// Policies protect against a hostile client; constraints protect against
/// Kafoo's own code; this type protects against a call site that never thought
/// about it. The three failure modes are different, so all three exist.
library;

/// Where a Meal is in its life.
///
/// `draft → published → unavailable → archived`. One-way except
/// `published ⇄ unavailable`. See [MealStatus.canTransitionTo].
enum MealStatus {
  /// Begun, not on offer, visible to nobody but its Cook.
  draft,

  /// On offer. The only status anyone other than the Cook can read.
  published,

  /// Off the menu for now, and expected back. Not a deletion.
  unavailable,

  /// Retired for good. Readable to its Cook and to order history, and it never
  /// returns to offer by any route.
  archived;

  /// The value stored in the `status` column.
  String get wireName => name;

  static MealStatus fromWireName(String value) => MealStatus.values.firstWhere(
        (status) => status.wireName == value,
        orElse: () =>
            throw ArgumentError.value(value, 'value', 'unknown Meal status'),
      );

  /// Whether a Meal in this status may move to [next].
  ///
  /// The rules, in the order they matter:
  ///
  /// - **A retired Meal never returns.** `archived` is terminal, and this is
  ///   the transition that must be impossible rather than merely unavailable —
  ///   once Orders exist, a Meal coming back from retirement takes a Customer's
  ///   history with it.
  /// - **A draft goes on offer before it goes anywhere else.** Nothing is taken
  ///   off a menu it was never on.
  /// - **`published` and `unavailable` swap freely.** That difference is what
  ///   makes a menu a menu.
  /// - **Staying put is allowed**, because an edit that does not touch the
  ///   status is the common case and must not be a transition failure.
  bool canTransitionTo(MealStatus next) {
    if (this == next) return true;

    return switch (this) {
      MealStatus.archived => false,
      MealStatus.draft => next == MealStatus.published,
      MealStatus.published =>
        next == MealStatus.unavailable || next == MealStatus.archived,
      MealStatus.unavailable =>
        next == MealStatus.published || next == MealStatus.archived,
    };
  }

  /// Whether anyone other than the owning Cook can read a Meal in this status.
  ///
  /// Only `published`. This mirrors the `anon` SELECT policy rather than
  /// replacing it — the database is what actually stops the read.
  bool get isPubliclyReadable => this == MealStatus.published;

  /// Whether a Meal in this status may be deleted outright.
  ///
  /// Drafts only. Anything that has been on offer is archived instead, because
  /// deleting it would remove a Meal a Customer may have ordered.
  bool get isDeletable => this == MealStatus.draft;
}

/// Who a nutrition figure came from.
///
/// A type rather than a string so a call site cannot invent a third answer.
/// The database derives this from what actually changed, never from what a
/// client claims — see the `derive_nutrition_source` trigger. This enum is how
/// the rest of Kafoo talks about the result, not how it is decided.
enum NutritionSource {
  /// The AI Assistant estimated it and the Cook did not change it. Still an
  /// estimate, even after the Cook approved it — approving an estimate does
  /// not verify it, and presenting it as verified is the failure this
  /// distinction exists to prevent.
  ai,

  /// The Cook set or corrected the number. It is theirs.
  cook;

  String get wireName => name;

  static NutritionSource fromWireName(String value) =>
      NutritionSource.values.firstWhere(
        (source) => source.wireName == value,
        orElse: () => throw ArgumentError.value(
            value, 'value', 'unknown nutrition source'),
      );

  /// Whether a figure from this source must be shown to a reader as an
  /// estimate. True for [ai] wherever the number appears — the summary screen,
  /// the Cook's own list, and a Customer reading a published Meal.
  bool get mustBeLabelledAnEstimate => this == NutritionSource.ai;
}

/// The cuisines a Meal can belong to.
///
/// A fixed set rather than free text, so two Cooks describing the same food
/// land in the same place. The identifiers are keys, not copy: they are never
/// shown to anyone, and the Arabic a Cook reads comes from the ARB files.
enum Cuisine {
  egyptian,
  levantine,
  gulf,
  sudanese,
  moroccan,
  turkish,
  italian,
  asian,
  american,
  other;

  String get wireName => name;

  static Cuisine? tryFromWireName(String value) {
    for (final cuisine in Cuisine.values) {
      if (cuisine.wireName == value) return cuisine;
    }
    return null;
  }
}

/// What kind of thing a Meal is.
///
/// Fixed set, same reasoning as [Cuisine].
enum MealCategory {
  main,
  appetizer,
  soup,
  salad,
  side,
  dessert,
  bakery,
  drink,
  other;

  String get wireName => name;

  static MealCategory? tryFromWireName(String value) {
    for (final category in MealCategory.values) {
      if (category.wireName == value) return category;
    }
    return null;
  }
}

/// A Meal, as it exists once written.
final class Meal {
  const Meal({
    required this.id,
    required this.cookId,
    required this.title,
    required this.description,
    required this.price,
    required this.cuisine,
    required this.category,
    required this.status,
    required this.nutritionSource,
    this.ingredients = const [],
    this.allergens = const [],
    this.calories,
    this.photoPath,
    this.publishedAt,
  });

  final String id;

  /// The Cook who owns it. A Meal cannot change Cooks, so nothing in Kafoo
  /// writes this after creation.
  final String cookId;

  final String title;
  final String description;

  /// The price of the **whole Meal**, not a portion of it.
  ///
  /// Held as a [String] on purpose. This is `numeric(10,2)` in Postgres, and
  /// routing money through a binary [double] on the way to a screen is how a
  /// price stops being exactly the number the Cook typed. Formatting for
  /// display is a presentation concern and uses `intl`.
  final String price;

  final Cuisine cuisine;
  final MealCategory category;
  final MealStatus status;

  final List<String> ingredients;

  /// Calories for the whole Meal, matching what the price covers. Null when
  /// the AI Assistant was unavailable or refused the photo and the Cook chose
  /// not to supply a figure — publishing must still work.
  final int? calories;

  final List<String> allergens;

  /// Whether [calories] and [allergens] are the AI Assistant's estimate or the
  /// Cook's own. Never set from a client claim.
  final NutritionSource nutritionSource;

  final String? photoPath;

  /// When the Meal first went on offer. Distinct from any later edit: a Meal
  /// taken off the menu and put back has not been republished.
  final DateTime? publishedAt;

  /// Whether this Meal may move to [next]. Ownership is not checked here —
  /// that is the RLS policy's job, and this type has no idea who is asking.
  bool canTransitionTo(MealStatus next) => status.canTransitionTo(next);

  /// Whether a reader other than the owning Cook may see it.
  bool get isPubliclyReadable => status.isPubliclyReadable;

  Meal copyWith({
    String? title,
    String? description,
    String? price,
    Cuisine? cuisine,
    MealCategory? category,
    MealStatus? status,
    List<String>? ingredients,
    int? calories,
    List<String>? allergens,
    NutritionSource? nutritionSource,
    String? photoPath,
    DateTime? publishedAt,
  }) =>
      Meal(
        id: id,
        cookId: cookId,
        title: title ?? this.title,
        description: description ?? this.description,
        price: price ?? this.price,
        cuisine: cuisine ?? this.cuisine,
        category: category ?? this.category,
        status: status ?? this.status,
        ingredients: ingredients ?? this.ingredients,
        calories: calories ?? this.calories,
        allergens: allergens ?? this.allergens,
        nutritionSource: nutritionSource ?? this.nutritionSource,
        photoPath: photoPath ?? this.photoPath,
        publishedAt: publishedAt ?? this.publishedAt,
      );
}

/// Mutable draft of a [Meal] held while the conversation is running.
///
/// **This diverges from E1 on purpose.** The Kitchen Profile conversation kept
/// nothing before confirmation; a Meal has more in it and is more expensive to
/// abandon, so a draft is persisted as the conversation proceeds. What is *not*
/// persisted is anything on offer — a draft is visible to its Cook and to
/// nobody else, which is the absence of a policy rather than a filter.
final class MealDraft {
  MealDraft();

  /// The id returned by createDraft, null until the first answer is persisted.
  String? mealId;
  String? title;
  String? description;
  String? price;
  Cuisine? cuisine;
  MealCategory? category;
  List<String> ingredients = const [];
  int? calories;
  List<String> allergens = const [];
  String? photoPath;

  /// Whether the photo step has been resolved — by supplying a photo or by
  /// declining. Separate from photoPath so that declining does not look like
  /// "not yet asked" and trap the Cook in a loop.
  bool photoResolved = false;

  /// Whether the Cook has said enough for the Meal to go on offer.
  ///
  /// Calories, allergens, ingredients and a photo are all absent from this
  /// list. Each of them can be missing — the AI Assistant may be unreachable,
  /// the Cook may refuse the photo, and neither is a reason to block a Cook
  /// from offering food they made.
  bool get isComplete =>
      _isPresent(title) &&
      _isPresent(description) &&
      _isPresent(price) &&
      cuisine != null &&
      category != null;

  static bool _isPresent(String? value) =>
      value != null && value.trim().isNotEmpty;
}

/// Whether taking [meal] off the menu would leave its Cook with nothing on
/// offer — and therefore with a kitchen nobody can find.
///
/// This is the rule that surprises Cooks: discoverability follows from having
/// food actually on offer, so a Cook who takes down their last Meal closes
/// their kitchen. Correct, and the reason it must be said before it happens
/// rather than discovered afterwards.
bool isLastMealOnOffer(Iterable<Meal> meals, Meal meal) {
  if (meal.status != MealStatus.published) return false;
  final publishedCount =
      meals.where((m) => m.status == MealStatus.published).length;
  if (publishedCount != 1) return false;
  return meals.where((m) => m.status == MealStatus.published).single.id ==
      meal.id;
}
