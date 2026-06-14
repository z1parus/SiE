import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/planning.dart';
import 'planning_provider.dart';

// ─── Agenda models ────────────────────────────────────────────────────────────

/// A single task surfaced in the War Room, enriched with its owning goal and
/// the name of the sub-goal it lives under (for context in the row).
class AgendaItem {
  const AgendaItem({
    required this.task,
    required this.goal,
    required this.subGoalId,
    required this.subGoalName,
    this.isBlocked = false,
    this.blockerNames = const [],
  });

  final PlanningTask task;
  final Goal goal;
  final String subGoalId;
  final String subGoalName;
  // Stage 8: blocked by incomplete prerequisites.
  final bool isBlocked;
  final List<String> blockerNames;
}

/// A milestone surfaced on the agenda horizon, with its owning goal.
class MilestoneRef {
  const MilestoneRef({required this.milestone, required this.goal});

  final Milestone milestone;
  final Goal goal;

  int? get daysUntil {
    final t = milestone.targetDate;
    if (t == null) return null;
    final today = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(t).difference(today).inDays;
  }
}

/// All agenda buckets, computed once from the planning state.
class AgendaBuckets {
  AgendaBuckets({
    required this.overdue,
    required this.today,
    required this.tomorrow,
    required this.thisWeek,
    required this.later,
    required this.noDate,
    required this.upcomingMilestones,
    required this.todayCompletedCount,
  });

  final List<AgendaItem> overdue;
  final List<AgendaItem> today;
  final List<AgendaItem> tomorrow;
  final List<AgendaItem> thisWeek;
  final List<AgendaItem> later;
  final List<AgendaItem> noDate;
  final List<MilestoneRef> upcomingMilestones;

  /// Tasks due today that are already completed — used for the day progress ring.
  final int todayCompletedCount;

  int get overdueCount => overdue.length;
  int get todayCount => today.length;

  /// Total tasks planned for today (remaining + already done).
  int get todayPlanned => today.length + todayCompletedCount;

  /// 0.0–1.0 completion of today's plan (1.0 when nothing planned).
  double get todayProgress =>
      todayPlanned == 0 ? 1.0 : todayCompletedCount / todayPlanned;

  /// True when there is genuinely nothing actionable to show.
  bool get isAllClear =>
      overdue.isEmpty && today.isEmpty && tomorrow.isEmpty && thisWeek.isEmpty;

  /// Total actionable (incomplete) tasks across the dated buckets.
  int get actionableCount =>
      overdue.length + today.length + tomorrow.length + thisWeek.length;

  static final AgendaBuckets empty = AgendaBuckets(
    overdue: const [],
    today: const [],
    tomorrow: const [],
    thisWeek: const [],
    later: const [],
    noDate: const [],
    upcomingMilestones: const [],
    todayCompletedCount: 0,
  );
}

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Aggregates tasks and milestones from every active goal into a day-oriented
/// agenda. Works purely on top of [planningProvider] — no extra DB queries.
final agendaProvider = Provider.autoDispose<AgendaBuckets>((ref) {
  final state = ref.watch(planningProvider).valueOrNull;
  if (state == null) return AgendaBuckets.empty;

  final today = DateUtils.dateOnly(DateTime.now());
  final tomorrow = today.add(const Duration(days: 1));
  // End of the current calendar week (Sunday). weekday: Mon=1 … Sun=7.
  final endOfWeek = today.add(Duration(days: 7 - today.weekday));

  final overdue = <AgendaItem>[];
  final todayItems = <AgendaItem>[];
  final tomorrowItems = <AgendaItem>[];
  final thisWeek = <AgendaItem>[];
  final later = <AgendaItem>[];
  final noDate = <AgendaItem>[];
  final milestones = <MilestoneRef>[];
  var todayCompleted = 0;

  for (final goal in state.activeGoals) {
    final byId = tasksById(goal);
    for (final sg in flattenSubGoals(goal.subGoals)) {
      for (final task in sg.tasks) {
        final blockers = taskBlockers(task, byId);
        final item = AgendaItem(
          task: task,
          goal: goal,
          subGoalId: sg.id,
          subGoalName: sg.name,
          isBlocked: blockers.isNotEmpty,
          blockerNames: [for (final b in blockers) b.name],
        );

        if (task.isCompleted) {
          // Count completed-today for the progress ring (regardless of hideDone).
          if (task.dueDate != null &&
              DateUtils.dateOnly(task.dueDate!) == today) {
            todayCompleted++;
          }
          continue; // completed tasks never populate actionable buckets
        }

        if (task.dueDate == null) {
          noDate.add(item);
          continue;
        }

        final due = DateUtils.dateOnly(task.dueDate!);
        if (due.isBefore(today)) {
          overdue.add(item);
        } else if (due == today) {
          todayItems.add(item);
        } else if (due == tomorrow) {
          tomorrowItems.add(item);
        } else if (!due.isAfter(endOfWeek)) {
          thisWeek.add(item);
        } else {
          later.add(item);
        }
      }
    }

    for (final ms in goal.milestones) {
      if (ms.isCompleted || ms.targetDate == null) continue;
      milestones.add(MilestoneRef(milestone: ms, goal: goal));
    }
  }

  // Within a bucket: higher goal priority first, then heavier task weight.
  int cmp(AgendaItem a, AgendaItem b) {
    final p = b.goal.priority.compareTo(a.goal.priority);
    if (p != 0) return p;
    return b.task.weight.compareTo(a.task.weight);
  }

  overdue.sort(cmp);
  todayItems.sort(cmp);
  tomorrowItems.sort(cmp);
  thisWeek.sort(cmp);
  later.sort(cmp);
  noDate.sort(cmp);
  milestones.sort((a, b) =>
      a.milestone.targetDate!.compareTo(b.milestone.targetDate!));

  return AgendaBuckets(
    overdue: overdue,
    today: todayItems,
    tomorrow: tomorrowItems,
    thisWeek: thisWeek,
    later: later,
    noDate: noDate,
    upcomingMilestones: milestones,
    todayCompletedCount: todayCompleted,
  );
});
