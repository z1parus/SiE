import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/sie_colors.dart';
import '../theme/sie_motion.dart';

/// Shimmering placeholder block (Stage 0 — design system).
///
/// Drop-in replacement for bare [CircularProgressIndicator]s: shows the
/// *shape* of the content that is loading so the UI feels responsive instead
/// of "stuck". Respects reduce-motion — the shimmer sweep is replaced by a
/// static muted fill when animations are disabled.
class SieSkeleton extends ConsumerStatefulWidget {
  const SieSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 8,
    this.margin,
  });

  final double? width;
  final double height;
  final double radius;
  final EdgeInsetsGeometry? margin;

  @override
  ConsumerState<SieSkeleton> createState() => _SieSkeletonState();
}

class _SieSkeletonState extends ConsumerState<SieSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    final base = c.isLightMode
        ? const Color(0x14000000)
        : Colors.white.withValues(alpha: 0.06);
    final highlight = c.isLightMode
        ? const Color(0x0A000000)
        : Colors.white.withValues(alpha: 0.12);

    final motion = SieMotion.enabled(context);
    if (motion && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!motion && _ctrl.isAnimating) {
      _ctrl.stop();
    }

    final box = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );

    if (!motion) return box;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 - 2 * (1 - t), 0),
              end: Alignment(1.0 + 2 * t, 0),
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// Vertical stack of [SieSkeleton] card rows for list placeholders.
class SieSkeletonList extends StatelessWidget {
  const SieSkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 72,
    this.spacing = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final int itemCount;
  final double itemHeight;
  final double spacing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < itemCount; i++)
            SieSkeleton(
              height: itemHeight,
              radius: 16,
              margin: EdgeInsets.only(bottom: i == itemCount - 1 ? 0 : spacing),
            ),
        ],
      ),
    );
  }
}
