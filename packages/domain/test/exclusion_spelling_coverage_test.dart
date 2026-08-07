import 'package:kafoo_domain/domain.dart';
import 'package:test/test.dart';

/// MEASURES THE GAP BETWEEN THE TWO SIDES OF AN EXCLUSION, rather than fixing it.
///
/// The Customer's side is this vocabulary. The Cook's side is `search_meals`,
/// which matches each surface form as a substring of what the Cook typed:
///
///     item ILIKE '%' || term || '%'
///
/// Both sides now fold — `ExclusionVocabulary.foldArabic` here and
/// `public.fold_arabic` in the migration that rewrote the predicate. This suite
/// is what measured the gap that made folding worth a migration, and it is kept
/// as the check that the two sides still agree.
///
/// Measured 2026-08-07 with no folding on either side: **13 of 156 plausible
/// Cook spellings reached nothing** — `مكرونه`, `عجينه`, `شعريه`, `بسطرمه`,
/// `قشده`, `جندوفلى`, `كاليمارى` and three hamza variants — and separately, a
/// single tatweel defeated all 93 forms. The first number could have been
/// enumerated away with seven more words; the second could not, which is what
/// decided it.
///
/// The failure this produces is SILENT UNDER-EXCLUSION. A Cook writes a
/// spelling nobody listed, their Meal survives a Customer's exclusion, and
/// SC-005 — an excluded food appears zero times — is broken with no error
/// anywhere. A Customer excluding a food is usually doing it for a dietary,
/// religious or health reason.
///
/// **A variant is only counted as a miss when NO form of the same exclusion
/// reaches it.** `مكرونه` is a miss for gluten only if `مكرونه`, `قمح`, `عيش`
/// and every other gluten form all fail to appear inside it — which is the same
/// question the database asks, since every form of the matched exclusion is
/// sent as `exclude_terms`.
void main() {
  group('Cook-side spelling coverage', () {
    test('every listed form is reached in every plausible Cook spelling', () {
      final misses = <String, List<String>>{};
      var variantCount = 0;

      for (final exclusion in ExclusionVocabulary.all) {
        final reached = <String>{};
        for (final form in exclusion.surfaceForms) {
          for (final variant in _spellings(form)) {
            variantCount++;
            // The same comparison `search_meals` makes: both sides folded, the
            // form matched as a substring of what the Cook typed.
            final folded = ExclusionVocabulary.foldArabic(variant);
            final covered = exclusion.surfaceForms
                .any((f) => folded.contains(ExclusionVocabulary.foldArabic(f)));
            if (!covered) reached.add(variant);
          }
        }
        if (reached.isNotEmpty) {
          misses[exclusion.id] = reached.toList()..sort();
        }
      }

      final report = StringBuffer()
        ..writeln('$variantCount plausible Cook spellings checked')
        ..writeln('${misses.values.fold(0, (n, v) => n + v.length)} '
            'reach no form of their own exclusion:');
      for (final id in misses.keys.toList()..sort()) {
        report.writeln('  $id: ${misses[id]!.join(' ')}');
      }

      expect(misses, isEmpty, reason: report.toString());
    });

    test('a tatweel in the middle of a word changes nothing', () {
      // The measurement that decided the migration: before folding, ONE
      // stretched letter defeated all 93 forms. `لحـمة` contained no listed
      // form of anything, so a Cook who stretched a word served meat to a
      // Customer who had excluded it, silently. It cannot be enumerated away —
      // a tatweel sits at any position in any word.
      final defeated = <String>[];
      for (final exclusion in ExclusionVocabulary.all) {
        for (final form in exclusion.surfaceForms) {
          final stretched = ExclusionVocabulary.foldArabic(_withTatweel(form));
          if (!exclusion.surfaceForms.any(
              (f) => stretched.contains(ExclusionVocabulary.foldArabic(f)))) {
            defeated.add(stretched);
          }
        }
      }
      expect(defeated, isEmpty,
          reason: '${defeated.length} forms are defeated by one tatweel: '
              '${defeated.take(8).join(' ')}…');
    });
  });
}

/// Every way an Egyptian Cook might reasonably type [form].
///
/// The three families Arabic writes more than one way, and only where a typist
/// actually varies: hamza on a word's FIRST letter, and ة/ه and ي/ى at the end
/// of a word — which is where those letters occur.
///
/// Deliberately narrow. A first pass varied the alef at every position and
/// reported `فرآخ` and `دجأج` as gaps; nobody types those, and a measurement
/// that inflates itself cannot be used to decide whether a migration is worth
/// it. Word-initial hamza (`اسماك`/`أسماك`) and the final ة/ه are what Cooks
/// actually disagree about.
Iterable<String> _spellings(String form) {
  var out = <String>[''];
  final words = form.split(' ');
  for (var w = 0; w < words.length; w++) {
    final word = words[w];
    for (var i = 0; i < word.length; i++) {
      final options =
          _optionsFor(word[i], first: i == 0, last: i == word.length - 1);
      out = [
        for (final prefix in out)
          for (final option in options) '$prefix$option',
      ];
    }
    if (w < words.length - 1) out = [for (final s in out) '$s '];
  }
  return out;
}

List<String> _optionsFor(
  String char, {
  required bool first,
  required bool last,
}) {
  const alef = ['ا', 'أ', 'إ', 'آ'];
  if (first && alef.contains(char)) return alef;
  if (last && (char == 'ه' || char == 'ة')) return ['ه', 'ة'];
  if (last && (char == 'ي' || char == 'ى')) return ['ي', 'ى'];
  return [char];
}

/// The same word with one tatweel in it — `لحـمة`.
String _withTatweel(String form) {
  final at = form.length ~/ 2;
  return '${form.substring(0, at)}ـ${form.substring(at)}';
}
