import 'dart:math';
import 'package:flutter/material.dart';

// Gold palette shared across session orbs
const kRimGold   = Color(0xFFC8A84B);
const kRimBronze = Color(0xFFAA7744);
const kRimLight  = Color(0xFFD9BB65);

// Teal palette for meditation orb
const kRimTeal      = Color(0xFF4ECDC4);
const kRimTealLight = Color(0xFF80E8E0);
const kRimTealDark  = Color(0xFF2BA8A0);

class SphereRimPainter extends CustomPainter {
  final double lightAngle;
  final double intensity;
  final bool isDark;
  final Color rimGold;
  final Color rimBronze;
  final Color rimLight;

  const SphereRimPainter({
    required this.lightAngle,
    required this.intensity,
    required this.isDark,
    this.rimGold   = kRimGold,
    this.rimBronze = kRimBronze,
    this.rimLight  = kRimLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center    = Offset(size.width / 2, size.height / 2);
    final radius    = size.width / 2 - 1.0;
    final rect      = Rect.fromCircle(center: center, radius: radius);
    final baseAlpha = (0.75 + intensity * 0.15).clamp(0.0, 1.0);

    final peakAngle = lightAngle - pi / 2;

    final gradient = SweepGradient(
      startAngle: peakAngle - pi,
      endAngle:   peakAngle + pi,
      colors: [
        rimBronze.withValues(alpha: baseAlpha * 0.80),
        rimGold  .withValues(alpha: baseAlpha * 0.92),
        rimLight .withValues(alpha: baseAlpha * 1.00),
        rimGold  .withValues(alpha: baseAlpha * 0.92),
        rimBronze.withValues(alpha: baseAlpha * 0.80),
      ],
      stops: const [0.0, 0.28, 0.50, 0.72, 1.0],
    );

    final rimPaint = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..shader      = gradient.createShader(rect);
    canvas.drawCircle(center, radius, rimPaint);
  }

  @override
  bool shouldRepaint(SphereRimPainter old) =>
      lightAngle != old.lightAngle || intensity != old.intensity;
}
