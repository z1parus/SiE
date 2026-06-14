import 'habit_log_entry.dart';

class Habit {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String color;
  final String? icon;
  final bool isPinned;
  final bool isArchived;
  final DateTime createdAt;

  /// Compact schedule descriptor (Stage 1 — flexible scheduling):
  ///   'daily'            — every day (default, legacy behaviour)
  ///   'weekdays:1,3,5'   — specific ISO weekdays (1=Mon … 7=Sun)
  ///   'weekly:N'         — N times per ISO week, any days
  ///   'interval:N'       — every N days from the first completion (anchor)
  final String schedule;

  const Habit({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.color = '#00C8FF',
    this.icon,
    this.isPinned = false,
    this.isArchived = false,
    this.schedule = 'daily',
    required this.createdAt,
  });

  factory Habit.fromMap(Map<dynamic, dynamic> map) => Habit(
        id: map['id']?.toString() ?? '',
        userId: map['user_id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        description: map['description']?.toString(),
        color: map['color']?.toString() ?? '#00C8FF',
        icon: map['icon']?.toString(),
        isPinned: map['is_pinned'] == true,
        isArchived: map['is_archived'] == true,
        schedule: (map['schedule']?.toString().isNotEmpty ?? false)
            ? map['schedule'].toString()
            : 'daily',
        createdAt:
            DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                DateTime.now(),
      );

  Habit copyWith({
    String? title,
    String? description,
    String? color,
    Object? icon = _sentinel,
    bool? isPinned,
    bool? isArchived,
    String? schedule,
  }) =>
      Habit(
        id: id,
        userId: userId,
        title: title ?? this.title,
        description: description ?? this.description,
        color: color ?? this.color,
        icon: icon == _sentinel ? this.icon : icon as String?,
        isPinned: isPinned ?? this.isPinned,
        isArchived: isArchived ?? this.isArchived,
        schedule: schedule ?? this.schedule,
        createdAt: createdAt,
      );

  /// True when this habit uses a non-daily schedule.
  bool get hasCustomSchedule => schedule != 'daily';
}

const _sentinel = Object();

// ── Schedule-aware helpers (Stage 1) ─────────────────────────────────────────

String habitDateKey(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday-start (ISO 8601) date-only for the week containing [day].
DateTime isoWeekStart(DateTime day) {
  final d = _dateOnly(day);
  return d.subtract(Duration(days: d.weekday - 1));
}

/// Earliest log date (date-only) among [logDates], or null if none.
/// Public wrapper used by UI to anchor `interval:N` schedules.
DateTime? firstLogDate(Set<String> logDates) => _firstLogDate(logDates);

DateTime? _firstLogDate(Set<String> logDates) {
  DateTime? first;
  for (final s in logDates) {
    final d = DateTime.tryParse(s);
    if (d == null) continue;
    if (first == null || d.isBefore(first)) first = d;
  }
  return first == null ? null : _dateOnly(first);
}

/// Whether [h] is scheduled to be performed on [day].
///
/// For `interval:N`, the anchor is the first completion date when known
/// ([firstLog]), otherwise the habit's creation date. `weekly:N` is "any day",
/// so every day is a candidate.
bool isScheduledOn(Habit h, DateTime day, {DateTime? firstLog}) {
  final s = h.schedule;
  if (s.isEmpty || s == 'daily') return true;

  if (s.startsWith('weekdays:')) {
    final days = s
        .substring('weekdays:'.length)
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toSet();
    if (days.isEmpty) return true; // malformed — fail open to daily
    return days.contains(day.weekday); // Mon=1 … Sun=7
  }

  if (s.startsWith('weekly:')) return true;

  if (s.startsWith('interval:')) {
    final n = int.tryParse(s.substring('interval:'.length)) ?? 1;
    if (n <= 1) return true;
    final anchor = _dateOnly(firstLog ?? h.createdAt);
    final d = _dateOnly(day);
    final diff = d.difference(anchor).inDays;
    return diff >= 0 && diff % n == 0;
  }

  return true; // unknown format — fail open
}

/// All scheduled (candidate) days for [h] within [from]..[to] inclusive.
/// Note: for `weekly:N` every day is a candidate (any-day goal).
List<DateTime> scheduledDaysInRange(Habit h, DateTime from, DateTime to,
    {DateTime? firstLog}) {
  final result = <DateTime>[];
  var day = _dateOnly(from);
  final end = _dateOnly(to);
  while (!day.isAfter(end)) {
    if (isScheduledOn(h, day, firstLog: firstLog)) result.add(day);
    day = day.add(const Duration(days: 1));
  }
  return result;
}

/// Number of completions required per week for a `weekly:N` schedule, else 0.
int weeklyTarget(Habit h) {
  if (!h.schedule.startsWith('weekly:')) return 0;
  return int.tryParse(h.schedule.substring('weekly:'.length)) ?? 1;
}

/// Schedule-aware streak.
///
/// • `daily` / `weekdays` / `interval` — walk back over *scheduled* days only;
///   the series breaks on the first missed scheduled day. A scheduled-but-not-
///   yet-logged *today* does NOT break the series (the day is still live).
/// • `weekly:N` — counted in ISO weeks: a week counts when completed ≥ N times;
///   streak = number of consecutive counted weeks. The current (in-progress)
///   week never breaks the series.
int scheduleAwareStreak(Habit h, Set<String> logDates) {
  if (logDates.isEmpty) return 0;

  if (h.schedule.startsWith('weekly:')) {
    final target = weeklyTarget(h);
    final perWeek = <DateTime, int>{};
    for (final s in logDates) {
      final d = DateTime.tryParse(s);
      if (d == null) continue;
      perWeek.update(isoWeekStart(d), (v) => v + 1, ifAbsent: () => 1);
    }
    var streak = 0;
    final currentWeek = isoWeekStart(DateTime.now());
    var week = currentWeek;
    while (true) {
      final count = perWeek[week] ?? 0;
      if (count >= target) {
        streak++;
      } else if (week != currentWeek) {
        break; // a past week fell short — series ends
      }
      week = week.subtract(const Duration(days: 7));
      if (currentWeek.difference(week).inDays > 730) break;
    }
    return streak;
  }

  // daily / weekdays / interval
  final firstLog = _firstLogDate(logDates);
  final today = _dateOnly(DateTime.now());
  var day = today;
  var n = 0;
  while (true) {
    if (isScheduledOn(h, day, firstLog: firstLog)) {
      if (logDates.contains(habitDateKey(day))) {
        n++;
      } else if (day != today) {
        break; // missed a past scheduled day — series ends
      }
    }
    day = day.subtract(const Duration(days: 1));
    if (today.difference(day).inDays > 730) break;
  }
  return n;
}

class HabitsState {
  final List<Habit> habits;

  /// habitId → set of 'yyyy-MM-dd' strings completed in last 30 days
  final Map<String, Set<String>> logDates;

  /// habitId → consecutive-day streak count (ending today)
  final Map<String, int> streaks;

  /// habitId → list of log entries (with note/emoji), newest first
  final Map<String, List<HabitLogEntry>> logEntries;

  const HabitsState({
    required this.habits,
    required this.logDates,
    required this.streaks,
    this.logEntries = const {},
  });

  static const empty =
      HabitsState(habits: [], logDates: {}, streaks: {});

  /// Active habits scheduled for [day] (defaults to today).
  List<Habit> dueOn([DateTime? day]) {
    final d = day ?? DateTime.now();
    return habits.where((h) {
      final firstLog = _firstLogDate(logDates[h.id] ?? const {});
      return isScheduledOn(h, d, firstLog: firstLog);
    }).toList();
  }

  /// Active habits NOT scheduled for [day] (defaults to today).
  List<Habit> notDueOn([DateTime? day]) {
    final d = day ?? DateTime.now();
    return habits.where((h) {
      final firstLog = _firstLogDate(logDates[h.id] ?? const {});
      return !isScheduledOn(h, d, firstLog: firstLog);
    }).toList();
  }
}
