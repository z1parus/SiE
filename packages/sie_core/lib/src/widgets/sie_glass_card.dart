import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/sie_colors.dart';

/// Flat card widget with press-scale feedback.
///
/// Interactive press feedback when [onTap] is non-null:
///   • Scale squeezes to 0.97 on tap-down.
///   • Returns to 1.0 with ease-out on release.
///
/// Set [glass] to true for the carousel-plaque look: a frosted-glass
/// [BackdropFilter] blur over the background plus a thin neutral-glass rim with
/// a soft outer glow (see [SieColors.glassPanel]). The flat default keeps the
/// original surface+border card so existing callers are unchanged.
class SieGlassCard extends ConsumerStatefulWidget {
  const SieGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.blurSigma = 30.0,
    this.glass = false,
    this.radius = 16,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double blurSigma;
  final VoidCallback? onTap;

  /// Frosted-glass plaque: translucent tinted fill over a backdrop blur, with a
  /// thin glowing neutral-glass rim. Off by default to preserve the flat card.
  final bool glass;

  /// Corner radius of the card / glass plaque (16 flat, 20 glass recommended).
  final double radius;

  @override
  ConsumerState<SieGlassCard> createState() => _SieGlassCardState();
}

class _SieGlassCardState extends ConsumerState<SieGlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync: this, value: 0.0);
    _pressAnim = CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    _pressCtrl.animateTo(1.0,
        duration: const Duration(milliseconds: 80), curve: Curves.easeIn);
  }

  void _onRelease() {
    _pressCtrl.animateTo(0.0,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    final card = widget.glass
        ? _buildGlass(c)
        : _buildFlat(c, c.flatCard(radius: widget.radius));

    if (widget.onTap == null) return card;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: (_) => _onRelease(),
      onTapCancel: _onRelease,
      child: AnimatedBuilder(
        animation: _pressAnim,
        builder: (_, child) => Transform.scale(
          scale: 1.0 - 0.03 * _pressAnim.value,
          child: child,
        ),
        child: card,
      ),
    );
  }

  Widget _buildFlat(SieColors c, BoxDecoration decoration) {
    return Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      padding: widget.padding ?? const EdgeInsets.all(16),
      decoration: decoration,
      child: widget.child,
    );
  }

  /// Frosted-glass plaque: outer frame (thin glowing rim, drawn outside the
  /// blur clip so the glow survives) wraps a clipped [BackdropFilter] with a
  /// translucent tinted fill; the content sits sharp on top of the blur.
  Widget _buildGlass(SieColors c) {
    final palette = c.glassPanel(radius: widget.radius);
    return Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: palette.frame,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: widget.blurSigma,
            sigmaY: widget.blurSigma,
          ),
          child: Container(
            padding: widget.padding ?? const EdgeInsets.all(16),
            decoration: palette.fill,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
