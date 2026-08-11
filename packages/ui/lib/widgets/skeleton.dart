import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// The gap between opening a screen and the data arriving.
///
/// **DESIGN.md left this undefined on purpose** — §7 lists it as a known gap
/// and tells an implementer to stop and ask rather than improvise. The founder
/// answered on 2026-08-11: build it, to the design's own hint, "a hairline
/// skeleton at the Meal-row footprint".
///
/// Three things follow from that hint and are not decoration:
///
/// - **The footprint is [KafooMealRow]'s, not a generic grey block.** Same
///   raised surface, same 1px border, same 16 radius, same 12 padding, same
///   80px thumbnail. The list does not resize when the real rows arrive, so a
///   Cook is not looking at a screen that jumps under her thumb.
/// - **The biggest bar sits where the price will be.** In a real row the price
///   is the largest thing; a skeleton whose silhouette says otherwise teaches
///   the wrong shape for the half-second before the data lands.
/// - **It breathes.** On Egyptian networks this state can last several
///   seconds, and a motionless skeleton reads as a hung app — which is when
///   people force-quit. The pulse stops entirely when the platform's
///   reduce-motion setting is on.
class KafooSkeletonList extends StatefulWidget {
  const KafooSkeletonList({
    required this.semanticsLabel,
    this.rows = 3,
    super.key,
  });

  /// What a screen reader says instead of reading empty boxes, e.g.
  /// «بحمّل أكلاتك…». Required, because the alternative is silence during the
  /// one state where a blind user most needs to be told to wait.
  final String semanticsLabel;

  /// Enough to read as a list, few enough not to imply a count. Three.
  final int rows;

  /// Finds one skeleton row in a test.
  ///
  /// The same reason [KafooTalkButton.amplitudeBarKey] exists: the row is built
  /// from `DecoratedBox` and `FadeTransition`, both of which Material uses
  /// internally, so an unkeyed `find.byType` measures a scaffold and passes for
  /// the wrong reason.
  static Key rowKey(int index) => ValueKey('kafoo.skeleton.row.$index');

  @override
  State<KafooSkeletonList> createState() => _KafooSkeletonListState();
}

class _KafooSkeletonListState extends State<KafooSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // Slower than a spinner on purpose. A fast pulse reads as urgency, and
    // waiting for a list is not urgent — it is just waiting.
    duration: const Duration(milliseconds: 1100),
  );

  /// Started and stopped HERE rather than in the field initializer, because
  /// reduce-motion is a MediaQuery answer and MediaQuery is not readable until
  /// dependencies resolve. It also has to be a real controller held at rest
  /// rather than a stand-in animation: a `late final` the build never touches
  /// is first constructed inside `dispose`, where creating a ticker throws.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      // Full opacity, not mid-pulse. Frozen halfway looks like a fault.
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticsLabel,
      liveRegion: true,
      excludeSemantics: true,
      child: ListView.separated(
        padding: const EdgeInsetsDirectional.fromSTEB(
          KafooSpacing.lg,
          KafooSpacing.md,
          KafooSpacing.lg,
          KafooSpacing.lg,
        ),
        itemCount: widget.rows,
        separatorBuilder: (_, __) => const SizedBox(height: KafooSpacing.row),
        itemBuilder: (_, index) => _SkeletonRow(
          key: KafooSkeletonList.rowKey(index),
          // A single controller drives every row, so they pulse together
          // rather than as a row of independent blinking lights.
          pulse: _controller,
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.pulse, super.key});

  final Animation<double> pulse;

  /// [KafooMealRow]'s thumbnail. Kept in step by living beside it.
  static const double _thumb = 80;

  /// The three lines a Meal row stacks, in its order.
  static final TextStyle _status = KafooType.glanceWordRow;
  static final TextStyle _price = KafooType.numeralRow;

  /// Arabic, because `ar` is the default locale rather than the fallback. In
  /// English the name line is 3px shorter and the skeleton is that much taller
  /// than the row it precedes — which is the harmless direction.
  static final TextStyle _name = KafooType.bodySmall(arabic: true);

  static double _line(TextStyle style) => style.fontSize! * style.height!;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KafooColors.surfaceRaised,
        borderRadius: BorderRadius.circular(KafooRadius.panel),
        border: Border.all(color: KafooColors.border),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(KafooSpacing.row),
        child: Row(
          spacing: KafooSpacing.row,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Bar(
              pulse: pulse,
              width: _thumb,
              height: _thumb,
              radius: KafooRadius.thumbnail,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: KafooSpacing.xs,
                children: [
                  // Status, price, name — in the row's own order, and each
                  // bar exactly as tall as the line it stands in for. Derived
                  // from the type scale rather than typed in, because a
                  // hand-picked height silently stops matching the day the
                  // scale moves, and the mismatch shows up as a list that
                  // jumps.
                  _Bar(pulse: pulse, width: 84, height: _line(_status)),
                  _Bar(pulse: pulse, width: 96, height: _line(_price)),
                  _Bar(pulse: pulse, width: 132, height: _line(_name)),
                ],
              ),
            ),
            _Bar(pulse: pulse, width: 44, height: 44, radius: KafooRadius.pill),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.pulse,
    required this.width,
    required this.height,
    this.radius = KafooRadius.control,
  });

  final Animation<double> pulse;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      // Never to zero. A bar that disappears makes the row's shape flicker,
      // which is the opposite of what a skeleton is for.
      opacity: pulse.drive(Tween(begin: 0.45, end: 1)),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: KafooColors.surfaceSunken,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
