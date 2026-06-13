import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

/// Singleton notification service exposed to the widget tree.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService.instance,
);

// ─── Per-device reminder settings (SharedPreferences) ──────────────────────────

class ReminderSettings {
  const ReminderSettings({
    this.remindersEnabled = false,
    this.dailyDigestEnabled = true,
    this.digestHour = 8,
    this.digestMinute = 0,
    this.stagnationNudge = false,
  });

  /// Master switch — true once the user has granted permission and opted in.
  final bool remindersEnabled;
  final bool dailyDigestEnabled;
  final int digestHour;
  final int digestMinute;
  final bool stagnationNudge;

  ReminderSettings copyWith({
    bool? remindersEnabled,
    bool? dailyDigestEnabled,
    int? digestHour,
    int? digestMinute,
    bool? stagnationNudge,
  }) =>
      ReminderSettings(
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        dailyDigestEnabled: dailyDigestEnabled ?? this.dailyDigestEnabled,
        digestHour: digestHour ?? this.digestHour,
        digestMinute: digestMinute ?? this.digestMinute,
        stagnationNudge: stagnationNudge ?? this.stagnationNudge,
      );
}

class ReminderSettingsNotifier extends AsyncNotifier<ReminderSettings> {
  static const _kEnabled = 'reminders_enabled';
  static const _kDigest = 'reminders_daily_digest';
  static const _kHour = 'reminders_digest_hour';
  static const _kMinute = 'reminders_digest_minute';
  static const _kStagnation = 'reminders_stagnation_nudge';

  @override
  Future<ReminderSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return ReminderSettings(
      remindersEnabled: prefs.getBool(_kEnabled) ?? false,
      dailyDigestEnabled: prefs.getBool(_kDigest) ?? true,
      digestHour: prefs.getInt(_kHour) ?? 8,
      digestMinute: prefs.getInt(_kMinute) ?? 0,
      stagnationNudge: prefs.getBool(_kStagnation) ?? false,
    );
  }

  Future<void> _persist(ReminderSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, s.remindersEnabled);
    await prefs.setBool(_kDigest, s.dailyDigestEnabled);
    await prefs.setInt(_kHour, s.digestHour);
    await prefs.setInt(_kMinute, s.digestMinute);
    await prefs.setBool(_kStagnation, s.stagnationNudge);
    state = AsyncData(s);
  }

  Future<void> setRemindersEnabled(bool v) async {
    final cur = state.valueOrNull ?? const ReminderSettings();
    await _persist(cur.copyWith(remindersEnabled: v));
  }

  Future<void> setDailyDigestEnabled(bool v) async {
    final cur = state.valueOrNull ?? const ReminderSettings();
    await _persist(cur.copyWith(dailyDigestEnabled: v));
  }

  Future<void> setDigestTime(int hour, int minute) async {
    final cur = state.valueOrNull ?? const ReminderSettings();
    await _persist(cur.copyWith(digestHour: hour, digestMinute: minute));
  }

  Future<void> setStagnationNudge(bool v) async {
    final cur = state.valueOrNull ?? const ReminderSettings();
    await _persist(cur.copyWith(stagnationNudge: v));
  }
}

final reminderSettingsProvider =
    AsyncNotifierProvider<ReminderSettingsNotifier, ReminderSettings>(
  ReminderSettingsNotifier.new,
);
