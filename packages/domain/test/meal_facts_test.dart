import 'package:kafoo_domain/domain.dart';
import 'package:test/test.dart';

void main() {
  // ADR-0015. `meal_step_test.dart` guards the old rule — four questions, in
  // order. These guard the new one: five required facts, and NO order at all.
  //
  // The order is the thing being deleted, so it is the thing worth a test. A
  // set that quietly comes back sorted is a script wearing a set's clothes, and
  // the next person to read it will build a wizard from it in good faith.

  test('a blank draft is missing all five facts, and never the photo', () {
    final missing = mealFactsMissing(
      dish: null,
      description: null,
      price: null,
      cuisine: null,
      category: null,
    );

    expect(missing, hasLength(5));
    expect(missing, equals(MealFact.values.toSet()));
    expect(
      MealFact.values.map((f) => f.wireName),
      isNot(contains('photo')),
      reason: 'A photo is optional and never blocks publishing. Naming it as a '
          'missing fact is how an assistant starts nagging a Cook who already '
          'declined to send one (FR-029).',
    );
  });

  test('a fact the Cook supplied is not missing', () {
    final missing = mealFactsMissing(
      dish: 'محشي ورق عنب',
      description: 'محشي بورق عنب وأرز ولحمة مفرومة',
      price: '١٢٠',
      cuisine: Cuisine.egyptian,
      category: MealCategory.main,
    );

    expect(missing, isEmpty);
  });

  test('whitespace is not an answer', () {
    final missing = mealFactsMissing(
      dish: '   ',
      description: 'محشي بورق عنب',
      price: '',
      cuisine: Cuisine.egyptian,
      category: MealCategory.main,
    );

    expect(missing, equals({MealFact.dish, MealFact.price}));
  });

  test('the result carries no order — only membership', () {
    // Two drafts missing the same two facts, reached from opposite directions.
    // If the returned collection ever gains a meaningful first element, one of
    // these orderings will differ and this fails.
    final a = mealFactsMissing(
      dish: null,
      description: 'كلام',
      price: null,
      cuisine: Cuisine.egyptian,
      category: MealCategory.main,
    );
    final b = mealFactsMissing(
      dish: null,
      description: 'كلام',
      price: null,
      cuisine: Cuisine.egyptian,
      category: MealCategory.main,
    );

    expect(a, equals(b));
    expect(a, isA<Set<MealFact>>());
    expect(
      () => (a as dynamic).add(MealFact.dish),
      throwsUnsupportedError,
      reason: 'The set is the assistant\'s view of what is missing. A caller '
          'that can mutate it can invent a requirement the database does not '
          'have.',
    );
  });

  test('an unapproved estimate is not a fact the Meal has', () {
    // The model may have guessed a cuisine. Until the Cook approves it, it is
    // not on the draft, so it is still missing. This is the approval step seen
    // from the domain layer, and ADR-0015 does not move it.
    final missing = mealFactsMissing(
      dish: 'كشري',
      description: 'كشري بالعدس والمكرونة',
      price: '٥٠',
      cuisine: null,
      category: null,
    );

    expect(missing, equals({MealFact.cuisine, MealFact.category}));
  });
}
