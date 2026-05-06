class DayXp {
  final DateTime date;
  final int xp;
  const DayXp(this.date, this.xp);
}

class DayFocus {
  final DateTime date;
  final int minutes;
  const DayFocus(this.date, this.minutes);
}

class AnalyticsData {
  final Map<DateTime, int> heatMap; // date → activity count
  final List<DayXp> xpHistory;      // last 7 days
  final List<DayFocus> focusByDay;  // last 7 days
  final int totalFocusMinutes;
  final double habitCompletionRate; // 0.0–1.0, last 30 days
  final int currentStreak;          // consecutive days with any habit log

  const AnalyticsData({
    required this.heatMap,
    required this.xpHistory,
    required this.focusByDay,
    required this.totalFocusMinutes,
    required this.habitCompletionRate,
    required this.currentStreak,
  });
}
