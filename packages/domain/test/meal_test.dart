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
}
