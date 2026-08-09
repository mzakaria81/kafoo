import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'event_names.dart';

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

/// Events that NEVER carry a person, whoever happens to be signed in.
///
/// **Discovery is not attributed, and the guard is here rather than at the call
/// sites for the same reason the consent gate sits on the funnel: call sites
/// keep being added, and the one that forgets is invisible.**
///
/// What made this necessary. `SearchPerformed` carried `result_count` — a number
/// that says a search happened and nothing about the person — and on 2026-08-08
/// it gained `top_cuisine` and `top_category`, and `MealOpened` arrived carrying
/// `cuisine` and `category`. Every event here is written with
/// `auth.currentUser?.id`, and in the app there is nearly always a current user.
/// So the change quietly created, for the first time, an ordered per-person
/// record of what kind of food a Customer looks for and what they open.
///
/// `docs/product/business-questions.md` had said the day before that Kafoo never
/// builds that picture — "there is **usually** no person to attach anything to".
/// The word "usually" was doing the work: true on the web, which holds no
/// session, and false in the app, which is the binary that ships. Found by
/// trust-reviewer.
///
/// Not one question that instrumentation was added to answer needs the join.
/// Every demand question in that document is aggregate, and Privacy rule 1 is to
/// collect only what a named feature needs today.
///
/// **The Cook's events are deliberately NOT here.** "Do Cooks who publish once
/// publish again?" is a per-Cook question by design, and answering it requires
/// the join.
const _unattributedEvents = <String>{
  EventNames.searchPerformed,
  EventNames.searchFailed,
  EventNames.recommendationAccepted,
  EventNames.mealOpened,
};

/// Whether [name] is recorded without a person. Exposed so it can be asserted.
@visibleForTesting
bool isUnattributed(String name) => _unattributedEvents.contains(name);

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
      // THE FUNNEL, NOT THE CALL SITES. A discovery event is unattributed even
      // when a Customer is signed in — see [_unattributedEvents].
      'person_id': isUnattributed(name)
          ? null
          : Supabase.instance.client.auth.currentUser?.id,
      'attributes': attributes,
    });
  } on Object catch (_) {
    // Measurement outage must never break a Cook's flow. This catches Error as
    // well as Exception deliberately: an uninitialised client throws a
    // StateError, and losing an event is always preferable to losing the Cook.
  }
}
