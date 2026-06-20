import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../screens/session_orb_painters.dart' show kRimTealDark, kRimTealLight;

/// Дефрагментация module preview — scattered glass shards drift inward and
/// settle into an ordered concentric orbit around a glowing gold-sand core
/// (the defragmentation motif), in the shared gold-on-anthracite language.
///
/// Self-contained and param-driven (no providers) so it can be golden-tested
/// in isolation — mirrors [FocusOrbitTimer]. Pass `motion: false` to freeze in
/// the calm "defragmented" state for a deterministic frame.
class DefragPreview extends StatefulWidget {
  final double size;
  final Color gold; // c.accent — warm (right half)
  final Color gold2; // c.accentSecondary — warm deep
  final Color goldLight; // kRimLight — warm rim
  final Color cold; // c.focusBreak — cold (left half)
  final Color glass; // c.glass
  final Color trackColor; // c.border
  final bool isLight;
  final bool motion; // when false, rests in the settled state

  const DefragPreview({
    super.key,
    this.size = 150,
    required this.gold,
    required this.gold2,
    required this.goldLight,
    required this.cold,
    required this.glass,
    required this.trackColor,
    this.isLight = false,
    this.motion = true,
  });

  @override
  State<DefragPreview> createState() => _DefragPreviewState();
}

class _DefragPreviewState extends State<DefragPreview>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl; // breathing scale
  late final AnimationController _defragCtrl; // converge ↔ disperse cycle
  late final AnimationController _driftCtrl; // slow seamless rotation
  late final Animation<double> _pulse;
  late final Animation<double> _defrag;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _pulse = Tween<double>(begin: 0.94, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _defragCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _defrag = CurvedAnimation(
      parent: _defragCtrl,
      curve: Curves.easeInOut,
    );
    _driftCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
    if (widget.motion) {
      _pulseCtrl.repeat(reverse: true);
      _defragCtrl.repeat(reverse: true);
      _driftCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _defragCtrl.dispose();
    _driftCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When motion is off, rest in the calm "defragmented" state (p = 1).
    final p = widget.motion ? _defrag.value : 1.0;
    final drift = widget.motion ? _driftCtrl.value * 2 * math.pi : 0.0;
    final scale = widget.motion ? _pulse.value : 1.0;
    return Center(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulse, _defrag, _driftCtrl]),
          builder: (_, _) {
            return Transform.scale(
              scale: scale,
              child: CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _DefragPreviewPainter(
                  p: p,
                  drift: drift,
                  isLight: widget.isLight,
                  glass: widget.glass,
                  gold: widget.gold,
                  gold2: widget.gold2,
                  goldLight: widget.goldLight,
                  cold: widget.cold,
                  trackColor: widget.trackColor,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A shard spec: its settled slot on the inner orbit plus its scattered pose
/// at the outer rim. Convergence `p` interpolates between the two.
class _Shard {
  final double slotAngle; // angle on the ordered orbit
  final double slotRadius; // radius of the ordered orbit
  final double scatterAngle; // angular jitter when scattered
  final double scatterRadius; // outer-rim radius when scattered
  final double spin; // rotation offset when scattered
  final double size; // chip half-size

  const _Shard({
    required this.slotAngle,
    required this.slotRadius,
    required this.scatterAngle,
    required this.scatterRadius,
    required this.spin,
    required this.size,
  });
}

class _DefragPreviewPainter extends CustomPainter {
  final double p; // convergence 0 (scattered) .. 1 (ordered)
  final double drift; // slow seamless rotation, radians
  final bool isLight;
  final Color glass;
  final Color gold;
  final Color gold2;
  final Color goldLight;
  final Color cold;
  final Color trackColor;

  const _DefragPreviewPainter({
    required this.p,
    required this.drift,
    required this.isLight,
    required this.glass,
    required this.gold,
    required this.gold2,
    required this.goldLight,
    required this.cold,
    required this.trackColor,
  });

  // Fixed shard layout — deterministic, no per-paint randomness.
  static const _orbitR = 52.0;
  static const _shards = <_Shard>[
    _Shard(slotAngle: 0.00, slotRadius: _orbitR, scatterAngle: -0.18, scatterRadius: 71, spin: 0.9, size: 4.6),
    _Shard(slotAngle: 0.63, slotRadius: _orbitR, scatterAngle: 0.22, scatterRadius: 74, spin: -0.6, size: 4.0),
    _Shard(slotAngle: 1.26, slotRadius: _orbitR, scatterAngle: -0.30, scatterRadius: 70, spin: 1.1, size: 5.0),
    _Shard(slotAngle: 1.89, slotRadius: _orbitR, scatterAngle: 0.14, scatterRadius: 73, spin: -0.4, size: 3.8),
    _Shard(slotAngle: 2.52, slotRadius: _orbitR, scatterAngle: 0.34, scatterRadius: 75, spin: 0.7, size: 4.4),
    _Shard(slotAngle: 3.15, slotRadius: _orbitR, scatterAngle: -0.10, scatterRadius: 71, spin: -0.9, size: 4.2),
    _Shard(slotAngle: 3.78, slotRadius: _orbitR, scatterAngle: 0.26, scatterRadius: 74, spin: 0.5, size: 4.8),
    _Shard(slotAngle: 4.41, slotRadius: _orbitR, scatterAngle: -0.34, scatterRadius: 70, spin: -1.0, size: 3.6),
    _Shard(slotAngle: 5.04, slotRadius: _orbitR, scatterAngle: 0.10, scatterRadius: 73, spin: 0.8, size: 4.5),
    _Shard(slotAngle: 5.67, slotRadius: _orbitR, scatterAngle: -0.22, scatterRadius: 75, spin: -0.5, size: 4.1),
  ];

  static Offset _dir(double a) => Offset(math.cos(a), math.sin(a));

  void _dottedCircle(Canvas canvas, Offset center, double radius, Paint paint,
      {int dots = 72}) {
    for (var i = 0; i < dots; i++) {
      final a = i * 2 * math.pi / dots + drift;
      canvas.drawCircle(center + _dir(a) * radius, paint.strokeWidth / 2, paint);
    }
  }

  Path _shardPath(double size) {
    // A thin geometric glass chip — elongated diamond.
    return Path()
      ..moveTo(0, -size * 1.4)
      ..lineTo(size * 0.55, 0)
      ..lineTo(0, size * 1.4)
      ..lineTo(-size * 0.55, 0)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const coreR = 15.0;

    // Cold-side shard gradient stops — derived from the `cold` token
    // (c.focusBreak) pulled toward the shared teal-rim constants, so the left
    // half stays in the design-system palette while reading as a distinct cool
    // hue against the warm gold right half.
    final coldLight = Color.lerp(cold, kRimTealLight, 0.5)!;
    final coldDark = Color.lerp(cold, kRimTealDark, 0.5)!;

    // ── 1. Frosted glass discs (concentric depth) ───────────────────────────
    void disc(double rad, double fill, double stroke) {
      canvas.drawCircle(
          center, rad, Paint()..color = glass.withValues(alpha: fill));
      canvas.drawCircle(
        center,
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = glass.withValues(alpha: stroke),
      );
    }

    disc(72, isLight ? 0.09 : 0.05, isLight ? 0.22 : 0.10);
    disc(52, isLight ? 0.11 : 0.06, isLight ? 0.26 : 0.12);
    disc(34, isLight ? 0.12 : 0.07, isLight ? 0.30 : 0.15);

    // ── 2. Outer radar tick ring — longer cardinal ticks ─────────────────────
    const ticks = 36;
    const tickR = 72.0;
    for (var i = 0; i < ticks; i++) {
      final a = i * 2 * math.pi / ticks + drift;
      final cardinal = i % 9 == 0;
      final p1 = center + _dir(a) * (tickR - (cardinal ? 5 : 2.5));
      final p2 = center + _dir(a) * tickR;
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = gold
              .withValues(alpha: (isLight ? 0.45 : 0.40) * (cardinal ? 1 : 0.55))
          ..strokeWidth = cardinal ? 1.4 : 1
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── 3. Faint dotted orbital arcs (ordered orbit + inner + outer guide) ──
    _dottedCircle(
      canvas,
      center,
      _orbitR,
      Paint()
        ..color = gold.withValues(alpha: isLight ? 0.32 : 0.24)
        ..strokeWidth = 1.4,
    );
    _dottedCircle(
      canvas,
      center,
      66,
      Paint()
        ..color = trackColor.withValues(alpha: isLight ? 0.32 : 0.24)
        ..strokeWidth = 1.2,
      dots: 60,
    );
    _dottedCircle(
      canvas,
      center,
      38,
      Paint()
        ..color = gold.withValues(alpha: isLight ? 0.28 : 0.20)
        ..strokeWidth = 1.1,
      dots: 44,
    );

    // ── 3b. Quadrant axes — thin crosshair dividing the circle in four ──────
    for (final a in [0.0, math.pi / 2, math.pi, -math.pi / 2]) {
      final p1 = center + _dir(a) * (coreR + 4);
      final p2 = center + _dir(a) * tickR;
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = gold.withValues(alpha: isLight ? 0.20 : 0.15)
          ..strokeWidth = 0.8,
      );
    }

    // ── 4. Shards: scattered (dim frosted) → settled (bright) ───────────────
    // `ease` sharpens the settle so shards read as "snapping into order".
    // Color split: warm gold on the right half (cos ≥ 0), cool teal on the left.
    final ep = p * p * (3 - 2 * p); // smoothstep
    for (final s in _shards) {
      final angle = s.scatterAngle * (1 - ep) + s.slotAngle + drift * 0.4;
      final radius = s.scatterRadius * (1 - ep) + s.slotRadius * ep;
      final pos = center + _dir(angle) * radius;
      final rotation = s.spin * (1 - ep);
      final warm = math.cos(s.slotAngle) >= 0;
      final baseLight = warm ? goldLight : coldLight;
      final baseMain = warm ? gold : cold;
      final baseDeep = warm ? gold2 : coldDark;
      // Brightness: dim frosted at scatter → rich at settle.
      final fillA = (isLight ? 0.22 : 0.18) + ep * (isLight ? 0.50 : 0.55);
      final strokeA = (isLight ? 0.40 : 0.34) + ep * (isLight ? 0.45 : 0.50);

      // Spoke core → settled shard — only as the shard aligns.
      if (ep > 0.15) {
        canvas.drawLine(
          center,
          pos,
          Paint()
            ..color = glass.withValues(alpha: (isLight ? 0.26 : 0.20) * ep)
            ..strokeWidth = 1,
        );
      }

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(rotation);
      final path = _shardPath(s.size);
      // Frosted fill — warm gold (right) or cool teal (left) gradient.
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            baseLight.withValues(alpha: fillA * 0.7),
            baseMain.withValues(alpha: fillA),
            baseDeep.withValues(alpha: fillA),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: s.size * 1.6));
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = baseMain.withValues(alpha: strokeA),
      );
      // Settled shards get a soft halo for the "ignited" look.
      if (ep > 0.6 && !isLight) {
        canvas.drawCircle(
          Offset.zero,
          s.size * 0.9,
          Paint()
            ..color = baseMain.withValues(alpha: (ep - 0.6) * 0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
        );
      }
      canvas.restore();
    }

    // ── 5. Glowing gold-sand core ────────────────────────────────────────────
    const coreGlowR = 26.0;
    canvas.drawCircle(
      center,
      coreGlowR,
      Paint()
        ..color = gold.withValues(alpha: isLight ? 0.10 : 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Core sphere — warm radial gradient (light centre → bronze edge).
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..shader = RadialGradient(
          colors: [goldLight, gold, gold2],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: coreR)),
    );
    // Thin gold rim.
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = gold.withValues(alpha: isLight ? 0.55 : 0.7),
    );
    // Cardinal tick marks — tactical-instrument feel.
    for (final a in [0.0, math.pi / 2, math.pi, -math.pi / 2]) {
      final p1 = center + _dir(a) * (coreR + 3);
      final p2 = center + _dir(a) * (coreR + 6);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = gold.withValues(alpha: 0.8)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DefragPreviewPainter old) =>
      old.p != p ||
      old.drift != drift ||
      old.isLight != isLight ||
      old.glass != glass ||
      old.gold != gold ||
      old.gold2 != gold2 ||
      old.goldLight != goldLight ||
      old.cold != cold ||
      old.trackColor != trackColor;
}