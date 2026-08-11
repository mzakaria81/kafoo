import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_domain/domain.dart';

import 'support/fake_meal_repository.dart';

/// THE ROW THE DATABASE ACTUALLY RETURNS, AND THE CRASH IT CAUSED.
///
/// On 2026-08-11 the founder created his Kitchen Profile, started his first Meal,
/// answered the dish name, typed the description and was told «مقدرناش نحفظ
/// الأكلة» — we could not save the Meal. The Meal WAS saved. Postgres had
/// written the description before the app decided the write had failed.
///
/// `updateDraft` sent the UPDATE, read the row back, and parsed it with a mapper
/// that cast `cuisine` and `category` to non-null `String`. A draft has neither:
/// `allow_incomplete_meal_drafts` dropped NOT NULL from all five conversation
/// answers precisely so a Cook who walks away halfway leaves a draft behind. The
/// cast threw `Null is not a subtype of String`, `on Object catch` turned that
/// into a save failure, and the Cook was told the opposite of the truth.
///
/// It happened on the SECOND QUESTION, every time, for every Cook. Nothing in
/// the repository was conditional; the second answer was simply the first write
/// that read a row back.
///
/// **Why no test saw it, which is the part worth keeping.** `FakeMealRepository`
/// invented what the Cook had not answered — `Cuisine.egyptian`,
/// `MealCategory.main`, a price of `'0'`, an empty description — so every test in
/// this directory ran against a row `meals` cannot produce. The fake was easier
/// to satisfy than the database, and a fake like that converts a red test into a
/// green one.
///
/// The row below is not written from memory. It was produced by inserting a
/// draft and updating its description on a real Postgres with this repository's
/// migrations applied, then selecting the repository's own column list.
const _draftAfterDescription = <String, dynamic>{
  'id': '69d0e03e-ffba-4d41-8a43-f63ea85d18e7',
  'cook_id': '7a38f558-6998-444f-99ca-a56ee528894c',
  'title': 'كشري',
  'description': 'عدس ورز ومكرونة',
  'price': null,
  'cuisine': null,
  'category': null,
  'status': 'draft',
  'ingredients': <String>[],
  'calories': null,
  'allergens': <String>[],
  'nutrition_source': 'ai',
  'photo_path': null,
  'created_at': '2026-08-11T03:47:39.338583+00:00',
  'updated_at': '2026-08-11T03:47:39.338583+00:00',
  'published_at': null,
};

void main() {
  group('the row a half-answered draft returns', () {
    test('parses without throwing', () {
      // The whole defect in one assertion. The deleted mapper threw here.
      expect(
        () => CookMeal.fromRow(_draftAfterDescription),
        returnsNormally,
        reason: 'Every write in the Meal conversation reads its row back. A '
            'mapper that cannot represent an unanswered question turns a '
            'successful save into a reported failure.',
      );
    });

    test('keeps unanswered questions unanswered', () {
      final meal = CookMeal.fromRow(_draftAfterDescription);

      expect(meal.title, 'كشري');
      expect(meal.description, 'عدس ورز ومكرونة');
      // Null, NOT a default. A cuisine invented here would be written to the
      // database by the next approval and presented to a Customer as the Cook's
      // own answer — and «مصري» is right often enough that nobody would notice
      // the times it is wrong.
      expect(meal.cuisine, isNull);
      expect(meal.category, isNull);
      // Null rather than the string "null", which is what `price.toString()` on
      // an absent price produced in the deleted mapper.
      expect(meal.price, isNull);
      expect(meal.isComplete, isFalse);
      expect(meal.asMeal, isNull);
    });
  });

  group('the fake answers with the shape the database answers with', () {
    // A fake that fills in what the Cook has not said is the reason a crash on
    // every Cook's second question shipped with a green gate. These assertions
    // are about the test double, deliberately: it is the thing that lied.

    test('a fresh draft carries only what was written to it', () async {
      final repo = FakeMealRepository();

      final result = await repo.updateDraft(
        mealId: 'm1',
        description: 'عدس ورز ومكرونة',
      );

      final draft = switch (result) {
        Success(value: final meal) => meal,
        Failure() => fail('the write should have succeeded'),
      };

      expect(draft.description, 'عدس ورز ومكرونة');
      expect(draft.title, isNull, reason: 'not answered through this fake');
      expect(draft.cuisine, isNull);
      expect(draft.category, isNull);
      expect(draft.price, isNull);
      expect(draft.isComplete, isFalse);
    });

    test('answers accumulate the way successive writes do', () async {
      final repo = FakeMealRepository();

      await repo.updateDraft(mealId: 'm1', title: 'كشري');
      await repo.updateDraft(mealId: 'm1', description: 'عدس ورز');
      final third = await repo.updateDraft(mealId: 'm1', price: '35');

      final draft = switch (third) {
        Success(value: final meal) => meal,
        Failure() => fail('the write should have succeeded'),
      };

      expect(draft.title, 'كشري');
      expect(draft.description, 'عدس ورز');
      expect(draft.price, '35');
      // Still not complete: cuisine and category come from the estimates the
      // Cook approves, or from the fallback questions. Until then this row
      // cannot leave draft, and the database is what says so.
      expect(draft.isComplete, isFalse);
    });
  });
}
