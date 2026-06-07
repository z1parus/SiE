import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/sie_colors.dart';

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
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double blurSigma;
  final VoidCallback? onTap;

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
    _pressCtrl.animateTo(
      1.0,
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeIn,
    );
  }

  void _onRelease() {
    _pressCtrl.animateTo(
      0.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    final decoration = c.flatCard();

    if (widget.onTap == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        padding: widget.padding ?? const EdgeInsets.all(16),
        decoration: decoration,
        child: widget.child,
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: (_) => _onRelease(),
      onTapCancel: _onRelease,
      child: AnimatedBuilder(
        animation: _pressAnim,
        builder: (_, child) => Transform.scale(
          scale: 1.0 - 0.03 * _pressAnim.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            margin: widget.margin,
            padding: widget.padding ?? const EdgeInsets.all(16),
            decoration: decoration,
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
