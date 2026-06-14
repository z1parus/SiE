import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mission_detail_screen.dart';
import 'focus_protocol_screen.dart';

// Launches the focus protocol bound to an agenda item's task (Stage 7).
void _startFocusOnAgendaItem(BuildContext context, AgendaItem item) {
  SieHaptics.selection();
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FocusProtocolScreen(
        initialTaskRef: (
          taskId: item.task.id,
          subGoalId: item.subGoalId,
          goalId: item.goal.id,
          taskTitle: item.task.name,
        ),
      ),
    ),
  );
}

// ─── Category icon (mirrors planning_screen) ───────────────────────────────────

IconData? _categoryIcon(GoalCategory? cat) => switch (cat) {
      GoalCategory.learning => Icons.school_outlined,
      GoalCategory.health => Icons.favorite_outline,
      GoalCategory.project => Icons.rocket_launch_outlined,
      GoalCategory.lifestyle => Icons.spa_outlined,
      GoalCategory.discipline => Icons.bolt_outlined,
      null => Icons.flag_outlined,
    };

// ─── War Room body (embedded under the «Повестка» segment) ─────────────────────

class WarRoomView extends ConsumerWidget {
  const WarRoomView({super.key});

  bool _isReadOnly(Goal goal) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (goal.userId == myId) return false;
    return goal.collaborators.any((col) =>
        col.userId == myId &&
        col.status == 'accepted' &&
        col.role == 'viewer');
  }

  // The single most important task to focus on now: top overdue, else top
  // today. Buckets are already priority/weight-sorted by the agenda provider.
  AgendaItem? _focusSuggestion(AgendaBuckets agenda) {
    if (agenda.overdue.isNotEmpty) return agenda.overdue.first;
    if (agenda.today.isNotEmpty) return agenda.today.first;
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final agenda = ref.watch(agendaProvider);
    final today = DateUtils.dateOnly(DateTime.now());

    final children = <Widget>[
      _DaySummary(agenda: agenda, c: c),
    ];

    // Auto-suggest focusing on the day's top-priority actionable task.
    final suggestion = _focusSuggestion(agenda);
    if (suggestion != null && !_isReadOnly(suggestion.goal)) {
      children.add(_FocusSuggestionCard(item: suggestion, c: c));
    }

    if (agenda.overdue.isNotEmpty) {
      children.add(_Section(
        title: 'Просрочено',
        icon: Icons.error_outline,
        accent: c.danger,
        items: agenda.overdue,
        today: today,
        c: c,
        isReadOnly: _isReadOnly,
      ));
    }
    if (agenda.today.isNotEmpty) {
      children.add(_Section(
        title: 'Сегодня',
        icon: Icons.star_outline,
        accent: c.accent,
        items: agenda.today,
        today: today,
        c: c,
        isReadOnly: _isReadOnly,
      ));
    }
    if (agenda.tomorrow.isNotEmpty) {
      children.add(_Section(
        title: 'Завтра',
        icon: Icons.wb_twilight_outlined,
        accent: c.textSecondary,
        items: agenda.tomorrow,
        today: today,
        c: c,
        isReadOnly: _isReadOnly,
      ));
    }
    if (agenda.thisWeek.isNotEmpty) {
      children.add(_Section(
        title: 'На этой неделе',
        icon: Icons.calendar_view_week_outlined,
        accent: c.textSecondary,
        items: agenda.thisWeek,
        today: today,
        c: c,
        isReadOnly: _isReadOnly,
      ));
    }

    if (agenda.upcomingMilestones.isNotEmpty) {
      children.add(_MilestoneHorizon(
          milestones: agenda.upcomingMilestones, c: c));
    }

    if (agenda.later.isNotEmpty) {
      children.add(_CollapsibleSection(
        title: 'Позже',
        count: agenda.later.length,
        items: agenda.later,
        today: today,
        c: c,
        isReadOnly: _isReadOnly,
      ));
    }
    if (agenda.noDate.isNotEmpty) {
      children.add(_CollapsibleSection(
        title: 'Без срока',
        count: agenda.noDate.length,
        items: agenda.noDate,
        today: today,
        c: c,
        isReadOnly: _isReadOnly,
      ));
    }

    if (agenda.isAllClear && agenda.later.isEmpty && agenda.noDate.isEmpty) {
      children.add(_AllClear(c: c));
    }

    return RefreshIndicator(
      color: c.accent,
      backgroundColor: c.isLightMode ? Colors.white : const Color(0xFF0D1B2A),
      onRefresh: () async {
        ref.invalidate(planningProvider);
        await ref.read(planningProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: children,
      ),
    );
  }
}

// ─── Day summary card with progress ring ───────────────────────────────────────

class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.agenda, required this.c});

  final AgendaBuckets agenda;
  final SieColors c;

  @override
  Widget build(BuildContext context) {
    final remaining = agenda.todayCount;
    final done = agenda.todayCompletedCount;
    final planned = agenda.todayPlanned;

    final summary = planned == 0
        ? 'На сегодня задач нет'
        : '$remaining ${_taskWord(remaining)} осталось · $done из $planned';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: c.flatCard(radius: 16),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CustomPaint(
              painter: _RingPainter(
                progress: agenda.todayProgress,
                track: c.border,
                fill: c.accent,
              ),
              child: Center(
                child: Text(
                  planned == 0 ? '—' : '${(agenda.todayProgress * 100).round()}%',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'СВОДКА ДНЯ',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (agenda.overdueCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${agenda.overdueCount} ${_taskWord(agenda.overdueCount)} просрочено',
                    style: TextStyle(
                      color: c.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.track, required this.fill});

  final double progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 3;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = track;
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = fill;
    canvas.drawCircle(center, radius, trackPaint);
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.fill != fill || old.track != track;
}

// ─── Focus suggestion card (Stage 7) ───────────────────────────────────────────

class _FocusSuggestionCard extends StatelessWidget {
  const _FocusSuggestionCard({required this.item, required this.c});

  final AgendaItem item;
  final SieColors c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _startFocusOnAgendaItem(context, item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: c.accent.withValues(alpha: 0.08),
          border: Border.all(color: c.accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.accent.withValues(alpha: 0.15),
              ),
              child: Icon(Icons.play_arrow_rounded, color: c.accent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'СФОКУСИРОВАТЬСЯ',
                    style: TextStyle(
                      color: c.accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.task.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.goal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Section ───────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.accent,
    required this.items,
    required this.today,
    required this.c,
    required this.isReadOnly,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<AgendaItem> items;
  final DateTime today;
  final SieColors c;
  final bool Function(Goal) isReadOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 16),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${items.length}',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ...items.map((item) => _AgendaRow(
              item: item,
              today: today,
              c: c,
              readOnly: isReadOnly(item.goal),
            )),
      ],
    );
  }
}

// ─── Collapsible section (Позже / Без срока) ───────────────────────────────────

class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.title,
    required this.count,
    required this.items,
    required this.today,
    required this.c,
    required this.isReadOnly,
  });

  final String title;
  final int count;
  final List<AgendaItem> items;
  final DateTime today;
  final SieColors c;
  final bool Function(Goal) isReadOnly;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_more : Icons.chevron_right,
                  color: c.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.title.toUpperCase(),
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.count}',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.items.map((item) => _AgendaRow(
                item: item,
                today: widget.today,
                c: c,
                readOnly: widget.isReadOnly(item.goal),
              )),
      ],
    );
  }
}

// ─── Agenda row ────────────────────────────────────────────────────────────────

class _AgendaRow extends ConsumerWidget {
  const _AgendaRow({
    required this.item,
    required this.today,
    required this.c,
    required this.readOnly,
  });

  final AgendaItem item;
  final DateTime today;
  final SieColors c;
  final bool readOnly;

  String? _dueLabel() {
    final due = item.task.dueDate;
    if (due == null) return null;
    final d = DateUtils.dateOnly(due);
    final diff = d.difference(today).inDays;
    if (diff < 0) return 'просрочено на ${-diff} ${_dayWord(-diff)}';
    if (diff == 0) return 'сегодня';
    if (diff == 1) return 'завтра';
    return 'через $diff ${_dayWord(diff)}';
  }

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MissionDetailScreen(goal: item.goal)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = item.task;
    final dueLabel = _dueLabel();
    final overdue = task.dueDate != null &&
        DateUtils.dateOnly(task.dueDate!).isBefore(today);

    final row = Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: c.flatCard(radius: 12),
      child: Row(
        children: [
          // Checkbox
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: readOnly
                ? null
                : () {
                    SieHaptics.success();
                    ref.read(planningProvider.notifier).toggleTask(
                        task.id, item.subGoalId, item.goal.id);
                  },
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: readOnly ? c.border : item.goal.color,
                  width: 2,
                ),
              ),
              child: readOnly
                  ? Icon(Icons.lock_outline, size: 11, color: c.textSecondary)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          // Body
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _open(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (task.isRecurring) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 4),
                          child: Icon(Icons.repeat,
                              size: 13, color: c.accentSecondary),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          task.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: item.goal.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(_categoryIcon(item.goal.settings.category),
                          size: 12, color: c.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          item.goal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (dueLabel != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '· $dueLabel',
                          style: TextStyle(
                            color: overdue ? c.danger : c.textSecondary,
                            fontSize: 11,
                            fontWeight:
                                overdue ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Focus ▶ (Stage 7)
          if (!readOnly)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _startFocusOnAgendaItem(context, item),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.play_circle_outline,
                    size: 20, color: c.accent),
              ),
            ),
          const SizedBox(width: 4),
          // XP weight badge
          Text(
            '+${taskXp(task.weight)}',
            style: TextStyle(
              color: c.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (readOnly) return row;

    // Swipe actions: → отложить на завтра, ← снять дедлайн.
    return Dismissible(
      key: ValueKey('agenda_${task.id}'),
      background: _swipeBg(
        align: Alignment.centerLeft,
        icon: Icons.event_outlined,
        label: 'На завтра',
        color: c.accent,
      ),
      secondaryBackground: _swipeBg(
        align: Alignment.centerRight,
        icon: Icons.event_busy_outlined,
        label: 'Снять срок',
        color: c.textSecondary,
      ),
      confirmDismiss: (dir) async {
        final notifier = ref.read(planningProvider.notifier);
        if (dir == DismissDirection.startToEnd) {
          final tomorrow = today.add(const Duration(days: 1));
          await notifier.rescheduleTask(
              task.id, item.subGoalId, item.goal.id, tomorrow);
        } else {
          await notifier.rescheduleTask(
              task.id, item.subGoalId, item.goal.id, null);
        }
        SieHaptics.selection();
        return false; // provider rebuild handles removal from the bucket
      },
      child: row,
    );
  }

  Widget _swipeBg({
    required Alignment align,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      alignment: align,
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Milestone horizon ─────────────────────────────────────────────────────────

class _MilestoneHorizon extends StatelessWidget {
  const _MilestoneHorizon({required this.milestones, required this.c});

  final List<MilestoneRef> milestones;
  final SieColors c;

  @override
  Widget build(BuildContext context) {
    final shown = milestones.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Row(
            children: [
              Icon(Icons.flag_outlined, color: c.accentSecondary, size: 16),
              const SizedBox(width: 6),
              Text(
                'ВЕХИ НА ГОРИЗОНТЕ',
                style: TextStyle(
                  color: c.accentSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        ...shown.map((m) {
          final days = m.daysUntil ?? 0;
          final overdue = days < 0;
          final label = overdue
              ? 'просрочена на ${-days} ${_dayWord(-days)}'
              : days == 0
                  ? 'сегодня'
                  : 'через $days ${_dayWord(days)}';
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: c.flatCard(radius: 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: m.goal.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.milestone.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.goal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: overdue ? c.danger : c.textSecondary,
                    fontSize: 11,
                    fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─── All-clear empty state ─────────────────────────────────────────────────────

class _AllClear extends StatelessWidget {
  const _AllClear({required this.c});

  final SieColors c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, color: c.success, size: 56),
          const SizedBox(height: 16),
          Text(
            'Чисто',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Все цели под контролем',
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Word helpers ──────────────────────────────────────────────────────────────

String _dayWord(int n) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return 'день';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'дня';
  return 'дней';
}

String _taskWord(int n) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return 'задача';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'задачи';
  return 'задач';
}
