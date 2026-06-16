import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/cosmetic_asset.dart';
import '../theme/sie_motion.dart';

/// Animated decorative pattern rendered on top of the profile background inside
/// [ProfileHeroCard].
///
/// The pattern hue inherits the equipped background [accent]; the catalogue
/// pattern only decides the [CosmeticAsset.patternSlug] and overlay opacity.
/// Honours reduce-motion: when motion is disabled the pattern renders a single
/// static frame instead of running a ticker.
///
/// Four distinct painter-based patterns (slug → look):
///   • `neural_threads` — glowing nodes + web of lines with light pulses
///   • `low_poly`       — faceted triangular crystal mesh with a light sweep
///   • `iso_grid`       — isometric cube field (rhombille) with a highlight wave
///   • `dot_matrix`     — strict dot grid with a travelling brightness wave
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
    // 8s seamless loop — fast enough to read as "alive", slow enough to be calm.
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
    final slug = widget._slug;
    if (slug == null) return const SizedBox.shrink();

    final motion = SieMotion.enabled(context);
    if (motion && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!motion && _ctrl.isAnimating) {
      _ctrl.stop();
    }

    final opacity = widget.pattern?.patternOpacity ?? 0.40;
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
    'neural_threads' => NeuralThreadsPainter(color: color, time: time),
    'dot_matrix'     => DotMatrixPainter(color: color, time: time),
    'low_poly'       => LowPolyPainter(color: color, time: time),
    'iso_grid'       => IsoCubesPainter(color: color, time: time),
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
    // A small non-zero time gives the static thumbnail a more representative
    // (mid-animation) frame than the flat t=0 state.
    final painter = patternPainterForSlug(pattern.patternSlug, color, time: 0.18);
    if (painter == null) return const SizedBox.shrink();
    return SizedBox.expand(child: CustomPaint(painter: painter));
  }
}

double _frac(double v) => v - v.floorToDouble();

// ── Neural threads ───────────────────────────────────────────────────────────

/// Glowing nodes linked by a web of lines, with bright pulses travelling along
/// the edges — a living "digital mind" lattice.
class NeuralThreadsPainter extends CustomPainter {
  NeuralThreadsPainter({required this.color, this.time = 0});

  final Color color;
  final double time;

  static const _count = 22;
  static final List<Offset> _base =
      _seeded(_count, 7, (r) => Offset(r.nextDouble(), r.nextDouble()));
  static final List<double> _phase =
      _seeded(_count, 31, (r) => r.nextDouble() * 2 * math.pi);
  static final List<double> _amp =
      _seeded(_count, 53, (r) => 0.4 + r.nextDouble() * 0.9);

  static List<T> _seeded<T>(int n, int seed, T Function(math.Random) fn) {
    final r = math.Random(seed);
    return List.generate(n, (_) => fn(r));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final t = time * 2 * math.pi;
    final maxDist = size.shortestSide * 0.55;

    final nodes = List<Offset>.generate(_count, (i) {
      final b = _base[i];
      final a = _amp[i];
      return Offset(
        (b.dx * size.width + math.sin(t + _phase[i]) * 9 * a)
            .clamp(0, size.width),
        (b.dy * size.height + math.cos(t * 0.9 + _phase[i] * 1.3) * 7 * a)
            .clamp(0, size.height),
      );
    });

    final linePaint = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final pulsePaint = Paint()..style = PaintingStyle.fill;

    int edge = 0;
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final dist = (nodes[i] - nodes[j]).distance;
        if (dist >= maxDist) continue;
        final fade = math.pow(1.0 - dist / maxDist, 1.3) as double;
        linePaint.color =
            color.withValues(alpha: (color.a * (0.18 + 0.55 * fade)).clamp(0.0, 1.0));
        canvas.drawLine(nodes[i], nodes[j], linePaint);

        // A light pulse runs along every 3rd visible edge.
        if (edge % 3 == 0) {
          final p = _frac(time * 2 + (edge * 0.13));
          final pos = Offset.lerp(nodes[i], nodes[j], p)!;
          // Triangular fade so the pulse appears/disappears smoothly.
          final glow = (1.0 - (p - 0.5).abs() * 2) * fade;
          pulsePaint.color =
              color.withValues(alpha: (color.a * glow).clamp(0.0, 1.0));
          canvas.drawCircle(pos, 1.8, pulsePaint);
        }
        edge++;
      }
    }

    // Glowing nodes (soft halo + bright core).
    final halo = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final core = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < nodes.length; i++) {
      final pulse = 0.6 + 0.4 * math.sin(t * 1.6 + _phase[i]);
      halo.color = color.withValues(alpha: (color.a * 0.35 * pulse).clamp(0.0, 1.0));
      canvas.drawCircle(nodes[i], 4.2, halo);
      core.color = color.withValues(alpha: (color.a * (0.7 + 0.3 * pulse)).clamp(0.0, 1.0));
      canvas.drawCircle(nodes[i], 1.9, core);
    }
  }

  @override
  bool shouldRepaint(NeuralThreadsPainter old) =>
      old.time != time || old.color != color;
}

// ── Dot matrix ───────────────────────────────────────────────────────────────

/// Strict grid of dots with a soft diagonal brightness wave travelling across.
class DotMatrixPainter extends CustomPainter {
  DotMatrixPainter({required this.color, this.time = 0});

  final Color color;
  final double time;

  static const _step = 15.0;
  static const _maxR = 1.9;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final diag = size.width + size.height;
    if (diag <= 0) return;

    for (double x = _step / 2; x < size.width; x += _step) {
      for (double y = _step / 2; y < size.height; y += _step) {
        final d = (x + y) / diag; // 0..1 along the diagonal
        final wave = 0.5 + 0.5 * math.sin(2 * math.pi * (d * 3 - time * 2));
        final brightness = 0.22 + 0.78 * wave * wave;
        paint.color = color.withValues(
          alpha: (color.a * brightness).clamp(0.0, 1.0),
        );
        canvas.drawCircle(Offset(x, y), _maxR * (0.55 + 0.45 * wave), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotMatrixPainter old) =>
      old.time != time || old.color != color;
}

// ── Low-poly mesh ────────────────────────────────────────────────────────────

/// Triangulated crystal mesh whose faces shimmer with a slow domain-drifting
/// value, plus a brighter highlight band sweeping diagonally.
class LowPolyPainter extends CustomPainter {
  LowPolyPainter({required this.color, this.time = 0});

  final Color color;
  final double time;

  static const _cell = 46.0;

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
      ..strokeWidth = 0.7
      ..color = color.withValues(alpha: (color.a * 0.45).clamp(0.0, 1.0));

    final diag = size.width + size.height;

    void tri(Offset a, Offset b, Offset cc) {
      final centroid = Offset(
        (a.dx + b.dx + cc.dx) / 3,
        (a.dy + b.dy + cc.dy) / 3,
      );
      final v = 0.5 +
          0.5 * math.sin(centroid.dx * 0.02 + centroid.dy * 0.024 + t);
      final dpos = (centroid.dx + centroid.dy) / (diag <= 0 ? 1 : diag);
      final sweep = math.max(0.0, math.sin(2 * math.pi * (dpos - time)));
      final brightness =
          (0.12 + 0.38 * v + 0.5 * sweep * sweep).clamp(0.0, 1.0);

      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(cc.dx, cc.dy)
        ..close();
      fill.color =
          color.withValues(alpha: (color.a * brightness).clamp(0.0, 1.0));
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

// ── Isometric cubes (rhombille tiling) ───────────────────────────────────────

/// A field of isometric cubes drawn as a rhombille tiling — every flat-top
/// hexagon is split into three rhombi (top / left / right faces) shaded at
/// three brightness levels for a clean 3D look. A diagonal highlight wave
/// sweeps across the top faces.
class IsoCubesPainter extends CustomPainter {
  IsoCubesPainter({required this.color, this.time = 0});

  final Color color;
  final double time;

  static const _r = 16.0; // hexagon circumradius

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Flat-top hexagon vertices (angles 0,60,…300). y is screen-down.
    final verts = List<Offset>.generate(6, (k) {
      final a = k * 60 * math.pi / 180;
      return Offset(_r * math.cos(a), _r * math.sin(a));
    });

    final colStep = _r * 1.5;            // horizontal spacing between centres
    final rowStep = _r * math.sqrt(3);   // vertical spacing
    final diag = size.width + size.height;
    final fill = Paint()..style = PaintingStyle.fill;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = color.withValues(alpha: (color.a * 0.5).clamp(0.0, 1.0));

    void rhombus(Offset c, Offset a, Offset b, Offset d, double shade) {
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + a.dx, c.dy + a.dy)
        ..lineTo(c.dx + b.dx, c.dy + b.dy)
        ..lineTo(c.dx + d.dx, c.dy + d.dy)
        ..close();
      fill.color = color.withValues(alpha: (color.a * shade).clamp(0.0, 1.0));
      canvas.drawPath(path, fill);
      canvas.drawPath(path, edge);
    }

    int col = 0;
    for (double cx = 0; cx < size.width + _r; cx += colStep, col++) {
      final yOffset = col.isOdd ? rowStep / 2 : 0.0;
      for (double cy = -rowStep; cy < size.height + rowStep; cy += rowStep) {
        final c = Offset(cx, cy + yOffset);

        // Diagonal highlight sweep modulates the top-face brightness.
        final dpos = (c.dx + c.dy) / (diag <= 0 ? 1 : diag);
        final sweep = math.max(0.0, math.sin(2 * math.pi * (dpos - time)));
        final topShade = (0.34 + 0.5 * sweep * sweep).clamp(0.0, 1.0);

        // Three rhombi share the centre and two adjacent hexagon vertices.
        // {v4,v5,v0} reads as the bright top face; the other two as the
        // shaded side faces.
        rhombus(c, verts[4], verts[5] + verts[4], verts[5], topShade); // top
        rhombus(c, verts[2], verts[3] + verts[2], verts[3], 0.14);     // left
        rhombus(c, verts[0], verts[1] + verts[0], verts[1], 0.22);     // right
      }
    }
  }

  @override
  bool shouldRepaint(IsoCubesPainter old) =>
      old.time != time || old.color != color;
}
