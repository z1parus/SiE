import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/cosmetic_asset.dart';
import '../theme/sie_motion.dart';
import 'neural_network_painter.dart';

/// Animated decorative pattern rendered on top of the profile background inside
/// [ProfileHeroCard].
///
/// The pattern hue inherits the equipped background [accent]; the catalogue
/// pattern only decides the [CosmeticAsset.patternSlug] and overlay opacity.
/// Honours reduce-motion: when motion is disabled the pattern renders a single
/// static frame instead of running a ticker.
///
/// Painter-based for now (self-contained, no shader asset registration);
/// `low_poly`/`iso_grid` are candidates to move to GLSL fragment shaders later.
class ProfilePatternLayer extends StatefulWidget {
  const ProfilePatternLayer({
    super.key,
    required this.pattern,
    required this.accent,
    this.legacyNeural = false,
  });

  /// Equipped pattern asset, if any.
  final CosmeticAsset? pattern;

  /// Base hue, inherited from the background accent.
  final Color accent;

  /// Render the neural pattern even without a [pattern] asset — used for
  /// backwards-compatibility with legacy backgrounds that set a custom colour
  /// or the `use_neural_pattern` flag.
  final bool legacyNeural;

  String? get _slug =>
      pattern?.patternSlug ?? (legacyNeural ? 'neural_threads' : null);

  @override
  State<ProfilePatternLayer> createState() => _ProfilePatternLayerState();
}

class _ProfilePatternLayerState extends State<ProfilePatternLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slug = widget._slug;
    if (slug == null) return const SizedBox.shrink();

    final motion = SieMotion.enabled(context);
    final opacity = widget.pattern?.patternOpacity ?? 0.40;
    final color = widget.accent.withValues(alpha: opacity.clamp(0.0, 1.0));

    // The neural pattern has its own self-animating widget — no shared ticker.
    if (slug == 'neural_threads') {
      if (_ctrl.isAnimating) _ctrl.stop();
      return motion
          ? NeuralNetworkWidget(color: color)
          : CustomPaint(painter: NeuralNetworkPainter(color: color));
    }

    if (motion && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!motion && _ctrl.isAnimating) {
      _ctrl.stop();
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final painter = switch (slug) {
          'dot_matrix' => DotMatrixPainter(color: color, time: _ctrl.value),
          'low_poly'   => LowPolyPainter(color: color, time: _ctrl.value),
          'iso_grid'   => IsoGridPainter(color: color, time: _ctrl.value),
          _            => DotMatrixPainter(color: color, time: _ctrl.value),
        };
        return SizedBox.expand(child: CustomPaint(painter: painter));
      },
    );
  }
}

/// Painter for a pattern [slug] tinted with [color] at animation [time]
/// (0..1 loop). Returns null for unknown slugs.
CustomPainter? patternPainterForSlug(String slug, Color color,
    {double time = 0}) {
  return switch (slug) {
    'neural_threads' => NeuralNetworkPainter(color: color, time: time),
    'dot_matrix'     => DotMatrixPainter(color: color, time: time),
    'low_poly'       => LowPolyPainter(color: color, time: time),
    'iso_grid'       => IsoGridPainter(color: color, time: time),
    _                => null,
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
    final painter = patternPainterForSlug(pattern.patternSlug, color);
    if (painter == null) return const SizedBox.shrink();
    return SizedBox.expand(child: CustomPaint(painter: painter));
  }
}

// ── Dot matrix ───────────────────────────────────────────────────────────────

/// Strict grid of dots with a soft diagonal brightness wave travelling across.
class DotMatrixPainter extends CustomPainter {
  DotMatrixPainter({required this.color, this.time = 0});

  final Color color;
  final double time;

  static const _step = 16.0;
  static const _maxR = 1.7;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final diag = size.width + size.height;
    if (diag <= 0) return;

    for (double x = _step / 2; x < size.width; x += _step) {
      for (double y = _step / 2; y < size.height; y += _step) {
        final d = (x + y) / diag; // 0..1 along the diagonal
        final wave = 0.5 + 0.5 * math.sin(2 * math.pi * (d * 3 - time));
        final brightness = 0.30 + 0.70 * wave;
        paint.color = color.withValues(
          alpha: (color.a * brightness).clamp(0.0, 1.0),
        );
        canvas.drawCircle(Offset(x, y), _maxR * (0.7 + 0.3 * wave), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotMatrixPainter old) =>
      old.time != time || old.color != color;
}

// ── Low-poly mesh ────────────────────────────────────────────────────────────

/// Triangulated mesh whose faces shimmer with a slow domain-drifting value, and
/// a brighter highlight band that sweeps diagonally.
class LowPolyPainter extends CustomPainter {
  LowPolyPainter({required this.color, this.time = 0});

  final Color color;
  final double time;

  static const _cell = 48.0;

  static double _hash(int i, int j) {
    final h = math.sin(i * 127.1 + j * 311.7) * 43758.5453;
    return h - h.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final cols = (size.width / _cell).ceil() + 1;
    final rows = (size.height / _cell).ceil() + 1;
    final t = time * 2 * math.pi;

    Offset point(int i, int j) {
      final jx = (_hash(i, j) - 0.5) * _cell * 0.55;
      final jy = (_hash(i + 100, j + 100) - 0.5) * _cell * 0.55;
      final drift = math.sin(t + (i + j) * 0.6) * 2.5;
      return Offset(i * _cell + jx + drift, j * _cell + jy - drift);
    }

    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = color.withValues(alpha: (color.a * 0.35).clamp(0.0, 1.0));

    final diag = size.width + size.height;

    void tri(Offset a, Offset b, Offset cc) {
      final centroid = Offset(
        (a.dx + b.dx + cc.dx) / 3,
        (a.dy + b.dy + cc.dy) / 3,
      );
      final v = 0.5 +
          0.5 * math.sin(centroid.dx * 0.018 + centroid.dy * 0.022 + t);
      // Diagonal highlight sweep.
      final dpos = (centroid.dx + centroid.dy) / (diag <= 0 ? 1 : diag);
      final sweep = math.max(0.0, math.sin(math.pi * (dpos - time * 1.0)));
      final brightness = (0.16 + 0.42 * v + 0.45 * sweep * sweep).clamp(0.0, 1.0);

      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(cc.dx, cc.dy)
        ..close();
      fill.color = color.withValues(alpha: (color.a * brightness).clamp(0.0, 1.0));
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }

    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < rows; j++) {
        final p00 = point(i, j);
        final p10 = point(i + 1, j);
        final p01 = point(i, j + 1);
        final p11 = point(i + 1, j + 1);
        tri(p00, p10, p01);
        tri(p10, p11, p01);
      }
    }
  }

  @override
  bool shouldRepaint(LowPolyPainter old) =>
      old.time != time || old.color != color;
}

// ── Isometric cubes ──────────────────────────────────────────────────────────

/// Tiled isometric cubes (Q*bert style): hexagon split into three rhombi with
/// three shades. Top faces breathe with a diagonal highlight sweep.
class IsoGridPainter extends CustomPainter {
  IsoGridPainter({required this.color, this.time = 0});

  final Color color;
  final double time;

  static const _r = 22.0; // hexagon radius

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final hStep = _r * math.sqrt(3); // horizontal centre spacing
    final vStep = _r * 1.5; // vertical centre spacing
    final diag = size.width + size.height;

    // Pre-compute the 6 pointy-top hexagon vertices (angles 30..330 step 60).
    Offset vertex(Offset c, double angleDeg) {
      final a = angleDeg * math.pi / 180;
      return Offset(c.dx + _r * math.cos(a), c.dy + _r * math.sin(a));
    }

    final fill = Paint()..style = PaintingStyle.fill;

    void rhombus(Offset a, Offset b, Offset c2, Offset d, double shade) {
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c2.dx, c2.dy)
        ..lineTo(d.dx, d.dy)
        ..close();
      fill.color = color.withValues(alpha: (color.a * shade).clamp(0.0, 1.0));
      canvas.drawPath(path, fill);
    }

    int row = 0;
    for (double cy = 0; cy < size.height + _r; cy += vStep, row++) {
      final xOffset = (row.isOdd) ? hStep / 2 : 0.0;
      for (double cx = -hStep; cx < size.width + hStep; cx += hStep) {
        final c = Offset(cx + xOffset, cy);

        final v30 = vertex(c, 30);
        final v90 = vertex(c, 90);
        final v150 = vertex(c, 150);
        final v210 = vertex(c, 210);
        final v270 = vertex(c, 270);
        final v330 = vertex(c, 330);

        // Diagonal highlight sweep over the top faces.
        final dpos = (c.dx + c.dy) / (diag <= 0 ? 1 : diag);
        final sweep = math.max(0.0, math.sin(math.pi * (dpos - time)));
        final topShade = (0.30 + 0.55 * sweep * sweep).clamp(0.0, 1.0);

        rhombus(c, v30, v90, v150, topShade);      // top  (brightest)
        rhombus(c, v150, v210, v270, 0.12);         // left (darkest)
        rhombus(c, v270, v330, v30, 0.20);          // right(medium)
      }
    }
  }

  @override
  bool shouldRepaint(IsoGridPainter old) =>
      old.time != time || old.color != color;
}
