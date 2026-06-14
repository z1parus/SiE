import 'habit.dart';

// ── Data class ─────────────────────────────────────────────────────────────────

class HabitMetrics {
  final int scheduledLast30;
  final int completedLast30;
  final int scheduledLast7;
  final int completedLast7;
  final int longestStreak;
  final int? bestWeekday;   // ISO 1=Mon..7=Sun; null if too little data
  final int? worstWeekday;
  final double? avgValueLast7;
  final String valueTrend; // 'up' | 'down' | 'flat' | 'none'
  final bool hasEnoughData; // false if < 7 days of history

  const HabitMetrics({
    required this.scheduledLast30,
    required this.completedLast30,
    required this.scheduledLast7,
    required this.completedLast7,
    required this.longestStreak,
    this.bestWeekday,
    this.worstWeekday,
    this.avgValueLast7,
    this.valueTrend = 'none',
    this.hasEnoughData = false,
  });

  static const empty = HabitMetrics(
    scheduledLast30: 0,
    completedLast30: 0,
    scheduledLast7: 0,
    completedLast7: 0,
    longestStreak: 0,
    valueTrend: 'none',
  );

  double get completionRate30d =>
      scheduledLast30 == 0 ? 0 : completedLast30 / scheduledLast30;

  double get completionRate7d =>
      scheduledLast7 == 0 ? 0 : completedLast7 / scheduledLast7;

  static HabitMetrics compute(
    Habit habit,
    Set<String> logDates,
    Map<String, double> logValues,
  ) {
    final now = DateTime.now();
    final first = firstLogDate(logDates);

    final hasData =
        first != null && now.difference(first).inDays >= 6;

    // 30-day window.
    final (sched30, comp30) =
        _completionInWindow(habit, logDates, now, days: 30);
    // 7-day window.
    final (sched7, comp7) =
        _completionInWindow(habit, logDates, now, days: 7);

    final longest = _longestStreak(habit, logDates, now);

    final (best, worst) =
        hasData ? _weekdayStats(habit, logDates, now) : (null, null);

    final (avg7, trend) = habit.isMetric
        ? _valueTrend(logValues, now)
        : (null, 'none');

    return HabitMetrics(
      scheduledLast30: sched30,
      completedLast30: comp30,
      scheduledLast7: sched7,
      completedLast7: comp7,
      longestStreak: longest,
      bestWeekday: best,
      worstWeekday: worst,
      avgValueLast7: avg7,
      valueTrend: trend,
      hasEnoughData: hasData,
    );
  }
}

// ── Pure computation helpers ──────────────────────────────────────────────────

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

(int scheduled, int completed) _completionInWindow(
  Habit habit,
  Set<String> logDates,
  DateTime now, {
  required int days,
}) {
  final from = _dateOnly(now).subtract(Duration(days: days - 1));
  final first = firstLogDate(logDates);
  final scheduled = scheduledDaysInRange(habit, from, now, firstLog: first);
  final completed =
      scheduled.where((d) => logDates.contains(habitDateKey(d))).length;
  return (scheduled.length, completed);
}

int _longestStreak(Habit habit, Set<String> logDates, DateTime now) {
  if (logDates.isEmpty) return 0;
  final first = firstLogDate(logDates);
  if (first == null) return 0;

  final schedule = habit.schedule;

  if (schedule.startsWith('weekly:')) {
    final target = int.tryParse(schedule.substring('weekly:'.length)) ?? 1;
    int max = 0, current = 0;
    var week = isoWeekStart(first);
    final currentWeekStart = isoWeekStart(now);
    while (!week.isAfter(now)) {
      final weekEnd = week.add(const Duration(days: 7));
      final logged = logDates.where((d) {
        final dt = DateTime.tryParse(d);
        return dt != null && !dt.isBefore(week) && dt.isBefore(weekEnd);
      }).length;
      if (logged >= target) {
        current++;
        if (current > max) max = current;
      } else if (week.isBefore(currentWeekStart)) {
        current = 0;
      }
      week = weekEnd;
    }
    return max;
  }

  if (schedule.startsWith('interval:')) {
    final n = int.tryParse(schedule.substring('interval:'.length)) ?? 2;
    int max = 0, current = 0;
    var anchor = _dateOnly(first);
    final today = _dateOnly(now);
    while (!anchor.isAfter(now)) {
      final periodEnd = anchor.add(Duration(days: n));
      final met = logDates.any((d) {
        final dt = DateTime.tryParse(d);
        return dt != null && !dt.isBefore(anchor) && dt.isBefore(periodEnd);
      });
      if (met) {
        current++;
        if (current > max) max = current;
      } else if (anchor.isBefore(today)) {
        current = 0;
      }
      anchor = periodEnd;
    }
    return max;
  }

  // daily / weekdays — streak over scheduled days.
  final scheduled =
      scheduledDaysInRange(habit, first, now, firstLog: first);
  int max = 0, current = 0;
  for (final day in scheduled) {
    if (logDates.contains(habitDateKey(day))) {
      current++;
      if (current > max) max = current;
    } else if (!_dateOnly(day).isAtSameMomentAs(_dateOnly(now))) {
      current = 0;
    }
  }
  return max;
}

(int? best, int? worst) _weekdayStats(
    Habit habit, Set<String> logDates, DateTime now) {
  final from = _dateOnly(now).subtract(const Duration(days: 90));
  final first = firstLogDate(logDates);
  final scheduled = scheduledDaysInRange(habit, from, now, firstLog: first);

  final totals = <int, int>{};   // weekday → scheduled count
  final done   = <int, int>{};   // weekday → completed count

  for (final day in scheduled) {
    final wd = day.weekday;
    totals[wd] = (totals[wd] ?? 0) + 1;
    if (logDates.contains(habitDateKey(day))) {
      done[wd] = (done[wd] ?? 0) + 1;
    }
  }

  // Only consider weekdays with ≥ 2 scheduled occurrences.
  final rates = {
    for (final e in totals.entries)
      if (e.value >= 2) e.key: (done[e.key] ?? 0) / e.value,
  };

  if (rates.isEmpty) return (null, null);

  final sorted = rates.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return (sorted.first.key, sorted.last.key);
}

(double? avg, String trend) _valueTrend(
    Map<String, double> logValues, DateTime now) {
  final today = _dateOnly(now);

  double _avg(int offsetStart, int offsetEnd) {
    var sum = 0.0;
    var count = 0;
    for (var i = offsetStart; i <= offsetEnd; i++) {
      final key =
          habitDateKey(today.subtract(Duration(days: i)));
      if (logValues.containsKey(key)) {
        sum += logValues[key]!;
        count++;
      }
    }
    return count == 0 ? 0 : sum / count;
  }

  final avg7  = _avg(0, 6);
  final avg14 = _avg(7, 13);

  String trend;
  if (avg7 == 0 && avg14 == 0) {
    trend = 'none';
  } else if (avg14 == 0) {
    trend = 'up';
  } else {
    final ratio = avg7 / avg14;
    trend = ratio > 1.1 ? 'up' : ratio < 0.9 ? 'down' : 'flat';
  }
  return (avg7 == 0 ? null : avg7, trend);
}

// ── Dashboard aggregate ───────────────────────────────────────────────────────

class HabitsDashboard {
  final int totalHabits;
  final double weeklyCompletionRate;
  final double monthlyCompletionRate;
  final List<_HabitRank> topHabits;
  final List<_HabitRank> laggingHabits;
  final Map<String, double> heatmapCompletionByDate;

  const HabitsDashboard({
    required this.totalHabits,
    required this.weeklyCompletionRate,
    required this.monthlyCompletionRate,
    required this.topHabits,
    required this.laggingHabits,
    required this.heatmapCompletionByDate,
  });

  static const empty = HabitsDashboard(
    totalHabits: 0,
    weeklyCompletionRate: 0,
    monthlyCompletionRate: 0,
    topHabits: [],
    laggingHabits: [],
    heatmapCompletionByDate: {},
  );

  static HabitsDashboard compute(
    List<Habit> habits,
    Map<String, Set<String>> logDates,
  ) {
    if (habits.isEmpty) return HabitsDashboard.empty;

    final now = DateTime.now();

    int totalSched7 = 0, totalComp7 = 0;
    int totalSched30 = 0, totalComp30 = 0;

    final ranks = <_HabitRank>[];
    for (final h in habits) {
      final dates = logDates[h.id] ?? const {};
      final (s7, c7)   = _completionInWindow(h, dates, now, days: 7);
      final (s30, c30) = _completionInWindow(h, dates, now, days: 30);
      totalSched7  += s7;
      totalComp7   += c7;
      totalSched30 += s30;
      totalComp30  += c30;
      if (s30 > 0) ranks.add(_HabitRank(h, s30, c30));
    }

    ranks.sort((a, b) => b.rate.compareTo(a.rate));
    final top      = ranks.take(3).toList();
    final lagging  = ranks.reversed.take(3).toList();

    // Aggregate heatmap: for each day in last 30d, fraction of due habits done.
    final heatmap  = <String, double>{};
    final today    = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < 30; i++) {
      final day = today.subtract(Duration(days: i));
      final key = habitDateKey(day);
      int dueCt = 0, doneCt = 0;
      for (final h in habits) {
        final first = firstLogDate(logDates[h.id] ?? const {});
        if (!isScheduledOn(h, day, firstLog: first)) continue;
        dueCt++;
        if (logDates[h.id]?.contains(key) ?? false) doneCt++;
      }
      if (dueCt > 0) heatmap[key] = doneCt / dueCt;
    }

    return HabitsDashboard(
      totalHabits: habits.length,
      weeklyCompletionRate:
          totalSched7 == 0 ? 0 : totalComp7 / totalSched7,
      monthlyCompletionRate:
          totalSched30 == 0 ? 0 : totalComp30 / totalSched30,
      topHabits: top,
      laggingHabits:
          lagging.where((r) => !top.any((t) => t.habit.id == r.habit.id)).toList(),
      heatmapCompletionByDate: heatmap,
    );
  }
}

class _HabitRank {
  final Habit habit;
  final int scheduled;
  final int completed;

  const _HabitRank(this.habit, this.scheduled, this.completed);

  double get rate => scheduled == 0 ? 0 : completed / scheduled;
}
