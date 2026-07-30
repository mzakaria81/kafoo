import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

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

  try {
    await Supabase.instance.client.from('analytics_events').insert({
      'name': name,
      'person_id': Supabase.instance.client.auth.currentUser?.id,
      'attributes': attributes,
    });
  } on Exception catch (_) {
    // Measurement outage must never break a Cook's flow.
  }
}
