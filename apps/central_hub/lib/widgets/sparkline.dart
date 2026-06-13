import 'dart:math' as math;
import 'package:flutter/material.dart';

class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.width = 80,
    this.height = 28,
    this.strokeWidth = 1.5,
  });

  final List<double> values;
  final Color color;
  final double width;
  final double height;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return SizedBox(width: width, height: height);
    return CustomPaint(
      size: Size(width, height),
      painter: _SparklinePainter(
        values: values,
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.strokeWidth,
  });

  final List<double> values;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (values.length == 1) {
      canvas.drawCircle(
          Offset(size.width / 2, size.height / 2), strokeWidth, paint);
      return;
    }

    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = maxV - minV;

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = range == 0
          ? size.height / 2
          : size.height - ((values[i] - minV) / range) * (size.height * 0.85) -
              (size.height * 0.075);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Highlight last point.
    if (values.isNotEmpty) {
      final lastX = size.width;
      final lastV = values.last;
      final lastY = range == 0
          ? size.height / 2
          : size.height -
              ((lastV - minV) / range) * (size.height * 0.85) -
              (size.height * 0.075);
      canvas.drawCircle(
          Offset(lastX, lastY), strokeWidth + 1, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}
