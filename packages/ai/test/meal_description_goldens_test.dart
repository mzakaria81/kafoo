import 'dart:convert';
import 'dart:io';

import 'package:kafoo_ai/ai.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:test/test.dart';

/// Discovers every fixture under `test/goldens/meal_description/` and runs it
/// against the meal-description prompt, with register assertions shared with
/// the TypeScript replay via `register_markers.json`.
void main() {
  final fixtures = _loadFixtures();
  final registry = _loadRegisterMarkers();

  test('corpus covers the required kinds', () {
    final kinds = fixtures.map((f) => f.kind).toList();
    expect(kinds.where((k) => k == 'typical').length, greaterThanOrEqualTo(3));
    expect(kinds.where((k) => k == 'dialect').length, greaterThanOrEqualTo(2));
    expect(
        kinds.where((k) => k == 'adversarial').length, greaterThanOrEqualTo(1));
    expect(kinds.where((k) => k == 'empty').length, greaterThanOrEqualTo(1));
  });

  // At least four fixtures carry an Egyptian marker. This is corpus-level, not
  // per-fixture: a short, entirely natural sentence like "حواوشي لحمة مفرومة
  // في عيش بلدي" contains none of the listed tokens, and demanding one per
  // fixture pushes an author to bend real sentences around a word list. At
  // corpus level it still proves the collection demonstrates dialect rather
  // than register-neutral prose.
  //
  // Four is exactly what the corpus carries today, so this bites — losing one
  // marker to a fixture edit turns it red rather than eating the slack. Scored
  // over the parsed description and its basis, which are the two things shown
  // to a Cook, not over the raw JSON around them.
  test('corpus demonstrates Egyptian register (≥4 fixtures with a marker)', () {
    var count = 0;
    for (final fixture in fixtures) {
      final description = _parseDescription(fixture);
      if (description == null) continue;
      final text = '${description.value} ${description.basis}';
      if (_hasEgyptianMarker(text, registry)) count++;
    }
    expect(count, greaterThanOrEqualTo(4),
        reason: 'only $count fixture(s) carry an Egyptian marker — the corpus '
            'should demonstrate dialect, not register-neutral prose');
  });

  // The Dart matcher and the TypeScript one share data but not code. These are
  // the two cases the TypeScript suite pins, and they are where a
  // re-implementation goes wrong.
  test('anchoring rules did not drift: بيحتوي is NOT Modern Standard', () {
    final msa = _findMsaMarkers(
        'العيش التوست بيحتوي على دقيق القمح اللي فيه جلوتين', registry);
    expect(msa, isEmpty);
  });

  test('anchoring rules did not drift: وتعتبر IS Modern Standard', () {
    final msa = _findMsaMarkers('الوجبة متكاملة وتعتبر طبق رئيسي', registry);
    expect(msa, isNotEmpty);
  });

  for (final fixture in fixtures) {
    test('golden: ${fixture.name}', () async {
      final provider = StubAiProvider({
        'meal-description': fixture.modelReply,
      });
      final request = AiRequest(
        promptId: 'meal-description',
        tier: ModelTier.fast,
        variables: {'said': fixture.said},
      );

      final result = await provider.complete(request);
      expect(result, isA<Success<AiResponse, AppError>>());
      final response = (result as Success<AiResponse, AppError>).value;

      // Untrusted Cook text must reach the provider unchanged.
      expect(provider.lastRequest, isNotNull);
      expect(provider.lastRequest!.variables['said'], fixture.said);

      final analysis = parseMealAnalysis(
        response.text,
        modelId: response.modelId,
      );
      expect(analysis, isA<Success<MealAnalysis, AppError>>());
      final mealAnalysis = (analysis as Success<MealAnalysis, AppError>).value;

      _assertExpect(fixture, mealAnalysis);

      // Register assertions: non-empty descriptions and their basis must carry
      // zero Modern Standard markers.
      final desc = mealAnalysis.description?.value;
      if (desc != null && desc.isNotEmpty) {
        final descMsa = _findMsaMarkers(desc, registry);
        expect(
          descMsa,
          isEmpty,
          reason:
              '${fixture.name}: description contains Modern Standard marker(s) [${descMsa.join(", ")}] in "$desc"',
        );

        final basis = mealAnalysis.description?.basis;
        if (basis != null && basis.isNotEmpty) {
          final basisMsa = _findMsaMarkers(basis, registry);
          expect(
            basisMsa,
            isEmpty,
            reason:
                '${fixture.name}: basis contains Modern Standard marker(s) [${basisMsa.join(", ")}] in "$basis"',
          );
        }
      }
    });
  }
}

void _assertExpect(_Fixture fixture, MealAnalysis analysis) {
  final expectMap = fixture.expect;

  if (expectMap.containsKey('isEmpty')) {
    expect(analysis.isEmpty, expectMap['isEmpty'], reason: fixture.name);
  }

  if (expectMap.containsKey('descriptionContains')) {
    final desc = analysis.description?.value;
    expect(desc, isNotNull, reason: fixture.name);
    final wanted = (expectMap['descriptionContains'] as List).cast<String>();
    for (final item in wanted) {
      expect(
        desc,
        contains(item),
        reason: '${fixture.name}: description should contain $item',
      );
    }
  }

  // Each of the three below demands a description before it checks anything.
  //
  // Guarding on `desc != null` instead would make every one of them pass when
  // the parser dropped the description entirely — and the fixtures that use
  // them most are the adversarial pair, where a vacuous pass says "the model
  // did not write a gluten-free claim" about a draft that does not exist. A
  // check that cannot fail is worse than no check, because it answers.
  if (expectMap.containsKey('descriptionNotContains')) {
    final desc = analysis.description?.value;
    expect(desc, isNotNull,
        reason: '${fixture.name}: no description to check for forbidden words');
    final forbidden =
        (expectMap['descriptionNotContains'] as List).cast<String>();
    for (final item in forbidden) {
      expect(
        desc!.contains(item),
        isFalse,
        reason: '${fixture.name}: description should not contain $item',
      );
    }
  }

  if (expectMap.containsKey('descriptionInArabicScript')) {
    final desc = analysis.description?.value;
    expect(desc, isNotNull,
        reason: '${fixture.name}: no description to check the script of');
    final isArabic = _isArabicScript(desc!);
    expect(
      isArabic,
      expectMap['descriptionInArabicScript'],
      reason: '${fixture.name}: descriptionInArabicScript expected '
          '${expectMap['descriptionInArabicScript']}, got $isArabic in "$desc"',
    );
  }

  if (expectMap.containsKey('maxSentences')) {
    final desc = analysis.description?.value;
    expect(desc, isNotNull,
        reason: '${fixture.name}: no description to count sentences in');
    final count = _countSentences(desc!);
    final max = expectMap['maxSentences'] as int;
    expect(
      count,
      lessThanOrEqualTo(max),
      reason:
          '${fixture.name}: description has $count sentences, max allowed is $max',
    );
  }

  // Unknown key — fail loudly so a misspelled assertion does not silently
  // shrink the corpus.
  final knownKeys = {
    'isEmpty',
    'descriptionContains',
    'descriptionNotContains',
    'descriptionInArabicScript',
    'maxSentences',
  };
  for (final key in expectMap.keys) {
    if (!knownKeys.contains(key)) {
      fail('${fixture.name}: unknown expect key: $key');
    }
  }
}

/// Space-anchored on purpose. A bare substring test would count بيحتوي
/// (Egyptian) as يحتوي (MSA), which is the exact distinction being measured.
///
/// The optional و is a conjunction written joined to the next word, and leaving
/// it out cost this check two real hits in the version 1 replay: وتعتبر in two
/// fixtures went unreported, and one of them was scored "Modern Standard
/// markers: none". Prefixes that change the register — the ب on بيحتوي — still
/// must not be skipped, so only the conjunction is optional.
bool _present(String haystack, String term) {
  return RegExp(r'(^|\s)و?' + term + r'(\s|$|[،.)(])').hasMatch(haystack);
}

List<String> _findMsaMarkers(String text, _RegisterMarkers registry) {
  return registry.msa
      .where((entry) => _present(text, entry['term'] as String))
      .map((entry) => '${entry['term']} (${entry['note']})')
      .toList();
}

bool _hasEgyptianMarker(String text, _RegisterMarkers registry) {
  return registry.egyptian.any((term) => _present(text, term));
}

/// The fixture's reply as the Cook would receive it, or null when the parser
/// dropped it — which is the correct outcome for the empty fixture.
MealSuggestion<String>? _parseDescription(_Fixture fixture) {
  final parsed = parseMealAnalysis(fixture.modelReply);
  if (parsed is! Success<MealAnalysis, AppError>) return null;
  return parsed.value.description;
}

bool _isArabicScript(String text) {
  return !RegExp(r'[a-zA-Z]').hasMatch(text);
}

/// Count sentences by splitting on `.`, `؟`, and `!`, ignoring empty trailing
/// pieces.
int _countSentences(String text) {
  return text.split(RegExp(r'[.؟!]')).where((p) => p.trim().isNotEmpty).length;
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

Directory _goldensDir() {
  final candidates = [
    Directory('test/goldens/meal_description'),
    Directory('packages/ai/test/goldens/meal_description'),
  ];
  for (final dir in candidates) {
    if (dir.existsSync()) return dir;
  }
  return candidates.first;
}

_RegisterMarkers _loadRegisterMarkers() {
  final candidates = [
    File('test/goldens/register_markers.json'),
    File('packages/ai/test/goldens/register_markers.json'),
  ];
  for (final file in candidates) {
    if (file.existsSync()) {
      final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return _RegisterMarkers(
        msa: (raw['msa'] as List).cast<Map<String, dynamic>>().toList(),
        egyptian: (raw['egyptian'] as List).cast<String>(),
      );
    }
  }
  throw StateError('register_markers.json not found');
}

final class _RegisterMarkers {
  const _RegisterMarkers({required this.msa, required this.egyptian});
  final List<Map<String, dynamic>> msa;
  final List<String> egyptian;
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
