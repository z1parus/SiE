import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/sie_theme.dart';

BorderRadius _deflateRadius(BorderRadius r, double by) => BorderRadius.only(
      topLeft: Radius.circular(math.max(0, r.topLeft.x - by)),
      topRight: Radius.circular(math.max(0, r.topRight.x - by)),
      bottomLeft: Radius.circular(math.max(0, r.bottomLeft.x - by)),
      bottomRight: Radius.circular(math.max(0, r.bottomRight.x - by)),
    );

/// Premium liquid-glass card: BackdropFilter blur + translucent gradient fill +
/// gradient specular border painted via [_LiquidGlassPainter].
///
/// Reads the border radius from [SieSpaceEffects] in the current theme.
/// Degrades gracefully when the extension is absent (tests / legacy theme).
class SieGlassCard extends StatelessWidget {
  const SieGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.blurSigma = 25.0,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double blurSigma;

  /// When non-null, wraps content in an [InkWell] whose ripple respects
  /// the card's inner border radius.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final spaceEffects = Theme.of(context).extension<SieSpaceEffects>();
    final decoration = spaceEffects?.glassDecoration ??
        BoxDecoration(borderRadius: BorderRadius.circular(24));
    final outerRadius =
        (decoration.borderRadius as BorderRadius?) ?? BorderRadius.circular(24);
    // 1 px inset so InkWell ripple doesn't overflow the specular border.
    final innerRadius = _deflateRadius(outerRadius, 1);

    Widget innerContent = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );

    if (onTap != null) {
      innerContent = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: innerRadius,
          child: innerContent,
        ),
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        // Must clip BEFORE BackdropFilter so blur is bounded to the card shape.
        borderRadius: outerRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: CustomPaint(
            // Painter draws fill + specular border behind all children.
            painter: _LiquidGlassPainter(outerRadius),
            child: innerContent,
          ),
        ),
      ),
    );
  }
}

// ── Liquid-glass fill + specular border ──────────────────────────────────────

class _LiquidGlassPainter extends CustomPainter {
  final BorderRadius borderRadius;

  const _LiquidGlassPainter(this.borderRadius);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    // Translucent gradient fill: 12 % white catches top-left light;
    // 2 % white at bottom-right lets the blurred star field show through fully.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x1EFFFFFF), // 12 % white — specular light catch
            Color(0x05FFFFFF), // 2 %  white — near-transparent
          ],
        ).createShader(rect),
    );

    // Specular glow border: bright white + cyan at top-left (the "light source"
    // edge) fading to near-invisible at bottom-right. Deflated by 0.5 px so the
    // 1 px stroke sits entirely within the card bounds rather than bleeding out.
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x59FFFFFF), // 35 % white   — sharp top-left specular
            Color(0x4D00E5FF), // 30 % neon cyan — mid refraction glint
            Color(0x0DFFFFFF), // 5 %  white   — bottom-right fade-out
          ],
          stops: [0.0, 0.45, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_LiquidGlassPainter old) =>
      old.borderRadius != borderRadius;
}
