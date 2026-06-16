import 'dart:math';
import 'package:flutter/material.dart';
import '../models/cosmetic_asset.dart';
import 'neural_network_painter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Profile Pattern Renderer
// ─────────────────────────────────────────────────────────────────────────────

class ProfilePatternRenderer extends StatelessWidget {
  final CosmeticAsset? pattern;
  final Color accentColor;

  const ProfilePatternRenderer({
    super.key,
    required this.pattern,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (pattern == null) return const SizedBox.shrink();

    final type = pattern!.patternType;
    final color = accentColor.withValues(alpha: 0.15);

    return switch (type) {
      'neural'     => NeuralNetworkWidget(color: color),
      'low_poly'   => LowPolyPattern(color: color),
      'isometric'  => IsometricPattern(color: color),
      'dot_matrix' => DotMatrixPattern(color: color),
      _            => const SizedBox.shrink(),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dot Matrix Pattern
// ─────────────────────────────────────────────────────────────────────────────

class DotMatrixPattern extends StatelessWidget {
  final Color color;
  const DotMatrixPattern({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _DotMatrixPainter(color: color),
      ),
    );
  }
}

class _DotMatrixPainter extends CustomPainter {
  final Color color;
  _DotMatrixPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.screen;

    const spacing = 12.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotMatrixPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Isometric Cubes Pattern
// ─────────────────────────────────────────────────────────────────────────────

class IsometricPattern extends StatelessWidget {
  final Color color;
  const IsometricPattern({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _IsometricPainter(color: color),
      ),
    );
  }
}

class _IsometricPainter extends CustomPainter {
  final Color color;
  _IsometricPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.screen;

    const sizeW = 20.0;
    const sizeH = 12.0;

    for (double y = 0; y < size.height + sizeH; y += sizeH) {
      double offsetX = (y / sizeH).floor() % 2 == 0 ? 0 : sizeW / 2;
      for (double x = -sizeW; x < size.width + sizeW; x += sizeW) {
        _drawCube(canvas, Offset(x + offsetX, y), sizeW, sizeH, paint);
      }
    }
  }

  void _drawCube(Canvas canvas, Offset top, double w, double h, Paint paint) {
    // Top face
    paint.color = color.withValues(alpha: color.a * 0.8);
    final pathTop = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(top.dx + w / 2, top.dy + h / 2)
      ..lineTo(top.dx, top.dy + h)
      ..lineTo(top.dx - w / 2, top.dy + h / 2)
      ..close();
    canvas.drawPath(pathTop, paint);

    // Left face
    paint.color = color.withValues(alpha: color.a * 0.4);
    final pathLeft = Path()
      ..moveTo(top.dx - w / 2, top.dy + h / 2)
      ..lineTo(top.dx, top.dy + h)
      ..lineTo(top.dx, top.dy + h * 2)
      ..lineTo(top.dx - w / 2, top.dy + h * 1.5)
      ..close();
    canvas.drawPath(pathLeft, paint);

    // Right face
    paint.color = color.withValues(alpha: color.a * 0.6);
    final pathRight = Path()
      ..moveTo(top.dx + w / 2, top.dy + h / 2)
      ..lineTo(top.dx, top.dy + h)
      ..lineTo(top.dx, top.dy + h * 2)
      ..lineTo(top.dx + w / 2, top.dy + h * 1.5)
      ..close();
    canvas.drawPath(pathRight, paint);
  }

  @override
  bool shouldRepaint(_IsometricPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Low-Poly Pattern
// ─────────────────────────────────────────────────────────────────────────────

class LowPolyPattern extends StatelessWidget {
  final Color color;
  const LowPolyPattern({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _LowPolyPainter(color: color),
      ),
    );
  }
}

class _LowPolyPainter extends CustomPainter {
  final Color color;
  _LowPolyPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random(42);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.screen;

    const gridSize = 40.0;
    final cols = (size.width / gridSize).ceil() + 1;
    final rows = (size.height / gridSize).ceil() + 1;

    final points = List.generate(cols + 1, (i) {
      return List.generate(rows + 1, (j) {
        return Offset(
          i * gridSize + (rand.nextDouble() - 0.5) * gridSize * 0.8,
          j * gridSize + (rand.nextDouble() - 0.5) * gridSize * 0.8,
        );
      });
    });

    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < rows; j++) {
        final p1 = points[i][j];
        final p2 = points[i + 1][j];
        final p3 = points[i][j + 1];
        final p4 = points[i + 1][j + 1];

        // Triangle 1
        paint.color = color.withValues(alpha: color.a * (0.3 + rand.nextDouble() * 0.7));
        final path1 = Path()
          ..moveTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..close();
        canvas.drawPath(path1, paint);

        // Triangle 2
        paint.color = color.withValues(alpha: color.a * (0.3 + rand.nextDouble() * 0.7));
        final path2 = Path()
          ..moveTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..lineTo(p4.dx, p4.dy)
          ..close();
        canvas.drawPath(path2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_LowPolyPainter old) => old.color != color;
}
