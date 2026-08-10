import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A Meal as a Customer meets it in a list.
///
/// Takes plain values rather than a domain type on purpose: this package is the
/// design system and must not depend on `packages/domain`, so the caller does
/// the mapping and this stays a widget.
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
    this.photoUrl,
    this.onTap,
    super.key,
  });

  /// What the Cook called it.
  final String title;

  /// Already formatted for the active locale. Never concatenated here — a price
  /// is money and formatting it is the caller's job with `intl`.
  final String price;

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

  final String? photoUrl;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
      child: Builder(
        builder: (context) => Card(
          margin: const EdgeInsetsDirectional.only(bottom: KafooSpacing.md),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(KafooSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photoUrl != null) ...[
                    MealCardPhoto(url: photoUrl!),
                    const SizedBox(width: KafooSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: textTheme.titleMedium),
                        const SizedBox(height: KafooSpacing.xs),
                        Text(kitchenLabel, style: textTheme.bodySmall),
                        const SizedBox(height: KafooSpacing.sm),
                        // THE LARGEST THING ON THE CARD, at 34/700.
                        //
                        // It was `titleSmall` — 14px, the smallest text here,
                        // sitting under a 20px Meal name. Meanwhile a token test
                        // asserted "a numeral is the largest thing in the system"
                        // and passed, because it compared tokens to tokens and
                        // never to a use. For a Cook who does not read
                        // comfortably the price is the one reliably readable
                        // element, and it was the hardest thing here to see.
                        Text(
                          price,
                          style: KafooType.numeralRow.copyWith(
                            color: KafooColors.primaryDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A Meal's photograph, named so a test can assert it is there without the
/// network resolving. See the note on [MealCard].
class MealCardPhoto extends StatelessWidget {
  const MealCardPhoto({required this.url, super.key});

  final String url;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(KafooRadius.thumbnail),
        child: Image.network(
          url,
          // A Meal photo beside the Meal's name is decorative in the semantics
          // sense; announcing it is noise. Harmless while the card excluded its
          // whole subtree — and no longer, now that it does not.
          excludeFromSemantics: true,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          // A Meal whose photo will not load still has a name and a price, and
          // those are what a Customer decides on. Losing the card over an image
          // is the trade this refuses.
          errorBuilder: (_, __, ___) => const SizedBox(
            width: _size,
            height: _size,
            child: ColoredBox(color: KafooColors.surfaceSunken),
          ),
        ),
      );
}
