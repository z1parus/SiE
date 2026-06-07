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
  final double dx;          // normalised offset from centre (×halfSize)
  final double dy;
  final double radius;      // px — varies by layer
  final double baseAlpha;   // base opacity — varies by layer
  final bool twinkles;
  final double twinkleFreq;
  final double twinklePhase;
  final bool isCyan;        // false → white
  final bool hasGlow;       // foreground highlights get a diffraction halo

  const _Star({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.baseAlpha,
    required this.twinkles,
    required this.twinkleFreq,
    required this.twinklePhase,
    required this.isCyan,
    required this.hasGlow,
  });
}

// ── Painter ───────────────────────────────────────────────────

class _SpacePainter extends CustomPainter {
  final Animation<double> animation;

  // Seed 43 — deterministic across rebuilds; distinct from StarrySkyBackground
  // (seed 42) so screens feel different from each other.
  static final List<_Star> _stars = _generate();

  _SpacePainter(this.animation) : super(repaint: animation);

  /// Generates 286 stars split into three depth layers (+30 % density boost):
  ///   Background  70 % (200) — dust particles, 0.3–0.7 px,  α 0.13–0.455
  ///   Midground   20 % ( 57) — standard stars, 0.8–1.2 px,  α 0.52–0.91
  ///   Foreground  10 % ( 29) — bright entities, 1.3–1.8 px, α 0.90–1.00
  static List<_Star> _generate() {
    final rng = Random(43);
    final stars = <_Star>[];

    // ── Layer 0: Background dust (200 stars, 70 %) ──────────
    // Ultra-dim, sub-pixel dots — the illusion of deep cosmic distance.
    // No twinkle: at this scale atmospheric scintillation is imperceptible.
    for (var i = 0; i < 200; i++) {
      stars.add(_Star(
        dx:           (rng.nextDouble() - 0.5) * 2.6,
        dy:           (rng.nextDouble() - 0.5) * 2.6,
        radius:       0.3 + rng.nextDouble() * 0.4,       // 0.30 – 0.70 px
        baseAlpha:    0.13 + rng.nextDouble() * 0.325,     // 0.13 – 0.455 (+30 %)
        twinkles:     false,
        twinkleFreq:  0.0,
        twinklePhase: 0.0,
        isCyan:       rng.nextDouble() < 0.12,             // mostly white dust
        hasGlow:      false,
      ));
    }

    // ── Layer 1: Midground stars (57 stars, 20 %) ───────────
    // Medium-brightness stars; ~30 % have a visible twinkle cadence.
    for (var i = 0; i < 57; i++) {
      final twinkles = rng.nextDouble() < 0.30;
      stars.add(_Star(
        dx:           (rng.nextDouble() - 0.5) * 2.6,
        dy:           (rng.nextDouble() - 0.5) * 2.6,
        radius:       0.8 + rng.nextDouble() * 0.4,       // 0.80 – 1.20 px
        baseAlpha:    0.52 + rng.nextDouble() * 0.39,      // 0.52 – 0.91 (+30 %)
        twinkles:     twinkles,
        twinkleFreq:  1.0 + rng.nextDouble() * 5.0,
        twinklePhase: rng.nextDouble() * 2 * pi,
        isCyan:       rng.nextDouble() < 0.25,
        hasGlow:      false,
      ));
    }

    // ── Layer 2: Foreground highlights (29 stars, 10 %) ─────
    // Bright celestial entities; all receive a soft diffraction glow halo.
    // Half twinkle with a slower, more majestic cadence.
    for (var i = 0; i < 29; i++) {
      final twinkles = rng.nextDouble() < 0.50;
      stars.add(_Star(
        dx:           (rng.nextDouble() - 0.5) * 2.6,
        dy:           (rng.nextDouble() - 0.5) * 2.6,
        radius:       1.3 + rng.nextDouble() * 0.5,       // 1.30 – 1.80 px
        baseAlpha:    0.90 + rng.nextDouble() * 0.10,      // 0.90 – 1.00 (+30 %)
        twinkles:     twinkles,
        twinkleFreq:  1.0 + rng.nextDouble() * 3.0,       // slower cadence
        twinklePhase: rng.nextDouble() * 2 * pi,
        isCyan:       rng.nextDouble() < 0.30,
        hasGlow:      true,
      ));
    }

    return stars;
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

    final solidPaint = Paint();
    // Glow halo paint: soft Gaussian blur mimics starlight diffraction.
    // Applied only to foreground highlights (hasGlow == true).
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6); // +30 % diffraction spread

    for (final star in _stars) {
      double alpha = star.baseAlpha;
      if (star.twinkles) {
        final wave = sin(t * 2 * pi * star.twinkleFreq + star.twinklePhase);
        // Reduced amplitude vs original (0.22 → 0.15) so bright foreground
        // stars never dip below ~0.70 and background changes stay subtle.
        alpha = (alpha + wave * 0.15).clamp(0.05, 1.0);
      }

      final baseColor = star.isCyan ? SieTheme.accent : Colors.white;
      final pos = Offset(star.dx * halfSize, star.dy * halfSize);

      if (star.hasGlow) {
        // Outer halo: blurred circle at 2.8× the star radius, 40 % of core
        // alpha — simulates realistic diffraction spikes / airy disk.
        glowPaint.color = baseColor.withValues(alpha: alpha * 0.68); // +30 % halo brightness
        canvas.drawCircle(pos, star.radius * 3.0, glowPaint); // wider airy disk
      }

      solidPaint.color = baseColor.withValues(alpha: alpha);
      canvas.drawCircle(pos, star.radius, solidPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpacePainter old) => false;
}
