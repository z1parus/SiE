import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sie_core/src/models/habit.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper around `flutter_local_notifications` for the planning module.
///
/// Scheduling is computed against the user's stored fixed UTC offset (the app
/// already models timezone as a single offset — see `userTimezoneProvider`),
/// so notifications fire at the correct local wall-clock time without relying
/// on a named IANA zone. All ids are derived deterministically from the entity
/// id, so re-scheduling replaces the previous notification instead of stacking.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _inited = false;
  Duration _offset = DateTime.now().timeZoneOffset;
  void Function(String? payload)? _onTap;

  static const _channelId = 'sie_planning_reminders';
  static const _channelName = 'Планирование';
  static const _channelDesc = 'Напоминания о задачах, вехах и дедлайнах целей';

  static const _habitChannelId = 'sie_habit_reminders';
  static const _habitChannelName = 'Привычки';
  static const _habitChannelDesc = 'Напоминания о привычках и вечерняя сводка';

  /// Stable positive 31-bit id from a string key.
  static int _idFor(String key) => key.hashCode & 0x7fffffff;

  void setOffset(Duration offset) => _offset = offset;

  Future<void> init({
    Duration? utcOffset,
    void Function(String? payload)? onTap,
  }) async {
    _onTap = onTap;
    if (utcOffset != null) _offset = utcOffset;
    if (_inited) return;
    if (kIsWeb) {
      _inited = true;
      return;
    }
    tzdata.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: darwin);

    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (resp) => _onTap?.call(resp.payload),
      );
      _inited = true;
    } catch (e) {
      debugPrint('SiE Notifications: init failed — $e');
    }
  }

  /// Requests OS permission to post notifications. Returns true if granted.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
            alert: true, badge: true, sound: true);
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('SiE Notifications: permission request failed — $e');
    }
    return false;
  }

  // ── Scheduling primitives ─────────────────────────────────────────────────

  /// UTC instant corresponding to the given local wall-clock time.
  tz.TZDateTime _instant(DateTime localWall) {
    final utc = DateTime.utc(localWall.year, localWall.month, localWall.day,
            localWall.hour, localWall.minute)
        .subtract(_offset);
    return tz.TZDateTime.from(utc, tz.UTC);
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  Future<void> _scheduleOneShot(
    int id,
    String title,
    String body,
    DateTime localWall, {
    String? payload,
  }) async {
    if (!_inited || kIsWeb) return;
    final when = _instant(localWall);
    // Never schedule in the past — would fire immediately (spam).
    if (when.isBefore(tz.TZDateTime.now(tz.UTC))) return;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      debugPrint('SiE Notifications: schedule failed — $e');
    }
  }

  // ── Public scheduling API ───────────────────────────────────────────────────

  Future<void> scheduleTaskReminder({
    required String taskId,
    required String taskName,
    required String goalName,
    required DateTime dueDate,
    required int remindBeforeDays,
  }) async {
    final dueMorning =
        DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);
    await _scheduleOneShot(
      _idFor('task_due_$taskId'),
      '⏳ Дедлайн сегодня',
      '«$taskName» — срок сегодня. Цель: $goalName',
      dueMorning,
      payload: 'war_room',
    );
    if (remindBeforeDays > 0) {
      final pre = dueMorning.subtract(Duration(days: remindBeforeDays));
      await _scheduleOneShot(
        _idFor('task_pre_$taskId'),
        '🎯 Скоро дедлайн',
        '«$taskName» — через $remindBeforeDays дн. Цель: $goalName',
        pre,
        payload: 'war_room',
      );
    }
  }

  Future<void> cancelTaskReminder(String taskId) async {
    await cancel(_idFor('task_due_$taskId'));
    await cancel(_idFor('task_pre_$taskId'));
  }

  Future<void> scheduleMilestoneReminder({
    required String milestoneId,
    required String milestoneName,
    required String goalName,
    required DateTime targetDate,
    required int remindBeforeDays,
  }) async {
    final morning =
        DateTime(targetDate.year, targetDate.month, targetDate.day, 9, 0);
    final when = remindBeforeDays > 0
        ? morning.subtract(Duration(days: remindBeforeDays))
        : morning;
    await _scheduleOneShot(
      _idFor('milestone_$milestoneId'),
      '📍 Веха на горизонте',
      '«$milestoneName» — цель «$goalName»',
      when,
      payload: 'war_room',
    );
  }

  Future<void> cancelMilestoneReminder(String milestoneId) =>
      cancel(_idFor('milestone_$milestoneId'));

  Future<void> scheduleGoalDeadline({
    required String goalId,
    required String goalName,
    required DateTime deadline,
    required int progressPercent,
    required int remindBeforeDays,
  }) async {
    final morning =
        DateTime(deadline.year, deadline.month, deadline.day, 9, 0);
    final when = remindBeforeDays > 0
        ? morning.subtract(Duration(days: remindBeforeDays))
        : morning;
    await _scheduleOneShot(
      _idFor('goal_deadline_$goalId'),
      '⏳ Дедлайн цели близко',
      '«$goalName» — дедлайн скоро. Прогресс $progressPercent%',
      when,
      payload: 'war_room',
    );
  }

  Future<void> cancelGoalDeadline(String goalId) =>
      cancel(_idFor('goal_deadline_$goalId'));

  /// Daily morning digest of the agenda. Repeats every day at [hour]:[minute].
  Future<void> scheduleDailyDigest({
    required int hour,
    required int minute,
    required int taskCount,
    String? milestoneHint,
  }) async {
    if (!_inited || kIsWeb) return;
    final id = _idFor('daily_digest');
    final body = taskCount == 0
        ? 'На сегодня запланированных задач нет.${milestoneHint != null ? ' $milestoneHint' : ''}'
        : '🎯 По плану сегодня: $taskCount.${milestoneHint != null ? ' $milestoneHint' : ''}';

    // Next occurrence of [hour:minute] in local wall-clock time.
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: 'Сводка дня',
        body: body,
        scheduledDate: _instant(next),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'war_room',
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('SiE Notifications: digest schedule failed — $e');
    }
  }

  Future<void> cancelDailyDigest() => cancel(_idFor('daily_digest'));

  /// Weekly review ritual reminder (Stage 9). Repeats on [weekday] (Mon=1 …
  /// Sun=7) at [hour]:[minute] local time.
  Future<void> scheduleWeeklyReview({
    required int weekday,
    required int hour,
    required int minute,
  }) async {
    if (!_inited || kIsWeb) return;
    final id = _idFor('weekly_review');

    // Next occurrence of the requested weekday/time in local wall-clock.
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    var addDays = (weekday - now.weekday) % 7;
    if (addDays < 0) addDays += 7;
    next = next.add(Duration(days: addDays));
    if (!next.isAfter(now)) next = next.add(const Duration(days: 7));

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: '🧭 Время еженедельного обзора',
        body: 'Подведём итоги недели и наметим фокус.',
        scheduledDate: _instant(next),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'weekly_review',
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (e) {
      debugPrint('SiE Notifications: weekly review schedule failed — $e');
    }
  }

  Future<void> cancelWeeklyReview() => cancel(_idFor('weekly_review'));

  /// Optional "stagnation nudge" for a fatigued goal (event-driven, at most
  /// one per goal — id is derived from goalId so it won't duplicate).
  Future<void> scheduleStagnationNudge({
    required String goalId,
    required String goalName,
    required DateTime when,
  }) async {
    await _scheduleOneShot(
      _idFor('stagnation_$goalId'),
      '💤 Цель замерла',
      '«$goalName» не двигалась несколько дней. Сделаем шаг?',
      when,
      payload: 'war_room',
    );
  }

  Future<void> cancelStagnationNudge(String goalId) =>
      cancel(_idFor('stagnation_$goalId'));

  // ── Habit Reminders (Stage 3) ─────────────────────────────────────────────

  NotificationDetails get _habitDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          _habitChannelId,
          _habitChannelName,
          channelDescription: _habitChannelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// Schedules repeating reminder(s) for [habit] according to its schedule.
  /// Existing notifications for the same habit are cancelled first so
  /// re-scheduling replaces rather than stacks.
  Future<void> scheduleHabitReminder(Habit habit) async {
    if (!_inited || kIsWeb) return;
    if (habit.reminderTime == null) return;

    await cancelHabitReminder(habit.id);

    final parts = habit.reminderTime!.split(':');
    if (parts.length != 2) return;
    final hour   = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    final schedule = habit.schedule;

    if (schedule.startsWith('weekdays:')) {
      final days = schedule
          .substring('weekdays:'.length)
          .split(',')
          .map(int.tryParse)
          .whereType<int>()
          .toList();
      for (final day in days) {
        await _scheduleWeeklyHabit(
          id: _idFor('habit_${habit.id}_wd$day'),
          habit: habit,
          weekday: day,
          hour: hour,
          minute: minute,
        );
      }
    } else {
      // 'daily', 'weekly:N', 'interval:N' — all get a daily repeating reminder.
      await _scheduleDailyHabit(
        id: _idFor('habit_${habit.id}'),
        habit: habit,
        hour: hour,
        minute: minute,
      );
    }
  }

  Future<void> _scheduleDailyHabit({
    required int id,
    required Habit habit,
    required int hour,
    required int minute,
  }) async {
    final now  = DateTime.now();
    var next   = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: '💪 Пора: ${habit.title}',
        body: habit.description ?? 'Не забудь выполнить привычку сегодня',
        scheduledDate: _instant(next),
        notificationDetails: _habitDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'habits',
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('SiE Notifications: habit daily schedule failed — $e');
    }
  }

  Future<void> _scheduleWeeklyHabit({
    required int id,
    required Habit habit,
    required int weekday,
    required int hour,
    required int minute,
  }) async {
    final now     = DateTime.now();
    var next      = DateTime(now.year, now.month, now.day, hour, minute);
    var addDays   = (weekday - now.weekday) % 7;
    if (addDays < 0) addDays += 7;
    next = next.add(Duration(days: addDays));
    if (!next.isAfter(now)) next = next.add(const Duration(days: 7));
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: '💪 Пора: ${habit.title}',
        body: habit.description ?? 'Не забудь выполнить привычку сегодня',
        scheduledDate: _instant(next),
        notificationDetails: _habitDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'habits',
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (e) {
      debugPrint('SiE Notifications: habit weekly schedule failed — $e');
    }
  }

  /// Cancels all pending notifications for [habitId].
  Future<void> cancelHabitReminder(String habitId) async {
    // Cancel daily / weekdays:1..7 slots (up to 8 IDs per habit).
    await cancel(_idFor('habit_$habitId'));
    for (var d = 1; d <= 7; d++) {
      await cancel(_idFor('habit_${habitId}_wd$d'));
    }
  }

  /// Schedules (or replaces) the evening habit digest at [hour]:[minute].
  /// Call on app start and whenever the time pref changes.
  Future<void> scheduleHabitDigest({
    required int hour,
    required int minute,
    required int pendingCount,
  }) async {
    if (!_inited || kIsWeb) return;
    final id = _idFor('habit_digest');
    if (pendingCount == 0) {
      await cancel(id);
      return;
    }
    final now  = DateTime.now();
    var next   = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: '📋 Сводка привычек',
        body: 'Ещё не закрыто: $pendingCount. Успеть до конца дня!',
        scheduledDate: _instant(next),
        notificationDetails: _habitDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'habits',
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('SiE Notifications: habit digest schedule failed — $e');
    }
  }

  Future<void> cancelHabitDigest() => cancel(_idFor('habit_digest'));

  Future<void> cancel(int id) async {
    if (!_inited || kIsWeb) return;
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('SiE Notifications: cancel failed — $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_inited || kIsWeb) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
