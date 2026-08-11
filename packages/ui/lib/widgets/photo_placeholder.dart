import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// An image slot with no photograph in it.
///
/// **This is a trust rule wearing a widget's clothes.** Kafoo's Meal photos are
/// shot with the Cook in her Kitchen; no AI-generated, synthesised or stock
/// food image may ever stand in for one, including "temporarily, to make a demo
/// look better". The defence against that is making the empty state obviously
/// unshippable — 45° hatching, a dashed edge, and a label in the error colour —
/// so nobody looks at a mock and assumes the photography problem is solved.
///
/// It must be impossible to mistake for a photograph at a glance, at thumbnail
/// size. That is why the hatching is drawn rather than tinted: a flat grey box
/// reads as a photo that has not loaded yet.
class KafooPhotoPlaceholder extends StatelessWidget {
  const KafooPhotoPlaceholder({
    required this.semanticsLabel,
    this.label,
    this.width,
    this.height,
    this.borderRadius = KafooRadius.thumbnail,
    super.key,
  });

  /// How the slot reads aloud, already localized. Required rather than
  /// optional: a screen reader user is exactly the person who cannot see that
  /// this is a placeholder.
  final String semanticsLabel;

  /// The visible warning, already localized — in Egyptian Arabic, saying that
  /// this is a temporary slot and will not ship. Omitted at thumbnail sizes
  /// where it cannot fit legibly; the hatching and dashed edge still carry it.
  final String? label;

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticsLabel,
        image: true,
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _PlaceholderPainter(borderRadius),
            child: label == null
                ? null
                : Center(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(KafooSpacing.sm),
                      child: Text(
                        label!,
                        textAlign: TextAlign.center,
                        style: KafooType.caption(arabic: true)
                            .copyWith(color: KafooColors.error),
                      ),
                    ),
                  ),
          ),
        ),
      );
}

class _PlaceholderPainter extends CustomPainter {
  const _PlaceholderPainter(this.radius);

  final double radius;

  static const _stripe = 10.0;
  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(rect, Paint()..color = KafooColors.surfaceSunken);

    // 45° hatching. Drawn as thick diagonal lines rather than as a gradient
    // because the stripe has to stay the same width whatever the slot's size —
    // a scaled gradient turns into a wash at thumbnail size, which is the exact
    // size at which this must not look like a photo.
    final hatch = Paint()
      ..color = KafooColors.disabledFill
      ..strokeWidth = _stripe;
    final span = size.width + size.height;
    for (var i = -size.height; i < span; i += _stripe * 2) {
      canvas.drawLine(
          Offset(i, 0), Offset(i + size.height, size.height), hatch);
    }
    canvas.restore();

    // Dashed edge, walked by hand: Flutter's BorderSide cannot dash, and a
    // solid edge here would read as a finished frame.
    final edge = Paint()
      ..color = KafooColors.placeholderBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + _dash),
          edge,
        );
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_PlaceholderPainter oldDelegate) =>
      oldDelegate.radius != radius;
}
