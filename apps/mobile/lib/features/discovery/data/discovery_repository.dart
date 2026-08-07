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

  /// What the AI Assistant makes of a set of results, once they are on screen.
  ///
  /// **Never awaited before results are shown.** FR-011 and SC-007: the AI
  /// Assistant does not sit between a Customer and their results. It is a
  /// separate method rather than a field on [SearchOutcome] precisely so that
  /// there is no shape in which the two can arrive together — a judgement
  /// modelled as part of the result is a judgement something will eventually
  /// wait for.
  ///
  /// Returns null when there is nothing to say, which is deliberately the same
  /// answer as a failure, a timeout, or a provider returning nonsense (T161).
  /// The Customer loses a sentence, never their results.
  Future<Judgement?> judge({
    required String phrase,
    required DiscoveryResults results,
  });

  /// Whether a Meal is STILL on offer, asked at the moment it is opened.
  ///
  /// FR-005: discovery reflects what is on offer when it is asked, and opening
  /// a Meal is a later moment than ranking it. A Cook taking food off the menu
  /// while a Customer reads about it is the one freshness case a Customer
  /// actually meets.
  ///
  /// **True on a failure, deliberately.** A network blip must not tell a
  /// Customer that food they can have is gone. Being wrong towards "still
  /// available" costs a wasted message to a Cook; being wrong the other way
  /// sends them somewhere else for no reason.
  Future<bool> isStillOnOffer(String mealId);
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
    this.notUnderstood = false,
    this.area,
  });

  /// The Meals, in the order the database returned them. Never re-sorted here.
  final DiscoveryResults results;

  /// Which exclusion Kafoo acted on, if any. An id, never the Customer's words.
  final String? excludedId;

  /// Whether a negation was recognised and the food after it was not.
  ///
  /// **A flag and not the words.** `discover` returned the Customer's own words
  /// here until 2026-08-07 — the whole tail of the sentence after the negation
  /// marker — and nothing ever read them: the sentence Kafoo says about this
  /// has no placeholder in it. Carrying them was a channel held open across the
  /// network, and into an error body, for no feature.
  final bool notUnderstood;

  /// The area the search was narrowed to, in the Customer's own words.
  ///
  /// **Without this, an empty result in a named area is indistinguishable from
  /// an empty marketplace**, and FR-024 turns on exactly that difference: one of
  /// them is "nothing in المهندسين, but there is food in الدقي" and the other is
  /// "no Cook anywhere has anything on offer". They are different sentences and
  /// only one of them is true.
  final String? area;

  /// Whether Kafoo narrowed to an area and found nothing there — FR-024.
  bool get areaIsEmpty => area != null && results.isEmpty;
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
            notUnderstood: data['notUnderstood'] == true,
            area: data['area'] as String?,
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
          notUnderstood: data['notUnderstood'] == true,
          area: data['area'] as String?,
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
  Future<Judgement?> judge({
    required String phrase,
    required DiscoveryResults results,
  }) async {
    try {
      final byId = <String, Meal>{
        for (final result in results.results)
          result.item.meal.id: result.item.meal,
      };
      final response = await _client.functions.invoke(
        'judge-results',
        body: {'phrase': phrase, 'mealIds': byId.keys.toList()},
      );
      final data = response.data;
      if (data is! Map) return null;

      // THE FIELD MUST BE PRESENT AND MUST BE A BOOLEAN, and requiring that is
      // the difference between the server promising and the client checking.
      //
      // Any 200 whose `answers` was not `true` read as "nothing here answers
      // you" — including a 200 carrying `{"error": "no judgement"}`, which is
      // the exact body the function returns when it declines to judge. It sends
      // that with a 503 and never a 200, so nothing was broken; the point is
      // that the safety of the whole design rested on no layer in between ever
      // turning a body into a 200. A gateway, a retry wrapper, or a platform
      // error page would have told a Customer their perfectly good results were
      // worthless. Found by ai-boundary-reviewer.
      if (data['answers'] is! bool) return null;
      if (data['answers'] == true) return const ResultsAnswer();

      // MATCHED against the set that was handed over, never looked up. A Meal
      // the AI Assistant invented has no id in this map and simply does not
      // appear — FR-015 says an alternative is a Meal genuinely on offer, and
      // the E2 finding was a model stating things nobody said.
      final alternatives = <Meal>[
        for (final id in (data['alternatives'] as List?) ?? const [])
          if (byId[id.toString()] case final meal?) meal,
      ];
      return NothingAnswers(alternatives: alternatives);
    } on Object catch (_) {
      // Every failure is "nothing to say". T161: results stay exactly as they
      // are and the Customer loses a sentence. `on Object` for the usual reason
      // — an uninitialised client throws StateError, a missing plugin TypeError.
      return null;
    }
  }

  @override
  Future<bool> isStillOnOffer(String mealId) async {
    try {
      final rows = await _client
          .from(_meals)
          .select('id')
          .eq('id', mealId)
          .eq('status', MealStatus.published.wireName);
      return rows.isNotEmpty;
    } on Object catch (_) {
      return true;
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
