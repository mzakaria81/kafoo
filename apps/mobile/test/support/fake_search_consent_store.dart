import 'dart:async';

import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/settings/data/search_consent_store.dart';

/// The device's storage, without a device.
///
/// It keeps the answer in a field rather than throwing it away, so a test can
/// build the app twice against the same instance and get the same answer — which
/// is what "asked once, across a restart" actually means (SC-015). A fake that
/// forgot between builds would make the question reappear and the test would be
/// asserting the opposite of the requirement.
class FakeSearchConsentStore implements SearchConsentStore {
  /// Creates a store, optionally already holding an answer.
  FakeSearchConsentStore([this.stored = SearchConsent.unanswered]);

  /// What is on the device.
  SearchConsent stored;

  /// Every answer written, so a test can prove the device was written to once
  /// and never with [SearchConsent.unanswered].
  final List<SearchConsent> writes = <SearchConsent>[];

  /// When true, [read] never completes — the state in which nothing has been
  /// answered and nothing may be sent.
  bool hold = false;

  @override
  Future<SearchConsent> read() async {
    if (hold) await Completer<void>().future;
    return stored;
  }

  @override
  Future<void> write(SearchConsent consent) async {
    writes.add(consent);
    stored = consent;
  }
}
