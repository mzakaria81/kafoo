import 'package:kafoo_domain/domain.dart';
import 'package:test/test.dart';

void main() {
  // T044: the conversation asks four questions. Everything else a Meal needs —
  // cuisine, category, ingredients, calories, allergens — is inferred by the AI
  // Assistant from those four answers and approved by the Cook at the summary.
  // Each question added here is one the AI Assistant failed to save the Cook,
  // so growing this list is a design decision that needs arguing for, not a
  // routine edit. A doc comment cannot fail a build; this test can.
  //
  // (`meal_step.dart` says "seven values". The meals table has nine Cook-facing
  // columns. The count is loose either way — four questions against everything
  // else is the rule, and that is what this asserts.)
  test(
      'T044: MealStepId has exactly four values — the questions the Cook answers',
      () {
    const values = MealStepId.values;
    expect(
      values,
      hasLength(4),
      reason:
          'MealStepId must have exactly 4 values (dish, description, photo, '
          'price). Cuisine, category, ingredients, calories and allergens are '
          'inferred by the AI Assistant and approved at the summary — asking '
          'the Cook for them instead means the AI Assistant has failed and the '
          'feature needs revisiting rather than shipping.',
    );

    // Name them so the failure message is self-documenting.
    expect(
        values,
        containsAllInOrder([
          MealStepId.dish,
          MealStepId.description,
          MealStepId.photo,
          MealStepId.price,
        ]));
  });

  test('wireName is stable for each MealStepId', () {
    expect(MealStepId.dish.wireName, 'dish');
    expect(MealStepId.description.wireName, 'description');
    expect(MealStepId.photo.wireName, 'photo');
    expect(MealStepId.price.wireName, 'price');
  });

  test('only photo is skippable', () {
    expect(MealStepId.dish.isSkippable, isFalse);
    expect(MealStepId.description.isSkippable, isFalse);
    expect(MealStepId.photo.isSkippable, isTrue);
    expect(MealStepId.price.isSkippable, isFalse);
  });
}
