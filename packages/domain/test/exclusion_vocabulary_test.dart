import 'package:kafoo_domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('ExclusionVocabulary.all', () {
    test('is not empty — an empty vocabulary understands nobody', () {
      // The list shipped empty with the type, deliberately, so the shape was
      // fixed before anything depended on it. While it stays empty every phrase
      // a Customer says reports not-understood, which is safe and useless.
      expect(ExclusionVocabulary.all, isNotEmpty);
    });

    test('every exclusion has at least one way of being written', () {
      for (final exclusion in ExclusionVocabulary.all) {
        expect(exclusion.surfaceForms, isNotEmpty,
            reason: '${exclusion.id} can never be matched by anything');
      }
    });

    test('ids are unique', () {
      final ids = ExclusionVocabulary.all.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('no surface form belongs to two exclusions', () {
      // A form claimed twice makes the lookup order decide which exclusion a
      // Customer gets, and the order of a list is not a decision anyone made.
      final owners = <String, String>{};
      for (final exclusion in ExclusionVocabulary.all) {
        for (final form in exclusion.surfaceForms) {
          expect(owners.containsKey(form), isFalse,
              reason:
                  '"$form" is claimed by both ${owners[form]} and ${exclusion.id}');
          owners[form] = exclusion.id;
        }
      }
    });

    test('every surface form finds its own exclusion', () {
      // The forms are what reach the database as exclude_terms, so a form that
      // does not round-trip through the lookup is a word a Customer can say and
      // Kafoo will not act on.
      for (final exclusion in ExclusionVocabulary.all) {
        for (final form in exclusion.surfaceForms) {
          final outcome = ExclusionVocabulary.lookUp(form);
          expect(outcome, isA<ExclusionFound>(),
              reason: '"$form" was not found');
          expect((outcome as ExclusionFound).exclusion.id, exclusion.id);
        }
      }
    });
  });

  group('ExclusionVocabulary.parse', () {
    test('a phrase with no negation marker excludes nothing', () {
      expect(ExclusionVocabulary.parse('عايز حاجة سخنة'), isA<NoExclusion>());
      expect(ExclusionVocabulary.parse(''), isA<NoExclusion>());
    });

    test('a recognised food after a marker is found', () {
      final outcome = ExclusionVocabulary.parse('عايز أكل من غير لحمة');
      expect(outcome, isA<ExclusionFound>());
      expect((outcome as ExclusionFound).exclusion.id, 'meat');
    });

    test('the longest marker wins', () {
      // 'من غير ما يكون فيه' contains 'من غير'. Matching the shorter one first
      // takes "ما يكون فيه لحمة" as the food, which is not a food — so Kafoo
      // would report not-understood on a phrase it handles.
      final outcome = ExclusionVocabulary.parse('أكل من غير ما يكون فيه لحمة');
      expect(outcome, isA<ExclusionFound>());
      expect((outcome as ExclusionFound).exclusion.id, 'meat');
    });

    test('words after the food do not defeat the match', () {
      // The measured phrase. 'خالص' is an intensifier, not part of the food.
      final outcome = ExclusionVocabulary.parse('أكل من غير لحمة خالص');
      expect(outcome, isA<ExclusionFound>());
      expect((outcome as ExclusionFound).exclusion.id, 'meat');
    });

    test('a food written as two words is matched as two words', () {
      final outcome = ExclusionVocabulary.parse('من غير فول سوداني');
      expect(outcome, isA<ExclusionFound>());
      expect((outcome as ExclusionFound).exclusion.id, 'peanut');
    });

    test('a marker with a food Kafoo does not know says so', () {
      // THE DANGEROUS CASE. The Customer said "without X" and Kafoo does not
      // know X. Returning results as though nothing had been excluded is the
      // failure this whole type exists to prevent.
      final outcome = ExclusionVocabulary.parse('من غير كافيار');
      expect(outcome, isA<ExclusionNotUnderstood>());
      expect((outcome as ExclusionNotUnderstood).phrase, 'كافيار');
    });

    test('a marker with nothing after it is not understood, never nothing', () {
      // "من غير" and then silence — a truncated recording, a cut-off sentence.
      // It is still a Customer who asked to exclude something.
      expect(ExclusionVocabulary.parse('عايز أكل من غير'),
          isA<ExclusionNotUnderstood>());
    });

    test('every marker is usable, not just the first', () {
      for (final marker in ExclusionVocabulary.negationMarkers) {
        final outcome = ExclusionVocabulary.parse('$marker لحمة');
        expect(outcome, isA<ExclusionFound>(),
            reason: '"$marker لحمة" was not understood');
      }
    });
  });
}
