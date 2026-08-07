import 'package:kafoo_domain/domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'discovery_repository.g.dart';

/// What a Customer can reach without holding a reference to it.
///
/// An interface rather than a concrete class so the browse flow can be driven
/// in a test without a live Supabase — which is what makes "a draft never
/// appears" provable in a widget test rather than only in the database.
///
/// **Nothing here writes.** Discovery reads and reads only; no Meal, Kitchen
/// Profile or Customer record is created or changed by anything behind this
/// interface.
abstract interface class DiscoveryRepository {
  /// Every Meal currently on offer, with the kitchen behind it.
  ///
  /// **RLS is what makes this correct, not the query.** The `anyone reads a
  /// published meal` policy is granted to `anon` and `authenticated` alike, so
  /// this returns the same rows signed in or not — which is the whole reason
  /// discovery works without an account. A status filter here would be a second
  /// copy of that rule in a place the database cannot see; there is one below
  /// anyway, and it is an optimisation rather than the guard.
  ///
  /// Newest on offer first. A Cook who has just put something up is the most
  /// likely to have it ready.
  Future<Result<List<DiscoveredMeal>, AppError>> mealsOnOffer();

  /// Ranked Meals for what a Customer said, and what Kafoo understood of it.
  ///
  /// **Calls `discover`, which holds no write credential and passes the caller's
  /// own credentials through to the database.** The phrase never reaches this
  /// app's storage, an analytics event, or a log line — FR-029.
  ///
  /// A failure here must never take browsing with it: the screen falls back to
  /// what is on offer, which is also search's zero state (FR-012).
  Future<Result<SearchOutcome, AppError>> search({
    required String phrase,
    String? area,
  });
}

/// What came back from a search: the Meals, and what Kafoo understood.
///
/// **[notUnderstood] is not decoration.** A negation Kafoo recognised without
/// recognising the food must reach the Customer as a sentence — returning
/// results as though no exclusion had been asked for is the failure the whole
/// exclusion design exists to prevent, and it is invisible unless the interface
/// is told.
final class SearchOutcome {
  /// Creates an outcome.
  const SearchOutcome({
    required this.results,
    this.excludedId,
    this.notUnderstood,
  });

  /// The Meals, in the order the database returned them. Never re-sorted here.
  final DiscoveryResults results;

  /// Which exclusion Kafoo acted on, if any. An id, never the Customer's words.
  final String? excludedId;

  /// The words following a negation marker that Kafoo could not map to a food.
  final String? notUnderstood;
}

/// The only layer that touches Supabase for discovery.
class SupabaseDiscoveryRepository implements DiscoveryRepository {
  const SupabaseDiscoveryRepository();

  static const String _meals = 'meals';
  static const String _kitchens = 'kitchen_profiles';

  /// Named columns, never `select()`.
  ///
  /// A bare select is `select=*`, and since E3 added `embedding` that is 768 floats — about 8 KB of
  /// JSON per Meal, so roughly 420 KB of vectors on a fifty-Meal browse, against a one-second
  /// budget on an Egyptian mobile connection. Nothing renders them.
  ///
  /// It is also the safer default in general: `*` widens with the table, so the first genuinely
  /// private column added to `meals` would start arriving here on the day it is created.
  static const String _mealColumns =
      'id, cook_id, title, description, price, cuisine, category, status, '
      'ingredients, calories, allergens, nutrition_source, photo_path, '
      'created_at, updated_at, published_at';

  static const String _kitchenColumns =
      'id, cook_id, display_name, story, area, delivery_terms, photo_path, '
      'address_form, created_at, updated_at';

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<Result<SearchOutcome, AppError>> search({
    required String phrase,
    String? area,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'discover',
        body: {'phrase': phrase, if (area != null) 'area': area},
      );

      final data = response.data;
      if (data is! Map) {
        return const Failure(AppError(messageKey: 'searchUnavailable'));
      }

      final mealRows = (data['meals'] as List?) ?? const [];
      if (mealRows.isEmpty) {
        return Success(
          SearchOutcome(
            results: const DiscoveryResults(results: []),
            excludedId: data['excluded'] as String?,
            notUnderstood: data['notUnderstood'] as String?,
          ),
        );
      }

      // The kitchens, in one query, the same way browse does it. `discover`
      // returns Meals alone because `search_meals` returns Meals alone, and a
      // join in the database would mean a foreign key added to suit a screen.
      final cookIds = mealRows
          .map((row) => (row as Map)['cook_id'] as String)
          .toSet()
          .toList();

      final kitchenRows = await _client
          .from(_kitchens)
          .select(_kitchenColumns)
          .inFilter('cook_id', cookIds);

      final kitchensByCook = <String, KitchenProfile>{
        for (final row in kitchenRows)
          row['cook_id'] as String: KitchenProfile.fromRow(row),
      };

      final ranked = <DiscoveryResult>[];
      for (final (index, row) in mealRows.indexed) {
        final map = Map<String, dynamic>.from(row as Map);
        final meal = CookMeal.fromRow(map).asMeal;
        final kitchen = kitchensByCook[map['cook_id'] as String];
        if (meal == null || kitchen == null) continue;
        // Rank is the database's order, recorded rather than recomputed.
        ranked.add(
          DiscoveryResult(
            item: DiscoveredMeal(meal: meal, kitchen: kitchen),
            rank: index + 1,
          ),
        );
      }

      return Success(
        SearchOutcome(
          results: DiscoveryResults(results: ranked),
          excludedId: data['excluded'] as String?,
          notUnderstood: data['notUnderstood'] as String?,
        ),
      );
    } on Object catch (e) {
      // `on Object`, not `on Exception` — same reason as below.
      //
      // The error key says search is unavailable rather than that something went
      // wrong, because the screen's answer is to fall back to browsing and the
      // Customer should be told which of the two they are looking at.
      return Failure(AppError(messageKey: 'searchUnavailable', cause: e));
    }
  }

  @override
  Future<Result<List<DiscoveredMeal>, AppError>> mealsOnOffer() async {
    try {
      final mealRows = await _client
          .from(_meals)
          .select(_mealColumns)
          .eq('status', MealStatus.published.wireName)
          .order('published_at', ascending: false);

      if (mealRows.isEmpty) return const Success(<DiscoveredMeal>[]);

      // Two queries rather than one join, and deliberately so: `meals` and
      // `kitchen_profiles` both reference `auth.users`, and neither references
      // the other, so there is no relationship for the data layer to traverse.
      // Adding a foreign key between them to make one query possible would be
      // changing the schema to suit a screen.
      final cookIds =
          mealRows.map((row) => row['cook_id'] as String).toSet().toList();

      final kitchenRows = await _client
          .from(_kitchens)
          .select(_kitchenColumns)
          .inFilter('cook_id', cookIds);

      final kitchensByCook = <String, KitchenProfile>{
        for (final row in kitchenRows)
          row['cook_id'] as String: KitchenProfile.fromRow(row),
      };

      final discovered = <DiscoveredMeal>[];
      for (final row in mealRows) {
        final meal = CookMeal.fromRow(row).asMeal;
        final kitchen = kitchensByCook[row['cook_id'] as String];

        // A Meal on offer whose kitchen did not come back is dropped rather
        // than shown kitchen-less. It should be unreachable — the widening
        // policy makes a kitchen readable exactly while it has a Meal on offer
        // — so this is the case where that has stopped being true, and showing
        // a Customer food with nobody behind it is worse than showing less.
        if (meal == null || kitchen == null) continue;
        discovered.add(DiscoveredMeal(meal: meal, kitchen: kitchen));
      }
      return Success(discovered);
    } on Object catch (e) {
      // `on Object`, not `on Exception`: an uninitialised Supabase client
      // throws StateError and a missing plugin throws TypeError, and both
      // stranded a loading spinner forever in E1.
      return Failure(AppError(messageKey: 'discoveryLoadError', cause: e));
    }
  }
}

@riverpod
DiscoveryRepository discoveryRepository(Ref ref) =>
    const SupabaseDiscoveryRepository();
