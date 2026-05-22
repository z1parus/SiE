import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/sie_theme.dart';

/// Self-contained full-screen space background. Manages its own animation
/// controller — just drop into a [Stack] as the bottom-most layer.
class SieSpaceBackground extends StatefulWidget {
  const SieSpaceBackground({super.key});

  @override
  State<SieSpaceBackground> createState() => _SieSpaceBackgroundState();
}

class _SieSpaceBackgroundState extends State<SieSpaceBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SpacePainter(_ctrl),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ── Star data ─────────────────────────────────────────────────

class _Star {
  final double dx;         // normalised offset from centre (×halfSize)
  final double dy;
  final double radius;     // 0.5 – 1.5 px
  final double baseAlpha;  // 0.20 – 0.90
  final bool twinkles;
  final double twinkleFreq;
  final double twinklePhase;
  final bool isCyan;       // false → white

  const _Star({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.baseAlpha,
    required this.twinkles,
    required this.twinkleFreq,
    required this.twinklePhase,
    required this.isCyan,
  });
}

// ── Painter ───────────────────────────────────────────────────

class _SpacePainter extends CustomPainter {
  final Animation<double> animation;

  // Seed 43 — distinct from StarrySkyBackground (seed 42) so screens feel
  // different from each other while remaining deterministic across rebuilds.
  static final List<_Star> _stars = _generate();

  _SpacePainter(this.animation) : super(repaint: animation);

  static List<_Star> _generate() {
    final rng = Random(43);
    return List.generate(220, (i) {
      final twinkles = rng.nextDouble() < 0.28;
      return _Star(
        dx: (rng.nextDouble() - 0.5) * 2.6,
        dy: (rng.nextDouble() - 0.5) * 2.6,
        radius: 0.5 + rng.nextDouble(),           // 0.5 – 1.5 px
        baseAlpha: 0.20 + rng.nextDouble() * 0.70, // 20 % – 90 %
        twinkles: twinkles,
        twinkleFreq: 1.0 + rng.nextDouble() * 5.0,
        twinklePhase: rng.nextDouble() * 2 * pi,
        // ~25 % cyan, 75 % white for variety
        isCyan: rng.nextDouble() < 0.25,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    // ── Deep-space vacuum fill ────────────────────────────────
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0A0E1A),
    );

    // ── Nebula layer 1 — cosmic indigo centred behind carousel ─
    final r1 = Rect.fromCenter(
      center: Offset(size.width * 0.50, size.height * 0.68),
      width:  size.width  * 1.30,
      height: size.height * 0.55,
    );
    canvas.drawOval(
      r1,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0x1A4B00CC), // cosmic indigo ~10 %
            Color(0x0D2A007A), // deep purple  ~5 %
            Color(0x00000000),
          ],
          stops: [0.0, 0.45, 1.0],
        ).createShader(r1),
    );

    // ── Nebula layer 2 — faint cyan flare, slightly offset ─────
    final r2 = Rect.fromCenter(
      center: Offset(size.width * 0.56, size.height * 0.58),
      width:  size.width  * 0.80,
      height: size.height * 0.35,
    );
    canvas.drawOval(
      r2,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0x0F00C8FF), // neon-cyan ~6 %
            Color(0x00000000),
          ],
        ).createShader(r2),
    );

    // ── Star field ────────────────────────────────────────────
    final t = animation.value;
    final halfSize = max(size.width, size.height) / 2;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(t * 2 * pi); // 1 revolution per 200 s — imperceptible drift

    final paint = Paint();
    for (final star in _stars) {
      double alpha = star.baseAlpha;
      if (star.twinkles) {
        final wave = sin(t * 2 * pi * star.twinkleFreq + star.twinklePhase);
        alpha = (alpha + wave * 0.22).clamp(0.05, 1.0);
      }
      paint.color = (star.isCyan ? SieTheme.accent : Colors.white)
          .withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(star.dx * halfSize, star.dy * halfSize),
        star.radius,
        paint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpacePainter old) => false;
}
