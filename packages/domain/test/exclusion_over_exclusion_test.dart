import 'package:kafoo_domain/domain.dart';
import 'package:test/test.dart';

/// MEASURES THE FOOD AN EXCLUSION TAKES AWAY THAT NOBODY ASKED IT TO, and
/// measures what the obvious fix would cost. It fixes neither.
///
/// The sibling suite `exclusion_spelling_coverage_test` measures the other
/// direction — a Cook's spelling that reaches no form of its own exclusion, so
/// a Customer is served the food they refused. That is the direction that can
/// break SC-005, and it is closed.
///
/// This is the direction that merely annoys: `بيض` is a substring of `أبيض`, so
/// a Customer excluding eggs loses white pepper, white rice and white sauce.
/// WP-017's notes called it "the most frequent false positive in the list" and
/// proposed matching at a word boundary instead. **Both halves of that sentence
/// turned out to be wrong, and the numbers below are why.**
///
/// ## What the Cook's side actually does
///
/// `search_meals` matches each surface form as a substring of `ingredients ||
/// allergens`, both sides folded:
///
///     public.fold_arabic(item) ILIKE '%' || public.fold_arabic(term) || '%'
///
/// Substring rather than word-boundary is deliberate. Arabic glues its articles
/// and prepositions onto the front of a noun and its feminine and plural
/// endings onto the back, so `لحم` has to reach `اللحمة`, `بالتوم` and
/// `لحوم` without anybody enumerating morphology onto every entry.
///
/// ## The two boundaries, measured 2026-08-08
///
/// Against the 70 pieces of Cook-side text below, the vocabulary matches 44
/// times.
///
/// **A LEFT boundary — the match must start a word, allowing for a clitic —
/// removes 7 of those 44 and costs nothing.** All seven are `أبيض` or `ملبن`.
///
/// **A RIGHT boundary as well — the match must also END a word — removes 14
/// MORE, and 11 of those are correct matches.** It would stop excluding
/// `جبنة`, `جبنة رومي`, `سمنة`, `لبنة`, `لحمة`, `لحمة مفرومة`, `كبدة` and
/// `بيضة مسلوقة`. A Customer avoiding dairy would be served cheese. That is
/// silent under-exclusion, which is the direction SC-005 exists to forbid, so
/// the two-sided match is not a candidate at any price.
///
/// **And the left boundary does not fix the case the note names.** `جبنة بيضاء`
/// — white cheese — begins the word `بيضاء` with `بيض`, so it survives a left
/// boundary untouched. So does `خبز لبناني` under a dairy exclusion. The
/// spellings that a boundary rule fixes are the masculine adjective `أبيض`; the
/// feminine `بيضاء` and the nisba `لبناني` need meaning, not letters.
///
/// ## Why nothing is changed here
///
/// A left boundary buys 7 hits out of 44 and pays for them with a CLOSED
/// LIST OF ARABIC CLITICS — the exact shape of enumeration that this package
/// already watched fail once, when 13 spellings and one tatweel defeated the
/// vocabulary. A clitic nobody listed becomes silent under-exclusion, and the
/// thing being bought is over-exclusion, which is the safe direction.
///
/// ADR-0012 is the fix: a classifier that reads `فلفل أبيض` and produces no EGG
/// concept, because it is reading a word rather than a run of letters. Until
/// then this suite pins the size of the problem so nobody re-litigates it from
/// memory, and goes red if a new surface form collides with ordinary Cook text.
void main() {
  group('Cook-side over-exclusion', () {
    test('the vocabulary reaches exactly eight words it does not mean', () {
      final unexplained = <String>{};

      for (final exclusion in ExclusionVocabulary.all) {
        for (final form in exclusion.surfaceForms) {
          final needle = ExclusionVocabulary.foldArabic(form);
          for (final text in _cookText) {
            final haystack = ExclusionVocabulary.foldArabic(text);
            for (final at in _occurrences(haystack, needle)) {
              if (!_startsAWord(haystack, at)) {
                unexplained.add('${exclusion.id}: $form in $text');
              }
            }
          }
        }
      }

      expect(
        unexplained,
        _knownOverExclusion,
        reason:
            'The set of words an exclusion reaches without meaning them has '
            'changed. If a form was ADDED, it now collides with ordinary Cook '
            'text and the Customer excluding that food loses a Meal that does '
            'not contain it — decide whether the form is worth it before '
            'pinning the new line here. If a form was REMOVED, check the '
            'spelling-coverage suite before celebrating: the two directions '
            'trade against each other.',
      );
    });

    test('a right-hand boundary would stop excluding cheese, ghee and meat',
        () {
      // The measurement that rules the two-sided match out. Kept as a test
      // rather than a comment because a comment is not re-run, and the next
      // person to propose word-boundary matching will propose both sides.
      final lost = <String>{};

      for (final exclusion in ExclusionVocabulary.all) {
        for (final form in exclusion.surfaceForms) {
          final needle = ExclusionVocabulary.foldArabic(form);
          for (final text in _cookText) {
            final haystack = ExclusionVocabulary.foldArabic(text);
            for (final at in _occurrences(haystack, needle)) {
              final ends = at + needle.length;
              final endsAWord =
                  ends == haystack.length || haystack[ends] == ' ';
              if (_startsAWord(haystack, at) && !endsAWord) {
                lost.add('${exclusion.id}: $form in $text');
              }
            }
          }
        }
      }

      // Named individually rather than counted. A count stays green while the
      // membership changes underneath it, and the membership is the argument:
      // every one of these is a Meal that SHOULD be withheld.
      expect(
        lost,
        containsAll(<String>[
          'dairy: جبن in جبنة',
          'dairy: سمن in سمنة',
          'dairy: لبن in لبنة',
          'meat: لحم in لحمة',
          'meat: كبد in كبدة اسكندراني',
          'egg: بيض in بيضة مسلوقة',
        ]),
        reason: 'Requiring the match to end a word would drop these, and every '
            'one is a food the Customer asked not to be served. Whatever '
            'replaces the substring match must still reach them.',
      );
    });

    test('white cheese survives a left boundary, which is the point', () {
      // The case WP-017's note names, and the case the proposed fix misses.
      const whiteCheese = 'جبنة بيضاء';
      final folded = ExclusionVocabulary.foldArabic(whiteCheese);
      final egg = ExclusionVocabulary.foldArabic('بيض');

      final at = _occurrences(folded, egg).single;
      expect(_startsAWord(folded, at), isTrue,
          reason: 'بيضاء begins with بيض, so a word-boundary rule leaves this '
              'exact false positive in place. Fixing it needs meaning — '
              'ADR-0012 — not a stricter letter match.');
    });
  });
}

/// Every clitic that can sit in front of a noun and still mean that noun.
///
/// Written out rather than generated so each entry is a claim somebody can
/// check. **This list is the reason the left-hand boundary is not being
/// adopted** — a clitic missing from it turns a correct exclusion into a silent
/// miss, and Arabic is not a language whose prefixes anybody finishes writing down.
const Set<String> _clitics = {
  '',
  'ال',
  'و',
  'ف',
  'ب',
  'ك',
  'ل',
  'وال',
  'فال',
  'بال',
  'كال',
  'لل',
  'ولل',
  'وب',
  'فب',
  'ول',
  'فل',
  'وك',
};

bool _startsAWord(String text, int at) {
  var start = at;
  while (start > 0 && text[start - 1] != ' ') {
    start--;
  }
  return _clitics.contains(text.substring(start, at));
}

Iterable<int> _occurrences(String haystack, String needle) sync* {
  for (var at = haystack.indexOf(needle);
      at != -1;
      at = haystack.indexOf(needle, at + 1)) {
    yield at;
  }
}

/// Cook-side text, from the three places Kafoo can observe it.
///
/// The single words come from `supabase/seed.sql` and from the model replies
/// pinned in `packages/ai/test/goldens/meal_analysis/` — every one of those
/// eight fixtures extracts bare head nouns, which is why over-exclusion is
/// nearly unreachable through the AI path today. **That is an observed model
/// habit and not a constraint**, and a Cook may edit the list by hand, which is
/// where the multi-word entries below come from.
const List<String> _cookText = [
  // Extracted by analyze-meal, pinned in the meal_analysis goldens.
  'مكرونة', 'لبن', 'دقيق', 'لحمة', 'جبنة', 'بيض', 'زبدة', 'جلوتين', 'ألبان',
  'عيش', 'بصل', 'خس', 'كاتشب', 'مستردة', 'فراخ', 'بقسماط', 'بطاطس', 'طماطم',
  'خيار', 'عدس', 'رز', 'حمص', 'صلصة', 'كرنب', 'كوسة', 'فلفل', 'شبت', 'بقدونس',
  'ملوخية', 'ثوم', 'كسبرة', 'عجين', 'مكسرات', 'زبيب', 'سكر',
  // Seeded ingredient arrays.
  'أرز', 'توم', 'سمنة', 'شطة', 'زيت', 'ليمون', 'بهارات',
  // Typed by a Cook editing what the model proposed. The adjective is what the
  // model drops and a person keeps.
  'فلفل أبيض', 'أرز أبيض', 'صوص أبيض', 'دقيق أبيض', 'عيش أبيض', 'سكر أبيض',
  'جبنة بيضاء', 'جبنة بيضا', 'جبنة رومي', 'لبن رايب', 'لبنة', 'قشطة',
  'سمنة بلدي', 'زيت زيتون', 'زيتون أسود', 'فلفل أسود',
  'لحمة مفرومة', 'لحوم باردة', 'كبدة اسكندراني', 'صدور فراخ', 'أسماك مشوية',
  'بيضة مسلوقة', 'مكرونة بشاميل', 'شوربة عدس',
  // Words that contain a form and mean something else. ملبن is Turkish delight
  // and خبز لبناني is a bread; neither contains dairy.
  'ملبن', 'خبز لبناني', 'زيتونة', 'جوز الهند',
];

/// Pinned rather than counted, so the membership is what has to stay true.
///
/// Eight entries, all of them a Customer losing a Meal that does not contain the
/// food they excluded. Over-exclusion, which is the safe direction — recorded
/// at its measured size so the next person to weigh a fix weighs it against a
/// number instead of an impression.
///
/// **`تونة` in `زيتونة` was bought deliberately on 2026-08-10**, and it is the
/// only line the founder's four vocabulary decisions added. Measured the same
/// run: `مايونيز` collides with NOTHING in this corpus, so `egg` grew its reach
/// at no Cook-side cost at all; `مبكلش` and `مباكلش` are negation markers rather
/// than foods and cannot appear here by construction; and `جوز` was left out, so
/// the pigeon Meals it would have hit are absent from this list by decision
/// rather than by luck.
///
/// The olive is the price of a tuna sandwich never reaching a fish allergy, and
/// it is ONE form: measured 2026-08-10, `زيتون`, `زيت زيتون` and `زيتون أسود`
/// are all untouched. Only the feminine singular `زيتونة` collides.
///
/// **A left-hand boundary WOULD recover it**, and an earlier draft of this note
/// claimed the opposite by mixing it up with `بيضاء`. `تونة` sits interior to
/// `زيتونة`, which is exactly the shape a left boundary removes — the same shape
/// as `أبيض`, listed above as one of the seven it fixes. The case a left
/// boundary genuinely cannot fix is the feminine adjective `بيضاء`, because
/// `بيضاء` BEGINS with `بيض`. The reason the boundary is still rejected is the
/// closed clitic list in the section above, not this collision.
const Set<String> _knownOverExclusion = {
  'dairy: لبن in ملبن',
  'egg: بيض in فلفل أبيض',
  'egg: بيض in أرز أبيض',
  'egg: بيض in صوص أبيض',
  'egg: بيض in دقيق أبيض',
  'egg: بيض in عيش أبيض',
  'egg: بيض in سكر أبيض',
  'fish: تونة in زيتونة',
};
