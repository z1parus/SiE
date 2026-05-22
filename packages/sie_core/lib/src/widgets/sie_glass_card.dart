import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/sie_theme.dart';

/// Premium liquid-glass card built from four explicit Stack layers:
///
///   L1 — BackdropFilter blur (σ30) + dark tint contrast bed
///   L2 — Specular sheen: angled white gloss that fades before card centre
///   L3 — Gradient border: bright white+cyan TL → invisible BR (CustomPainter)
///   L4 — Content, fully isolated above all glass effects
///
/// An outer [BoxShadow] detaches the card from the star-field background.
class SieGlassCard extends StatelessWidget {
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

  /// When non-null, wraps content in an [InkWell] whose ripple respects
  /// the card's border radius.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final spaceEffects = Theme.of(context).extension<SieSpaceEffects>();
    final decoration = spaceEffects?.glassDecoration ??
        BoxDecoration(borderRadius: BorderRadius.circular(24));
    final radius =
        (decoration.borderRadius as BorderRadius?) ?? BorderRadius.circular(24);

    // L4 — content
    Widget content = Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: content,
        ),
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      // Outer drop-shadow detaches card from the background.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000014), // 20 % deep black-purple
              blurRadius: 30,
              spreadRadius: -6,
              offset: Offset(0, 8),
            ),
          ],
        ),
        // ClipRRect MUST wrap BackdropFilter so the blur is bounded to the
        // card's rounded shape and doesn't bleed into adjacent elements.
        child: ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            width: width,
            height: height,
            // passthrough: parent's tight constraints flow into the content
            // (critical for Expanded children inside carousel cards).
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                // ── L1: Blur + dark tint contrast bed ──────────────────────
                // BackdropFilter samples everything painted before this widget
                // in the scene (the star field). ColoredBox adds a faint dark
                // wash so the white specular highlights pop above the stars.
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                    ),
                    child: const ColoredBox(color: Color(0x220A0E1A)),
                  ),
                ),

                // ── L2: Specular sheen ──────────────────────────────────────
                // A diagonal gloss line (top-left → bottom-right) that fades
                // out completely before the card centre — simulating the curved
                // lens reflection of a physical liquid-glass surface.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0x38FFFFFF), // 22 % white — crisp reflection
                          Color(0x14FFFFFF), // 8 %  white
                          Colors.transparent, // fully gone by stop 0.6
                        ],
                        stops: [0.0, 0.3, 0.6],
                      ),
                    ),
                  ),
                ),

                // ── L3: Liquid border ───────────────────────────────────────
                // Top-left edge: bright white + neon-cyan refraction catch.
                // Bottom-right edge: fades to near-invisible.
                // Drawn via CustomPainter to avoid Flutter's assertion that
                // forbids non-uniform Border with borderRadius in BoxDecoration.
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LiquidBorderPainter(radius),
                  ),
                ),

                // ── L4: Content ─────────────────────────────────────────────
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Gradient specular border ──────────────────────────────────────────────────

class _LiquidBorderPainter extends CustomPainter {
  final BorderRadius borderRadius;

  const _LiquidBorderPainter(this.borderRadius);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Deflate by 0.5 so the 1 px stroke sits entirely inside the card bounds.
    canvas.drawRRect(
      borderRadius.toRRect(rect).deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x73FFFFFF), // 45 % white   — sharp TL specular edge
            Color(0x6600E5FF), // 40 % neon cyan — mid refraction glint
            Color(0x05FFFFFF), // 2 %  white   — BR fades to near-invisible
          ],
          stops: [0.0, 0.4, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_LiquidBorderPainter old) =>
      old.borderRadius != borderRadius;
}
