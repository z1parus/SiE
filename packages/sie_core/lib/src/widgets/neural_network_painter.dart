import 'dart:math';
import 'package:flutter/material.dart';

// ── Static seed data (computed once) ─────────────────────────────────────────
final _baseNodes = _generate(48, 42, (r) => Offset(r.nextDouble(), r.nextDouble()));
final _phases    = _generate(48, 99, (r) => r.nextDouble() * 2 * pi);
final _speeds    = _generate(48, 77, (r) => 0.25 + r.nextDouble() * 0.75);

List<T> _generate<T>(int n, int seed, T Function(Random) fn) {
  final r = Random(seed);
  return List.generate(n, (_) => fn(r));
}

// ── Painter ───────────────────────────────────────────────────────────────────
class NeuralNetworkPainter extends CustomPainter {
  final Color color;
  final double time; // 0..1 loops

  const NeuralNetworkPainter({required this.color, this.time = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final t       = time * 2 * pi;
    final maxDist = size.shortestSide * 0.40;

    // Animate node positions
    final nodes = List.generate(_baseNodes.length, (i) {
      final base  = _baseNodes[i];
      final phase = _phases[i];
      final spd   = _speeds[i];
      return Offset(
        (base.dx * size.width  + sin(t * spd + phase) * 14).clamp(0, size.width),
        (base.dy * size.height + cos(t * spd * 0.8 + phase + 1.3) * 11).clamp(0, size.height),
      );
    });

    final linePaint = Paint()
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final nodePaint = Paint()..style = PaintingStyle.fill;

    // Lines
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final dist = (nodes[i] - nodes[j]).distance;
        if (dist < maxDist) {
          final fade = pow(1.0 - dist / maxDist, 1.4) as double;
          linePaint.color = color.withValues(alpha: (color.a * fade).clamp(0, 1));
          canvas.drawLine(nodes[i], nodes[j], linePaint);
        }
      }
    }

    // Nodes with subtle pulse
    for (int i = 0; i < nodes.length; i++) {
      final pulse = 1.0 + sin(t * _speeds[i] * 1.6 + _phases[i]) * 0.35;
      nodePaint.color = color.withValues(alpha: (color.a * (0.7 + pulse * 0.15)).clamp(0, 1));
      canvas.drawCircle(nodes[i], 2.2 * pulse, nodePaint);
    }
  }

  @override
  bool shouldRepaint(NeuralNetworkPainter old) =>
      old.time != time || old.color != color;
}

// ── Animated widget wrapper ───────────────────────────────────────────────────
class NeuralNetworkWidget extends StatefulWidget {
  final Color color;
  const NeuralNetworkWidget({super.key, required this.color});

  @override
  State<NeuralNetworkWidget> createState() => _NeuralNetworkWidgetState();
}

class _NeuralNetworkWidgetState extends State<NeuralNetworkWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => SizedBox.expand(
        child: CustomPaint(
          painter: NeuralNetworkPainter(color: widget.color, time: _ctrl.value),
        ),
      ),
    );
  }
}
