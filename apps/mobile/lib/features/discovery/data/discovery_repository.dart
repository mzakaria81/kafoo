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
