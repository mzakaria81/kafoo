import 'package:kafoo_domain/domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/discovery_repository.dart';

part 'browse_controller.g.dart';

/// What the browse screen is showing.
class BrowseState {
  const BrowseState({
    this.onOffer = const [],
    this.error,
    this.loading = true,
  });

  /// Meals currently on offer, newest first.
  final List<DiscoveredMeal> onOffer;

  final AppError? error;

  /// True until the first load answers.
  ///
  /// Separate from `onOffer.isEmpty`, because to a Customer the two mean
  /// opposite things and one of them is a lie. Without this, the screen says
  /// "no food is on offer" for the whole of every first load — telling someone
  /// the marketplace is empty when it is merely slow, every single time they
  /// open the app. The Cook's own list learned this the same way.
  final bool loading;

  /// Whether to tell the Customer there is nothing on offer.
  ///
  /// Deliberately narrow: not while loading, and **not on a failure**. A
  /// failure is Kafoo's fault and an empty marketplace is not, and dressing one
  /// up as the other is a small lie that costs trust for no benefit.
  bool get saysNothingOnOffer => !loading && error == null && onOffer.isEmpty;

  BrowseState copyWith({
    List<DiscoveredMeal>? onOffer,
    Object? error = _undefined,
    bool? loading,
  }) =>
      BrowseState(
        onOffer: onOffer ?? this.onOffer,
        error: error == _undefined ? this.error : error as AppError?,
        loading: loading ?? this.loading,
      );

  static const _undefined = Object();
}

@riverpod
class BrowseController extends _$BrowseController {
  DiscoveryRepository get _repository => ref.read(discoveryRepositoryProvider);

  @override
  BrowseState build() {
    _load();
    return const BrowseState();
  }

  Future<void> _load() async {
    final result = await _repository.mealsOnOffer();
    if (!ref.mounted) return;
    switch (result) {
      case Success(value: final items):
        state = state.copyWith(onOffer: items, error: null, loading: false);
      case Failure(error: final err):
        state = state.copyWith(error: err, loading: false);
    }
  }

  /// Reloads what is on offer.
  ///
  /// Discovery reflects the moment it is asked, not the moment the screen was
  /// opened — a Cook takes food off the menu while a Customer is looking at it.
  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    await _load();
  }
}
