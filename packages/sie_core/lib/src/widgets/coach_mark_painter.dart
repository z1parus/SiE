import 'package:flutter/material.dart';

/// Paints a dimmed scrim over the whole screen with a rounded "cutout" around
/// the spotlighted target, plus a soft gold outline + glow around the hole.
/// When [target] is null the whole area is dimmed (centred-card steps).
class CoachMarkPainter extends CustomPainter {
  final Rect? target;
  final Color dimColor;
  final Color accent;
  final double radius;
  final double padding;

  const CoachMarkPainter({
    required this.target,
    required this.dimColor,
    required this.accent,
    this.radius = 12,
    this.padding = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final dim = Paint()..color = dimColor;

    if (target == null) {
      canvas.drawPath(full, dim);
      return;
    }

    final rect = target!.inflate(padding);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final hole = Path()..addRRect(rr);
    canvas.drawPath(Path.combine(PathOperation.difference, full, hole), dim);

    // Soft outer glow.
    canvas.drawRRect(
      rr,
      Paint()
        ..color = accent.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Crisp gold outline.
    canvas.drawRRect(
      rr,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(CoachMarkPainter old) =>
      old.target != target ||
      old.dimColor != dimColor ||
      old.accent != accent;
}
