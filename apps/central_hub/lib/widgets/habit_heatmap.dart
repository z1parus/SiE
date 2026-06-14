import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:sie_core/sie_core.dart';

/// Grid heatmap similar to GitHub contribution graph.
///
/// Columns are ISO weeks (Mon on top), newest on the right.
/// [logDates] is the Set<String> of 'YYYY-MM-DD' dates where the habit was
/// completed (or where the daily target was met for metric habits).
/// [logValues] is optional Map<dateKey, value> used to shade metric habits
/// by intensity (value/target ratio) instead of binary on/off.
class HabitHeatmap extends StatelessWidget {
  final Habit habit;
  final Set<String> logDates;
  final Map<String, double> logValues;
  final SieColors sc;
  final int weeks; // number of weeks to show
  final Color accentColor;

  const HabitHeatmap({
    super.key,
    required this.habit,
    required this.logDates,
    required this.sc,
    required this.accentColor,
    this.logValues = const {},
    this.weeks = 16,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _HeatmapPainter(
          habit: habit,
          logDates: logDates,
          logValues: logValues,
          accentColor: accentColor,
          emptyColor: sc.border.withValues(alpha: 0.4),
          weeks: weeks,
        ),
        size: Size(double.infinity, weeks <= 16 ? 88 : 140),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final Habit habit;
  final Set<String> logDates;
  final Map<String, double> logValues;
  final Color accentColor;
  final Color emptyColor;
  final int weeks;

  _HeatmapPainter({
    required this.habit,
    required this.logDates,
    required this.logValues,
    required this.accentColor,
    required this.emptyColor,
    required this.weeks,
  });

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void paint(Canvas canvas, Size size) {
    // Layout: 7 rows (Mon–Sun), [weeks] columns.
    // Leave left margin for weekday labels.
    const labelW = 22.0;
    const gap    = 2.0;
    final cellW  = (size.width - labelW - gap * (weeks - 1)) / weeks;
    final cellH  = (size.height - gap * 6) / 7;

    final today     = DateTime.now();
    // Align right edge to end of current week (or today).
    final todayMidnight = DateTime(today.year, today.month, today.day);

    // rightmost column = week containing today (partial).
    // column index 0 = oldest week on the left.
    final colDates = <DateTime>[];
    // Monday of the week that contains today.
    final currentWeekMon = todayMidnight.subtract(
        Duration(days: todayMidnight.weekday - 1));
    for (var w = weeks - 1; w >= 0; w--) {
      colDates.add(currentWeekMon.subtract(Duration(days: w * 7)));
    }

    final firstLog = firstLogDate(logDates);
    final targetVal = habit.effectiveTarget;
    final isMetric  = habit.isMetric;

    for (var col = 0; col < weeks; col++) {
      final weekMon = colDates[col];
      for (var row = 0; row < 7; row++) {
        final day = weekMon.add(Duration(days: row));
        if (day.isAfter(todayMidnight)) continue;

        final key       = _key(day);
        final scheduled = isScheduledOn(habit, day, firstLog: firstLog);
        final done      = logDates.contains(key);

        Color fill;
        if (!scheduled) {
          fill = emptyColor.withValues(alpha: 0.15);
        } else if (done) {
          if (isMetric) {
            final val = logValues[key] ?? 0;
            final ratio = (val / targetVal).clamp(0.0, 1.0);
            fill = Color.lerp(
                accentColor.withValues(alpha: 0.15),
                accentColor,
                ratio)!;
          } else {
            fill = accentColor;
          }
        } else {
          fill = emptyColor;
        }

        final left = labelW + col * (cellW + gap);
        final top  = row * (cellH + gap);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, cellW, cellH),
          const Radius.circular(2),
        );
        canvas.drawRRect(rect, Paint()..color = fill);
      }
    }

    // Weekday labels (Mo/Вт/Чт/Сб — even rows only).
    const labels = ['Пн', '', 'Ср', '', 'Пт', '', 'Вс'];
    final textStyle = TextStyle(
      color: emptyColor.withValues(alpha: 0.9),
      fontSize: 8,
      fontWeight: FontWeight.w500,
    );
    for (var row = 0; row < 7; row += 2) {
      final tp = TextPainter(
        text: TextSpan(text: labels[row], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, row * (cellH + gap) + (cellH - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.logDates != logDates ||
      old.logValues != logValues ||
      old.weeks != weeks;
}

/// Simplified heatmap for the dashboard overview — shows aggregated daily
/// completion fraction (0..1) across all habits via [completionByDate].
class AggregateHeatmap extends StatelessWidget {
  final Map<String, double> completionByDate; // dateKey → 0..1
  final SieColors sc;
  final Color accentColor;
  final int days;

  const AggregateHeatmap({
    super.key,
    required this.completionByDate,
    required this.sc,
    required this.accentColor,
    this.days = 28,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _AggregatePainter(
          completionByDate: completionByDate,
          accentColor: accentColor,
          emptyColor: sc.border.withValues(alpha: 0.35),
          days: days,
        ),
        size: const Size(double.infinity, 72),
      ),
    );
  }
}

class _AggregatePainter extends CustomPainter {
  final Map<String, double> completionByDate;
  final Color accentColor;
  final Color emptyColor;
  final int days;

  _AggregatePainter({
    required this.completionByDate,
    required this.accentColor,
    required this.emptyColor,
    required this.days,
  });

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void paint(Canvas canvas, Size size) {
    const gap  = 3.0;
    final cellW = (size.width - gap * (days - 1)) / days;
    const cellH = 72.0;

    final today = DateTime.now();

    for (var i = days - 1; i >= 0; i--) {
      final day   = today.subtract(Duration(days: i));
      final key   = _key(day);
      final rate  = completionByDate[key] ?? 0;
      final alpha = rate == 0 ? 0.0 : 0.15 + rate * 0.85;
      final fill  = rate == 0
          ? emptyColor
          : accentColor.withValues(alpha: alpha);
      final col   = days - 1 - i;
      final rect  = RRect.fromRectAndRadius(
        Rect.fromLTWH(col * (cellW + gap), 0, cellW, cellH),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, Paint()..color = fill);
    }
  }

  @override
  bool shouldRepaint(_AggregatePainter old) =>
      old.completionByDate != completionByDate;
}
