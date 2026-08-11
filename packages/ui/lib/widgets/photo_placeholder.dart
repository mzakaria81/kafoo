import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// An image slot with no photograph in it.
///
/// **This is a trust rule wearing a widget's clothes.** Kafoo's Meal photos are
/// shot with the Cook in her Kitchen; no AI-generated, synthesised or stock
/// food image may ever stand in for one, including "temporarily, to make a demo
/// look better". The defence against that is making a mock obviously
/// unshippable — 45° hatching, a dashed edge, and a label in the error colour —
/// so nobody looks at one and assumes the photography problem is solved.
///
/// It must be impossible to mistake for a photograph at a glance, at thumbnail
/// size. That is why the hatching is drawn rather than tinted: a flat grey box
/// reads as a photo that has not loaded yet.
///
/// **TWO REGISTERS, AND THE DIFFERENCE IS WHETHER ANYTHING IS WRONG.** [mock]
/// is the alarm above. Its opposite — the default — is a real Meal whose Cook
/// simply did not take a photograph, which she is allowed to do and may never
/// change. Shouting hazard stripes at a Customer over a Meal that is genuinely
/// on offer says "this is fake" about real food, which is the same accusation
/// the wording was just fixed to stop making. The quiet register is muted and
/// plain, and still cannot be mistaken for a photograph, because a photograph
/// is not a flat tinted box with a word in the middle of it.
class KafooPhotoPlaceholder extends StatelessWidget {
  const KafooPhotoPlaceholder({
    required this.semanticsLabel,
    this.label,
    this.mock = false,
    this.width,
    this.height,
    this.borderRadius = KafooRadius.thumbnail,
    super.key,
  });

  /// How the slot reads aloud, already localized. Required rather than
  /// optional: a screen reader user is exactly the person who cannot see that
  /// this is a placeholder.
  final String semanticsLabel;

  /// The visible words, already localized and in Egyptian Arabic. Omitted at
  /// thumbnail sizes where it cannot fit legibly.
  final String? label;

  /// Whether this slot is a mock that must never be mistaken for shippable.
  ///
  /// True is the loud register: hazard hatching, a dashed edge, error-coloured
  /// words. False — the default — is a real Meal with no photograph, which is a
  /// permitted and possibly permanent state, and gets no alarm.
  final bool mock;

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
            painter: _PlaceholderPainter(borderRadius, mock: mock),
            child: label == null
                ? null
                : Center(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(KafooSpacing.sm),
                      child: Text(
                        label!,
                        textAlign: TextAlign.center,
                        style: KafooType.caption(arabic: true).copyWith(
                          color:
                              mock ? KafooColors.error : KafooColors.textMuted,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      );
}

class _PlaceholderPainter extends CustomPainter {
  const _PlaceholderPainter(this.radius, {required this.mock});

  final double radius;

  /// See [KafooPhotoPlaceholder.mock]. False draws the quiet register: a flat
  /// sunken panel and a plain hairline, no hazard stripes and no dashes.
  final bool mock;

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
    if (mock) {
      final hatch = Paint()
        ..color = KafooColors.disabledFill
        ..strokeWidth = _stripe;
      final span = size.width + size.height;
      for (var i = -size.height; i < span; i += _stripe * 2) {
        canvas.drawLine(
            Offset(i, 0), Offset(i + size.height, size.height), hatch);
      }
    }
    canvas.restore();

    // Dashed edge, walked by hand: Flutter's BorderSide cannot dash, and a
    // solid edge here would read as a finished frame.
    final edge = Paint()
      ..color = KafooColors.placeholderBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = mock ? 1.5 : 1;
    if (!mock) {
      // A plain hairline. Nothing is wrong here, so nothing shouts.
      canvas.drawRRect(rrect, edge);
      return;
    }
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
      oldDelegate.radius != radius || oldDelegate.mock != mock;
}
