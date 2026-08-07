import 'dart:async';

import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/discovery/data/discovery_repository.dart';

/// Drives discovery without a network.
///
/// Discovery only reads, so unlike the other fakes there are no writes to
/// record. What this one exists to control is the three answers a Customer can
/// get — food, nothing, or a failure — because they are three different screens
/// and only one of them is the happy path.
class FakeDiscoveryRepository implements DiscoveryRepository {
  FakeDiscoveryRepository({
    this.onOffer = const <DiscoveredMeal>[],
    this.fail = false,
    this.hold = false,
  });

  /// What [mealsOnOffer] returns.
  List<DiscoveredMeal> onOffer;

  /// When true, [mealsOnOffer] fails — the case where a Customer must be told
  /// something rather than shown an empty screen.
  bool fail;

  /// When true, [mealsOnOffer] never completes.
  ///
  /// This is how the loading state is testable at all. Without it the fake
  /// answers in the same frame and a test can never observe the spinner, which
  /// is exactly where E1 lost a screen to an error it was not catching.
  bool hold;

  /// What [search] returns when it succeeds.
  SearchOutcome searchOutcome = const SearchOutcome(
    results: DiscoveryResults(results: []),
  );

  /// What [judge] returns, or null for "nothing to say".
  Judgement? judgement;

  /// When true, [judge] NEVER COMPLETES.
  ///
  /// This is how FR-011 is provable rather than asserted. Results must be on
  /// screen before the AI Assistant has finished considering them, and the only
  /// evidence of that is a judgement that has not finished — a fast fake proves
  /// nothing, because a screen that waits for it looks identical.
  bool holdJudgement = false;

  /// The phrases this fake was asked for, so a test can assert what left the
  /// device — and, with the switch off, that NOTHING did.
  final List<String> phrases = <String>[];

  /// The areas each search was narrowed to, positionally matching [phrases].
  ///
  /// FR-024a turns on the CUSTOMER choosing an area, so a test has to be able
  /// to see that the second request carried one and the first did not.
  final List<String?> areas = <String?>[];

  int calls = 0;

  @override
  Future<Result<List<DiscoveredMeal>, AppError>> mealsOnOffer() async {
    calls++;
    if (hold) {
      await Completer<void>().future;
    }
    if (fail) {
      return const Failure(AppError(messageKey: 'discoveryLoadError'));
    }
    return Success(onOffer);
  }

  @override
  Future<Result<SearchOutcome, AppError>> search({
    required String phrase,
    String? area,
  }) async {
    // Recorded rather than counted: the assertions that matter about search are
    // about what left the device, and a count cannot answer those.
    phrases.add(phrase);
    areas.add(area);
    if (hold) {
      await Completer<void>().future;
    }
    if (fail) {
      return const Failure(AppError(messageKey: 'searchUnavailable'));
    }
    return Success(searchOutcome);
  }

  /// The phrases handed to [judge], so a test can assert that a Customer who
  /// refused sends nothing to the AI Assistant either.
  final List<String> judged = <String>[];

  @override
  Future<Judgement?> judge({
    required String phrase,
    required DiscoveryResults results,
  }) async {
    judged.add(phrase);
    if (holdJudgement) {
      await Completer<void>().future;
    }
    return judgement;
  }
}
