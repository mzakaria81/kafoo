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
}
