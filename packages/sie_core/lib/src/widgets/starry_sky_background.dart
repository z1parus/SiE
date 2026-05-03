import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/sie_theme.dart';

/// Full-screen animated star field. Pass an [animation] that runs 0→1 over a
/// long duration (e.g. 150 s); the painter uses it for slow rotation and
/// per-star twinkle. Wrap in [RepaintBoundary] so it repaints independently
/// from the rest of the widget tree.
class StarrySkyBackground extends StatelessWidget {
  final Animation<double> animation;

  const StarrySkyBackground({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _StarryPainter(animation),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ── Star data ─────────────────────────────────────────────────

class _Star {
  final double dx; // normalized offset from center (scaled by halfSize in painter)
  final double dy;
  final double radius; // logical pixels
  final double baseAlpha;
  final bool twinkles;
  final double twinkleFreq; // cycles per rotation
  final double twinklePhase; // radians

  const _Star({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.baseAlpha,
    required this.twinkles,
    required this.twinkleFreq,
    required this.twinklePhase,
  });
}

// ── Painter ───────────────────────────────────────────────────

class _StarryPainter extends CustomPainter {
  final Animation<double> animation;

  // Generated once (fixed seed → deterministic layout across frames and builds).
  static final List<_Star> _stars = _generate();

  _StarryPainter(this.animation) : super(repaint: animation);

  static List<_Star> _generate() {
    final rng = Random(42);
    return List.generate(190, (i) {
      // Spread across 2.8 × halfSize so the rotated field always covers
      // screen corners (diagonal = 1.41 × shorter side).
      final dx = (rng.nextDouble() - 0.5) * 2.8;
      final dy = (rng.nextDouble() - 0.5) * 2.8;
      final twinkles = rng.nextDouble() < 0.30;
      return _Star(
        dx: dx,
        dy: dy,
        radius: 0.5 + rng.nextDouble() * 1.5,
        baseAlpha: 0.15 + rng.nextDouble() * 0.72,
        twinkles: twinkles,
        // Slow variation: 1–7 oscillations per full sky rotation.
        twinkleFreq: 1.0 + rng.nextDouble() * 6.0,
        twinklePhase: rng.nextDouble() * 2 * pi,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Solid background — matches SieTheme.background exactly so there's no
    // gap between this painter and the surrounding Scaffold color.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = SieTheme.background,
    );

    final t = animation.value; // 0 → 1 per 150 s cycle
    // Scale factor so normalized offsets cover the full diagonal.
    final halfSize = max(size.width, size.height) / 2;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    // One full revolution per cycle — barely perceptible at 150 s.
    canvas.rotate(t * 2 * pi);

    final paint = Paint();
    for (final star in _stars) {
      double alpha = star.baseAlpha;
      if (star.twinkles) {
        // Oscillate alpha ±25 pp around base; result clamped to [0.05, 1.0].
        final wave = sin(t * 2 * pi * star.twinkleFreq + star.twinklePhase);
        alpha = (alpha + wave * 0.25).clamp(0.05, 1.0);
      }
      paint.color = SieTheme.accent.withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(star.dx * halfSize, star.dy * halfSize),
        star.radius,
        paint,
      );
    }

    canvas.restore();
  }

  // Repaints are triggered automatically via `repaint: animation`.
  @override
  bool shouldRepaint(_StarryPainter old) => false;
}
