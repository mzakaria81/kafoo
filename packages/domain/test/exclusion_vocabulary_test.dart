import 'package:kafoo_domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('ExclusionVocabulary.all', () {
    test('is not empty — an empty vocabulary understands nobody', () {
      // The list shipped empty with the type, deliberately, so the shape was
      // fixed before anything depended on it. While it stays empty every phrase
      // a Customer says reports not-understood, which is safe and useless.
      expect(ExclusionVocabulary.all, isNotEmpty);
    });

    test('every exclusion has at least one way of being written', () {
      for (final exclusion in ExclusionVocabulary.all) {
        expect(exclusion.surfaceForms, isNotEmpty,
            reason: '${exclusion.id} can never be matched by anything');
      }
    });

    test('ids are unique', () {
      final ids = ExclusionVocabulary.all.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('no surface form belongs to two exclusions', () {
      // A form claimed twice makes the lookup order decide which exclusion a
      // Customer gets, and the order of a list is not a decision anyone made.
      final owners = <String, String>{};
      for (final exclusion in ExclusionVocabulary.all) {
        for (final form in exclusion.surfaceForms) {
          expect(owners.containsKey(form), isFalse,
              reason:
                  '"$form" is claimed by both ${owners[form]} and ${exclusion.id}');
          owners[form] = exclusion.id;
        }
      }
    });

    test('no form is a second spelling of another form of the same food', () {
      // Both sides fold now, so `جبنة` and `جبنه` are one form written twice.
      // A list that carries both teaches the next author to keep adding pairs —
      // and the pairs were never the coverage, since the pair nobody thought of
      // is the one that let a Meal through.
      for (final exclusion in ExclusionVocabulary.all) {
        final folded =
            exclusion.surfaceForms.map(ExclusionVocabulary.foldArabic).toList();
        expect(folded.toSet().length, folded.length,
            reason: '${exclusion.id} lists one word twice: $folded');
      }
    });

    test('a longer form of one food never hides inside another food', () {
      // Cross-entry containment makes list order decide the answer. There is
      // exactly one, it is pinned here, and a second one fails this test rather
      // than quietly changing what a Customer gets.
      final overlaps = <String>[];
      for (final exclusion in ExclusionVocabulary.all) {
        for (final form in exclusion.surfaceForms) {
          final folded = ExclusionVocabulary.foldArabic(form);
          for (final other in ExclusionVocabulary.all) {
            if (identical(other, exclusion)) continue;
            for (final otherForm in other.surfaceForms) {
              if (folded.contains(ExclusionVocabulary.foldArabic(otherForm))) {
                overlaps.add('${exclusion.id}:$form ⊃ ${other.id}:$otherForm');
              }
            }
          }
        }
      }
      expect(overlaps, ['shellfish:كابوريا ⊃ fish:بوري'],
          reason: 'a new overlap between two foods — decide which word wins '
              'rather than letting the length of the string decide');
    });

    test('every surface form finds its own exclusion', () {
      // The forms are what reach the database as exclude_terms, so a form that
      // does not round-trip through the lookup is a word a Customer can say and
      // Kafoo will not act on.
      for (final exclusion in ExclusionVocabulary.all) {
        for (final form in exclusion.surfaceForms) {
          final outcome = ExclusionVocabulary.lookUp(form);
          expect(outcome, isA<ExclusionFound>(),
              reason: '"$form" was not found');
          expect((outcome as ExclusionFound).exclusion.id, exclusion.id);
        }
      }
    });
  });

  group('ExclusionVocabulary.parse', () {
    test('a phrase with no negation marker excludes nothing', () {
      expect(ExclusionVocabulary.parse('عايز حاجة سخنة'), isA<NoExclusion>());
      expect(ExclusionVocabulary.parse(''), isA<NoExclusion>());
    });

    test('a recognised food after a marker is found', () {
      final outcome = ExclusionVocabulary.parse('عايز أكل من غير لحمة');
      expect(outcome, isA<ExclusionFound>());
      expect((outcome as ExclusionFound).exclusion.id, 'meat');
    });

    test('a spelling nobody enumerated is still understood', () {
      // The gap this folding closed, said in the Customer's voice. Each of
      // these was ExclusionNotUnderstood before 2026-08-07: the word is
      // ordinary, the spelling is ordinary, and nobody had listed that exact
      // one. `لحـمة` is the tatweel case — one stretched letter, and the whole
      // vocabulary missed it.
      for (final (phrase, id) in const [
        ('من غير مكرونه', 'gluten'),
        ('من غير بسطرمه', 'meat'),
        ('من غير قشده', 'dairy'),
        ('عندي حساسية من جندوفلى', 'shellfish'),
        ('من غير لحـمة', 'meat'),
      ]) {
        final outcome = ExclusionVocabulary.parse(phrase);
        expect(outcome, isA<ExclusionFound>(),
            reason: '"$phrase" was not read');
        expect((outcome as ExclusionFound).exclusion.id, id, reason: phrase);
      }
    });

    // ─────────────────────────────────────────────────────────────────────
    // EVERY CASE BELOW WAS FOUND BY localization-reviewer RUNNING THE CODE, on
    // 2026-08-07, against a suite that was green. They are the shared corpus:
    // `discover/index_test.ts` carries the identical list, because the app and
    // the Edge Function parse the same sentence and a silent disagreement
    // between them is a Customer's exclusion understood on one side and
    // matching nothing on the other.
    // ─────────────────────────────────────────────────────────────────────
    test('an allergy spelled with ه is still an allergy', () {
      // The markers were compared raw while the foods folded. `حساسية` is the
      // only marker word carrying a ة and `حساسيه` is at least as common, so
      // this returned NoExclusion — not not-understood, NOTHING. A Customer
      // states a nut allergy, the screen says nothing, the nuts come back.
      for (final (phrase, id) in const [
        ('عندي حساسيه من المكسرات', 'nuts'),
        ('حساسيه من اللبن', 'dairy'),
        ('عندى حساسيه من الفول السوداني', 'peanut'),
      ]) {
        final outcome = ExclusionVocabulary.parse(phrase);
        expect(outcome, isA<ExclusionFound>(), reason: phrase);
        expect((outcome as ExclusionFound).exclusion.id, id, reason: phrase);
      }
    });

    test('two foods in one breath: the FIRST one is honoured', () {
      // Documented behaviour that stopped being true the moment this side
      // started matching inside a phrase — the second food won on the
      // ordering, so a Customer naming milk had eggs excluded and the milk came
      // back. Two exclusions in one breath is the ordinary shape of an allergy
      // sentence.
      for (final (phrase, id) in const [
        ('من غير لبن ولا بيض', 'dairy'),
        ('مش عايز سمك ولا لحمة', 'fish'),
        ('من غير لحمة ولا فراخ', 'meat'),
        ('مش عايزة عيش ولا جبنة', 'gluten'),
        ('بدون قمح ولا لبن', 'gluten'),
      ]) {
        final outcome = ExclusionVocabulary.parse(phrase);
        expect(outcome, isA<ExclusionFound>(), reason: phrase);
        expect((outcome as ExclusionFound).exclusion.id, id, reason: phrase);
      }
    });

    test('a food name inside another word is not the food', () {
      // `أبيض` contains `بيض`. Matching anywhere inside the phrase answered
      // `egg` for white cheese — so the cheese stayed on the screen under a
      // label naming eggs, which is under-exclusion of the named food wearing
      // the wrong name. Word-start matching is the fix, and it is one-sided:
      // the Cook's side must keep matching anywhere, because ingredients are
      // written `بالبصل` and `بالسمنة`.
      expect(
        (ExclusionVocabulary.parse('من غير جبنة بيضاء') as ExclusionFound)
            .exclusion
            .id,
        'dairy',
      );
      for (final phrase in const [
        'مش عايز فلفل أبيض',
        'من غير رز أبيض',
        'من غير ملبن',
      ]) {
        expect(ExclusionVocabulary.parse(phrase), isA<ExclusionNotUnderstood>(),
            reason: '$phrase should say Kafoo did not understand, not guess');
      }
    });

    test('peanut butter is peanut, not butter', () {
      // `زبدة` begins the phrase and `سوداني` only begins a word once the
      // article is stripped. Taking the first reading that matched anything
      // answered `dairy` — leaving every peanut Meal on the screen, in front of
      // the allergy people most often mean by that sentence.
      expect(
        (ExclusionVocabulary.parse('من غير زبدة الفول السوداني')
                as ExclusionFound)
            .exclusion
            .id,
        'peanut',
      );
    });

    test('over-exclusion that is deliberate stays', () {
      // `سمكري` is a plumber and reads as fish; `بلاش أكل لبناني` reads as
      // dairy because `لبناني` genuinely begins with `لبن`. Both show the
      // Customer LESS food, which is the safe direction, and both are pinned so
      // that nobody "fixes" them into under-exclusion later. Fixing them
      // properly needs a list of words that are not foods, which is a bigger
      // thing than this file.
      expect(
          (ExclusionVocabulary.parse('من غير سمكري') as ExclusionFound)
              .exclusion
              .id,
          'fish');
      expect(
          (ExclusionVocabulary.parse('بلاش أكل لبناني') as ExclusionFound)
              .exclusion
              .id,
          'dairy');
    });

    test('the bare stem an Egyptian ingredient list actually carries', () {
      // Folding solves ة against ه and does nothing for a word written without
      // the ة at all. Eleven entries were listed only in their ة form, so
      // `سمن بلدي` — the most ordinary way ghee is written — missed a dairy
      // exclusion entirely.
      for (final (phrase, id) in const [
        ('بدون سمن', 'dairy'),
        ('من غير عجين', 'gluten'),
        ('من غير كبد', 'meat'),
        ('من غير معكرونة', 'gluten'),
      ]) {
        final outcome = ExclusionVocabulary.parse(phrase);
        expect(outcome, isA<ExclusionFound>(), reason: phrase);
        expect((outcome as ExclusionFound).exclusion.id, id, reason: phrase);
      }
    });

    test('an invisible character changes nothing', () {
      // A zero-width non-joiner renders identically to nothing at all on every
      // screen in the product. Before the fold covered it, `ل\u200Cحم` defeated
      // every meat exclusion and no reviewer could have seen it.
      for (final phrase in const [
        'من غير ل\u200Cحمة',
        'من غير لحمة\u200F',
        'من غير\u00A0لحمة',
      ]) {
        final outcome = ExclusionVocabulary.parse(phrase);
        expect(outcome, isA<ExclusionFound>(), reason: phrase);
        expect((outcome as ExclusionFound).exclusion.id, 'meat',
            reason: phrase);
      }
    });

    test('crab is crab, not the fish whose name is inside it', () {
      final outcome = ExclusionVocabulary.parse('من غير كابوريا');
      expect(outcome, isA<ExclusionFound>());
      expect((outcome as ExclusionFound).exclusion.id, 'shellfish');
    });

    test('the longest marker wins', () {
      // 'من غير ما يكون فيه' contains 'من غير'. Matching the shorter one first
      // takes "ما يكون فيه لحمة" as the food, which is not a food — so Kafoo
      // would report not-understood on a phrase it handles.
      final outcome = ExclusionVocabulary.parse('أكل من غير ما يكون فيه لحمة');
      expect(outcome, isA<ExclusionFound>());
      expect((outcome as ExclusionFound).exclusion.id, 'meat');
    });

    test('words after the food do not defeat the match', () {
      // The measured phrase. 'خالص' is an intensifier, not part of the food.
      final outcome = ExclusionVocabulary.parse('أكل من غير لحمة خالص');
      expect(outcome, isA<ExclusionFound>());
      expect((outcome as ExclusionFound).exclusion.id, 'meat');
    });

    test('a food written as two words is matched as two words', () {
      final outcome = ExclusionVocabulary.parse('من غير فول سوداني');
      expect(outcome, isA<ExclusionFound>());
      expect((outcome as ExclusionFound).exclusion.id, 'peanut');
    });

    test('a marker with a food Kafoo does not know says so', () {
      // THE DANGEROUS CASE. The Customer said "without X" and Kafoo does not
      // know X. Returning results as though nothing had been excluded is the
      // failure this whole type exists to prevent.
      final outcome = ExclusionVocabulary.parse('من غير كافيار');
      expect(outcome, isA<ExclusionNotUnderstood>());
      expect((outcome as ExclusionNotUnderstood).phrase, 'كافيار');
    });

    test('a marker with nothing after it is not understood, never nothing', () {
      // "من غير" and then silence — a truncated recording, a cut-off sentence.
      // It is still a Customer who asked to exclude something.
      expect(ExclusionVocabulary.parse('عايز أكل من غير'),
          isA<ExclusionNotUnderstood>());
    });

    test('an allergy is a negation — "عندي حساسية من" is how people say it',
        () {
      // Found by localization-reviewer 2026-08-07, by running the code: this
      // returned NoExclusion. Not not-understood — NOTHING EXCLUDED. The
      // Customer states an allergy, Kafoo serves them the food, and says
      // nothing. It is the silent drop this whole file exists to prevent,
      // arriving through the marker list rather than the food list, and it is
      // the single most likely phrasing for the case the list is FOR.
      final outcome = ExclusionVocabulary.parse('عندي حساسية من المكسرات');
      expect(outcome, isA<ExclusionFound>());
      expect((outcome as ExclusionFound).exclusion.id, 'nuts');
    });

    test('a woman asking is understood as well as a man', () {
      // 'مش عايز' is masculine. A woman says 'مش عايزة', which matched the
      // masculine marker as a PREFIX and left the ة behind as the first word of
      // the food — measured, it reported not-understood on "ة لحمة". Half the
      // customer base, on mainstream phrasing.
      for (final phrase in ['مش عايزة لحمة', 'مش عاوزة لحمة']) {
        final outcome = ExclusionVocabulary.parse(phrase);
        expect(outcome, isA<ExclusionFound>(),
            reason: '"$phrase" was not understood');
        expect((outcome as ExclusionFound).exclusion.id, 'meat');
      }
    });

    test('the definite article does not defeat a match', () {
      // ال is the most natural way to say it, and matching was exact on the
      // Customer's side while being loose on the Cook's. The looseness has to
      // point both ways.
      for (final phrase in ['من غير اللحمة', 'من غير البصل', 'من غير اللبن']) {
        expect(ExclusionVocabulary.parse(phrase), isA<ExclusionFound>(),
            reason: '"$phrase" was not understood');
      }
    });

    test('a filler word between the marker and the food is skipped', () {
      for (final phrase in ['من غير أي لحمة', 'من غير اي لحمة', 'بلاش بصل']) {
        expect(ExclusionVocabulary.parse(phrase), isA<ExclusionFound>(),
            reason: '"$phrase" was not understood');
      }
    });

    test('every marker is usable, not just the first', () {
      for (final marker in ExclusionVocabulary.negationMarkers) {
        final outcome = ExclusionVocabulary.parse('$marker لحمة');
        expect(outcome, isA<ExclusionFound>(),
            reason: '"$marker لحمة" was not understood');
      }
    });
  });

  // THE FOUR CALLS THE FOUNDER TOOK ON 2026-08-10, AND THE ONE HE DID NOT.
  //
  // WP-017 reached all seven of its acceptance criteria and then stopped, on
  // five questions no session should answer alone: each is a judgement about
  // Egyptian Arabic where being wrong serves somebody the food they said they
  // cannot eat. Four were decided. `كندوز` / `ضاني` / `مبحبش` stay out, because
  // the open question there is whether Cooks TYPE those words or only say them,
  // and nobody has asked a Cook yet.
  //
  // These are pinned as tests rather than left in a note because a note does not
  // fail. Anyone reversing one of these decisions has to delete an assertion
  // that names the reasoning, which is the only kind of record that survives a
  // stranger in a hurry.
  group('the vocabulary decisions of 2026-08-10', () {
    test('mayonnaise is egg', () {
      final outcome = ExclusionVocabulary.parse('من غير مايونيز');
      expect(outcome, isA<ExclusionFound>());
      expect((outcome as ExclusionFound).exclusion.id, 'egg');
    });

    test('excluding mayonnaise excludes every egg, and that is the decision',
        () {
      // ONE FORM SET SERVES BOTH DIRECTIONS, so this cannot be scoped to the
      // sauce. The same list matches what the Customer said and what the Cook
      // wrote, so `مايونيز` under `egg` means a Customer who asked to lose
      // mayonnaise also loses omelettes. That is over-exclusion, which is the
      // direction this feature is allowed to be wrong in — and the reverse,
      // someone avoiding eggs being handed mayonnaise, is the failure the
      // package exists to prevent.
      final byMayonnaise = ExclusionVocabulary.parse('من غير مايونيز');
      final byEgg = ExclusionVocabulary.parse('من غير بيض');
      expect((byMayonnaise as ExclusionFound).exclusion.id,
          (byEgg as ExclusionFound).exclusion.id);
    });

    test('tuna is fish', () {
      final outcome = ExclusionVocabulary.parse('من غير تونة');
      expect(outcome, isA<ExclusionFound>());
      expect((outcome as ExclusionFound).exclusion.id, 'fish');
    });

    test('walnut is deliberately absent, and this is the record of that', () {
      // NOT AN OVERSIGHT — do not "fix" this by adding `جوز`.
      //
      // localization-reviewer argued it unprompted and the founder agreed:
      // `جوز` on its own means a HUSBAND, and `جوز حمام` is a PAIR of pigeons.
      // Adding it would label a pigeon Meal as containing walnuts, and an
      // exclusion pointing at the wrong food is worse than one that misses —
      // the same reasoning that keeps `طحين` out of `sesame` in exclusion.dart.
      //
      // Walnut itself is still reachable: `عين جمل` and `عين الجمل` are both
      // listed under `nuts`, which is what an Egyptian ingredient list carries.
      for (final exclusion in ExclusionVocabulary.all) {
        expect(exclusion.surfaceForms, isNot(contains('جوز')),
            reason: '${exclusion.id} lists جوز — see the comment above this '
                'test before restoring it');
      }
      expect(ExclusionVocabulary.lookUp('جوز'), isA<ExclusionNotUnderstood>());
    });

    test('مبكلش is a negation — the Customer said they do not eat it', () {
      // `مبكلش لحمة` excluded NOTHING before this. Not not-understood: the
      // phrase carried no recognised marker at all, so it read as an ordinary
      // request and the meat came back — the exact shape of the allergy bug
      // closed on 2026-08-07, arriving through a marker nobody had listed.
      final outcome = ExclusionVocabulary.parse('مبكلش لحمة');
      expect(outcome, isA<ExclusionFound>());
      expect((outcome as ExclusionFound).exclusion.id, 'meat');
    });

    test('مباكلش is the same word, and Egyptians type both', () {
      final outcome = ExclusionVocabulary.parse('مباكلش لحمة');
      expect(outcome, isA<ExclusionFound>());
      expect((outcome as ExclusionFound).exclusion.id, 'meat');
    });
  });

  // WHAT THE REVIEWERS FOUND WHEN THE FOUR DECISIONS ABOVE WERE ALREADY GREEN.
  //
  // Both of these are the same lesson: **adding one spelling of a word can be
  // worse than adding none of it.** Before, Kafoo said nothing and a Customer
  // read the ingredients themselves. After, Kafoo says confidently that it
  // removed the food — and the spelling nobody listed walks straight past. The
  // suites were green for the spellings somebody thought of, which is the exact
  // shape of every defect this file records.
  group('the spellings the first pass missed, 2026-08-10', () {
    test('a Cook writing تونا is reached, not just تونة', () {
      // THE FALSE-REASSURANCE CASE, and the reason this could not wait.
      // `تونة` is the tin; `تونا` is the menu board and `سلطة تونا`. Folding
      // does not join them — `تونة` folds to `تونه` and `تونا` stays `تونا`.
      // Before this: a Customer says `من غير سمك`, Kafoo answers fish and says
      // it removed سمك, and the tuna salad is still on the screen.
      for (final item in ['تونا', 'سلطة تونا', 'ساندوتش تونا']) {
        expect(_cookSideReach(item), 'fish',
            reason: 'a Cook writing "$item" is invisible to a fish exclusion');
      }
    });

    test('a Customer writing تونا is understood too', () {
      final outcome = ExclusionVocabulary.parse('من غير تونا');
      expect(outcome, isA<ExclusionFound>());
      expect((outcome as ExclusionFound).exclusion.id, 'fish');
    });

    test('the ما particle is written apart as often as it is joined', () {
      // The negation particle is ما, and detaching it is the MORE literate
      // spelling — which is what somebody stating a religious rule tends to
      // use. All four returned NoExclusion: not not-understood, nothing at all.
      for (final phrase in [
        'مابكلش لحمة',
        'ماباكلش لحمة',
        'ما بكلش لحمة',
        'ما باكلش لحمة',
      ]) {
        final outcome = ExclusionVocabulary.parse(phrase);
        expect(outcome, isA<ExclusionFound>(),
            reason: '"$phrase" said nothing');
        expect((outcome as ExclusionFound).exclusion.id, 'meat',
            reason: phrase);
      }
    });

    test('بس ends the exclusion — what follows is a liking, not the food', () {
      // THE SENTENCE THAT PRODUCED A CONFIDENT FALSE STATEMENT.
      // "I don't eat meat BUT I like chicken" is the ordinary shape of a
      // habitual negation, and `بس` was not a conjunction — so the whole tail
      // became the food, the longest match won, and it was the food they said
      // they LIKED. Kafoo excluded the chicken, left the meat on the screen,
      // and told the Customer it had removed chicken.
      for (final (phrase, id) in const [
        ('مبكلش لحمة بس بحب الفراخ', 'meat'),
        ('مباكلش لحمة بس عايز فراخ', 'meat'),
        ('مبكلش سمك بس بحب الجمبري', 'fish'),
        // Pre-existing on the old markers too — this was never only about the
        // habitual ones.
        ('من غير لحمة بس بحب الفراخ', 'meat'),
      ]) {
        final outcome = ExclusionVocabulary.parse(phrase);
        expect(outcome, isA<ExclusionFound>(), reason: phrase);
        expect((outcome as ExclusionFound).exclusion.id, id, reason: phrase);
      }
    });

    test('بس does not cut a food whose name merely begins with it', () {
      // `بسطرمة` is meat. Conjunctions match as WHOLE WORDS, so this must be
      // untouched — splitting on the characters would halve an ordinary food.
      final outcome = ExclusionVocabulary.parse('من غير بسطرمة');
      expect(outcome, isA<ExclusionFound>());
      expect((outcome as ExclusionFound).exclusion.id, 'meat');
    });

    test('the olive that was already bought is the only one, still', () {
      // تونا must not widen the trade. `زيتون` and `زيت زيتون` are what an
      // ingredient list normally carries and neither may start colliding.
      for (final safe in ['زيتون', 'زيت زيتون', 'زيتون أسود']) {
        expect(_cookSideReach(safe), isNull,
            reason: '"$safe" now collides with an exclusion');
      }
    });
  });
}

/// What the COOK side reaches, simulating `search_meals`:
/// `fold_arabic(item) ILIKE '%' || fold_arabic(term) || '%'` — anywhere in the
/// string, which is the half that the Customer-side lookup does not model.
String? _cookSideReach(String item) {
  final haystack = ExclusionVocabulary.foldArabic(item);
  for (final exclusion in ExclusionVocabulary.all) {
    for (final form in exclusion.surfaceForms) {
      if (haystack.contains(ExclusionVocabulary.foldArabic(form))) {
        return exclusion.id;
      }
    }
  }
  return null;
}
