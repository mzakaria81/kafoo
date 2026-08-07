import 'package:kafoo_domain/domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'search_consent_store.g.dart';

/// Where a Customer's answer about their own words is kept.
///
/// **On the device, and that is FR-029d rather than an implementation choice.**
/// Kafoo holds no record of a Customer — discovery works signed out, which is
/// the whole reason a shared link is worth anything — so there is no row to put
/// this on and nobody to put it against. A server-side answer would be
/// unavailable to exactly the person who arrives without an account, which is
/// the person most likely to be asked.
///
/// An interface so the search flow can be driven in a test without a platform
/// channel, and so **what left the device** can be asserted with the switch in
/// each position.
abstract interface class SearchConsentStore {
  /// The stored answer, or [SearchConsent.unanswered] if there is none.
  Future<SearchConsent> read();

  /// Records an answer.
  ///
  /// [SearchConsent.unanswered] is not writable, and that is deliberate: a
  /// Customer cannot become un-asked. SC-015 says the question appears zero
  /// times after any answer, and a code path that could restore the unanswered
  /// state is a code path that could ask again.
  Future<void> write(SearchConsent consent);
}

/// The device's own storage.
class DeviceSearchConsentStore implements SearchConsentStore {
  /// Creates a store.
  const DeviceSearchConsentStore();

  /// Namespaced, because this device holds one Kafoo answer and may hold
  /// anything else. Never renamed — a renamed key is a Customer being asked a
  /// question they already answered.
  static const String _key = 'kafoo.search_consent';

  static const String _granted = 'granted';
  static const String _refused = 'refused';

  @override
  Future<SearchConsent> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return switch (prefs.getString(_key)) {
        _granted => SearchConsent.granted,
        _refused => SearchConsent.refused,
        // Anything else — absent, or a value from a version that wrote
        // something different — is unanswered. Reading an unrecognised value as
        // `granted` would send a Customer's words on the strength of a string
        // nobody can account for.
        _ => SearchConsent.unanswered,
      };
    } on Object catch (_) {
      // `on Object`, not `on Exception`: a missing plugin surfaces as a
      // TypeError and an uninitialised binding as a StateError, and both have
      // stranded a screen in this repository before. Failing to read is
      // unanswered, which asks the question again — the safe direction, because
      // the other one sends words on the strength of a failed read.
      return SearchConsent.unanswered;
    }
  }

  @override
  Future<void> write(SearchConsent consent) async {
    final value = switch (consent) {
      SearchConsent.granted => _granted,
      SearchConsent.refused => _refused,
      SearchConsent.unanswered => null,
    };
    if (value == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value);
    } on Object catch (_) {
      // A write that fails means the question is asked again next time, which is
      // an annoyance. Crashing a Customer out of search would be worse.
    }
  }
}

@riverpod
SearchConsentStore searchConsentStore(Ref ref) =>
    const DeviceSearchConsentStore();

/// The answer, and the two ways it changes: answering the question at the first
/// search, and the Settings switch afterwards.
@riverpod
class SearchConsentController extends _$SearchConsentController {
  @override
  Future<SearchConsent> build() => ref.read(searchConsentStoreProvider).read();

  /// Records an answer and publishes it.
  ///
  /// Optimistic on purpose: the answer is what the Customer just said, and the
  /// disk write is bookkeeping. Waiting for the write would leave the switch
  /// showing the old position while a platform channel finishes.
  Future<void> answer(SearchConsent consent) async {
    if (consent == SearchConsent.unanswered) return;
    state = AsyncData(consent);
    await ref.read(searchConsentStoreProvider).write(consent);
  }
}
