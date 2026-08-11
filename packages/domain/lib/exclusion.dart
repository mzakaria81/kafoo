/// What a Customer asked not to be shown. No Flutter, no Supabase.
///
/// This type exists because of a measurement rather than a preference. On
/// 2026-08-06 the phrase `أكل من غير لحمة خالص` — "food with no meat at all" —
/// was run against a corpus containing both meat and meatless Meals, matched by
/// meaning. It returned **meat dishes**: the first correct answer sat at rank 6
/// and precision@5 was 0.00. See `docs/ops/spike-discovery-embeddings.md`.
///
/// That is a known property of matching by meaning rather than a defect to fix
/// — the representation of "no meat" sits next to the representation of "meat".
/// So an exclusion is never handed to a model. It becomes a database predicate,
/// and this type is the vocabulary that predicate is built from.
///
/// **Why it is a closed list rather than free text.** A Customer excluding a
/// food is usually doing so for dietary, religious or health reasons, and
/// serving them the opposite is a betrayal rather than a poor result. A closed
/// list can be wrong in only one direction: it fails to recognise something,
/// which is visible and says so. Free text fails silently by matching nothing
/// and returning everything.
library;

/// A food a Customer asked not to be shown.
///
/// [surfaceForms] are the ways the thing is actually written, not a definition
/// of it. Matching is by these forms, so a form that is missing means a Customer
/// who used that word is not understood — which [ExclusionVocabulary.lookUp]
/// reports rather than swallowing.
final class Exclusion {
  /// Creates an exclusion.
  const Exclusion({
    required this.id,
    required this.surfaceForms,
  });

  /// The stable name for this exclusion. Never shown to anyone.
  final String id;

  /// The ways a Customer might write it, and the ways a Cook might have written
  /// it in a Meal's ingredients.
  final Set<String> surfaceForms;

  @override
  bool operator ==(Object other) => other is Exclusion && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Exclusion($id)';
}

/// The result of trying to understand what a Customer excluded.
///
/// The two failure cases are deliberately different things, because they must
/// produce different behaviour. Nothing asked for is ordinary. A negation
/// **recognised but not understood** is the dangerous one: it means the Customer
/// said "without X" and Kafoo does not know what X is, and returning results as
/// though no exclusion had been asked for is exactly the failure the measurement
/// above found, arriving by a different route.
sealed class ExclusionLookup {
  /// Creates a lookup outcome.
  const ExclusionLookup();
}

/// The Customer excluded nothing.
final class NoExclusion extends ExclusionLookup {
  /// Creates the no-exclusion outcome.
  const NoExclusion();
}

/// The Customer excluded something Kafoo recognises.
final class ExclusionFound extends ExclusionLookup {
  /// Creates a recognised exclusion.
  const ExclusionFound(this.exclusion);

  /// What was excluded.
  final Exclusion exclusion;
}

/// A negation was recognised and the thing being excluded was not.
///
/// **This must reach the Customer.** Kafoo says it did not understand rather
/// than quietly dropping the exclusion; the [phrase] is what they wrote, so the
/// interface can say which word it failed on.
final class ExclusionNotUnderstood extends ExclusionLookup {
  /// Creates the not-understood outcome around the unrecognised [phrase].
  const ExclusionNotUnderstood(this.phrase);

  /// The words that followed the negation marker.
  final String phrase;
}

/// The controlled list of things a Customer can exclude.
///
/// Deliberately small and deliberately additive. Growing it is how exclusions
/// improve; guessing at it is how a Customer gets served food they asked not to
/// see.
///
/// **The entries themselves land with the exclusion work, not here.** This
/// package ships the type and the lookup so the shape is fixed before anything
/// depends on it; a Meal is not filtered by any of this until that work runs.
abstract final class ExclusionVocabulary {
  /// Egyptian Arabic negation markers, as a closed set.
  ///
  /// Closed because these are the ways the language marks "without", not a
  /// sample of them. Longest first: `من غير ما يكون فيه` contains `من غير`, and
  /// matching the shorter one first would take the rest of the phrase as the
  /// thing excluded.
  ///
  /// **An allergy is a negation, and leaving it out was a silent drop.** Found
  /// 2026-08-07 by running the code rather than reading it: `عندي حساسية من
  /// المكسرات` returned [NoExclusion] — not not-understood, nothing excluded.
  /// The Customer states an allergy, is served the food, and is told nothing.
  /// It is the failure this file exists to prevent, arriving through the marker
  /// list instead of the food list, on the phrasing most likely to carry a real
  /// medical need.
  ///
  /// **The feminine forms are not politeness, they are half the customers.**
  /// `مش عايز` is masculine; a woman says `مش عايزة`, which matched the
  /// masculine marker as a prefix and left the ة behind as the first word of
  /// the food. Measured: `مش عايزة لحمة` reported not-understood on `ة لحمة`.
  static const List<String> negationMarkers = <String>[
    'عندي حساسية من',
    'حساسية من',
    'من غير ما يكون فيه',
    'مش عايزة',
    'مش عاوزة',
    'مش عايز',
    'مش عاوز',
    'من غير',
    'بدون',
    'بلاش',
    // "I DON'T EAT" IS A NEGATION, AND IT WAS RETURNING NOTHING AT ALL.
    //
    // Added 2026-08-10 on the founder's call. Measured before it went in:
    // `مبكلش لحمة` produced [NoExclusion] — not not-understood, NOTHING. No
    // marker in the list matched, so the phrase read as an ordinary request and
    // the meat came back with the screen saying nothing was dropped.
    //
    // That is the same failure as `عندي حساسية من` on 2026-08-07, for the same
    // structural reason: the marker list is a closed set, and a way of saying
    // "without" that nobody wrote down is silent rather than loud. Habitual
    // negation — "I don't eat X" — is how a preference gets stated when it is
    // long-standing, which is exactly when it is religious or medical.
    //
    // Longer first WITHIN this pair: `مباكلش` does not contain `مبكلش` (the ا
    // sits between the ب and the ك and folding does not remove it), so order is
    // not load-bearing between these two. Written longest-first anyway, because
    // the next word added here may not be so lucky.
    //
    // **THE LIST AS A WHOLE IS NO LONGER LONGEST-FIRST, AND THE RULE THAT
    // MATTERS IS CONTAINMENT, NOT LENGTH.** These two are six and five
    // characters and sit below `بدون` and `بلاش` at four. That is safe here
    // because no marker in this list contains either of them — but the header
    // comment above still says "longest first", which was true when it was
    // written and is now only true within each family. What must never break is
    // that a marker containing another sits ABOVE the one it contains, which is
    // why `من غير ما يكون فيه` precedes `من غير`.
    //
    // Position in this list is not merely cosmetic: `parse` picks the marker by
    // LIST INDEX rather than by where it appears in the sentence, so a marker
    // lower down loses a compound sentence to one above it. Measured 2026-08-10:
    // `مبكلش لحمة وبدون بصل` answers `onion`, honouring the taste preference
    // stated second over the habitual negation stated first. That behaviour
    // predates these two entries — `بدون بصل ومن غير لحمة` answers `meat` on the
    // old markers alone — so it is recorded here rather than fixed under a
    // vocabulary change, and it is the founder's call.
    // THE PARTICLE IS ما AND IT IS WRITTEN APART AS OFTEN AS IT IS JOINED.
    // Added 2026-08-10 after the first two went in. All four of these returned
    // NoExclusion — nothing excluded, nothing said — while the suite was green
    // for `مبكلش` and `مباكلش`, because whoever wrote them (me) reasoned about
    // the ا between ب and ك and never asked whether the negation particle can
    // stand on its own. It can, and detaching it is the MORE literate spelling,
    // which is what somebody stating a religious rule tends to reach for.
    //
    // Longest first, and none of the six contains another: folding preserves
    // the space, so `ما بكلش` and `مابكلش` are genuinely two forms rather than
    // one written twice.
    'ما باكلش',
    'ماباكلش',
    'ما بكلش',
    'مابكلش',
    'مباكلش',
    'مبكلش',
  ];

  /// Words that can sit between the marker and the food without being part of
  /// it — `من غير أي لحمة`.
  static const Set<String> _fillers = {'اي', 'شويه'};

  /// Every exclusion Kafoo understands.
  ///
  /// **Small on purpose, and additive on purpose.** These are the things a
  /// Customer most often needs excluded for a reason that matters — the major
  /// allergens, the meats a religious or dietary rule turns on, and two
  /// aromatics people genuinely cannot eat. Growing it is how exclusions
  /// improve; guessing at it is how somebody gets served food they asked not to
  /// see.
  ///
  /// **The forms are how the word is WRITTEN, not what it means.** They are
  /// matched as substrings against what a Cook typed into a Meal's ingredients
  /// and allergens, so `لحم` reaches `لحمة مفرومة` without either party having
  /// agreed on a vocabulary. That direction of looseness is deliberate: a
  /// substring match over-excludes rather than under-excludes, and
  /// over-excluding shows a Customer less food while under-excluding hands them
  /// the thing they asked to avoid.
  ///
  /// **ONE SPELLING PER WORD, because both sides now fold.** This list carried
  /// `لحمة` and `لحمه`, `جبنة` and `جبنه`, `بلطي` and `بلطى` — the same word
  /// written out twice so that a Cook using either was reached. That worked for
  /// the pairs somebody thought of. Measured 2026-08-07 by
  /// `exclusion_spelling_coverage_test`: 13 of 156 plausible Cook spellings
  /// reached nothing — `مكرونه`, `بسطرمه`, `قشده`, `شعريه` among them — and a
  /// single tatweel defeated all 93 forms, `لحـمة` matching no entry anywhere.
  /// [foldArabic] and `public.fold_arabic` in SQL now fold both sides, so a
  /// second spelling of a word here buys nothing and reads as though it did.
  ///
  /// **A form is never shared between two entries.** `exclusion_vocabulary_test`
  /// asserts it, because a form claimed twice would let list order decide which
  /// exclusion a Customer gets, and the order of a list is not a decision
  /// anybody made.
  static const List<Exclusion> all = <Exclusion>[
    // A broken plural inserts a letter, so the singular is not a substring of
    // it: a Cook writing لحوم حمراء is not reached by لحم. Same for أسماك.
    Exclusion(
      id: 'meat',
      surfaceForms: {
        'لحم', 'لحوم',
        // The cuts and products a Cook actually lists. Naming the word for meat
        // and stopping there misses everything an Egyptian menu is made of.
        'كبد', 'سجق', 'بسطرمة', 'لانشون',
      },
    ),
    // بانيه matters more than it looks: it stands alone in an ingredients list
    // with no فراخ anywhere near it. It is correct transliterated register —
    // do not "correct" it to Arabic.
    Exclusion(
      id: 'chicken',
      surfaceForms: {'فراخ', 'فرخ', 'دجاج', 'بانيه'},
    ),
    Exclusion(
      id: 'fish',
      surfaceForms: {
        'سمك', 'أسماك',
        // Named fish. Excluding سمك and being served رنجة is the failure.
        'سلمون', 'رنجة', 'فسيخ', 'بلطي', 'بوري', 'سردين',
        // `تونة` SITS INSIDE `زيتونة`, AND IT GOES IN ANYWAY.
        //
        // Founder's call, 2026-08-10. Tuna is the fish most likely to reach a
        // Customer without the word `سمك` anywhere near it — it arrives in a
        // sandwich, a salad or a filling, and somebody avoiding fish for an
        // allergy is exactly who meets it that way.
        //
        // The cost is ONE olive form, and the mechanism is the Cook side rather
        // than the Customer side. `search_meals` matches
        // `fold_arabic(item) ILIKE '%' || fold_arabic(term) || '%'` — ANYWHERE
        // in the string, not at a word start — so a Cook who wrote `زيتونة`
        // loses that Meal to a fish exclusion. Measured 2026-08-10: `زيتون`,
        // `زيت زيتون` and `زيتون أسود` are all untouched, so the mass noun an
        // ingredient list normally carries does not collide. Only the feminine
        // singular does. The Customer side is unaffected — `من غير زيتونة`
        // correctly returns not-understood and never answers `fish`.
        // Over-exclusion is the direction this feature is allowed
        // to be wrong in: an olive nobody wanted removed is an annoyance, and a
        // tuna sandwich served to a fish allergy is the thing SC-005 forbids.
        // The size of it is pinned in exclusion_over_exclusion_test.dart.
        // BOTH SPELLINGS, AND SHIPPING ONE WAS WORSE THAN SHIPPING NEITHER.
        // `تونة` is the tin, `تونا` is the menu board — `سلطة تونا`,
        // `ساندوتش تونا`. Folding does not join them: `تونة` folds to `تونه`
        // and `تونا` keeps its alef. Found 2026-08-10 by localization-reviewer
        // after `تونة` alone had gone in and every suite was green. With only
        // `تونة` listed, a Customer excluding fish was told Kafoo had removed
        // سمك and was then served the tuna salad — the first version of this
        // entry turned an honest silence into a confident false statement.
        'تونة', 'تونا',
      },
    ),
    // Crustaceans and molluscs are distinct allergies and are grouped here.
    // That over-excludes, which is the safe direction and matches how the word
    // "shellfish" is normally understood.
    Exclusion(
      id: 'shellfish',
      surfaceForms: {
        'جمبري',
        'استاكوزا',
        'كابوريا',
        'محار',
        'سبيط',
        'كاليماري',
        'قريدس',
        'حبار',
        'جندوفلي',
      },
    ),
    // `بيض` alone: `بيضة` and `بيضه` both contain it, so naming them added
    // nothing even before folding.
    // `مايونيز` IS HERE, AND IT EXCLUDES EVERY EGG RATHER THAN JUST THE SAUCE.
    //
    // Founder's call, 2026-08-10. One form set serves both directions — the
    // same list reads what the Customer said and matches what the Cook wrote —
    // so there is no way to say "lose the mayonnaise, keep the omelette". A
    // Customer naming mayonnaise loses eggs entirely.
    //
    // Taken knowing that, because the reverse is worse by a wide margin:
    // mayonnaise is egg that does not look like egg, and somebody avoiding eggs
    // reads an ingredient list, sees no `بيض`, and eats it.
    Exclusion(id: 'egg', surfaceForms: {'بيض', 'مايونيز'}),
    // Butter and ghee before cream: anyone avoiding dairy means سمنة and زبدة
    // long before they mean قشطة, and Egyptian cooking uses both constantly.
    // لبنة and لبن رايب need no entry — لبن reaches them as a substring.
    Exclusion(
      id: 'dairy',
      surfaceForms: {
        'لبن',
        'حليب',
        'جبن',
        'زبادي',
        'قشطة',
        // قشدة is not a spelling of قشطة — different letter, both are written.
        'قشدة',
        'زبدة',
        'سمن',
        'كريمة',
        'قريش',
      },
    ),
    // Peanut is its own entry rather than part of `nuts`, because it is not a
    // nut and because someone allergic to one is frequently not allergic to the
    // other. Merging them would exclude food nobody needed excluded.
    // `سوداني` alone reaches `فول سوداني` and `زبدة الفول السوداني` alike, and
    // there is no other food it collides with.
    Exclusion(id: 'peanut', surfaceForms: {'سوداني'}),
    Exclusion(
      id: 'nuts',
      surfaceForms: {
        'مكسرات', 'لوز', 'عين جمل', 'عين الجمل', 'بندق', 'فستق', 'كاجو',
        // In every stuffed dish, and absent from every list that forgets it.
        'صنوبر', 'بيكان',
        // `جوز` IS MISSING ON PURPOSE. THIS IS A DECISION, NOT A GAP.
        //
        // Founder's call, 2026-08-10, on localization-reviewer's unprompted
        // recommendation. `جوز` on its own means a HUSBAND, and `جوز حمام` is a
        // PAIR of pigeons — so adding it would tell a Customer avoiding nuts
        // that a pigeon Meal contains walnuts. An exclusion pointing at the
        // wrong food is worse than one that misses, which is the same reasoning
        // that keeps `طحين` out of `sesame` a few lines below.
        //
        // WALNUT IS REACHABLE ON THE CUSTOMER'S SIDE AND NOT ON THE COOK'S, and
        // an earlier draft of this comment said only the first half. `عين جمل`
        // and `عين الجمل` are what an Egyptian ingredient list usually carries
        // and both are above, so a Cook who writes either is correctly withheld.
        // But ONE FORM SET SERVES BOTH DIRECTIONS, so leaving `جوز` out to
        // protect the Customer side leaves the Cook side open: measured
        // 2026-08-10, a Cook writing `جوز` or `جوز مطحون` is reached by NOTHING,
        // and a Customer who said `عندي حساسية من المكسرات` is shown that Meal.
        // Silent under-exclusion on a nut allergy — the direction SC-005 forbids.
        //
        // That gap cannot be closed by editing this list. It needs the Customer
        // and Cook form sets split, or the extraction prompt pinned to emit
        // `عين جمل` for walnut. Both are open decisions recorded in WP-017 and
        // neither is taken here. `meals.ingredients` is AI-extracted and models
        // drift to Modern Standard Arabic, where walnut IS `جوز` — so this is a
        // live risk, not a hypothetical one.
        //
        // Written down here AND pinned by a test, because the next author will
        // otherwise read the absence as an oversight and close it.
      },
    ),
    // طحين is deliberately NOT here. In Modern Standard Arabic and the Levant it
    // means FLOUR, so an AI-written ingredient list could map a sesame exclusion
    // onto bread — an exclusion that points at the wrong food is worse than one
    // that misses.
    Exclusion(id: 'sesame', surfaceForms: {'سمسم', 'طحينة'}),
    // NAMING FLOUR AND STOPPING THERE WAS NOT USABLE BY A COELIAC. Every entry
    // added below is ordinary Egyptian ingredient text that قمح/دقيق/جلوتين do
    // not reach. شوفان is included though oats are not wheat: cross-contamination
    // is routine, and over-excluding is the direction to be wrong in.
    //
    // This entry still wants review by somebody who knows coeliac practice
    // rather than by somebody who knows Arabic.
    Exclusion(
      id: 'gluten',
      surfaceForms: {
        'قمح',
        'دقيق',
        'جلوتين',
        'غلوتين',
        'سميد',
        'بقسماط',
        'مكرونة',
        'معكرونة',
        'عيش',
        'خبز',
        'رقاق',
        'فريك',
        'شعرية',
        'عجين',
        'شوفان',
      },
    ),
    Exclusion(id: 'onion', surfaceForms: {'بصل'}),
    Exclusion(id: 'garlic', surfaceForms: {'توم', 'ثوم'}),
  ];

  /// Finds the exclusion [term] names, if Kafoo knows it.
  ///
  /// Returns [ExclusionNotUnderstood] rather than null for an unrecognised
  /// term, because the caller must not be able to treat "I do not know this
  /// word" the same as "nothing was excluded". Those produce opposite
  /// behaviour and the type is what stops them being confused.
  static ExclusionLookup lookUp(String term) {
    final needle = term.trim();
    if (needle.isEmpty) return const NoExclusion();

    // BOTH READINGS ARE WEIGHED, RATHER THAN THE FIRST ONE THAT MATCHES AT ALL.
    //
    // `من غير زبدة الفول السوداني` answered `dairy`: `زبدة` starts the phrase,
    // and the article-stripped reading — where `سوداني` finally begins a word
    // and wins on length — was never reached, because the first candidate had
    // already matched something. Peanut butter excluding milk and leaving every
    // peanut Meal on the screen is the dangerous direction, in front of the
    // allergy people most often mean.
    final matches = <({Exclusion exclusion, int length, int at, int index})>[];
    for (final candidate in {
      foldArabic(needle),
      foldArabic(_withoutArticles(needle)),
    }) {
      final match = _matchAtWordStart(candidate);
      if (match != null) matches.add(match);
    }
    if (matches.isEmpty) return ExclusionNotUnderstood(needle);
    matches.sort((a, b) => b.length.compareTo(a.length));
    return ExclusionFound(matches.first.exclusion);
  }

  /// The food a Customer named, matched where a WORD BEGINS.
  ///
  /// **`أبيض` contains `بيض`, and that is not a Customer asking about eggs.**
  /// This side matched anywhere inside the string for one afternoon, to make it
  /// ask the same question the Cook's side asks, and localization-reviewer ran
  /// it: `من غير جبنة بيضاء` — the most ordinary way a Cairene names white
  /// cheese — answered `egg`. The Customer is then told Kafoo removed the food
  /// with eggs in it, and the white cheese is still on the screen. That is
  /// under-exclusion of the food they named, wearing a label naming a food they
  /// did not, which is the one combination this file promises not to produce.
  /// `فلفل أبيض`, `رز أبيض` and `ملبن` all did the same thing.
  ///
  /// **THE LOOSENESS IS ONE-SIDED, AND DELIBERATELY SO.** `search_meals` keeps
  /// matching anywhere, because a Cook writes `بالبصل`, `والتوم`, `بالسمنة`,
  /// and a word-start rule there would miss every one of them — that is
  /// under-exclusion on the side where it is dangerous. Here the input is a
  /// short phrase somebody said, so a word start is exactly the right shape.
  ///
  /// **Longest first, then earliest.** `زبدة الفول السوداني` starts with a
  /// dairy word and is a peanut product; taking the earliest match would answer
  /// `dairy` and leave every peanut Meal on the screen, in front of somebody
  /// who may be allergic to peanuts. The longer form is the more specific word.
  /// Position only breaks ties — `جبنة بيضاء` matches `جبن` and `بيض` at the
  /// same length, and the food the Customer said first is the honest answer.
  ///
  /// The ordering is TOTAL on purpose, down to the vocabulary index. Ordering
  /// on length alone left the tie to the sort algorithm, and Dart's is not
  /// stable while JavaScript's is — so the two sides answered `من غير جبنة
  /// بيضاء` differently, and a Dart SDK bump could have changed either without
  /// a diff. Found by localization-reviewer by running both.
  static ({Exclusion exclusion, int length, int at, int index})?
      _matchAtWordStart(String candidate) {
    ({Exclusion exclusion, int length, int at, int index})? best;

    for (final (index, entry) in _foldedForms.indexed) {
      final (exclusion, form) = entry;
      final at = _wordStartIndexOf(candidate, form);
      if (at < 0) continue;
      if (best == null ||
          form.length > best.length ||
          (form.length == best.length && at < best.at) ||
          (form.length == best.length && at == best.at && index < best.index)) {
        best =
            (exclusion: exclusion, length: form.length, at: at, index: index);
      }
    }
    return best;
  }

  /// Where [form] appears at the start of a word in [text], or -1.
  static int _wordStartIndexOf(String text, String form) {
    var from = 0;
    while (true) {
      final at = text.indexOf(form, from);
      if (at < 0) return -1;
      if (at == 0 || text[at - 1] == ' ') return at;
      from = at + 1;
    }
  }

  /// Every form, folded, in vocabulary order. The order is a tie-break of last
  /// resort in [_matchAtWordStart] and decides nothing on its own.
  static final List<(Exclusion, String)> _foldedForms = [
    for (final exclusion in all)
      for (final form in exclusion.surfaceForms) (exclusion, foldArabic(form)),
  ];

  /// Words that end the food and begin something else — `من غير لبن ولا بيض`,
  /// `مبكلش لحمة بس بحب الفراخ`.
  ///
  /// Matched as whole words. A bare `و` is also a prefix (`وبصل`), so splitting
  /// on the character rather than the word would cut ordinary food names in
  /// half — and `بس` is the front of `بسطرمة`, which is meat.
  ///
  /// **`بس` IS NOT A CONJUNCTION AND IT BELONGS HERE ANYWAY.** It means "but",
  /// and what follows it is the opposite of an exclusion: the food the Customer
  /// says they DO want. Added 2026-08-10 after trust-reviewer measured what its
  /// absence did — `مبكلش لحمة بس بحب الفراخ`, "I don't eat meat but I like
  /// chicken", took the whole tail as the food, let the longest match win, and
  /// excluded the CHICKEN. The meat stayed on the screen and Kafoo told the
  /// Customer it had removed chicken.
  ///
  /// That is under-exclusion of the food they named wearing a label naming a
  /// food they did not — the one combination this file promises not to produce.
  /// It is also the ordinary shape of a habitual negation, so it arrived on the
  /// phrasing most likely to carry a religious or medical rule. Pre-existing:
  /// `من غير لحمة بس بحب الفراخ` did the same before the habitual markers
  /// existed.
  static const Set<String> _conjunctions = {'ولا', 'و', 'أو', 'او', 'بس'};

  /// One shape for a word Arabic writes several ways.
  ///
  /// **This must fold identically to `public.fold_arabic` in SQL and to
  /// `foldArabic` in `supabase/functions/discover/parse.ts`.** The Customer's
  /// word is recognised here; the Cook's ingredient is matched there. If the
  /// three disagree, a Customer's exclusion is understood and then matches
  /// nothing — which is silent under-exclusion arriving by a different route
  /// than the one it was written to close.
  ///
  /// Spelling only, never meaning. `ة` and `ه` are one letter to a typist and
  /// two different words to nobody; `سمك` and `لحم` stay different foods.
  ///
  /// It deliberately does NOT strip the definite article, which is the one rule
  /// `normalise_area` has and this does not: substring matching already reaches
  /// `اللحمة` from `لحم`, and a Customer's side handles `ال` separately in
  /// [_withoutArticles].
  /// **The character sets are written out rather than using `\s`.** Dart's `\s`
  /// is Unicode-aware, Postgres' `[[:space:]]` under `COLLATE "C"` is ASCII
  /// only, and the two quietly disagreed on seventeen codepoints — a no-break
  /// space inside `عين الجمل` folded here and not there, so walnut escaped a
  /// nut exclusion. Nobody has to type one: `meals.ingredients` is AI-extracted
  /// text and nothing between the model and the column touches it. Pinning the
  /// same explicit set in all three is the only way "they fold identically"
  /// stays true rather than being true on the day it was written.
  static String foldArabic(String value) => value
      .toLowerCase()
      // INVISIBLE MARKS FIRST, AND ENTIRELY. Diacritics, tatweel, and the
      // zero-width and directional characters beside it. `\u0644\u200C\u062D\u0645` with a
      // zero-width non-joiner renders identically to `\u0644\u062D\u0645` on every screen in
      // the product, and defeated every meat exclusion — the same class as the
      // tatweel this fold was written to close, left half open.
      //
      // Before the whitespace step, because U+FEFF is whitespace to Dart and
      // JavaScript and is not whitespace to Postgres: collapsing first would
      // turn it into a space in two folds and delete it in the third.
      .replaceAll(_invisible, '')
      .replaceAll(_whitespace, ' ')
      // Trimmed AFTER collapsing, never before. Postgres' one-argument btrim
      // strips only U+0020, so trimming first left a leading tab to become a
      // space that nothing then removed.
      .trim()
      .replaceAll(RegExp('[\u0623\u0625\u0622\u0671]'), '\u0627')
      .replaceAll('\u0649', '\u064A')
      .replaceAll('\u0629', '\u0647');

  /// Marks that carry no spelling: Arabic diacritics, tatweel, and the
  /// zero-width and directional characters that render as nothing at all.
  static final RegExp _invisible =
      RegExp('[\u0640\u064B-\u065F\u0670\u06D6-\u06ED'
          '\u200B-\u200F\u061C\uFEFF]');

  /// Every space Unicode has, written out. See the note above [foldArabic].
  static final RegExp _whitespace =
      RegExp('[\u0009-\u000D\u0020\u0085\u00A0\u1680\u2000-\u200A'
          '\u2028\u2029\u202F\u205F\u3000]+');

  /// Drops a leading `ال` from each word.
  ///
  /// **The looseness has to point both ways.** A Cook's ingredients are matched
  /// by substring, so `اللحمة` in a Meal already reaches the form `لحمة`. The
  /// Customer's side was exact, so `من غير اللحمة` — the most natural way to
  /// say it — reported not-understood. That asymmetry was invisible because
  /// each side is correct on its own.
  ///
  /// It also reaches `عين الجمل` from the form `عين جمل` without a second entry.
  static String _withoutArticles(String term) => term
      .split(RegExp(r'\s+'))
      .map((word) =>
          word.length > 3 && word.startsWith('ال') ? word.substring(2) : word)
      .join(' ');

  /// Reads what a Customer asked to avoid out of what they said.
  ///
  /// **Returning [NoExclusion] for a phrase that contained a negation would be
  /// the whole defect**, so it happens in exactly one case: no negation marker
  /// is present at all. A marker with a food nobody recognises — or with
  /// nothing after it, which is what a cut-off recording produces — is
  /// [ExclusionNotUnderstood], and the interface must say so rather than
  /// answering as though the Customer had asked for nothing.
  ///
  /// Only the first marker is read. A Customer excluding two things in one
  /// breath gets the first honoured and is told about it; that is a smaller
  /// wrong than guessing at the second.
  static ExclusionLookup parse(String phrase) {
    // FOLDED FIRST, MARKERS INCLUDED, AND THAT IS NOT TIDINESS.
    //
    // The foods were folded on 2026-08-07 and the markers were left compared
    // raw, one line above them. `حساسية` is the only marker word carrying a ة,
    // and `حساسيه` is at least as common in how Egyptians type — so
    // `عندي حساسيه من المكسرات` returned NoExclusion. Not not-understood:
    // NOTHING. A Customer states a nut allergy, the screen says nothing at all,
    // and the nuts come back.
    //
    // That is verbatim the failure this file's own comment says was found and
    // closed the same morning. It was closed for the marker LIST and reopened
    // by the marker SPELLING, and the list hand-enumerating `عندي` and `عندى`
    // is the tell that nobody looked at it again. Found by
    // localization-reviewer, by running it.
    final text = foldArabic(phrase);
    if (text.isEmpty) return const NoExclusion();

    // `negationMarkers` is longest-first, and a test holds it that way:
    // 'من غير ما يكون فيه' contains 'من غير', and matching the shorter one
    // first takes "ما يكون فيه لحمة" as the food — which is not a food, so a
    // phrase Kafoo handles would report not-understood.
    for (final marker in negationMarkers) {
      final at = text.indexOf(foldArabic(marker));
      if (at < 0) continue;

      final remainder = text.substring(at + foldArabic(marker).length).trim();
      if (remainder.isEmpty) return ExclusionNotUnderstood(remainder);

      final words = remainder.split(' ').where((w) => w.isNotEmpty).toList();
      while (words.length > 1 && _fillers.contains(foldArabic(words.first))) {
        words.removeAt(0);
      }

      // ONE BREATH, TWO FOODS: THE FIRST IS THE ONE HONOURED, AND IT STOPPED
      // BEING. `من غير لبن ولا بيض` excluded EGGS after the Customer's side
      // began matching inside a phrase — the whole remainder matched, and the
      // second food won on the ordering. So the Customer names milk, Kafoo
      // names eggs, and the milk is still on the screen. Two exclusions in one
      // breath is the ordinary shape of an allergy sentence, not an edge case.
      //
      // Cutting at the conjunction restores what this method has always
      // promised. The second food is still dropped — that is the documented
      // smaller wrong — but the one that is honoured is the one they said
      // first.
      final conjunction =
          words.indexWhere((w) => _conjunctions.contains(foldArabic(w)));
      final firstFood =
          conjunction < 0 ? words : words.take(conjunction).toList();
      if (firstFood.isEmpty) return ExclusionNotUnderstood(remainder);

      // Longest run of words first, so a two-word food beats its first word.
      // Shorter runs then catch the ordinary case where the food is followed by
      // something that is not part of it — `من غير لحمة خالص`, the phrase the
      // 2026-08-06 measurement used, where `خالص` is an intensifier.
      for (var take = firstFood.length; take >= 1; take--) {
        final candidate = firstFood.take(take).join(' ');
        final outcome = lookUp(candidate);
        if (outcome is ExclusionFound) return outcome;
      }
      return ExclusionNotUnderstood(remainder);
    }
    return const NoExclusion();
  }
}
