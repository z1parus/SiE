import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/cosmetic_asset.dart';
import '../theme/sie_motion.dart';

/// Decorative **stroke-only** pattern rendered on top of the profile background
/// inside [ProfileHeroCard]. No fills — the chosen background colour stays
/// visible between the thin luminous lines and remains dominant.
///
/// The line hue inherits the equipped background [accent]; the catalogue pattern
/// only decides the [CosmeticAsset.patternSlug] and overlay opacity.
/// Honours reduce-motion: a single static frame instead of a ticker.
///
/// Five patterns (slug → look), all in the app's gold / tactical language:
///   • `topo`             — flowing topographic contour lines
///   • `radar`            — concentric rings + rotating sweep
///   • `guilloche`        — fine interwoven premium curves (rosette)
///   • `hud_grid`         — sparse coordinate grid + crosshair ticks + brackets
///   • `sphere_meridians` — thin wireframe globe (lat/long), slow rotation
class ProfilePatternLayer extends StatefulWidget {
  const ProfilePatternLayer({
    super.key,
    required this.pattern,
    required this.accent,
  });

  /// Equipped pattern asset, if any.
  final CosmeticAsset? pattern;

  /// Base hue, inherited from the background accent.
  final Color accent;

  @override
  State<ProfilePatternLayer> createState() => _ProfilePatternLayerState();
}

class _ProfilePatternLayerState extends State<ProfilePatternLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // 8s seamless loop — alive but calm.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slug = widget.pattern?.patternSlug;
    if (slug == null) return const SizedBox.shrink();

    final motion = SieMotion.enabled(context);
    if (motion && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!motion && _ctrl.isAnimating) {
      _ctrl.stop();
    }

    final opacity = widget.pattern?.patternOpacity ?? 0.5;
    final color = widget.accent.withValues(alpha: opacity.clamp(0.0, 1.0));

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final painter = patternPainterForSlug(slug, color, time: _ctrl.value);
        if (painter == null) return const SizedBox.shrink();
        return SizedBox.expand(child: CustomPaint(painter: painter));
      },
    );
  }
}

/// Painter for a pattern [slug] tinted with [color] at animation [time]
/// (0..1 seamless loop). Returns null for unknown slugs.
CustomPainter? patternPainterForSlug(String slug, Color color,
    {double time = 0}) {
  return switch (slug) {
    'topo'             => TopoPainter(color: color, time: time),
    'radar'            => RadarPainter(color: color, time: time),
    'guilloche'        => GuillochePainter(color: color, time: time),
    'hud_grid'         => HudGridPainter(color: color, time: time),
    'sphere_meridians' => SphereMeridiansPainter(color: color, time: time),
    _                  => null,
  };
}

/// Static (non-animated) thumbnail of a pattern — used in shop/customization
/// grids where dozens of live tickers would be wasteful.
class ProfilePatternThumb extends StatelessWidget {
  const ProfilePatternThumb({
    super.key,
    required this.pattern,
    required this.accent,
  });

  final CosmeticAsset pattern;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = accent.withValues(
      alpha: pattern.patternOpacity.clamp(0.0, 1.0),
    );
    // A small non-zero time gives a more representative (mid-animation) frame.
    final painter = patternPainterForSlug(pattern.patternSlug, color, time: 0.2);
    if (painter == null) return const SizedBox.shrink();
    return SizedBox.expand(child: CustomPaint(painter: painter));
  }
}

double _frac(double v) => v - v.floorToDouble();

Color _a(Color c, double f) =>
    c.withValues(alpha: (c.a * f).clamp(0.0, 1.0));

// ── Topographic contour lines ────────────────────────────────────────────────

/// Flowing relief contour lines (tactical elevation map). Stroke-only.
class TopoPainter extends CustomPainter {
  TopoPainter({required this.color, this.time = 0});
  final Color color;
  final double time;

  static const _gap = 17.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final t = time * 2 * math.pi;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeJoin = StrokeJoin.round;

    var idx = 0;
    for (double baseY = -_gap; baseY < size.height + _gap; baseY += _gap, idx++) {
      final phase = idx * 0.7;
      final path = Path();
      var first = true;
      for (double x = 0; x <= size.width; x += 6) {
        final y = baseY +
            8.0 * math.sin(x * 0.022 + phase + t) +
            4.5 * math.sin(x * 0.011 - t * 0.8 + phase * 1.3);
        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
      paint.color = _a(color, idx.isEven ? 0.9 : 0.55);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(TopoPainter old) =>
      old.time != time || old.color != color;
}

// ── Radar sweep ──────────────────────────────────────────────────────────────

/// Concentric rings + radial ticks + a rotating sweep line with a faint trail.
class RadarPainter extends CustomPainter {
  RadarPainter({required this.color, this.time = 0});
  final Color color;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final center = Offset(size.width * 0.72, size.height * 0.5);
    final maxR = size.height * 0.66;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = _a(color, 0.6);
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxR * i / 3, ring);
    }

    // Radial ticks every 30°.
    final tick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = _a(color, 0.4);
    for (var k = 0; k < 12; k++) {
      final a = k * math.pi / 6;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(center + dir * (maxR * 0.86), center + dir * maxR, tick);
    }

    // Sweep line + fading trailing arc.
    final angle = -math.pi / 2 + time * 2 * math.pi;
    final rect = Rect.fromCircle(center: center, radius: maxR);
    final trail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    const seg = 8;
    for (var s = 0; s < seg; s++) {
      final a0 = angle - (s + 1) * 0.09;
      trail.color = _a(color, 0.5 * (1 - s / seg));
      canvas.drawArc(rect, a0, 0.09, false, trail);
    }
    final sweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = _a(color, 1.0)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawLine(
      center,
      center + Offset(math.cos(angle), math.sin(angle)) * maxR,
      sweep,
    );
  }

  @override
  bool shouldRepaint(RadarPainter old) =>
      old.time != time || old.color != color;
}

// ── Guilloché rosette ────────────────────────────────────────────────────────

/// Fine interwoven parametric curves, like the engine-turning on premium cards.
class GuillochePainter extends CustomPainter {
  GuillochePainter({required this.color, this.time = 0});
  final Color color;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;
    final baseR = math.min(size.width, size.height) * 0.42;
    final t = time * 2 * math.pi;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    for (var layer = 0; layer < 3; layer++) {
      final k = 5 + layer * 2;
      final amp = baseR * (0.16 + layer * 0.03);
      final phase = t + layer * 2 * math.pi / 3;
      final path = Path();
      var first = true;
      for (double th = 0; th <= 2 * math.pi + 0.05; th += 0.05) {
        final r = baseR * 0.74 +
            amp * math.cos(k * th + phase) +
            amp * 0.45 * math.cos((k + 3) * th - phase);
        final x = cx + r * math.cos(th);
        final y = cy + r * math.sin(th) * 0.62; // squashed to fit the wide card
        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
      paint.color = _a(color, 0.85 - layer * 0.18);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(GuillochePainter old) =>
      old.time != time || old.color != color;
}

// ── HUD tactical grid ────────────────────────────────────────────────────────

/// Sparse coordinate grid with crosshair ticks, corner brackets and a soft
/// horizontal scan line.
class HudGridPainter extends CustomPainter {
  HudGridPainter({required this.color, this.time = 0});
  final Color color;
  final double time;

  static const _step = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = _a(color, 0.3);
    for (double x = _step; x < size.width; x += _step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = _step; y < size.height; y += _step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Crosshair "+" ticks at every other intersection.
    final tick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = _a(color, 0.7);
    var col = 0;
    for (double x = _step; x < size.width; x += _step, col++) {
      var row = 0;
      for (double y = _step; y < size.height; y += _step, row++) {
        if ((col + row).isOdd) continue;
        canvas.drawLine(Offset(x - 2.5, y), Offset(x + 2.5, y), tick);
        canvas.drawLine(Offset(x, y - 2.5), Offset(x, y + 2.5), tick);
      }
    }

    // Corner brackets.
    final bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _a(color, 0.85);
    const m = 8.0, len = 14.0;
    final w = size.width, h = size.height;
    void corner(Offset o, double dx, double dy) {
      canvas.drawLine(o, o + Offset(len * dx, 0), bracket);
      canvas.drawLine(o, o + Offset(0, len * dy), bracket);
    }
    corner(Offset(m, m), 1, 1);
    corner(Offset(w - m, m), -1, 1);
    corner(Offset(m, h - m), 1, -1);
    corner(Offset(w - m, h - m), -1, -1);

    // Soft scan line.
    final scanY = size.height * _frac(time);
    final scan = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = _a(color, 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), scan);
  }

  @override
  bool shouldRepaint(HudGridPainter old) =>
      old.time != time || old.color != color;
}

// ── Sphere meridians (wireframe globe) ───────────────────────────────────────

/// Thin wireframe globe — latitude rings + rotating longitude arcs. Echoes the
/// app's golden breathing sphere. Stroke-only.
class SphereMeridiansPainter extends CustomPainter {
  SphereMeridiansPainter({required this.color, this.time = 0});
  final Color color;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;
    final r = math.min(size.width, size.height) * 0.46;
    final t = time * 2 * math.pi;

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = _a(color, 0.85);
    canvas.drawCircle(Offset(cx, cy), r, outline);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Latitudes — horizontal ellipses at fixed heights.
    for (var i = -2; i <= 2; i++) {
      if (i == 0) continue;
      final lat = i * math.pi / 7;
      final ly = cy + r * math.sin(lat);
      final rx = r * math.cos(lat);
      line.color = _a(color, 0.5);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, ly), width: rx * 2, height: rx * 0.5),
        line,
      );
    }

    // Longitudes — vertical ellipses whose width oscillates → globe rotation.
    for (var i = 0; i < 4; i++) {
      final phase = t + i * math.pi / 4;
      final rx = (r * math.cos(phase)).abs();
      line.color = _a(color, 0.4 + 0.4 * (rx / r));
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: r * 2),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(SphereMeridiansPainter old) =>
      old.time != time || old.color != color;
}
