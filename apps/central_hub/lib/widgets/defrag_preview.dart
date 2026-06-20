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

/// A shard spec: its settled slot on a concentric band plus its scattered pose
/// at the outer rim. Convergence `p` interpolates between the two.
class _Shard {
  final double slotAngle; // angle on the ordered orbit
  final double slotRadius; // radius of the ordered band
  final double scatterAngle; // angular jitter when scattered
  final double scatterRadius; // outer-rim radius when scattered
  final double spin; // rotation offset when scattered
  final double size; // chip half-size
  final int shapeType; // 0 diamond · 1 triangle · 2 shard · 3 pentagon
  final double bandDelay; // when this band starts converging (wave)

  const _Shard({
    required this.slotAngle,
    required this.slotRadius,
    required this.scatterAngle,
    required this.scatterRadius,
    required this.spin,
    required this.size,
    required this.shapeType,
    required this.bandDelay,
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

  // Three concentric bands of shards (inner → outer), denser toward the rim.
  // (radius, count, baseSize, convergence delay for the defrag wave)
  static const _bands = <({double r, int count, double size, double delay})>[
    (r: 32.0, count: 7, size: 3.6, delay: 0.00),
    (r: 49.0, count: 9, size: 4.3, delay: 0.12),
    (r: 66.0, count: 11, size: 5.0, delay: 0.24),
  ];

  // Deterministic layout (no per-paint randomness) — built once.
  static final List<_Shard> _shards = _buildShards();

  static List<_Shard> _buildShards() {
    final out = <_Shard>[];
    var idx = 0;
    for (var b = 0; b < _bands.length; b++) {
      final band = _bands[b];
      for (var k = 0; k < band.count; k++) {
        final slot = k * 2 * math.pi / band.count + b * 0.45;
        out.add(_Shard(
          slotAngle: slot,
          slotRadius: band.r,
          scatterAngle: math.sin(idx * 1.7) * 0.28,
          scatterRadius: 76.0 + (idx % 3) * 3.0,
          spin: math.sin(idx * 2.3),
          size: band.size + math.sin(idx * 0.9) * 0.6,
          shapeType: idx % 4,
          bandDelay: band.delay,
        ));
        idx++;
      }
    }
    return out;
  }

  static Offset _dir(double a) => Offset(math.cos(a), math.sin(a));

  void _dottedCircle(Canvas canvas, Offset center, double radius, Paint paint,
      {int dots = 72}) {
    for (var i = 0; i < dots; i++) {
      final a = i * 2 * math.pi / dots + drift;
      canvas.drawCircle(center + _dir(a) * radius, paint.strokeWidth / 2, paint);
    }
  }

  Path _shardPath(int type, double s) {
    switch (type) {
      case 1: // triangle
        return Path()
          ..moveTo(0, -s * 1.5)
          ..lineTo(s * 1.25, s * 1.0)
          ..lineTo(-s * 1.25, s * 1.0)
          ..close();
      case 2: // irregular shard
        return Path()
          ..moveTo(0, -s * 1.5)
          ..lineTo(s * 0.95, -s * 0.1)
          ..lineTo(s * 0.35, s * 1.35)
          ..lineTo(-s * 0.8, s * 0.5)
          ..close();
      case 3: // pentagon crystal
        final p = Path();
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + i * 2 * math.pi / 5;
          final o = Offset(math.cos(a) * s * 1.2, math.sin(a) * s * 1.2);
          i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
        }
        return p..close();
      default: // elongated diamond
        return Path()
          ..moveTo(0, -s * 1.4)
          ..lineTo(s * 0.55, 0)
          ..lineTo(0, s * 1.4)
          ..lineTo(-s * 0.55, 0)
          ..close();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const coreR = 18.0;

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

    // ── 3. Concentric band rings (smooth) — one per shard band, for depth ────
    for (final band in _bands) {
      canvas.drawCircle(
        center,
        band.r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = trackColor.withValues(alpha: isLight ? 0.30 : 0.18),
      );
    }

    // ── 3b. Faint dotted orbital guides (drifting) ───────────────────────────
    _dottedCircle(
      canvas,
      center,
      _bands[1].r,
      Paint()
        ..color = gold.withValues(alpha: isLight ? 0.32 : 0.24)
        ..strokeWidth = 1.3,
    );
    _dottedCircle(
      canvas,
      center,
      _bands[2].r,
      Paint()
        ..color = trackColor.withValues(alpha: isLight ? 0.30 : 0.22)
        ..strokeWidth = 1.2,
      dots: 60,
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
    for (final s in _shards) {
      // Per-band convergence wave — inner band settles first.
      final bp = ((p - s.bandDelay) / (1 - s.bandDelay)).clamp(0.0, 1.0);
      final ep = bp * bp * (3 - 2 * bp); // smoothstep
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
      final path = _shardPath(s.shapeType, s.size);
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

    // ── 5. Glowing gold-sand core — layered nebula halo + bright sphere ───────
    // Soft outer halos (nebula): large, faint, blurred — builds the "излучает
    // тёплое свечение" look of the reference core.
    canvas.drawCircle(
      center,
      coreR * 2.1,
      Paint()
        ..color = gold.withValues(alpha: isLight ? 0.06 : 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawCircle(
      center,
      coreR * 1.5,
      Paint()
        ..color = gold.withValues(alpha: isLight ? 0.10 : 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
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
    // Bright inner seed — concentrated highlight just off-centre.
    canvas.drawCircle(
      center.translate(-coreR * 0.12, -coreR * 0.12),
      coreR * 0.42,
      Paint()
        ..color = goldLight.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
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