import 'dart:convert';
import 'dart:io';

import 'package:kafoo_ai/ai.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:test/test.dart';

/// Discovers every fixture under `test/goldens/meal_analysis/` and runs it.
///
/// The corpus is files, not a Dart list, so adding a case is adding a file and
/// the runner cannot silently stop covering one that was deleted to go green.
void main() {
  final fixtures = _loadFixtures();

  test('corpus covers the required kinds', () {
    final kinds = fixtures.map((f) => f.kind).toList();
    expect(kinds.where((k) => k == 'typical').length, greaterThanOrEqualTo(3));
    expect(kinds.where((k) => k == 'dialect').length, greaterThanOrEqualTo(2));
    expect(
        kinds.where((k) => k == 'adversarial').length, greaterThanOrEqualTo(1));
    expect(kinds.where((k) => k == 'empty').length, greaterThanOrEqualTo(1));
  });

  test('every adversarial fixture demands non-empty allergens', () {
    for (final fixture in fixtures.where((f) => f.kind == 'adversarial')) {
      expect(
        fixture.expect['allergensNotEmpty'],
        isTrue,
        reason:
            '${fixture.name}: adversarial cases must assert allergensNotEmpty',
      );
    }
  });

  for (final fixture in fixtures) {
    test('golden: ${fixture.name}', () async {
      final provider = StubAiProvider({
        'meal-analysis': fixture.modelReply,
      });
      final request = AiRequest(
        promptId: 'meal-analysis',
        tier: ModelTier.fast,
        variables: {'said': fixture.said},
      );

      final result = await provider.complete(request);
      expect(result, isA<Success<AiResponse, AppError>>());
      final response = (result as Success<AiResponse, AppError>).value;

      // Untrusted Cook text must reach the provider unchanged. Scrubbing it
      // here would hide the injection surface the adversarial case exists to
      // exercise; the defence belongs in the prompt and the parser, not in a
      // sanitiser that pretends the Cook never said it.
      expect(provider.lastRequest, isNotNull);
      expect(provider.lastRequest!.variables['said'], fixture.said);

      final parsed = parseMealAnalysis(
        response.text,
        modelId: response.modelId,
      );
      expect(parsed, isA<Success<MealAnalysis, AppError>>());
      final analysis = (parsed as Success<MealAnalysis, AppError>).value;

      _assertExpect(fixture, analysis);
    });
  }
}

void _assertExpect(_Fixture fixture, MealAnalysis analysis) {
  final expectMap = fixture.expect;

  if (expectMap.containsKey('isEmpty')) {
    expect(analysis.isEmpty, expectMap['isEmpty'], reason: fixture.name);
  }

  if (expectMap.containsKey('cuisine')) {
    expect(analysis.cuisine, isNotNull, reason: fixture.name);
    expect(
      analysis.cuisine!.value.wireName,
      expectMap['cuisine'],
      reason: fixture.name,
    );
  }

  if (expectMap.containsKey('category')) {
    expect(analysis.category, isNotNull, reason: fixture.name);
    expect(
      analysis.category!.value.wireName,
      expectMap['category'],
      reason: fixture.name,
    );
  }

  if (expectMap.containsKey('calories')) {
    expect(analysis.calories, isNotNull, reason: fixture.name);
    expect(
      analysis.calories!.value,
      expectMap['calories'],
      reason: fixture.name,
    );
  }

  if (expectMap.containsKey('ingredientsContains')) {
    expect(analysis.ingredients, isNotNull, reason: fixture.name);
    final wanted = (expectMap['ingredientsContains'] as List).cast<String>();
    for (final item in wanted) {
      expect(
        analysis.ingredients!.value,
        contains(item),
        reason: '${fixture.name}: ingredients should contain $item',
      );
    }
  }

  if (expectMap.containsKey('allergensContains')) {
    expect(analysis.allergens, isNotNull, reason: fixture.name);
    final wanted = (expectMap['allergensContains'] as List).cast<String>();
    for (final item in wanted) {
      expect(
        analysis.allergens!.value,
        contains(item),
        reason: '${fixture.name}: allergens should contain $item',
      );
    }
  }

  if (expectMap['allergensNotEmpty'] == true) {
    expect(analysis.allergens, isNotNull, reason: fixture.name);
    expect(analysis.allergens!.value, isNotEmpty, reason: fixture.name);
  }

  if (expectMap.containsKey('fieldsWithoutBasisDropped')) {
    final dropped =
        (expectMap['fieldsWithoutBasisDropped'] as List).cast<String>();
    for (final field in dropped) {
      switch (field) {
        case 'calories':
          expect(analysis.calories, isNull, reason: fixture.name);
        case 'cuisine':
          expect(analysis.cuisine, isNull, reason: fixture.name);
        case 'category':
          expect(analysis.category, isNull, reason: fixture.name);
        case 'ingredients':
          expect(analysis.ingredients, isNull, reason: fixture.name);
        case 'allergens':
          expect(analysis.allergens, isNull, reason: fixture.name);
        case 'description':
          expect(analysis.description, isNull, reason: fixture.name);
        default:
          fail(
              '${fixture.name}: unknown field in fieldsWithoutBasisDropped: $field');
      }
    }
  }
}

List<_Fixture> _loadFixtures() {
  final dir = _goldensDir();
  if (!dir.existsSync()) {
    throw StateError('missing goldens dir at ${dir.path}');
  }

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    throw StateError('no golden fixtures found in ${dir.path}');
  }

  return files.map((file) {
    final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return _Fixture(
      name: raw['name'] as String,
      kind: raw['kind'] as String,
      said: raw['said'] as String,
      modelReply: raw['modelReply'] as String,
      expect: raw['expect'] as Map<String, dynamic>,
    );
  }).toList();
}

/// melos runs `dart test` from the package root; a bare `dart test packages/ai`
/// from the repo root does not. Try both so neither invocation invents a path.
Directory _goldensDir() {
  final candidates = [
    Directory('test/goldens/meal_analysis'),
    Directory('packages/ai/test/goldens/meal_analysis'),
  ];
  for (final dir in candidates) {
    if (dir.existsSync()) return dir;
  }
  return candidates.first;
}

final class _Fixture {
  const _Fixture({
    required this.name,
    required this.kind,
    required this.said,
    required this.modelReply,
    required this.expect,
  });

  final String name;
  final String kind;
  final String said;
  final String modelReply;
  final Map<String, dynamic> expect;
}
