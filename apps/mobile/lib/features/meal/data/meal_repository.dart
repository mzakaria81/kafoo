import 'dart:typed_data';

import 'package:kafoo_domain/domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'meal_repository.g.dart';

/// Meal operations for the publishing flow.
///
/// An interface rather than a concrete class so the flow can be driven in a
/// test without a live Supabase — which is what makes "a cancelled publish
/// writes nothing" provable rather than asserted.
abstract interface class MealRepository {
  /// Creates a draft Meal owned by the signed-in Cook.
  ///
  /// The `cook_id` comes from the session, never from an argument.
  /// Starts a draft from the first thing the Cook said, and returns its id.
  ///
  /// Only the title is required: that is all a Cook has given after answering
  /// one question, and the conversation persists as it goes so that walking
  /// away halfway leaves a draft rather than nothing. Completeness is enforced
  /// by the database on the way OUT of `draft`, not on the way in.
  ///
  /// Returns an id rather than a [Meal] because at this moment there is no Meal
  /// — [Meal] models a complete one, with a title, a price and a cuisine, and
  /// widening it to describe a half-finished draft would make every published
  /// Meal in the app carry nullable fields that cannot actually be null. The
  /// conversation holds its own answers; what it needs from the database is the
  /// identity to attach them to, and the path to store a photograph under.
  Future<Result<String, AppError>> createDraft({required String title});

  /// Updates only the fields supplied on a draft Meal.
  ///
  /// The Meal must belong to the signed-in Cook, enforced by RLS.
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
  });

  /// Moves a draft to `published` and sets `published_at`.
  ///
  /// The database trigger sets `published_at` on the first publish moment;
  /// this layer only changes the status.
  Future<Result<Meal, AppError>> publish(String mealId);

  /// Uploads a photo to the `meal-photos` bucket at `{uid}/{mealId}.jpg`.
  ///
  /// The storage policies only permit a Cook's own folder, so any other layout
  /// fails at the database and must not be attempted.
  Future<Result<String, AppError>> uploadPhoto({
    required String mealId,
    required Uint8List bytes,
  });

  /// Every Meal belonging to the signed-in Cook, at every status.
  ///
  /// RLS is what scopes this to the caller — the "cook reads own meals" policy.
  /// Newest first, so the Meal a Cook was just working on is at the top.
  Future<Result<List<Meal>, AppError>> myMeals();

  // ponytail: overlaps with publish(String) — publish should fold into
  // setStatus once the publishing flow is free to change.
  Future<Result<Meal, AppError>> setStatus({
    required String mealId,
    required MealStatus next,
  });

  /// Deletes a draft outright.
  ///
  /// Drafts only. Anything that has been on offer is archived instead — the
  /// DELETE policy enforces this, and a Meal a Customer may have ordered must
  /// never disappear.
  Future<Result<void, AppError>> deleteDraft(String mealId);
}

/// The only layer that touches Supabase for Meals.
///
/// RLS is the real guard on every call here — these queries are scoped by
/// `auth.uid()` in the database, not by the filters written below.
class SupabaseMealRepository implements MealRepository {
  const SupabaseMealRepository();

  static const String _table = 'meals';
  static const String _bucket = 'meal-photos';

  SupabaseClient get _client => Supabase.instance.client;

  String? get _uid => _client.auth.currentUser?.id;

  @override
  Future<Result<String, AppError>> createDraft({required String title}) async {
    try {
      final uid = _uid;
      if (uid == null) {
        return const Failure(AppError(messageKey: 'mealSaveError'));
      }
      // Only what the Cook has actually answered. An unanswered question is an absent column
      // rather than an explicit null, so the row says "not asked yet" instead of "answered with
      // nothing", and the database defaults keep applying.
      final row = await _client
          .from(_table)
          .insert({
            'cook_id': uid,
            'title': title,
            'status': MealStatus.draft.wireName,
          })
          .select('id')
          .single();
      return Success(row['id'] as String);
    } on Object catch (e) {
      return Failure(AppError(messageKey: 'mealSaveError', cause: e));
    }
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
    try {
      final uid = _uid;
      if (uid == null) {
        return const Failure(AppError(messageKey: 'mealSaveError'));
      }
      final fields = <String, Object?>{
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (price != null) 'price': price,
        if (cuisine != null) 'cuisine': cuisine.wireName,
        if (category != null) 'category': category.wireName,
        if (ingredients != null) 'ingredients': ingredients,
        if (calories != null) 'calories': calories,
        if (allergens != null) 'allergens': allergens,
        if (photoPath != null) 'photo_path': photoPath,
      };
      if (fields.isEmpty) {
        // Nothing to update — read the current state and return it.
        final row =
            await _client.from(_table).select().eq('id', mealId).single();
        return Success(_fromRow(row));
      }
      final row = await _client
          .from(_table)
          .update(fields)
          .eq('id', mealId)
          .select()
          .single();
      return Success(_fromRow(row));
    } on Object catch (e) {
      return Failure(AppError(messageKey: 'mealSaveError', cause: e));
    }
  }

  @override
  Future<Result<Meal, AppError>> publish(String mealId) async {
    try {
      final uid = _uid;
      if (uid == null) {
        return const Failure(AppError(messageKey: 'mealSaveError'));
      }
      final row = await _client
          .from(_table)
          .update({'status': MealStatus.published.wireName})
          .eq('id', mealId)
          .select()
          .single();
      return Success(_fromRow(row));
    } on Object catch (e) {
      return Failure(AppError(messageKey: 'mealSaveError', cause: e));
    }
  }

  @override
  Future<Result<String, AppError>> uploadPhoto({
    required String mealId,
    required Uint8List bytes,
  }) async {
    try {
      final uid = _uid;
      if (uid == null) {
        return const Failure(AppError(messageKey: 'mealPhotoError'));
      }
      final path = '$uid/$mealId.jpg';
      await _client.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return Success(path);
    } on Object catch (e) {
      return Failure(AppError(messageKey: 'mealPhotoError', cause: e));
    }
  }

  @override
  Future<Result<List<Meal>, AppError>> myMeals() async {
    try {
      final uid = _uid;
      if (uid == null) {
        return const Failure(AppError(messageKey: 'mealLoadError'));
      }
      final rows = (await _client
          .from(_table)
          .select()
          .order('created_at', ascending: false)) as List;
      return Success(rows.cast<Map<String, dynamic>>().map(_fromRow).toList());
    } on Object catch (e) {
      return Failure(AppError(messageKey: 'mealLoadError', cause: e));
    }
  }

  @override
  Future<Result<Meal, AppError>> setStatus({
    required String mealId,
    required MealStatus next,
  }) async {
    try {
      final uid = _uid;
      if (uid == null) {
        return const Failure(AppError(messageKey: 'mealAvailabilityError'));
      }
      final row = await _client
          .from(_table)
          .update({'status': next.wireName})
          .eq('id', mealId)
          .select()
          .single();
      return Success(_fromRow(row));
    } on Object catch (e) {
      return Failure(AppError(messageKey: 'mealAvailabilityError', cause: e));
    }
  }

  @override
  Future<Result<void, AppError>> deleteDraft(String mealId) async {
    try {
      final uid = _uid;
      if (uid == null) {
        return const Failure(AppError(messageKey: 'mealDeleteError'));
      }
      await _client.from(_table).delete().eq('id', mealId);
      return const Success(null);
    } on Object catch (e) {
      return Failure(AppError(messageKey: 'mealDeleteError', cause: e));
    }
  }

  Meal _fromRow(Map<String, dynamic> row) {
    return Meal(
      id: row['id'] as String,
      cookId: row['cook_id'] as String,
      title: row['title'] as String,
      description: row['description'] as String,
      price: row['price'].toString(),
      cuisine: Cuisine.tryFromWireName(row['cuisine'] as String) ??
          (throw ArgumentError.value(
            row['cuisine'],
            'cuisine',
            'unknown cuisine',
          )),
      category: MealCategory.tryFromWireName(row['category'] as String) ??
          (throw ArgumentError.value(
            row['category'],
            'category',
            'unknown meal category',
          )),
      status: MealStatus.fromWireName(row['status'] as String),
      ingredients: (row['ingredients'] as List).cast<String>(),
      calories: row['calories'] as int?,
      allergens: (row['allergens'] as List).cast<String>(),
      nutritionSource: NutritionSource.fromWireName(
        row['nutrition_source'] as String,
      ),
      photoPath: row['photo_path'] as String?,
      publishedAt: row['published_at'] == null
          ? null
          : DateTime.parse(row['published_at'] as String),
    );
  }
}

/// The default [MealRepository] provider.
///
/// Tests override this with [FakeMealRepository] via ProviderScope.
@Riverpod(keepAlive: true)
MealRepository mealRepository(Ref ref) => const SupabaseMealRepository();
