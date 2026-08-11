import 'dart:async';
import 'dart:io';
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
  ///
  /// **Returns [CookMeal], and the type is the fix for a defect that stopped
  /// every Cook from putting a Meal on offer.** This returned `Meal` until
  /// 2026-08-11 and parsed the row with a mapper that casts title, description,
  /// cuisine and category to non-null. A draft has none of the last two — the
  /// whole point of `allow_incomplete_meal_drafts` — so the cast threw, the
  /// throw was caught as a save failure, and the Cook was told «مقدرناش نحفظ
  /// الأكلة» about a row the database had already written. It happened on the
  /// second question of the conversation, every time, for everyone.
  ///
  /// [createDraft] two declarations above says why [Meal] cannot describe a
  /// half-finished draft. That reasoning was written down and then contradicted
  /// here. A signature is the only version of it a later change cannot ignore.
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
  });

  /// Moves a draft to `published` and sets `published_at`.
  ///
  /// The database trigger sets `published_at` on the first publish moment;
  /// this layer only changes the status.
  ///
  /// [CookMeal] here too, even though a published row IS complete —
  /// `enforce_meal_lifecycle` refuses to let it leave draft otherwise. One
  /// mapper for every row this file reads is worth more than a second one that
  /// is correct only while a guarantee holds somewhere else.
  Future<Result<CookMeal, AppError>> publish(String mealId);

  /// Uploads a photo to the `meal-photos` bucket at `{uid}/{mealId}.jpg`.
  ///
  /// The storage policies only permit a Cook's own folder, so any other layout
  /// fails at the database and must not be attempted.
  Future<Result<String, AppError>> uploadPhoto({
    required String mealId,
    required Uint8List bytes,
  });

  /// A URL the app can render for a photo stored at [photoPath].
  ///
  /// **THE SUMMARY SHOWED THE PATH ITSELF UNTIL 2026-08-11.** A Cook who had
  /// just taken a photograph of her food was shown the text
  /// `7a38f558-…/69d0e03e-….jpg` where the photograph should have been, on the
  /// screen where she checks the Meal before putting it on offer. Nothing
  /// resolved a URL anywhere in the app, so there was nothing for the row to
  /// render — `public_meal_view.dart` takes a `photoUrl` and no caller had ever
  /// supplied one either.
  ///
  /// Synchronous and non-failing because `meal-photos` is a PUBLIC bucket
  /// (`create_meals.sql`), so this is string construction rather than a request.
  /// It stays on the repository regardless: this layer is the only one that may
  /// know how Supabase addresses storage.
  String photoUrl(String photoPath);

  /// Every Meal belonging to the signed-in Cook, at every status.
  ///
  /// Returns [CookMeal] rather than [Meal] because a draft may be half-answered
  /// — the conversation persists each answer as it arrives. [Meal] models a
  /// complete offer and cannot represent that row.
  ///
  /// RLS is what scopes this to the caller — the "cook reads own meals" policy.
  /// Newest first, so the Meal a Cook was just working on is at the top.
  Future<Result<List<CookMeal>, AppError>> myMeals();

  // ponytail: overlaps with publish(String) — publish should fold into
  // setStatus once the publishing flow is free to change.
  Future<Result<CookMeal, AppError>> setStatus({
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
  /// [requestEmbedding] is injected only so a test can make it fail. In production it is null and
  /// [_askForEmbedding] calls the Edge Function.
  const SupabaseMealRepository({
    Future<void> Function(String mealId)? requestEmbedding,
  }) : _requestEmbedding = requestEmbedding;

  final Future<void> Function(String mealId)? _requestEmbedding;

  static const String _table = 'meals';

  /// Named columns, never `select()`.
  ///
  /// A bare select is `select=*`, and since E3 added `embedding` that is 768 floats — roughly 8 KB
  /// of JSON per Meal that nothing renders. On a Cook's Meal list it is pure weight on an Egyptian
  /// mobile connection.
  ///
  /// **It is also a ranking concern, which is the part that is not obvious.** A Cook cannot write
  /// their own vector — `protect_meal_embedding` refuses it — but they write the description that
  /// produces it. Handing them the resulting vectors is what makes tuning a description against the
  /// ranker practical, so the read side reopens what the write side closed. Found by
  /// ai-boundary-reviewer, 2026-08-07.
  ///
  /// `discovery_repository.dart` has named its columns since it was written; this file was not
  /// updated when the column landed.
  static const String _columns =
      'id, cook_id, title, description, price, cuisine, category, status, '
      'ingredients, calories, allergens, nutrition_source, photo_path, '
      'created_at, updated_at, published_at';
  static const String _bucket = 'meal-photos';

  SupabaseClient get _client => Supabase.instance.client;

  String? get _uid => _client.auth.currentUser?.id;

  /// Asks Kafoo to give this Meal a vector, and never lets that matter to the Cook.
  ///
  /// **Not awaited, and every failure is swallowed. Both are the feature.** A Meal with no vector is
  /// invisible to search and fully visible to browsing, so an unreachable provider, an exhausted
  /// quota or a bad key makes a Meal HARDER TO FIND — never lost, and never a Cook who cannot
  /// publish because a model provider is down. Awaiting this would put a model provider's availability on
  /// the path of the most important action a Cook takes.
  ///
  /// It is fired on publish and on a title or description change, and NOT on a price, photo or
  /// status change: those do not alter what the food IS, so re-embedding them would spend a model
  /// call and move a Meal's ranking for no reason a Customer could perceive.
  ///
  /// WHICH EDITS COUNT, as a named rule rather than a condition buried in a method. It is the part
  /// with a decision in it, and `meal_embedding_trigger_test.dart` is what stops somebody
  /// "simplifying" it to re-embed on every save.
  static bool changesWhatTheFoodIs({String? title, String? description}) =>
      title != null || description != null;

  void _askForEmbedding(String mealId) {
    final request = _requestEmbedding ??
        (id) async {
          await _client.functions.invoke('embed-meal', body: {'mealId': id});
        };
    unawaited(
      request(mealId).catchError((Object _) {
        // Deliberately silent. See above — the Cook's save has already succeeded, and there is
        // nothing here they could act on.
      }),
    );
  }

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
        final row = await _client
            .from(_table)
            .select(_columns)
            .eq('id', mealId)
            .single();
        return Success(_cookMealFromRow(row));
      }
      final row = await _client
          .from(_table)
          .update(fields)
          .eq('id', mealId)
          .select(_columns)
          .single();
      // Only when the WORDS changed. A price edit is the same food, and a Meal that re-embeds on
      // every save spends a model call per keystroke-batch and drifts in the rankings while a Cook
      // is still deciding what to charge.
      if (changesWhatTheFoodIs(title: title, description: description)) {
        _askForEmbedding(mealId);
      }
      return Success(_cookMealFromRow(row));
    } on Object catch (e) {
      return Failure(AppError(messageKey: 'mealSaveError', cause: e));
    }
  }

  @override
  Future<Result<CookMeal, AppError>> publish(String mealId) async {
    try {
      final uid = _uid;
      if (uid == null) {
        return const Failure(AppError(messageKey: 'mealSaveError'));
      }
      final row = await _client
          .from(_table)
          .update({'status': MealStatus.published.wireName})
          .eq('id', mealId)
          .select(_columns)
          .single();
      // A Meal reaching Customers for the first time is exactly when it needs to be findable.
      _askForEmbedding(mealId);
      return Success(_cookMealFromRow(row));
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
  String photoUrl(String photoPath) =>
      _client.storage.from(_bucket).getPublicUrl(photoPath);

  @override
  Future<Result<List<CookMeal>, AppError>> myMeals() async {
    try {
      final uid = _uid;
      if (uid == null) {
        return const Failure(AppError(messageKey: 'mealLoadError'));
      }
      final rows = (await _client
          .from(_table)
          .select(_columns)
          .order('created_at', ascending: false)) as List;
      return Success(
        rows.cast<Map<String, dynamic>>().map(_cookMealFromRow).toList(),
      );
    } on Object catch (e) {
      // OFFLINE IS A DIFFERENT SENTENCE FROM BROKEN. Everything landed on
      // `mealLoadError`, and the screen above titles that «مفيش نت» and
      // reassures «المشكلة في النت بس» — so a Cook whose read was refused by a
      // policy, or whose row would not parse, was sent to check her WiFi. The
      // one thing worse than an error is an error that sends someone to fix
      // something that is not broken.
      // Written out twice rather than as one constructor with a computed key:
      // the gate that checks every messageKey has an Arabic sentence reads the
      // token after `messageKey:`, so anything but a literal there reads as a
      // key nobody wrote a string for.
      return Failure(
        _looksOffline(e)
            ? AppError(messageKey: 'mealOfflineError', cause: e)
            : AppError(messageKey: 'mealLoadError', cause: e),
      );
    }
  }

  /// Whether a thrown error is the phone failing to reach the network.
  ///
  /// Matched on type and message rather than on a status code, because the
  /// client wraps a socket failure differently on each platform and none of the
  /// wrappers is exported.
  static bool _looksOffline(Object error) {
    if (error is SocketException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection closed') ||
        text.contains('connection refused') ||
        text.contains('network is unreachable');
  }

  @override
  Future<Result<CookMeal, AppError>> setStatus({
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
          .select(_columns)
          .single();
      return Success(_cookMealFromRow(row));
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

  /// Maps a row that may still be a half-answered draft.
  ///
  /// Delegates to [CookMeal.fromRow]: the mapping is a rule and it now has one
  /// home, because discovery reads the same table and a second copy of it would
  /// drift.
  ///
  /// **THE SECOND COPY IS GONE, AND DELETING IT IS THE FIX.** A `_fromRow`
  /// beside this one built a [Meal] and cast title, description, cuisine and
  /// category to non-null. Both mappers kept working and disagreed about
  /// exactly the four columns a draft leaves empty, which is the drift the
  /// comment above predicted, in the same file, already written down. Do not
  /// add a mapper here that cannot represent a draft — every row this table
  /// returns may be one.
  CookMeal _cookMealFromRow(Map<String, dynamic> row) => CookMeal.fromRow(row);
}

/// The default [MealRepository] provider.
///
/// Tests override this with [FakeMealRepository] via ProviderScope.
@Riverpod(keepAlive: true)
MealRepository mealRepository(Ref ref) => const SupabaseMealRepository();
