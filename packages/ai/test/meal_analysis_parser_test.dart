import 'package:kafoo_ai/ai.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('parseMealAnalysis', () {
    test('a missing basis drops its field even when the value looks fine', () {
      const reply = '''
{
  "cuisine": "egyptian",
  "category": "main",
  "basis": {
    "category": "ده طبق رئيسي"
  }
}
''';

      final result = parseMealAnalysis(reply);
      final analysis = _success(result);

      expect(analysis.cuisine, isNull);
      expect(analysis.category, isNotNull);
      expect(analysis.category!.value, MealCategory.main);
    });

    test('an out-of-range calorie count is dropped, never clamped', () {
      const reply = '''
{
  "calories": 190000,
  "cuisine": "egyptian",
  "basis": {
    "calories": "رقم عشوائي",
    "cuisine": "كشري"
  }
}
''';

      final result = parseMealAnalysis(reply);
      final analysis = _success(result);

      expect(analysis.calories, isNull);
      expect(analysis.cuisine!.value, Cuisine.egyptian);
    });

    test('a double calorie count is dropped rather than truncated', () {
      const reply = '''
{
  "calories": 850.5,
  "basis": {
    "calories": "تقريبة"
  }
}
''';

      final result = parseMealAnalysis(reply);
      final analysis = _success(result);

      expect(analysis.calories, isNull);
    });

    test('a negative calorie count is dropped', () {
      const reply = '''
{
  "calories": -10,
  "basis": {
    "calories": "سالب"
  }
}
''';

      final result = parseMealAnalysis(reply);
      final analysis = _success(result);

      expect(analysis.calories, isNull);
    });

    test('an unknown cuisine drops that field and never guesses', () {
      const reply = '''
{
  "cuisine": "martian",
  "category": "main",
  "basis": {
    "cuisine": "من كوكب تاني",
    "category": "طبق رئيسي"
  }
}
''';

      final result = parseMealAnalysis(reply);
      final analysis = _success(result);

      expect(analysis.cuisine, isNull);
      expect(analysis.category!.value, MealCategory.main);
    });

    test('non-JSON text is a Failure, not an exception or empty analysis', () {
      final result = parseMealAnalysis('ده مش JSON خالص');

      expect(result, isA<Failure<MealAnalysis, AppError>>());
      final failure = result as Failure<MealAnalysis, AppError>;
      expect(failure.error.messageKey, 'aiMealAnalysisInvalid');
    });

    test('a JSON array is a Failure — the reply must be an object', () {
      final result = parseMealAnalysis('["عدس", "رز"]');

      expect(result, isA<Failure<MealAnalysis, AppError>>());
      final failure = result as Failure<MealAnalysis, AppError>;
      expect(failure.error.messageKey, 'aiMealAnalysisInvalid');
    });

    test('one bad field does not discard the good ones', () {
      const reply = '''
{
  "cuisine": "not-a-real-cuisine",
  "allergens": ["جلوتين", "ألبان"],
  "calories": 900,
  "basis": {
    "cuisine": "تخمين غلط",
    "allergens": "المكرونة واللبن ظاهرين",
    "calories": "طبق كامل"
  }
}
''';

      final result = parseMealAnalysis(reply);
      final analysis = _success(result);

      expect(analysis.cuisine, isNull);
      expect(analysis.allergens, isNotNull);
      expect(analysis.allergens!.value, containsAll(['جلوتين', 'ألبان']));
      expect(analysis.calories!.value, 900);
    });

    test('non-string list entries are dropped; empty survivors drop the field',
        () {
      const reply = '''
{
  "ingredients": [1, null, "", "  "],
  "allergens": ["جلوتين", 42, ""],
  "basis": {
    "ingredients": "مفيش حاجة صلحت",
    "allergens": "القمح ظاهر"
  }
}
''';

      final result = parseMealAnalysis(reply);
      final analysis = _success(result);

      expect(analysis.ingredients, isNull);
      expect(analysis.allergens!.value, ['جلوتين']);
    });

    test('values with no reasons at all is a failure, not a shrug', () {
      // 2026-08-11, THE FOUNDER'S «محشي صغير». The model answered in 2.5 seconds
      // with a 785-byte reply and his screen read «المساعد مقدرش يقدّر حاجة» —
      // the assistant could not estimate anything. Two completely different
      // events wearing one sentence: a model with no opinion, and a model whose
      // answer this product cannot use.
      //
      // Dropping an unexplained value is correct — a calorie count with no reason
      // behind it is one a Cook has no grounds to believe. Reporting it as
      // silence is not: nobody could act on it, and nothing in the logs said it
      // had happened.
      const reply = '''
{
  "ingredients": ["ورق عنب", "أرز"],
  "calories": 320,
  "allergens": [],
  "cuisine": "egyptian",
  "category": "appetizer",
  "basis": {}
}
''';

      final result = parseMealAnalysis(reply, modelId: 'test-model');

      expect(
        result,
        isA<Failure<MealAnalysis, AppError>>(),
        reason: 'THE BUG: this was a Success carrying an empty analysis, which '
            'the summary renders as "the assistant could not estimate '
            'anything" — the one thing that had not happened.',
      );
      expect(
        (result as Failure<MealAnalysis, AppError>).error.messageKey,
        'analyzeMealInvalidResponse',
        reason: 'a provider contract failure, which the Cook now reads as a '
            'sentence instead of inferring from an empty section',
      );
    });

    test('some reasons missing is still a useful answer', () {
      // The rule working rather than failing. Two explained fields reach her;
      // the unexplained one is dropped and the analysis is NOT an error, because
      // there is something here worth her time.
      const reply = '''
{
  "ingredients": ["ورق عنب", "أرز"],
  "calories": 320,
  "cuisine": "egyptian",
  "basis": {
    "ingredients": "من وصف الطباخ",
    "cuisine": "محشي مصري"
  }
}
''';

      final analysis = _success(parseMealAnalysis(reply));

      expect(analysis.isEmpty, isFalse);
      expect(analysis.ingredients?.value, ['ورق عنب', 'أرز']);
      expect(analysis.cuisine?.value, Cuisine.egyptian);
      expect(
        analysis.calories,
        isNull,
        reason: 'filled but unexplained, so dropped — and one dropped field is '
            'not a broken reply',
      );
    });

    test(
        'a well-formed empty reply yields an empty analysis, inventing nothing',
        () {
      const reply = '''
{
  "ingredients": [],
  "calories": null,
  "allergens": [],
  "cuisine": null,
  "category": null,
  "basis": {}
}
''';

      final result = parseMealAnalysis(reply, modelId: 'test-model');
      final analysis = _success(result);

      expect(analysis.isEmpty, isTrue);
      expect(analysis.modelId, 'test-model');
      expect(analysis.usedPhoto, isFalse);
    });

    test('usedPhoto and modelId pass through on a successful parse', () {
      const reply = '''
{
  "cuisine": "egyptian",
  "basis": {
    "cuisine": "كشري"
  }
}
''';

      final result = parseMealAnalysis(
        reply,
        modelId: 'test-model',
        usedPhoto: true,
      );
      final analysis = _success(result);

      expect(analysis.modelId, 'test-model');
      expect(analysis.usedPhoto, isTrue);
      expect(analysis.cuisine!.value, Cuisine.egyptian);
    });

    test('an empty-string basis is treated as missing', () {
      const reply = '''
{
  "cuisine": "egyptian",
  "category": "main",
  "basis": {
    "cuisine": "   ",
    "category": "طبق رئيسي"
  }
}
''';

      final result = parseMealAnalysis(reply);
      final analysis = _success(result);

      expect(analysis.cuisine, isNull);
      expect(analysis.category!.value, MealCategory.main);
    });
  });
}

MealAnalysis _success(Result<MealAnalysis, AppError> result) {
  expect(result, isA<Success<MealAnalysis, AppError>>());
  return (result as Success<MealAnalysis, AppError>).value;
}
