import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Receives an event instead of the database. Test seam only.
typedef EventRecorder = void Function(
    String name, Map<String, Object> attributes);

/// When set, events go here instead of to Supabase.
///
/// This exists because event ATTRIBUTES are constitutional and, until it did, none of them were
/// testable. `emitEvent` wrote directly to `Supabase.instance.client`, so a widget test had no way
/// to observe what was emitted — and consequently not one test in this repository asserted an
/// attribute. That was found on 2026-08-03 by deleting `speech_locale` from a call site and
/// watching the whole suite stay green, including a test group named after it.
///
/// Attribute correctness is not a detail: `docs/product/event-model.md` is a source of truth that
/// funnels and product decisions are read off, and an event carrying the wrong attribute is a
/// measurement that lies rather than one that fails.
///
/// Production never sets this. Tests set it in `setUp` and null it in `tearDown`.
@visibleForTesting
EventRecorder? debugEventRecorder;

// FR-037: events record WHICH step, never WHAT was said. The guard below
// catches the most obvious violations — any string attribute longer than 100
// characters is almost certainly free text from a person. The primary
// enforcement is at call sites; this is the safety net.
const _maxAttributeStringLength = 100;

/// Records that a named event occurred, writing to [analytics_events].
///
/// Fails silently: a measurement outage must never interrupt a Cook's flow.
/// Call sites use [unawaited] so the absence of `await` is intentional, not
/// an oversight.
Future<void> emitEvent(
  String name, {
  Map<String, Object> attributes = const {},
}) async {
  // Drop the event silently if any attribute value looks like free text.
  for (final value in attributes.values) {
    if (value is String && value.length > _maxAttributeStringLength) {
      return;
    }
  }

  // Deliberately AFTER the free-text guard above, so a test observes exactly what production would
  // have written — including an event the guard drops.
  final recorder = debugEventRecorder;
  if (recorder != null) {
    recorder(name, attributes);
    return;
  }

  try {
    await Supabase.instance.client.from('analytics_events').insert({
      'name': name,
      'person_id': Supabase.instance.client.auth.currentUser?.id,
      'attributes': attributes,
    });
  } on Object catch (_) {
    // Measurement outage must never break a Cook's flow. This catches Error as
    // well as Exception deliberately: an uninitialised client throws a
    // StateError, and losing an event is always preferable to losing the Cook.
  }
}
