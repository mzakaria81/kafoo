import 'dart:convert';
import 'dart:io';

import 'package:kafoo_domain/domain.dart';
import 'package:test/test.dart';

/// The Dart third of a three-way agreement.
///
/// `test/goldens/arabic_folding.json` says what the fold returns. This suite
/// holds Dart to it; `supabase/functions/discover/index_test.ts` holds the
/// TypeScript to the same file; and `supabase/tests/arabic_folding_test.sql`,
/// which is GENERATED from it, holds Postgres.
///
/// **Why a shared file rather than three sets of hand-written cases.** The three
/// disagreed on seventeen whitespace codepoints on 2026-08-07 and nothing
/// noticed, because each side had cases somebody wrote for it and each side
/// passed its own. Both reviewers found the divergence by building throwaway
/// differential harnesses and deleting them afterwards. A shared expectation is
/// that harness, kept — and the failure it prevents is silent: a Customer's word
/// recognised in the app that then matches no Meal in the database.
void main() {
  final cases = _cases();

  test('the case file is not empty and covers the classes that broke', () {
    expect(cases.length, greaterThanOrEqualTo(25));
    for (final required in const [
      'tatweel_middle', // one stretched letter defeated all 93 forms
      'zwnj', // renders as nothing, defeated every meat exclusion
      'nbsp', // folded in two implementations and not the third
      'tab_leading', // btrim ordering
      'meat_stays_meat', // spelling, never meaning
    ]) {
      expect(cases.any((c) => c['id'] == required), isTrue,
          reason: 'the case "$required" was removed — it is one of the ones '
              'that actually broke, and it is here to stay broken-proof');
    }
  });

  for (final c in cases) {
    test('folds ${c['id']}: ${c['why']}', () {
      expect(
        ExclusionVocabulary.foldArabic(c['input'] as String),
        c['folded'],
        reason: 'Dart disagrees with test/goldens/arabic_folding.json. If the '
            'fold changed on purpose, change the file and re-run '
            'scripts/generate-folding-cases.py so all three move together.',
      );
    });
  }

  test('folding is idempotent', () {
    // Folding a folded word must change nothing. Without this a rule could be
    // added that keeps rewriting on every pass, and the three implementations
    // would diverge by how many times each happened to apply it.
    for (final c in cases) {
      final once = ExclusionVocabulary.foldArabic(c['input'] as String);
      expect(ExclusionVocabulary.foldArabic(once), once,
          reason: c['id'] as String);
    }
  });
}

List<Map<String, dynamic>> _cases() {
  final file = File('test/goldens/arabic_folding.json');
  if (!file.existsSync()) {
    throw StateError('missing ${file.path} — the shared fold expectation');
  }
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return (decoded['cases'] as List).cast<Map<String, dynamic>>();
}
