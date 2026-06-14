import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

class ReminderSettingsScreen extends ConsumerWidget {
  const ReminderSettingsScreen({super.key});

  Future<void> _resync(WidgetRef ref) =>
      ref.read(planningProvider.notifier).resyncReminders();

  Future<void> _toggleMaster(WidgetRef ref, bool value) async {
    final notifier = ref.read(reminderSettingsProvider.notifier);
    if (value) {
      final granted =
          await ref.read(notificationServiceProvider).requestPermission();
      if (!granted) {
        await notifier.setRemindersEnabled(false);
        return;
      }
      await notifier.setRemindersEnabled(true);
      await _resync(ref);
    } else {
      await notifier.setRemindersEnabled(false);
      await ref.read(notificationServiceProvider).cancelAll();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final settingsAsync = ref.watch(reminderSettingsProvider);

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: c.textPrimary),
          title: Text('Напоминания',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
        ),
        body: settingsAsync.when(
          loading: () =>
              Center(child: CircularProgressIndicator(color: c.accent)),
          error: (_, _) => Center(
              child: Text('Ошибка', style: TextStyle(color: c.textSecondary))),
          data: (s) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _Card(
                c: c,
                child: _SwitchRow(
                  c: c,
                  title: 'Напоминания включены',
                  subtitle:
                      'Локальные уведомления о задачах, вехах и дедлайнах',
                  value: s.remindersEnabled,
                  onChanged: (v) => _toggleMaster(ref, v),
                ),
              ),
              if (!s.remindersEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    'Включите, чтобы получать напоминания. Потребуется разрешение системы.',
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                ),
              if (s.remindersEnabled) ...[
                const SizedBox(height: 12),
                _Card(
                  c: c,
                  child: Column(
                    children: [
                      _SwitchRow(
                        c: c,
                        title: 'Дневная сводка',
                        subtitle: 'Утренний обзор задач на сегодня',
                        value: s.dailyDigestEnabled,
                        onChanged: (v) async {
                          await ref
                              .read(reminderSettingsProvider.notifier)
                              .setDailyDigestEnabled(v);
                          await _resync(ref);
                        },
                      ),
                      if (s.dailyDigestEnabled) ...[
                        Divider(color: c.border, height: 24),
                        _TimeRow(
                          c: c,
                          hour: s.digestHour,
                          minute: s.digestMinute,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                  hour: s.digestHour, minute: s.digestMinute),
                            );
                            if (picked != null) {
                              await ref
                                  .read(reminderSettingsProvider.notifier)
                                  .setDigestTime(picked.hour, picked.minute);
                              await _resync(ref);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Card(
                  c: c,
                  child: _SwitchRow(
                    c: c,
                    title: 'Подталкивать при застое',
                    subtitle:
                        'Уведомлять, если цель не двигалась несколько дней',
                    value: s.stagnationNudge,
                    onChanged: (v) async {
                      await ref
                          .read(reminderSettingsProvider.notifier)
                          .setStagnationNudge(v);
                      await _resync(ref);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _Card(
                  c: c,
                  child: Column(
                    children: [
                      _SwitchRow(
                        c: c,
                        title: 'Обзор недели',
                        subtitle:
                            'Еженедельное приглашение подвести итоги',
                        value: s.weeklyReviewEnabled,
                        onChanged: (v) async {
                          await ref
                              .read(reminderSettingsProvider.notifier)
                              .setWeeklyReviewEnabled(v);
                          await _resync(ref);
                        },
                      ),
                      if (s.weeklyReviewEnabled) ...[
                        Divider(color: c.border, height: 24),
                        _ReviewScheduleRow(
                          c: c,
                          weekday: s.reviewWeekday,
                          hour: s.reviewHour,
                          minute: s.reviewMinute,
                          onPickTime: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                  hour: s.reviewHour, minute: s.reviewMinute),
                            );
                            if (picked != null) {
                              await ref
                                  .read(reminderSettingsProvider.notifier)
                                  .setReviewSchedule(s.reviewWeekday,
                                      picked.hour, picked.minute);
                              await _resync(ref);
                            }
                          },
                          onPickDay: (day) async {
                            await ref
                                .read(reminderSettingsProvider.notifier)
                                .setReviewSchedule(
                                    day, s.reviewHour, s.reviewMinute);
                            await _resync(ref);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewScheduleRow extends StatelessWidget {
  const _ReviewScheduleRow({
    required this.c,
    required this.weekday,
    required this.hour,
    required this.minute,
    required this.onPickTime,
    required this.onPickDay,
  });

  final SieColors c;
  final int weekday;
  final int hour;
  final int minute;
  final VoidCallback onPickTime;
  final ValueChanged<int> onPickDay;

  static const _days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    final time =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('День недели',
            style: TextStyle(color: c.textPrimary, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: List.generate(7, (i) {
            final day = i + 1; // Mon=1 … Sun=7
            final sel = day == weekday;
            return GestureDetector(
              onTap: () => onPickDay(day),
              child: Container(
                width: 38,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel
                      ? c.accent.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? c.accent : c.border),
                ),
                child: Text(_days[i],
                    style: TextStyle(
                        color: sel ? c.accent : c.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPickTime,
          child: Row(
            children: [
              Expanded(
                child: Text('Время обзора',
                    style: TextStyle(color: c.textPrimary, fontSize: 15)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(time,
                    style: TextStyle(
                        color: c.accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.c, required this.child});
  final SieColors c;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: c.flatCard(radius: 14),
        child: child,
      );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.c,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final SieColors c;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(color: c.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: c.accent,
        ),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.c,
    required this.hour,
    required this.minute,
    required this.onTap,
  });

  final SieColors c;
  final int hour;
  final int minute;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text('Время сводки',
                style: TextStyle(color: c.textPrimary, fontSize: 15)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(label,
                style: TextStyle(
                    color: c.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
