import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'photo_placeholder.dart';

/// A Meal as a Customer meets it.
///
/// Takes plain values rather than a domain type on purpose: this package is the
/// design system and must not depend on `packages/domain`, so the caller does
/// the mapping and this stays a widget.
///
/// **The Cook's identity sits on the photo, not under the price.** Trust in
/// Kafoo comes from the person; below the price, her name becomes a footnote to
/// a transaction. That placement is the reason [kitchenLabel] is required
/// rather than optional.
///
/// **The photo is a named widget rather than an [Image] built inline**, and
/// that is not a style choice. `Image.network` cannot resolve under the test
/// binding and takes its whole subtree down with it, so a test asserting on a
/// card containing one ends up testing the network. [MealCardPhoto] is what a
/// test asserts on instead.
class MealCard extends StatelessWidget {
  const MealCard({
    required this.title,
    required this.price,
    required this.kitchenLabel,
    required this.semanticsLabel,
    required this.placeholderLabel,
    this.priceUnit,
    this.meta,
    this.reviewScore,
    this.photoUrl,
    this.action,
    this.soldOutLabel,
    this.onTap,
    super.key,
  });

  /// What the Cook called it.
  final String title;

  /// Already formatted for the active locale. Never concatenated here — a price
  /// is money and formatting it is the caller's job with `intl`.
  ///
  /// Pass the numeral alone and put the currency in [priceUnit]: the number is
  /// the decision the Customer is making, so it is set two steps larger than
  /// the word beside it.
  final String price;

  /// "جنيه", one step down from [price]. Optional, because a caller holding
  /// only a combined string still renders correctly — just without the size
  /// difference the design asks for.
  final String? priceUnit;

  /// Who cooked it, already phrased ("from Fatma's Kitchen"). The first
  /// question a Customer asks, so it is required rather than optional.
  final String kitchenLabel;

  /// How the whole card reads aloud, already composed and localized.
  ///
  /// Supplied by the caller rather than built here, and the reason is specific:
  /// composing it in this package meant hardcoding an Arabic comma into a
  /// widget that also renders under `en`, where many voices announce or
  /// mispause it. Concatenation also fixes the field order across every locale,
  /// which is the thing placeholders exist to avoid.
  final String semanticsLabel;

  /// How an empty photo slot reads aloud. Required: an image slot with no
  /// photograph must announce itself as one, and a Meal without a photo is the
  /// normal case until real photography is shot with the Cook.
  final String placeholderLabel;

  /// One line under the title — cuisine, distance, ready-by.
  final String? meta;

  /// The Review score, already formatted.
  final String? reviewScore;

  final String? photoUrl;

  /// The primary action. Wraps onto its own line rather than squeezing the
  /// price when text is scaled up.
  final Widget? action;

  /// Set to mark the Meal sold out — the pill's text, already localized.
  final String? soldOutLabel;

  final VoidCallback? onTap;

  static const double _photoHeight = 180;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soldOut = soldOutLabel != null;

    // `excludeSemantics` on THIS node rather than an ExcludeSemantics child.
    //
    // The child form swallowed the InkWell's tap action while `button: true`
    // kept advertising the node as pressable — measured as
    // `IS BUTTON: true, HAS TAP ACTION: false`. A screen reader announced every
    // Meal as a button and its double-tap did nothing, so browsing was a dead
    // end for a blind Customer. The action has to live on the same node that
    // claims to be a button.
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: Opacity(
        opacity: soldOut ? 0.85 : 1,
        child: Card(
          margin: const EdgeInsetsDirectional.only(bottom: KafooSpacing.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _photo(context, soldOut),
                Padding(
                  padding: const EdgeInsetsDirectional.all(KafooSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: KafooSpacing.xs,
                    children: [
                      // No truncation: a Customer must be able to read the
                      // whole name, and a Cook her own Meal's.
                      Text(title, style: theme.textTheme.titleLarge),
                      if (meta != null)
                        Text(
                          meta!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: KafooColors.textMuted),
                        ),
                      if (reviewScore != null)
                        Text(
                          reviewScore!,
                          style: theme.textTheme.labelLarge
                              ?.copyWith(color: KafooColors.primaryDeep),
                        ),
                      const SizedBox(height: KafooSpacing.xs),
                      // Wraps rather than shrinking: at 200% text scale the
                      // action drops below the price instead of squeezing it.
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: KafooSpacing.row,
                        runSpacing: KafooSpacing.row,
                        children: [
                          _price(context),
                          if (action != null) action!,
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // A Wrap rather than a Row, and that is not interchangeable here. A price
  // is never truncated and never shrunk — it is the decision the Customer is
  // making — so when 24px doubles to 48px the number and its currency move
  // onto separate lines instead of running off the card. A Row overflowed by
  // 40 pixels at 200% on a 390px phone.
  Widget _price(BuildContext context) => Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: KafooSpacing.xs,
        children: [
          Text(
            price,
            style: KafooType.numeralRow.copyWith(
              fontSize: 24,
              color: KafooColors.onSurface,
            ),
          ),
          if (priceUnit != null)
            Text(
              priceUnit!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 15, color: KafooColors.textMuted),
            ),
        ],
      );

  Widget _photo(BuildContext context, bool soldOut) => Stack(
        children: [
          SizedBox(
            height: _photoHeight,
            width: double.infinity,
            child: photoUrl == null
                ? KafooPhotoPlaceholder(
                    semanticsLabel: placeholderLabel,
                    label: placeholderLabel,
                    borderRadius: 0,
                  )
                : MealCardPhoto(url: photoUrl!, height: _photoHeight),
          ),
          if (soldOut)
            Positioned.fill(
              child: ColoredBox(
                color: KafooElevation.soldOutVeil,
                child: Center(
                  child: Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: KafooSpacing.md,
                      vertical: KafooSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: KafooColors.surface,
                      borderRadius: BorderRadius.circular(KafooRadius.pill),
                    ),
                    child: Text(
                      soldOutLabel!,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
              ),
            ),
          // The Cook, on the photo. See the class comment.
          PositionedDirectional(
            end: KafooSpacing.row,
            bottom: KafooSpacing.row,
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: KafooSpacing.row,
                vertical: KafooSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: KafooElevation.pillOnPhoto,
                borderRadius: BorderRadius.circular(KafooRadius.pill),
              ),
              child: Text(
                kitchenLabel,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: KafooColors.onSurface),
              ),
            ),
          ),
        ],
      );
}

/// A Meal's photograph, named so a test can assert it is there without the
/// network resolving. See the note on [MealCard].
class MealCardPhoto extends StatelessWidget {
  const MealCardPhoto({required this.url, this.height = 72, super.key});

  final String url;
  final double height;

  @override
  Widget build(BuildContext context) => Image.network(
        url,
        // A Meal photo beside the Meal's name is decorative in the semantics
        // sense; announcing it is noise. Harmless while the card excluded its
        // whole subtree — and no longer, now that it does not.
        excludeFromSemantics: true,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        // A Meal whose photo will not load still has a name and a price, and
        // those are what a Customer decides on. Losing the card over an image
        // is the trade this refuses.
        errorBuilder: (_, __, ___) => SizedBox(
          height: height,
          child: const ColoredBox(color: KafooColors.surfaceSunken),
        ),
      );
}

/// A Meal's photograph, full width.
///
/// Named as its own widget so the "has a photo" branch can be asserted in a
/// test. [Image.network] cannot resolve under the test binding, so a test that
/// looked for the decoded image would be testing the network rather than the
/// layout.
///
/// **IN THE DESIGN SYSTEM BECAUSE TWO SCREENS SHOW A MEAL'S PHOTOGRAPH.** It
/// lived inside `public_meal_view.dart` — a Customer-facing screen — while the
/// Cook's own summary rendered the storage path as text beside the word
/// «الصورة». The widget that draws a photograph was one import away from the
/// screen that needed it and behind a screen nobody would think to import.
class MealPhoto extends StatelessWidget {
  const MealPhoto({
    required this.url,
    required this.semanticsLabel,
    super.key,
  });

  final String url;

  /// What a Cook who cannot see the screen hears here.
  ///
  /// **Required, and it caught a regression on the day this widget moved.** The
  /// summary row it replaced rendered the storage path as TEXT — useless to read
  /// but at least audible. An unlabelled image announced nothing, so a Cook
  /// using a screen reader came out of this change with strictly less than she
  /// had: no way to confirm her photograph was attached, on the screen whose
  /// whole purpose is checking the Meal before offering it.
  ///
  /// CLAUDE.md: a component is unfinished until its spoken line is written. An
  /// optional label would have let the next caller ship the same gap.
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KafooSpacing.sm),
        child: Image.network(
          url,
          // The label lives on the Semantics node above, which is the one place
          // it can be composed by the caller. Announcing the image separately
          // would read it twice.
          excludeFromSemantics: true,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
