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
    this.size = 172,
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
  final int shapeType; // 0 diamond · 1 triangle · 2 shard · 3 pentagon · 4 hexagon
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

/// Small static accent crystals that sit between the main shard bands.
class _Connector {
  final double angle;
  final double radius;
  final double size;
  final int shapeType; // 0 dot · 1 hexagon

  const _Connector({
    required this.angle,
    required this.radius,
    required this.size,
    required this.shapeType,
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
    (r: 34.0, count: 8, size: 4.8, delay: 0.00),
    (r: 52.0, count: 11, size: 5.8, delay: 0.14),
    (r: 70.0, count: 14, size: 6.8, delay: 0.28),
  ];

  // Small connector chips placed halfway between shard bands to mimic the fine
  // detail in the reference mandala.
  static const _connectorBands = <({double r, int count, double size})>[
    (r: 43.0, count: 10, size: 2.4),
    (r: 61.0, count: 13, size: 2.8),
  ];

  // Deterministic layout (no per-paint randomness) — built once.
  static final List<_Shard> _shards = _buildShards();
  static final List<_Connector> _connectors = _buildConnectors();

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
          scatterRadius: 82.0 + (idx % 3) * 4.0,
          spin: math.sin(idx * 2.3),
          size: band.size *
              (1.0 + (idx % 5 == 0 ? 0.35 : 0.0) + math.sin(idx * 0.9) * 0.12),
          shapeType: idx % 5,
          bandDelay: band.delay,
        ));
        idx++;
      }
    }
    return out;
  }

  static List<_Connector> _buildConnectors() {
    final out = <_Connector>[];
    var idx = 0;
    for (final band in _connectorBands) {
      for (var k = 0; k < band.count; k++) {
        final a = k * 2 * math.pi / band.count + idx * 0.55;
        out.add(_Connector(
          angle: a,
          radius: band.r,
          size: band.size,
          shapeType: idx % 2,
        ));
      }
      idx++;
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
      case 4: // hexagon crystal
        final p = Path();
        for (var i = 0; i < 6; i++) {
          final a = -math.pi / 2 + i * math.pi / 3;
          final o = Offset(math.cos(a) * s * 1.15, math.sin(a) * s * 1.15);
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
    const coreR = 26.0;

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

    disc(76, isLight ? 0.09 : 0.05, isLight ? 0.22 : 0.10);
    disc(52, isLight ? 0.11 : 0.06, isLight ? 0.26 : 0.12);
    disc(34, isLight ? 0.12 : 0.07, isLight ? 0.30 : 0.15);

    // ── 2. Outer radar tick ring — longer cardinal ticks ─────────────────────
    const ticks = 48;
    const tickR = 80.0;
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
              .withValues(alpha: (isLight ? 0.55 : 0.50) * (cardinal ? 1 : 0.65))
          ..strokeWidth = cardinal ? 1.6 : 1.1
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
      final fillA = (isLight ? 0.32 : 0.26) + ep * (isLight ? 0.52 : 0.58);
      final strokeA = (isLight ? 0.60 : 0.55) + ep * (isLight ? 0.40 : 0.45);

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
      // Soft inner glow behind every shard for the glassy "ignited" look.
      canvas.drawCircle(
        Offset.zero,
        s.size * 1.1,
        Paint()
          ..color = baseMain.withValues(alpha: fillA * 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      // Frosted fill — warm gold (right) or cool teal (left) gradient.
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseLight.withValues(alpha: fillA * 0.8),
            baseMain.withValues(alpha: fillA),
            baseDeep.withValues(alpha: fillA * 0.9),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: s.size * 1.7));
      canvas.drawPath(path, fillPaint);
      // Main edge — slightly brighter to define the crystal silhouette.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = baseMain.withValues(alpha: strokeA),
      );
      // Top-left glossy highlight edge (glass reflection).
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = Colors.white.withValues(alpha: isLight ? 0.55 : 0.75),
      );
      canvas.restore();
    }

    // ── 4b. Small static connector chips between shard bands ──────────────────
    // These add the fine grain detail visible in the reference mandala.
    for (final conn in _connectors) {
      final pos = center + _dir(conn.angle + drift * 0.25) * conn.radius;
      final warm = math.cos(conn.angle) >= 0;
      final baseMain = warm ? gold : cold;
      final fillA = isLight ? 0.20 : 0.16;
      final strokeA = isLight ? 0.45 : 0.40;

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      if (conn.shapeType == 1) {
        final path = Path();
        for (var i = 0; i < 6; i++) {
          final a = -math.pi / 2 + i * math.pi / 3;
          final o = Offset(math.cos(a) * conn.size, math.sin(a) * conn.size);
          i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()..color = baseMain.withValues(alpha: fillA),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = baseMain.withValues(alpha: strokeA),
        );
      } else {
        canvas.drawCircle(
          Offset.zero,
          conn.size * 0.7,
          Paint()..color = baseMain.withValues(alpha: fillA),
        );
        canvas.drawCircle(
          Offset.zero,
          conn.size * 0.7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = baseMain.withValues(alpha: strokeA),
        );
      }
      canvas.restore();
    }

    // ── 5. Glowing gold-sand core — layered nebula halo + bright sphere ───────
    // Reference-style sun-like core: multiple blurred halos for a soft nimbus,
    // then a bright radial sphere and a hot highlight seed.
    final haloBaseAlpha = isLight ? 0.08 : 0.12;
    for (final (radiusMul, blur, alphaMul) in [
      (3.2, 28.0, 1.0),
      (2.6, 20.0, 1.4),
      (2.0, 12.0, 1.85),
      (1.5, 6.0, 2.2),
    ]) {
      canvas.drawCircle(
        center,
        coreR * radiusMul,
        Paint()
          ..color = gold.withValues(
              alpha: (haloBaseAlpha * alphaMul).clamp(0.0, 1.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }
    // Core sphere — warm radial gradient (light centre → bronze edge).
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..shader = RadialGradient(
          colors: [goldLight, gold, gold2],
          stops: const [0.0, 0.50, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: coreR)),
    );
    // Bright inner seed — concentrated highlight just off-centre.
    canvas.drawCircle(
      center.translate(-coreR * 0.10, -coreR * 0.10),
      coreR * 0.45,
      Paint()
        ..color = goldLight.withValues(alpha: 1.0)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // Extra hot pinpoint to keep the centre from going flat.
    canvas.drawCircle(
      center.translate(-coreR * 0.06, -coreR * 0.06),
      coreR * 0.22,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    // Thin gold rim.
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = gold.withValues(alpha: isLight ? 0.55 : 0.75),
    );
    // Cardinal tick marks — tactical-instrument feel.
    for (final a in [0.0, math.pi / 2, math.pi, -math.pi / 2]) {
      final p1 = center + _dir(a) * (coreR + 3);
      final p2 = center + _dir(a) * (coreR + 7);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = gold.withValues(alpha: 0.85)
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