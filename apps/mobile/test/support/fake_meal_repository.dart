import 'dart:typed_data';

import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/meal/data/meal_repository.dart';

/// Records every write it is asked to make, so a test can assert which writes
/// happened — and, more usefully, that none did.
class FakeMealRepository implements MealRepository {
  FakeMealRepository({this.existing, this.failOperations = false});

  /// What operations return. Null entries are created on demand.
  Meal? existing;

  /// When true, all mutating operations fail.
  bool failOperations;

  int createDraftCalls = 0;
  int updateDraftCalls = 0;
  int publishCalls = 0;
  int uploadPhotoCalls = 0;

  String? lastCreatedMealId;

  /// Every title a draft was started from, in order.
  final List<String> createdTitles = [];
  String? lastPublishedMealId;
  String? lastUploadedMealId;

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
  Future<Result<Meal, AppError>> updateDraft({
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
    if (failOperations) {
      return const Failure(AppError(messageKey: 'mealSaveError'));
    }
    final base = existing ??
        Meal(
          id: mealId,
          cookId: 'fake-cook',
          title: title ?? 'Untitled',
          description: description ?? '',
          price: price ?? '0',
          cuisine: cuisine ?? Cuisine.egyptian,
          category: category ?? MealCategory.main,
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
  Future<Result<Meal, AppError>> publish(String mealId) async {
    publishCalls++;
    if (failOperations) {
      return const Failure(AppError(messageKey: 'mealSaveError'));
    }
    final base = existing ??
        Meal(
          id: mealId,
          cookId: 'fake-cook',
          title: 'Untitled',
          description: '',
          price: '0',
          cuisine: Cuisine.egyptian,
          category: MealCategory.main,
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
    if (failOperations) {
      return const Failure(AppError(messageKey: 'mealPhotoError'));
    }
    lastUploadedMealId = mealId;
    return Success('fake-cook/$mealId.jpg');
  }
}
