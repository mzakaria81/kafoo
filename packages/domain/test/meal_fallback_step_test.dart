import 'package:kafoo_domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test('wireName is stable for each MealFallbackStepId', () {
    expect(MealFallbackStepId.cuisine.wireName, 'cuisine');
    expect(MealFallbackStepId.category.wireName, 'category');
  });

  test('fallback order is cuisine then category then null', () {
    expect(
      nextUnansweredMealFallbackStep(
        cuisineNeeded: true,
        categoryNeeded: true,
      ),
      MealFallbackStepId.cuisine,
    );
    expect(
      nextUnansweredMealFallbackStep(
        cuisineNeeded: false,
        categoryNeeded: true,
      ),
      MealFallbackStepId.category,
    );
    expect(
      nextUnansweredMealFallbackStep(
        cuisineNeeded: false,
        categoryNeeded: false,
      ),
      isNull,
    );
  });

  test('only category needed skips cuisine', () {
    expect(
      nextUnansweredMealFallbackStep(
        cuisineNeeded: false,
        categoryNeeded: true,
      ),
      MealFallbackStepId.category,
    );
  });

  test('only cuisine needed does not ask category', () {
    expect(
      nextUnansweredMealFallbackStep(
        cuisineNeeded: true,
        categoryNeeded: false,
      ),
      MealFallbackStepId.cuisine,
    );
  });
}
