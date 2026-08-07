import 'dart:convert';
import 'dart:io';

import 'package:kafoo_ai/ai.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:test/test.dart';

/// The judgement corpus, from the Dart side.
///
/// **The parser is not here, and that is deliberate.** `judge-results` reads
/// the model's reply where the call is made, in TypeScript, and its own suite
/// runs every fixture in this directory through that real parser. Writing a
/// second parser in Dart so this file could re-check the same replies would be
/// two implementations of a trust rule, which is one more than can be kept
/// honest — the same reasoning that made `meal-description` return the shape
/// `meal-analysis` already returns.
///
/// What is checked here is what only this side can check: that the corpus
/// covers the cases the contract names, that no fixture asserts something the
/// rules forbid, and that a Customer's words reach the provider through the
/// abstraction unchanged (ADR-0005).
void main() {
  final fixtures = _loadFixtures();

  test('the corpus covers every case the contract names', () {
    final kinds = fixtures.map((f) => f['kind'] as String).toSet();
    for (final required in const [
      'typical', // results plainly answer
      'nothing', // nothing answers
      'close', // TOPICALLY CLOSE BUT WRONG — the case that justifies the function
      'popularity',
      'proximity',
      'adversarial',
    ]) {
      expect(kinds, contains(required),
          reason: 'no fixture of kind "$required" — the contract names it');
    }
  });

  test('the hard case is present and is genuinely hard', () {
    // If the close-but-wrong fixture were built from unrelated Meals it would
    // be the sushi case wearing another name, and the whole function would be
    // doing what a score already does. Every Meal in it must be food of the
    // same broad kind as the request — here, meat dishes against a request for
    // a burger.
    final close = fixtures.firstWhere((f) => f['kind'] == 'close');
    final meals = (close['meals'] as List).cast<Map<String, dynamic>>();
    expect(meals.length, greaterThanOrEqualTo(3),
        reason: 'one or two Meals is not a set a score would struggle with');
    expect(close['expect']['answers'], isFalse);
    final descriptions = meals.map((m) => m['description'] as String).join(' ');
    expect(descriptions, contains('لحمة'),
        reason: 'the close case should be near-misses, not unrelated food');
  });

  // FR-015 said as a property of the corpus itself. A fixture that expected an
  // alternative nobody handed over would be a golden case certifying the exact
  // failure the E2 replay found — a model naming food nobody is cooking, with
  // the suite marking it PASS.
  for (final fixture in fixtures) {
    test(
        'no fixture expects a Meal that was not handed over: ${fixture['name']}',
        () {
      final handed = (fixture['meals'] as List)
          .cast<Map<String, dynamic>>()
          .map((m) => m['id'] as String)
          .toSet();
      final expected =
          (fixture['expect']['alternatives'] as List?)?.cast<String>() ??
              const <String>[];
      for (final id in expected) {
        expect(handed, contains(id),
            reason: '"$id" is not one of the Meals this fixture hands over');
      }
      expect(expected.length, lessThanOrEqualTo(3),
          reason: '"nothing here, but try these many" is not an answer');
    });
  }

  test('a smuggled claim is refused whole, never stripped and used', () {
    // The popularity and proximity fixtures both carry a field the schema does
    // not have — that is how a model makes a claim it was forbidden to make.
    // Both must expect NO judgement at all. A fixture expecting the claim to be
    // quietly dropped and the verdict kept would be asserting that Kafoo
    // publishes the opinion of a model that just broke a rule.
    for (final fixture in fixtures
        .where((f) => f['kind'] == 'popularity' || f['kind'] == 'proximity')) {
      expect(fixture['expect']['judged'], isFalse,
          reason: fixture['name'] as String);
      final reply = jsonDecode(fixture['modelReply'] as String) as Map;
      expect(reply.keys.toSet().difference({'answers', 'alternatives'}),
          isNotEmpty,
          reason: '${fixture['name']}: the reply carries no smuggled field, so '
              'this fixture proves nothing');
    }
  });

  // ADR-0005. Every model call goes through the abstraction, and the Customer's
  // own words reach it unchanged — scrubbing them would change what was asked.
  for (final fixture in fixtures) {
    test('the request reaches the provider unchanged: ${fixture['name']}',
        () async {
      final provider = StubAiProvider({
        'discovery-judgement': fixture['modelReply'] as String,
      });
      final request = AiRequest(
        promptId: 'discovery-judgement',
        tier: ModelTier.fast,
        variables: {'phrase': fixture['phrase'] as String},
      );

      final result = await provider.complete(request);
      expect(result, isA<Success<AiResponse, AppError>>());

      expect(provider.lastRequest, isNotNull);
      expect(provider.lastRequest!.variables['phrase'], fixture['phrase']);
      expect(provider.lastRequest!.promptId, 'discovery-judgement');
    });
  }
}

List<Map<String, dynamic>> _loadFixtures() {
  final dir = Directory('test/goldens/discovery_judgement');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    throw StateError('no judgement goldens in ${dir.path}');
  }
  return [
    for (final file in files)
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
  ];
}
