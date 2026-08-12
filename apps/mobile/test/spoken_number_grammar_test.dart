import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_mobile/l10n/app_localizations_ar.dart';

/// **Arabic counts differently at one, two, three-to-ten and eleven-up, and the
/// noun changes with the number rather than the other way round.**
///
/// The Meal-list greeting said «عندك {total} أكلة» for every count, so a Cook
/// with three Meals was greeted «عندك 3 أكلة» — which is wrong in a way no
/// Egyptian would write and no Egyptian would say. It reached a real screen
/// because every test that touched this sentence used a count in the
/// eleven-and-up range, which is the one range where the singular is correct.
///
/// It matters more out loud than on the page. ADR-0013 makes the screen the
/// receipt of a spoken exchange, so this sentence is read to a Cook who may not
/// read it herself, by a voice she is meant to trust as Cairene.
///
/// The categories below are the CLDR plural categories, and they line up with
/// Arabic grammar exactly: `one` = 1, `two` = 2, `few` = 3–10, `many` = 11–99,
/// `other` = 100 and up. That is why this is an ICU plural rather than a
/// hand-written switch — the rule already exists and `intl` already knows it.
void main() {
  final ar = AppLocalizationsAr();

  // total is never 0: MyMealsState(meals: []) renders MyMealsEmpty, which has
  // its own invitation. published IS 0 whenever every Meal is still a draft.
  String greet(int total, int published) =>
      ar.myMealsSpokenSummary('feminine', total, published);

  group('the greeting counts Meals in Arabic', () {
    test('one Meal is «أكلة واحدة», never «1 أكلة»', () {
      final line = greet(1, 1);
      expect(line, contains('أكلة واحدة'));
      expect(line, isNot(contains('1 أكلة')));
    });

    test(
        'two Meals use the dual «أكلتين», which Arabic has and English does not',
        () {
      expect(greet(2, 2), contains('أكلتين'));
    });

    test('three to ten take the PLURAL «أكلات» — the case that shipped broken',
        () {
      for (final n in [3, 5, 10]) {
        final line = greet(n, 0);
        expect(
          line,
          contains('$n أكلات'),
          reason: '$n Meals must read «$n أكلات»',
        );
        expect(
          line,
          isNot(contains('$n أكلة')),
          reason: 'this is the exact defect: «$n أكلة» is not Arabic',
        );
      }
    });

    test('eleven and up return to the singular «أكلة», which is also Arabic',
        () {
      // The range every previous test used, and the reason nobody saw the bug.
      for (final n in [11, 16, 20, 99]) {
        expect(greet(n, 0), contains('$n أكلة'));
      }
    });

    test('nothing on the menu is said in words, never as «منهم 0»', () {
      final line = greet(5, 0);
      expect(line, contains('مفيش'));
      expect(line, isNot(contains('منهم 0')));
      expect(line, isNot(contains('0 على المنيو')));
    });

    test('one on the menu is «واحدة», not the digit', () {
      final line = greet(5, 1);
      expect(line, contains('منهم واحدة'));
      expect(line, isNot(contains('منهم 1')));
    });

    test('both grammars still exist — a Cook is addressed as she or he', () {
      // ADR-0010. The plural rewrite must not have collapsed the two forms.
      expect(
          ar.myMealsSpokenSummary('feminine', 5, 2), contains('عايزة تعملي'));
      expect(ar.myMealsSpokenSummary('other', 5, 2), contains('عايز تعمل'));
    });
  });
}
