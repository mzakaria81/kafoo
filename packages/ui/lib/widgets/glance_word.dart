import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// The closed set of words that may be set large.
///
/// Reading cannot be assumed, so large Arabic text is a fixed vocabulary. Each
/// word always appears at the same size, weight, colour and position, which is
/// what lets it be recognised by silhouette rather than read. The colour
/// carries the same meaning as the word, redundantly: if the word is not read,
/// the colour alone still has to land.
///
/// **This enum is the closed set.** DESIGN.md §10.4 forbids a twelfth large
/// word without adding it here first — an unrecognised shape is worse than no
/// word at all — so the set lives in the type system rather than in a comment.
/// The words themselves are Arabic strings and belong in the ARB files; a
/// caller passes the localized text alongside the case.
enum GlanceWord {
  /// منشورة
  published(KafooColors.success),

  /// مسودة — the one drawn with a dashed edge, because a draft is not final.
  draft(KafooColors.textMuted, dashed: true),

  /// مش متاحة
  unavailable(KafooColors.warning),

  /// أرشيف
  archived(KafooColors.textSubtle),

  /// طلب جديد
  newOrder(KafooColors.voice),

  /// وصل
  arrived(KafooColors.success),

  /// اتلغى
  cancelled(KafooColors.error),

  /// محفوظ
  saved(KafooColors.voiceDeep, dashed: true),

  /// مفيش نت
  offline(KafooColors.error),

  /// اتبعت — delivery state, shown only on your own outgoing Message.
  sent(KafooColors.voiceDeep),

  /// اتقرت — delivery state, shown only on your own outgoing Message.
  read(KafooColors.success);

  const GlanceWord(this.colour, {this.dashed = false});

  /// The colour that must mean the same thing as the word.
  final Color colour;

  /// Whether the word is drawn with a dashed underline — reserved for the two
  /// states that are provisional rather than settled.
  final bool dashed;
}

/// How large a [GlanceWord] is drawn.
enum GlanceWordSize {
  /// 20px, in a list row.
  row,

  /// 32px, as the verdict of a whole screen.
  verdict,
}

/// A status word from the closed set.
///
/// [text] is the Arabic word, already localized by the caller — this package is
/// the design system and cannot reach the app's ARB files.
class KafooGlanceWord extends StatelessWidget {
  const KafooGlanceWord({
    required this.word,
    required this.text,
    this.size = GlanceWordSize.row,
    super.key,
  });

  final GlanceWord word;

  /// The localized word. Must be the entry from the closed set that matches
  /// [word]; passing anything else defeats the point of the set.
  final String text;

  final GlanceWordSize size;

  @override
  Widget build(BuildContext context) {
    final style = (size == GlanceWordSize.row
            ? KafooType.glanceWordRow
            : KafooType.glanceWordVerdict)
        .copyWith(color: word.colour);

    // The word itself is drawn plain. [GlanceWord.dashed] is carried as data
    // rather than rendered here: DESIGN.md's dashed edge belongs to the
    // container a caller may draw around a provisional state, and Flutter's
    // BorderSide cannot dash — a solid line standing in for a dashed one would
    // say "settled" about the two states that are not.
    return Semantics(
      // Status carried by colour alone is status a colour-blind Cook does not
      // get. The word is the label either way.
      label: text,
      child: Text(text, style: style),
    );
  }
}
