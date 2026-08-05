import 'package:kafoo_domain/meal.dart';
import 'package:kafoo_domain/meal_analysis.dart';
import 'package:test/test.dart';

/// Every legal and illegal lifecycle transition from
/// `specs/003-meal-publishing/data-model.md`, proven without a database.
///
/// These do not replace the pgTAP suites. The database is what actually stops
/// a hostile client; this is what stops Kafoo's own code from asking. Both
/// exist because the two failure modes are different.
void main() {
  group('MealStatus.canTransitionTo', () {
    test('a draft goes on offer', () {
      expect(MealStatus.draft.canTransitionTo(MealStatus.published), isTrue);
    });

    test('a draft goes nowhere else — it is not on a menu to be taken off', () {
      expect(MealStatus.draft.canTransitionTo(MealStatus.unavailable), isFalse);
      expect(MealStatus.draft.canTransitionTo(MealStatus.archived), isFalse);
    });

    test('published and unavailable swap freely — this is what a menu is', () {
      expect(
        MealStatus.published.canTransitionTo(MealStatus.unavailable),
        isTrue,
      );
      expect(
        MealStatus.unavailable.canTransitionTo(MealStatus.published),
        isTrue,
      );
    });

    test('anything on offer can be retired', () {
      expect(MealStatus.published.canTransitionTo(MealStatus.archived), isTrue);
      expect(
        MealStatus.unavailable.canTransitionTo(MealStatus.archived),
        isTrue,
      );
    });

    test('a retired Meal never returns to offer, by any route', () {
      for (final next in MealStatus.values) {
        if (next == MealStatus.archived) continue;
        expect(
          MealStatus.archived.canTransitionTo(next),
          isFalse,
          reason: 'archived must not reach ${next.name}',
        );
      }
    });

    test('nothing goes back to draft once it has left', () {
      for (final from in MealStatus.values) {
        if (from == MealStatus.draft) continue;
        expect(
          from.canTransitionTo(MealStatus.draft),
          isFalse,
          reason: '${from.name} must not reach draft',
        );
      }
    });

    test('staying put is allowed — an edit is not a transition failure', () {
      for (final status in MealStatus.values) {
        expect(status.canTransitionTo(status), isTrue);
      }
    });
  });

  group('who can read what', () {
    test('only a published Meal is readable by anyone but its Cook', () {
      expect(MealStatus.published.isPubliclyReadable, isTrue);
      expect(MealStatus.draft.isPubliclyReadable, isFalse);
      expect(MealStatus.unavailable.isPubliclyReadable, isFalse);
      expect(MealStatus.archived.isPubliclyReadable, isFalse);
    });

    test('only a draft can be deleted — anything on offer is archived', () {
      expect(MealStatus.draft.isDeletable, isTrue);
      expect(MealStatus.published.isDeletable, isFalse);
      expect(MealStatus.unavailable.isDeletable, isFalse);
      expect(MealStatus.archived.isDeletable, isFalse);
    });
  });

  group('NutritionSource', () {
    test('an AI estimate must be labelled one even after a Cook approves it',
        () {
      expect(NutritionSource.ai.mustBeLabelledAnEstimate, isTrue);
    });

    test("a figure the Cook set is the Cook's, and carries no estimate label",
        () {
      expect(NutritionSource.cook.mustBeLabelledAnEstimate, isFalse);
    });

    test('an unknown wire value is an error rather than a silent default', () {
      expect(
        () => NutritionSource.fromWireName('verified'),
        throwsArgumentError,
      );
    });
  });

  group('wire names round-trip', () {
    test('every status survives a trip through the database representation',
        () {
      for (final status in MealStatus.values) {
        expect(MealStatus.fromWireName(status.wireName), status);
      }
    });

    test('an unknown status is an error rather than a silent draft', () {
      expect(() => MealStatus.fromWireName('deleted'), throwsArgumentError);
    });

    test('a cuisine outside the fixed set resolves to null, not to other', () {
      expect(Cuisine.tryFromWireName('egyptian'), Cuisine.egyptian);
      expect(Cuisine.tryFromWireName('martian'), isNull);
    });

    test('a category outside the fixed set resolves to null, not to other', () {
      expect(MealCategory.tryFromWireName('main'), MealCategory.main);
      expect(MealCategory.tryFromWireName('brunch'), isNull);
    });
  });

  group('MealDraft.isComplete', () {
    MealDraft filledDraft() => MealDraft()
      ..title = 'كشري'
      ..description = 'كشري بالعدس والحمص، وصفة ماما'
      ..price = '75.00'
      ..cuisine = Cuisine.egyptian
      ..category = MealCategory.main;

    test('a Cook can offer food without a photo, calories or allergens', () {
      final draft = filledDraft();

      expect(draft.isComplete, isTrue);
      expect(draft.photoPath, isNull);
      expect(draft.calories, isNull);
      expect(draft.allergens, isEmpty);
    });

    test('a blank answer does not count as an answer', () {
      final draft = filledDraft()..title = '   ';

      expect(draft.isComplete, isFalse);
    });

    test('every required value is actually required', () {
      expect((filledDraft()..title = null).isComplete, isFalse);
      expect((filledDraft()..description = null).isComplete, isFalse);
      expect((filledDraft()..price = null).isComplete, isFalse);
      expect((filledDraft()..cuisine = null).isComplete, isFalse);
      expect((filledDraft()..category = null).isComplete, isFalse);
    });
  });

  group('a suggestion is not a Meal', () {
    test('an empty analysis has nothing for a Cook to approve', () {
      const analysis = MealAnalysis.empty();

      expect(analysis.isEmpty, isTrue);
      expect(analysis.usedPhoto, isFalse);
    });

    test('a suggestion carries the basis the Cook is shown', () {
      const analysis = MealAnalysis(
        cuisine: MealSuggestion(
          value: Cuisine.egyptian,
          basis: 'الكشري طبق مصري',
        ),
      );

      expect(analysis.isNotEmpty, isTrue);
      expect(analysis.cuisine!.basis, isNotEmpty);
    });
  });

  group('isLastMealOnOffer', () {
    const _meal = CookMeal(
      id: 'm1',
      cookId: 'c1',
      title: 'كشري',
      description: 'عدس ورز',
      price: '35',
      cuisine: Cuisine.egyptian,
      category: MealCategory.main,
      status: MealStatus.published,
      nutritionSource: NutritionSource.ai,
    );

    test('true when the Meal is the only published one', () {
      expect(isLastMealOnOffer([_meal], _meal), isTrue);
    });

    test('false when the Cook has two published Meals', () {
      const other = CookMeal(
        id: 'm2',
        cookId: 'c1',
        title: 'محشي',
        description: 'ورق عنب',
        price: '50',
        cuisine: Cuisine.egyptian,
        category: MealCategory.main,
        status: MealStatus.published,
        nutritionSource: NutritionSource.ai,
      );

      expect(isLastMealOnOffer([_meal, other], _meal), isFalse);
    });

    test('false when the Meal is already unavailable', () {
      const unavailable = CookMeal(
        id: 'm1',
        cookId: 'c1',
        title: 'كشري',
        description: 'عدس ورز',
        price: '35',
        cuisine: Cuisine.egyptian,
        category: MealCategory.main,
        status: MealStatus.unavailable,
        nutritionSource: NutritionSource.ai,
      );

      expect(isLastMealOnOffer([unavailable], unavailable), isFalse);
    });

    test('false for an empty list', () {
      expect(isLastMealOnOffer([], _meal), isFalse);
    });

    test('false when the Meal id is not in the list', () {
      const other = CookMeal(
        id: 'm2',
        cookId: 'c1',
        title: 'محشي',
        description: 'ورق عنب',
        price: '50',
        cuisine: Cuisine.egyptian,
        category: MealCategory.main,
        status: MealStatus.published,
        nutritionSource: NutritionSource.ai,
      );

      expect(isLastMealOnOffer([other], _meal), isFalse);
    });
  });

  group('CookMeal', () {
    const complete = CookMeal(
      id: 'm1',
      cookId: 'c1',
      title: 'كشري',
      description: 'عدس ورز',
      price: '35',
      cuisine: Cuisine.egyptian,
      category: MealCategory.main,
      status: MealStatus.published,
      nutritionSource: NutritionSource.ai,
      ingredients: ['عدس', 'رز'],
      allergens: ['جلوتين'],
      calories: 520,
      photoPath: 'c1/m1.jpg',
    );

    test('a complete CookMeal yields a Meal whose every field matches', () {
      final meal = complete.asMeal;
      expect(meal, isNotNull);
      expect(meal!.id, complete.id);
      expect(meal.cookId, complete.cookId);
      expect(meal.title, complete.title);
      expect(meal.description, complete.description);
      expect(meal.price, complete.price);
      expect(meal.cuisine, complete.cuisine);
      expect(meal.category, complete.category);
      expect(meal.status, complete.status);
      expect(meal.nutritionSource, complete.nutritionSource);
      expect(meal.ingredients, complete.ingredients);
      expect(meal.allergens, complete.allergens);
      expect(meal.calories, complete.calories);
      expect(meal.photoPath, complete.photoPath);
      expect(meal.publishedAt, complete.publishedAt);
      expect(complete.isComplete, isTrue);
    });

    test('missing description is incomplete and asMeal is null', () {
      const missing = CookMeal(
        id: 'm1',
        cookId: 'c1',
        title: 'كشري',
        price: '35',
        cuisine: Cuisine.egyptian,
        category: MealCategory.main,
        status: MealStatus.draft,
        nutritionSource: NutritionSource.ai,
      );
      expect(missing.isComplete, isFalse);
      expect(missing.asMeal, isNull);
    });

    test('missing price is incomplete and asMeal is null', () {
      const missing = CookMeal(
        id: 'm1',
        cookId: 'c1',
        title: 'كشري',
        description: 'عدس ورز',
        cuisine: Cuisine.egyptian,
        category: MealCategory.main,
        status: MealStatus.draft,
        nutritionSource: NutritionSource.ai,
      );
      expect(missing.isComplete, isFalse);
      expect(missing.asMeal, isNull);
    });

    test('missing cuisine is incomplete and asMeal is null', () {
      const missing = CookMeal(
        id: 'm1',
        cookId: 'c1',
        title: 'كشري',
        description: 'عدس ورز',
        price: '35',
        category: MealCategory.main,
        status: MealStatus.draft,
        nutritionSource: NutritionSource.ai,
      );
      expect(missing.isComplete, isFalse);
      expect(missing.asMeal, isNull);
    });

    test('missing category is incomplete and asMeal is null', () {
      const missing = CookMeal(
        id: 'm1',
        cookId: 'c1',
        title: 'كشري',
        description: 'عدس ورز',
        price: '35',
        cuisine: Cuisine.egyptian,
        status: MealStatus.draft,
        nutritionSource: NutritionSource.ai,
      );
      expect(missing.isComplete, isFalse);
      expect(missing.asMeal, isNull);
    });

    test('a published CookMeal is complete', () {
      expect(complete.status, MealStatus.published);
      expect(complete.isComplete, isTrue);
      expect(complete.asMeal, isNotNull);
    });
  });
}
