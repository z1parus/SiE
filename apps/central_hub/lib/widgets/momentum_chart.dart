import 'package:flutter/material.dart';
import 'package:sie_core/sie_core.dart';

// ─── Momentum display helpers (shared by stats screen + goal card) ────────────

({String label, IconData icon, Color color}) momentumDisplay(
    MomentumState state, SieColors sc) {
  switch (state) {
    case MomentumState.accelerating:
      return (label: 'УСКОРЯЕТСЯ', icon: Icons.trending_up, color: sc.success);
    case MomentumState.steady:
      return (label: 'СТАБИЛЬНО', icon: Icons.trending_flat, color: sc.accent);
    case MomentumState.stalling:
      return (label: 'ЗАМЕДЛЯЕТСЯ', icon: Icons.trending_down, color: sc.warning);
    case MomentumState.atRisk:
      return (label: 'ПОД УГРОЗОЙ', icon: Icons.trending_down, color: sc.danger);
    case MomentumState.noData:
      return (label: 'НЕТ ДАННЫХ', icon: Icons.more_horiz, color: sc.textSecondary);
  }
}

/// A lightweight progress-over-time chart: the actual progress line (0–100%)
/// plus an optional ideal burndown line to the deadline. CustomPainter, no
/// external chart dependency — consistent with SiE's painter-driven aesthetic.
class MomentumChart extends StatelessWidget {
  const MomentumChart({
    super.key,
    required this.snapshots,
    required this.color,
    required this.sc,
    this.deadline,
    this.goalCreatedAt,
    this.projected,
    this.height = 150,
  });

  final List<GoalProgressSnapshot> snapshots;
  final Color color;
  final SieColors sc;
  final DateTime? deadline;
  final DateTime? goalCreatedAt;
  final DateTime? projected;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _MomentumPainter(
          snapshots: snapshots,
          color: color,
          sc: sc,
          deadline: deadline,
          goalCreatedAt: goalCreatedAt,
          projected: projected,
        ),
      ),
    );
  }
}

class _MomentumPainter extends CustomPainter {
  _MomentumPainter({
    required this.snapshots,
    required this.color,
    required this.sc,
    this.deadline,
    this.goalCreatedAt,
    this.projected,
  });

  final List<GoalProgressSnapshot> snapshots;
  final Color color;
  final SieColors sc;
  final DateTime? deadline;
  final DateTime? goalCreatedAt;
  final DateTime? projected;

  @override
  void paint(Canvas canvas, Size size) {
    if (snapshots.isEmpty) return;

    const padTop = 8.0;
    const padBottom = 18.0; // room for x labels
    const padLeft = 28.0; // room for y labels (0/50/100)
    const padRight = 8.0;
    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;

    // Time axis: from goal start (or first snapshot) to deadline/projected/last.
    final sorted = [...snapshots]
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    final tStart = goalCreatedAt != null &&
            goalCreatedAt!.isBefore(sorted.first.capturedAt)
        ? goalCreatedAt!
        : sorted.first.capturedAt;
    final candidates = <DateTime>[
      sorted.last.capturedAt,
      if (deadline != null) deadline!,
      if (projected != null) projected!,
    ];
    var tEnd = candidates.reduce((a, b) => a.isAfter(b) ? a : b);
    var span = tEnd.difference(tStart).inMinutes.toDouble();
    if (span <= 0) {
      tEnd = tStart.add(const Duration(days: 1));
      span = tEnd.difference(tStart).inMinutes.toDouble();
    }

    double dx(DateTime t) =>
        padLeft + (t.difference(tStart).inMinutes / span) * chartW;
    double dy(double progress) =>
        padTop + (1 - (progress.clamp(0, 100) / 100)) * chartH;

    // ── Grid + y labels (0 / 50 / 100) ──
    final gridPaint = Paint()
      ..color = sc.border
      ..strokeWidth = 0.5;
    final textStyle = TextStyle(color: sc.textSecondary, fontSize: 8);
    for (final lvl in [0, 50, 100]) {
      final y = dy(lvl.toDouble());
      canvas.drawLine(Offset(padLeft, y), Offset(size.width - padRight, y),
          gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: '$lvl', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padLeft - tp.width - 4, y - tp.height / 2));
    }

    // ── Ideal burndown line (start,0 → deadline,100) ──
    if (deadline != null && goalCreatedAt != null) {
      final idealPaint = Paint()
        ..color = sc.textSecondary.withValues(alpha: 0.45)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      _drawDashedLine(
        canvas,
        Offset(dx(goalCreatedAt!), dy(0)),
        Offset(dx(deadline!), dy(100)),
        idealPaint,
      );
    }

    // ── Deadline vertical marker ──
    if (deadline != null) {
      final x = dx(deadline!);
      if (x <= size.width - padRight + 0.5) {
        final dlPaint = Paint()
          ..color = sc.danger.withValues(alpha: 0.5)
          ..strokeWidth = 1;
        _drawDashedLine(canvas, Offset(x, padTop),
            Offset(x, padTop + chartH), dlPaint, dash: 3, gap: 3);
      }
    }

    // ── Actual progress line ──
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final pts = <Offset>[];
    for (var i = 0; i < sorted.length; i++) {
      final p = Offset(dx(sorted[i].capturedAt), dy(sorted[i].progress));
      pts.add(p);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, linePaint);

    // Fill area under the line.
    if (pts.length >= 2) {
      final fill = Path.from(path)
        ..lineTo(pts.last.dx, dy(0))
        ..lineTo(pts.first.dx, dy(0))
        ..close();
      canvas.drawPath(
          fill,
          Paint()
            ..color = color.withValues(alpha: 0.08)
            ..style = PaintingStyle.fill);
    }

    // ── Projection segment (last actual → projected completion @100%) ──
    if (projected != null && sorted.isNotEmpty) {
      final projPaint = Paint()
        ..color = color.withValues(alpha: 0.55)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      _drawDashedLine(
        canvas,
        pts.last,
        Offset(dx(projected!), dy(100)),
        projPaint,
      );
      // Projected endpoint dot.
      canvas.drawCircle(Offset(dx(projected!), dy(100)), 3,
          Paint()..color = color.withValues(alpha: 0.7));
    }

    // ── Data dots ──
    final dotPaint = Paint()..color = color;
    for (final p in pts) {
      canvas.drawCircle(p, 2.5, dotPaint);
    }
    // Emphasise the latest point.
    canvas.drawCircle(pts.last, 4,
        Paint()..color = color.withValues(alpha: 0.25));
    canvas.drawCircle(pts.last, 2.5, dotPaint);
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint,
      {double dash = 5, double gap = 4}) {
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var dist = 0.0;
    while (dist < total) {
      final start = a + dir * dist;
      final end = a + dir * (dist + dash).clamp(0, total).toDouble();
      canvas.drawLine(start, end, paint);
      dist += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_MomentumPainter old) =>
      old.snapshots != snapshots ||
      old.color != color ||
      old.projected != projected;
}
