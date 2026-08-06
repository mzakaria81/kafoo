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

  final String? photoUrl;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: onTap != null,
      label: '$title، $kitchenLabel، $price',
      child: ExcludeSemantics(
        child: Card(
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
                        Text(
                          price,
                          style: textTheme.titleSmall
                              ?.copyWith(color: KafooColors.primary),
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
        borderRadius: BorderRadius.circular(KafooSpacing.sm),
        child: Image.network(
          url,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          // A Meal whose photo will not load still has a name and a price, and
          // those are what a Customer decides on. Losing the card over an image
          // is the trade this refuses.
          errorBuilder: (_, __, ___) => const SizedBox(
            width: _size,
            height: _size,
            child: ColoredBox(color: Color(0x14000000)),
          ),
        ),
      );
}
