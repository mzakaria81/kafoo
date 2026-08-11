import 'dart:typed_data';

import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/meal/data/meal_repository.dart';

/// One [MealRepository.updateDraft] invocation, with every field that was sent.
///
/// Tests assert both that Cook answers reach the database and that analysed
/// fields never do — this record is what makes the second claim measurable.
class FakeUpdateDraftCall {
  const FakeUpdateDraftCall({
    required this.mealId,
    this.title,
    this.description,
    this.price,
    this.cuisine,
    this.category,
    this.ingredients,
    this.calories,
    this.allergens,
    this.photoPath,
  });

  final String mealId;
  final String? title;
  final String? description;
  final String? price;
  final Cuisine? cuisine;
  final MealCategory? category;
  final List<String>? ingredients;
  final int? calories;
  final List<String>? allergens;
  final String? photoPath;

  /// True when any field the AI Assistant proposes was included in the write.
  bool get carriesAnalysedField =>
      cuisine != null ||
      category != null ||
      ingredients != null ||
      calories != null ||
      allergens != null;
}

/// Records every write it is asked to make, so a test can assert which writes
/// happened — and, more usefully, that none did.
///
/// **IT MUST ANSWER WITH THE SHAPE THE DATABASE ANSWERS WITH.** This fake used
/// to hand back a complete [Meal] on every write, inventing `Cuisine.egyptian`,
/// `MealCategory.main`, a price of `'0'` and an empty description for answers
/// the Cook had not given yet. Every test in this directory therefore ran
/// against a row `meals` cannot produce — a draft has those columns NULL by
/// design — and the real repository crashed on the second question of the
/// conversation for every Cook, with the whole gate green. 2026-08-11.
///
/// A fake that is easier to satisfy than the thing it stands in for is worse
/// than no fake: it converts a red test into a green one.
class FakeMealRepository implements MealRepository {
  FakeMealRepository({
    Meal? existing,
    this.failOperations = false,
    this.failUploads = false,
    List<CookMeal>? meals,
  })  : existing = existing?.asCookMeal,
        meals = meals ?? [];

  /// What operations return. Null entries are created on demand, and are as
  /// empty as a real draft — the Cook has answered nothing yet.
  CookMeal? existing;

  /// When true, all mutating operations fail.
  bool failOperations;

  /// When true, [uploadPhoto] fails independently of [failOperations].
  bool failUploads;

  int createDraftCalls = 0;
  int updateDraftCalls = 0;
  int publishCalls = 0;
  int uploadPhotoCalls = 0;

  String? lastCreatedMealId;

  /// Every title a draft was started from, in order.
  final List<String> createdTitles = [];
  String? lastPublishedMealId;
  String? lastUploadedMealId;

  /// Every [updateDraft] call, in order, with the fields that were sent.
  final List<FakeUpdateDraftCall> updateDraftArgs = [];

  @override
  Future<Result<String, AppError>> createDraft({required String title}) async {
    createDraftCalls++;
    if (failOperations) {
      return const Failure(AppError(messageKey: 'mealSaveError'));
    }
    final id = 'fake-meal-$createDraftCalls';
    lastCreatedMealId = id;
    createdTitles.add(title);
    return Success(id);
  }

  @override
  Future<Result<CookMeal, AppError>> updateDraft({
    required String mealId,
    String? title,
    String? description,
    String? price,
    Cuisine? cuisine,
    MealCategory? category,
    List<String>? ingredients,
    int? calories,
    List<String>? allergens,
    String? photoPath,
  }) async {
    updateDraftCalls++;
    updateDraftArgs.add(
      FakeUpdateDraftCall(
        mealId: mealId,
        title: title,
        description: description,
        price: price,
        cuisine: cuisine,
        category: category,
        ingredients: ingredients,
        calories: calories,
        allergens: allergens,
        photoPath: photoPath,
      ),
    );
    if (failOperations) {
      return const Failure(AppError(messageKey: 'mealSaveError'));
    }
    // A NEW DRAFT CARRIES ONLY WHAT THE COOK HAS ANSWERED. No invented cuisine,
    // no `'0'` price, no empty-string description standing in for a question
    // nobody has been asked — those are the values that hid the crash. What is
    // absent here is absent in `meals` too, and the two must keep agreeing.
    final base = existing ??
        CookMeal(
          id: mealId,
          cookId: 'fake-cook',
          status: MealStatus.draft,
          nutritionSource: NutritionSource.ai,
        );
    final updated = base.copyWith(
      title: title,
      description: description,
      price: price,
      cuisine: cuisine,
      category: category,
      ingredients: ingredients,
      calories: calories,
      allergens: allergens,
      photoPath: photoPath,
    );
    existing = updated;
    return Success(updated);
  }

  @override
  Future<Result<CookMeal, AppError>> publish(String mealId) async {
    publishCalls++;
    if (failOperations) {
      return const Failure(AppError(messageKey: 'mealSaveError'));
    }
    // Publishing a draft nothing was written to is not a state `meals` allows —
    // `enforce_meal_lifecycle` refuses it. The fake keeps the row as empty as it
    // found it rather than filling the gaps, so a test that publishes without
    // answering is testing the same impossible row the database would reject.
    final base = existing ??
        CookMeal(
          id: mealId,
          cookId: 'fake-cook',
          status: MealStatus.draft,
          nutritionSource: NutritionSource.ai,
        );
    final published = base.copyWith(
      status: MealStatus.published,
      publishedAt: DateTime.now(),
    );
    lastPublishedMealId = mealId;
    existing = published;
    return Success(published);
  }

  @override
  Future<Result<String, AppError>> uploadPhoto({
    required String mealId,
    required Uint8List bytes,
  }) async {
    uploadPhotoCalls++;
    if (failOperations || failUploads) {
      return const Failure(AppError(messageKey: 'mealPhotoError'));
    }
    lastUploadedMealId = mealId;
    return Success('fake-cook/$mealId.jpg');
  }

  /// Meals returned by myMeals(). Set by tests; defaults to empty.
  List<CookMeal> meals = [];

  int myMealsCalls = 0;
  int setStatusCalls = 0;
  int deleteDraftCalls = 0;

  final List<({String mealId, MealStatus next})> setStatusArgs = [];
  String? lastDeletedMealId;

  /// How long [myMeals] takes to answer.
  ///
  /// Zero by default so every existing test is unaffected. A test that needs
  /// to observe what the screen renders WHILE the load is in flight sets it —
  /// without a delay the load resolves inside the first pump and the loading
  /// state is unobservable, which is how it shipped rendering "no Meals yet"
  /// to Cooks who have Meals.
  Duration myMealsDelay = Duration.zero;

  @override
  Future<Result<List<CookMeal>, AppError>> myMeals() async {
    myMealsCalls++;
    if (myMealsDelay > Duration.zero) {
      await Future<void>.delayed(myMealsDelay);
    }
    if (failOperations) {
      return const Failure(AppError(messageKey: 'mealLoadError'));
    }
    return Success(List.unmodifiable(meals));
  }

  @override
  Future<Result<CookMeal, AppError>> setStatus({
    required String mealId,
    required MealStatus next,
  }) async {
    setStatusCalls++;
    setStatusArgs.add((mealId: mealId, next: next));
    if (failOperations) {
      return const Failure(AppError(messageKey: 'mealAvailabilityError'));
    }
    final idx = meals.indexWhere((m) => m.id == mealId);
    if (idx == -1) {
      return const Failure(AppError(messageKey: 'mealAvailabilityError'));
    }
    final updated = meals[idx].copyWith(status: next);
    meals = [...meals]..[idx] = updated;
    return Success(updated);
  }

  @override
  Future<Result<void, AppError>> deleteDraft(String mealId) async {
    deleteDraftCalls++;
    if (failOperations) {
      return const Failure(AppError(messageKey: 'mealDeleteError'));
    }
    lastDeletedMealId = mealId;
    meals = meals.where((m) => m.id != mealId).toList();
    return const Success(null);
  }
}
