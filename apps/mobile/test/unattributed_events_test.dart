// Which events carry a person, and which never do.
//
// The production path writes `person_id` inside a Supabase insert that no test
// can observe — `debugEventRecorder` short-circuits before it. So the decision
// is pulled out into `isUnattributed`, and this asserts the decision rather than
// the insert. That is the whole reason it is a named predicate and not an
// inline ternary.

import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_mobile/features/analytics/emit_event.dart';
import 'package:kafoo_mobile/features/analytics/event_names.dart';

void main() {
  group('discovery is never attributed to a person', () {
    // Asserted as a SET, not one by one. A new discovery event added to
    // EventNames without being added to the unattributed set is the failure this
    // exists to catch, and a per-event test would pass while missing it.
    const discovery = <String>{
      EventNames.searchPerformed,
      EventNames.searchFailed,
      EventNames.recommendationAccepted,
      EventNames.mealOpened,
    };

    test('every discovery event is unattributed', () {
      for (final name in discovery) {
        expect(isUnattributed(name), isTrue,
            reason: '$name would be written with the signed-in person id, '
                'which builds a per-Customer record of what they like — '
                'docs/product/business-questions.md refuses exactly that');
      }
    });

    test('a Cook event is still attributed, and that is deliberate', () {
      // "Do Cooks who publish once publish again?" is a per-Cook question by
      // design and cannot be answered without the join. The rule is about
      // Customers' taste, not about turning attribution off everywhere.
      for (final name in [
        EventNames.mealPublished,
        EventNames.mealDrafted,
        EventNames.kitchenProfileCreated,
        EventNames.conversationStepCompleted,
      ]) {
        expect(isUnattributed(name), isFalse, reason: '$name');
      }
    });

    test('the set is exactly discovery — nothing has crept in', () {
      // Guards the other direction. Silently unattributing a Cook event would
      // break a funnel nobody is watching, and would look like a privacy
      // improvement while doing it.
      final all = <String>[
        EventNames.accountCreated,
        EventNames.accountRemoved,
        EventNames.kitchenProfileCreated,
        EventNames.mealPublished,
        EventNames.mealArchived,
        EventNames.signInStarted,
        EventNames.signInCompleted,
        EventNames.signInFailed,
        EventNames.conversationStarted,
        EventNames.conversationStepCompleted,
        EventNames.conversationCompleted,
        EventNames.mealDrafted,
        EventNames.mealUpdated,
        ...discovery,
      ];
      expect(
        all.where(isUnattributed).toSet(),
        discovery,
        reason: 'only discovery may be unattributed',
      );
    });
  });
}
