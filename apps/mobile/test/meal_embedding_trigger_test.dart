import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_mobile/features/meal/data/meal_repository.dart';

void main() {
  group('what makes a Meal worth re-embedding', () {
    // A Meal's vector represents WHAT THE FOOD IS. Re-embedding on anything else spends a model
    // call and moves the Meal's ranking for a change no Customer could perceive — and on a Cook
    // saving repeatedly while deciding a price, it does it over and over.
    //
    // The rule is a named function rather than a condition inside `updateDraft` so this test can
    // exist at all. Without it, "re-embed on every save" is a one-line simplification that looks
    // tidier and costs money quietly.

    test('changing the words counts', () {
      expect(
        SupabaseMealRepository.changesWhatTheFoodIs(title: 'كشري بلدي'),
        isTrue,
      );
      expect(
        SupabaseMealRepository.changesWhatTheFoodIs(
            description: 'عدس ورز ومكرونة'),
        isTrue,
      );
      expect(
        SupabaseMealRepository.changesWhatTheFoodIs(
          title: 'كشري',
          description: 'عدس',
        ),
        isTrue,
      );
    });

    test('an edit that touches neither does not count', () {
      // The call site passes only title and description, so everything else — price, photo,
      // cuisine, calories, allergens — arrives here as two nulls. That is the case this asserts.
      expect(SupabaseMealRepository.changesWhatTheFoodIs(), isFalse);
      expect(
        SupabaseMealRepository.changesWhatTheFoodIs(
            title: null, description: null),
        isFalse,
      );
    });

    test('an empty string is a change, not an absence', () {
      // A Cook clearing a description has changed what the food is described as. Treating '' as
      // "unchanged" would leave the Meal findable by words the Cook has just deleted.
      expect(
          SupabaseMealRepository.changesWhatTheFoodIs(description: ''), isTrue);
    });
  });
}
