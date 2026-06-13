import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tactical_map_view.dart';
import 'mission_accomplished_screen.dart';
import 'goal_stats_screen.dart';
import 'ai_decomposition_sheet.dart';
import 'milestone_metric_screen.dart';
import '../widgets/sparkline.dart';

// ─── Color helpers ────────────────────────────────────────────────────────────

int _categoryDp(GoalCategory? cat) => switch (cat) {
      GoalCategory.project    => 50,
      GoalCategory.learning   => 40,
      GoalCategory.health     => 35,
      GoalCategory.discipline => 30,
      GoalCategory.lifestyle  => 25,
      null                    => 20,
    };

String _formatDate(DateTime d) =>
    '${d.day}.${d.month.toString().padLeft(2, '0')}.${d.year}';

// ─── Screen ───────────────────────────────────────────────────────────────────

class MissionDetailScreen extends ConsumerStatefulWidget {
  const MissionDetailScreen({super.key, required this.goal});

  final Goal goal;

  @override
  ConsumerState<MissionDetailScreen> createState() =>
      _MissionDetailScreenState();
}

class _MissionDetailScreenState extends ConsumerState<MissionDetailScreen> {
  bool _mapMode = false;
  String? _selectedSubGoalId;
  RealtimeChannel? _presenceChannel;
  Set<String> _onlineUserIds = {};

  @override
  void initState() {
    super.initState();
    _joinPresence();
  }

  void _joinPresence() {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return;
    _presenceChannel = SupabaseService.client
        .channel('goal_presence:${widget.goal.id}')
        .onPresenceSync((_) {
          final ids = (_presenceChannel?.presenceState() ?? [])
              .expand((s) => s.presences)
              .map((p) => p.payload['user_id'] as String? ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
          if (mounted) setState(() => _onlineUserIds = ids);
        })
        .subscribe((status, _) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await _presenceChannel?.track({'user_id': me.id});
          }
        });
  }

  @override
  void dispose() {
    _presenceChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sc = ref.watch(sieColorsProvider);
    final planningAsync = ref.watch(planningProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final myId = Supabase.instance.client.auth.currentUser?.id;

    // Always use latest goal from provider if available
    final goal = planningAsync.valueOrNull?.goals
            .firstWhere((g) => g.id == widget.goal.id,
                orElse: () => widget.goal) ??
        widget.goal;

    final isOwner = myId != null && goal.userId == myId;
    final canEdit = isOwner ||
        goal.collaborators.any((c) =>
            c.userId == myId &&
            c.status == 'accepted' &&
            c.role == 'editor');

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _MissionHeader(
                goal: goal,
                mapMode: _mapMode,
                onToggle: () => setState(() => _mapMode = !_mapMode),
                sc: sc,
                onBack: () => Navigator.pop(context),
                onSettings: isOwner
                    ? () => _showGoalSettingsSheet(context, goal, sc,
                        onlineUserIds: _onlineUserIds)
                    : null,
                onStats: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GoalStatsScreen(goal: goal),
                  ),
                ),
                onAiDecompose: canEdit && goal.status == 'active' && GroqService.isInitialized
                    ? () => showAiDecompositionSheet(context, goal)
                    : null,
                isShared: !isOwner,
              ),
              Expanded(
                child: _mapMode
                    ? TacticalMapView(goal: goal, canEdit: canEdit)
                    : _DetailListView(
                        goal: goal,
                        sc: sc,
                        selectedSubGoalId: _selectedSubGoalId,
                        onSubGoalSelected: (id) =>
                            setState(() => _selectedSubGoalId = id),
                        isQuickEntryActive:
                            MediaQuery.of(context).viewInsets.bottom > 0,
                        canEdit: canEdit,
                      ),
              ),
              if (canEdit)
                _QuickEntryBar(
                  goal: goal,
                  sc: sc,
                  selectedSubGoalId: _selectedSubGoalId,
                  onSubGoalSelected: (id) =>
                      setState(() => _selectedSubGoalId = id),
                  bottomInset: bottomInset,
                )
              else
                SizedBox(height: bottomInset + 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mission Header ───────────────────────────────────────────────────────────

class _MissionHeader extends StatelessWidget {
  const _MissionHeader({
    required this.goal,
    required this.mapMode,
    required this.onToggle,
    required this.sc,
    required this.onBack,
    this.onSettings,
    required this.onStats,
    this.onAiDecompose,
    this.isShared = false,
  });

  final Goal goal;
  final bool mapMode;
  final VoidCallback onToggle;
  final SieColors sc;
  final VoidCallback onBack;
  final VoidCallback? onSettings;
  final VoidCallback onStats;
  final VoidCallback? onAiDecompose;
  final bool isShared;

  @override
  Widget build(BuildContext context) {
    final progress = goalProgress(goal);
    final goalColor = goal.color;
    final fatigued = isGoalFatigued(goal);
    final advice = _MissionHeader._buildAdvice(goal);
    final catIcon = _categoryIcon(goal.settings.category);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
      decoration: BoxDecoration(
        color: sc.surface,
        border: Border(bottom: BorderSide(color: sc.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: sc.textPrimary, size: 22),
                onPressed: onBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              if (fatigued)
                Icon(Icons.warning_amber_rounded,
                    color: sc.warning, size: 16),
              if (fatigued) const SizedBox(width: 6),
              _StatusChip(status: goal.status, sc: sc),
              if (isShared) ...[
                const SizedBox(width: 6),
                Icon(Icons.people_outlined, size: 13,
                    color: sc.accent.withValues(alpha: 0.8)),
              ],
              if (onAiDecompose != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.auto_awesome_outlined,
                      color: sc.accent, size: 20),
                  onPressed: onAiDecompose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'AI-план',
                ),
              ],
              const Spacer(),
              if (onSettings != null) ...[
                IconButton(
                  icon: Icon(Icons.settings_outlined,
                      color: sc.textSecondary, size: 20),
                  onPressed: onSettings,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                icon: Icon(Icons.bar_chart_outlined,
                    color: sc.textSecondary, size: 20),
                onPressed: onStats,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              _ViewToggle(
                  mapMode: mapMode, onToggle: onToggle, goalColor: goalColor, sc: sc),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: sc.priorityColor(goal.priority),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  goal.name,
                  style: TextStyle(
                    color: sc.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
              if (catIcon != null) ...[
                const SizedBox(width: 8),
                Icon(catIcon, size: 18, color: sc.textSecondary),
              ],
            ],
          ),
          const SizedBox(height: 10),
          _HeaderProgressBar(progress: progress, goalColor: goalColor, sc: sc),
          if (goal.deadline != null) ...[
            const SizedBox(height: 6),
            _DeadlineChip(
              daysLeft: goal.daysUntilDeadline!,
              isOverdue: goal.isOverdue,
              sc: sc,
            ),
          ],
          if (advice.isNotEmpty) ...[
            const SizedBox(height: 8),
            _StrategicAdviceCard(advice: advice, sc: sc),
          ],
        ],
      ),
    );
  }

  static List<String> _buildAdvice(Goal g) {
    if (g.status != 'active') return const [];
    final advice = <String>[];
    final now = DateTime.now();

    final ref_ = g.updatedAt ?? g.createdAt;
    final daysSinceUpdate = now.difference(ref_).inDays;
    if (daysSinceUpdate >= 7 && goalProgress(g) < 100.0) {
      advice.add(
          'Цель не обновлялась $daysSinceUpdate дн. Выполни хотя бы одну задачу.');
    }

    int overdue = 0;
    void countOverdue(List<SubGoal> sgs) {
      for (final sg in sgs) {
        for (final t in sg.tasks) {
          if (!t.isCompleted && t.dueDate != null && now.isAfter(t.dueDate!)) {
            overdue++;
          }
        }
        countOverdue(sg.children);
      }
    }
    countOverdue(g.subGoals);
    if (overdue >= 2) {
      advice.add('$overdue задач просрочено. Расставь приоритеты.');
    }

    if (g.deadline != null) {
      final daysLeft = g.deadline!.difference(now).inDays;
      if (daysLeft >= 0 && daysLeft <= 14 && goalProgress(g) < 50.0) {
        advice.add(
            'До дедлайна $daysLeft дн., прогресс ${goalProgress(g).round()}%. Ускоряйся!');
      }
    }
    return advice;
  }
}

IconData? _categoryIcon(GoalCategory? cat) => switch (cat) {
      GoalCategory.learning   => Icons.school_outlined,
      GoalCategory.health     => Icons.favorite_outline,
      GoalCategory.project    => Icons.rocket_launch_outlined,
      GoalCategory.lifestyle  => Icons.spa_outlined,
      GoalCategory.discipline => Icons.bolt_outlined,
      null                    => null,
    };

Color _categoryColor(GoalCategory cat) => switch (cat) {
      GoalCategory.learning   => const Color(0xFF4A90D9),
      GoalCategory.health     => const Color(0xFF5AAD6A),
      GoalCategory.project    => const Color(0xFFE07830),
      GoalCategory.lifestyle  => const Color(0xFF9B59B6),
      GoalCategory.discipline => const Color(0xFFF4C430),
    };

String _categoryLabel(GoalCategory cat) => switch (cat) {
      GoalCategory.learning   => 'Обучение',
      GoalCategory.health     => 'Здоровье',
      GoalCategory.project    => 'Проект',
      GoalCategory.lifestyle  => 'Образ жизни',
      GoalCategory.discipline => 'Дисциплина',
    };

class _StrategicAdviceCard extends StatelessWidget {
  const _StrategicAdviceCard({required this.advice, required this.sc});

  final List<String> advice;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: sc.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: sc.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: sc.warning, size: 14),
              const SizedBox(width: 6),
              Text(
                'СОВЕТ',
                style: TextStyle(
                  color: sc.warning,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...advice.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: TextStyle(
                            color: sc.warning.withValues(alpha: 0.8),
                            fontSize: 12)),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(
                            color: sc.textSecondary, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _HeaderProgressBar extends StatelessWidget {
  const _HeaderProgressBar({
    required this.progress,
    required this.goalColor,
    required this.sc,
  });

  final double progress;
  final Color goalColor;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: sc.border,
              valueColor: AlwaysStoppedAnimation<Color>(goalColor),
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${progress.round()}%',
          style: TextStyle(
              color: goalColor, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.mapMode,
    required this.onToggle,
    required this.goalColor,
    required this.sc,
  });

  final bool mapMode;
  final VoidCallback onToggle;
  final Color goalColor;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sc.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleSegment(
              icon: Icons.list,
              active: !mapMode,
              goalColor: goalColor,
              sc: sc,
              isLeft: true,
            ),
            _ToggleSegment(
              icon: Icons.map_outlined,
              active: mapMode,
              goalColor: goalColor,
              sc: sc,
              isLeft: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required this.icon,
    required this.active,
    required this.goalColor,
    required this.sc,
    required this.isLeft,
  });

  final IconData icon;
  final bool active;
  final Color goalColor;
  final SieColors sc;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: active ? goalColor.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.horizontal(
          left: isLeft ? const Radius.circular(7) : Radius.zero,
          right: !isLeft ? const Radius.circular(7) : Radius.zero,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16, color: active ? goalColor : sc.textSecondary),
        ],
      ),
    );
  }
}

// ─── Detail List View ─────────────────────────────────────────────────────────

class _DetailListView extends ConsumerWidget {
  const _DetailListView({
    required this.goal,
    required this.sc,
    required this.selectedSubGoalId,
    required this.onSubGoalSelected,
    this.isQuickEntryActive = false,
    this.canEdit = true,
  });

  final Goal goal;
  final SieColors sc;
  final String? selectedSubGoalId;
  final void Function(String?) onSubGoalSelected;
  final bool isQuickEntryActive;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: sc.accent,
      backgroundColor: sc.isLightMode ? Colors.white : const Color(0xFF0D1B2A),
      onRefresh: () async {
        ref.invalidate(planningProvider);
        await ref.read(planningProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SubGoalsSection(goal: goal, sc: sc,
                isQuickEntryActive: isQuickEntryActive, canEdit: canEdit),
            const SizedBox(height: 16),
            _MilestonesSection(goal: goal, sc: sc, canEdit: canEdit),
            const SizedBox(height: 16),
            _HabitSynergySection(goal: goal, sc: sc),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Recursive task count helpers ────────────────────────────────────────────

int _totalTasks(SubGoal sg) {
  int n = sg.tasks.length;
  for (final c in sg.children) { n += _totalTasks(c); }
  return n;
}

int _completedTasks(SubGoal sg) {
  int n = sg.tasks.where((t) => t.isCompleted).length;
  for (final c in sg.children) { n += _completedTasks(c); }
  return n;
}

// ─── Sub-goals Section ────────────────────────────────────────────────────────

class _SubGoalsSection extends ConsumerStatefulWidget {
  const _SubGoalsSection({
    required this.goal,
    required this.sc,
    this.isQuickEntryActive = false,
    this.canEdit = true,
  });

  final Goal goal;
  final SieColors sc;
  final bool isQuickEntryActive;
  final bool canEdit;

  @override
  ConsumerState<_SubGoalsSection> createState() => _SubGoalsSectionState();
}

class _SubGoalsSectionState extends ConsumerState<_SubGoalsSection> {
  final Set<String> _expanded = {};
  final Set<String> _scoutedIds = {};

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final sc = widget.sc;
    final fogEnabled =
        goal.settings.isFogOfWarEnabled && !widget.isQuickEntryActive;
    final visibleIds =
        computeFogVisibleIds(goal.subGoals, _scoutedIds, fogEnabled);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'ОПЕРАЦИИ',
          icon: Icons.account_tree_outlined,
          count: goal.subGoals.length,
          sc: sc,
          onInfo: fogEnabled ? () => _showFogOfWarInfo(context, sc) : null,
          onAdd: widget.canEdit
              ? () => _showAddSubGoalSheet(context, ref, goal, sc)
              : null,
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: goal.subGoals.length,
          onReorder: widget.canEdit
              ? (oldIdx, newIdx) {
                  if (newIdx > oldIdx) newIdx--;
                  final ids = goal.subGoals.map((sg) => sg.id).toList();
                  ids.insert(newIdx, ids.removeAt(oldIdx));
                  ref
                      .read(planningProvider.notifier)
                      .reorderSubGoals(goal.id, null, ids);
                }
              : (_, __) {},
          itemBuilder: (ctx, i) {
            final sg = goal.subGoals[i];
            final isVisible = visibleIds.contains(sg.id);
            if (!isVisible && fogEnabled) {
              return _LockedSubGoalSlot(
                key: ValueKey('locked_${sg.id}'),
                sc: sc,
                onScout: () => setState(() => _scoutedIds.add(sg.id)),
              );
            }
            final isScouted = _scoutedIds.contains(sg.id) &&
                !computeFogVisibleIds(goal.subGoals, const {}, fogEnabled).contains(sg.id);
            return _SubGoalTile(
              key: ValueKey(sg.id),
              subGoal: sg,
              goal: goal,
              sc: sc,
              reorderIndex: i,
              isExpanded: _expanded.contains(sg.id),
              isScouted: isScouted,
              visibleIds: visibleIds,
              fogEnabled: fogEnabled,
              canEdit: widget.canEdit,
              onScoutChild: (id) => setState(() => _scoutedIds.add(id)),
              onToggle: () => setState(() {
                if (_expanded.contains(sg.id)) {
                  _expanded.remove(sg.id);
                } else {
                  _expanded.add(sg.id);
                }
              }),
              expandedSet: _expanded,
              onToggleChild: (id) => setState(() {
                if (_expanded.contains(id)) {
                  _expanded.remove(id);
                } else {
                  _expanded.add(id);
                }
              }),
            );
          },
        ),
      ],
    );
  }
}

class _SubGoalTile extends ConsumerWidget {
  const _SubGoalTile({
    super.key,
    required this.subGoal,
    required this.goal,
    required this.sc,
    required this.isExpanded,
    required this.onToggle,
    this.depth = 0,
    this.reorderIndex = 0,
    required this.expandedSet,
    required this.onToggleChild,
    this.isScouted = false,
    this.visibleIds,
    this.fogEnabled = false,
    this.onScoutChild,
    this.canEdit = true,
  });

  final SubGoal subGoal;
  final Goal goal;
  final SieColors sc;
  final bool isExpanded;
  final VoidCallback onToggle;
  final int depth;
  final int reorderIndex;
  final Set<String> expandedSet;
  final void Function(String) onToggleChild;
  final bool isScouted;
  final Set<String>? visibleIds;
  final bool fogEnabled;
  final void Function(String)? onScoutChild;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = subGoal;
    final done = _completedTasks(sg);
    final total = _totalTasks(sg);
    final childCount = sg.children.length;
    final childPart = childCount > 0 ? ' · $childCount эт.' : '';
    final prog = subGoalProgress(sg);

    Widget tile = Container(
      margin: const EdgeInsets.fromLTRB(0, 4, 16, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: sg.isCompleted
                ? goal.color.withValues(alpha: 0.4)
                : sc.border),
        color: sc.surface,
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onToggle,
            onLongPress: canEdit
                ? () => _showSubGoalOptionsSheet(context, ref, sg, goal, sc)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (canEdit)
                    ReorderableDragStartListener(
                      index: reorderIndex,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.drag_handle,
                            size: 18, color: sc.textSecondary),
                      ),
                    ),
                  _SubGoalDot(sg: sg, goalColor: goal.color, sc: sc),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sg.name,
                          style: TextStyle(
                            color: sg.isCompleted
                                ? sc.textSecondary
                                : sc.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            decoration: sg.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$done/$total задач$childPart · ${prog.round()}%',
                          style: TextStyle(
                              color: sc.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (isScouted)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.lock_outline,
                          size: 14, color: sc.textSecondary),
                    ),
                  Icon(
                    isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 18,
                    color: sc.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(height: 1, color: sc.border),
            Column(
              children: [
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: sg.tasks.length,
                  onReorder: canEdit
                      ? (oldIdx, newIdx) {
                          if (newIdx > oldIdx) newIdx--;
                          final ids = sg.tasks.map((t) => t.id).toList();
                          ids.insert(newIdx, ids.removeAt(oldIdx));
                          ref.read(planningProvider.notifier).reorderTasks(goal.id, sg.id, ids);
                        }
                      : (_, __) {},
                  itemBuilder: (ctx, i) => _TaskTile(
                    key: ValueKey(sg.tasks[i].id),
                    task: sg.tasks[i],
                    subGoal: sg,
                    goal: goal,
                    sc: sc,
                    reorderIndex: i,
                    canEdit: canEdit,
                  ),
                ),
                if (sg.children.isNotEmpty)
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: sg.children.length,
                    onReorder: canEdit
                        ? (oldIdx, newIdx) {
                            if (newIdx > oldIdx) newIdx--;
                            final ids = sg.children.map((c) => c.id).toList();
                            ids.insert(newIdx, ids.removeAt(oldIdx));
                            ref.read(planningProvider.notifier).reorderSubGoals(goal.id, sg.id, ids);
                          }
                        : (_, __) {},
                    itemBuilder: (ctx, i) {
                      final child = sg.children[i];
                      final childVisible =
                          visibleIds == null || visibleIds!.contains(child.id);
                      if (!childVisible && fogEnabled) {
                        return Padding(
                          key: ValueKey('locked_${child.id}'),
                          padding: const EdgeInsets.only(left: 16),
                          child: _LockedSubGoalSlot(
                            sc: sc,
                            onScout: () => onScoutChild?.call(child.id),
                          ),
                        );
                      }
                      return Padding(
                        key: ValueKey(child.id),
                        padding: const EdgeInsets.only(left: 16),
                        child: _SubGoalTile(
                          subGoal: child,
                          goal: goal,
                          sc: sc,
                          depth: depth + 1,
                          reorderIndex: i,
                          isExpanded: expandedSet.contains(child.id),
                          onToggle: () => onToggleChild(child.id),
                          expandedSet: expandedSet,
                          onToggleChild: onToggleChild,
                          visibleIds: visibleIds,
                          fogEnabled: fogEnabled,
                          onScoutChild: onScoutChild,
                          canEdit: canEdit,
                        ),
                      );
                    },
                  ),
                _AddTaskRow(subGoal: sg, goal: goal, sc: sc, canEdit: canEdit),
                _AddChildSubGoalRow(subGoal: sg, goal: goal, sc: sc, canEdit: canEdit),
              ],
            ),
          ],
        ],
      ),
    );

    if (isScouted) {
      return Opacity(opacity: 0.5, child: tile);
    }
    return tile;
  }
}

class _SubGoalDot extends StatelessWidget {
  const _SubGoalDot({required this.sg, required this.goalColor, required this.sc});

  final SubGoal sg;
  final Color goalColor;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    if (sg.isCompleted) {
      return Icon(Icons.check_circle, color: goalColor, size: 28);
    }
    return SizedBox(
      width: 32,
      height: 32,
      child: CustomPaint(
        painter: _SmallArcPainter(
          progress: subGoalProgress(sg) / 100,
          color: goalColor,
          trackColor: sc.border,
        ),
      ),
    );
  }
}

// ─── Locked SubGoal Slot ──────────────────────────────────────────────────────

class _LockedSubGoalSlot extends StatelessWidget {
  const _LockedSubGoalSlot({super.key, required this.sc, required this.onScout});

  final SieColors sc;
  final VoidCallback onScout;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onScout,
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sc.border.withValues(alpha: 0.4)),
          color: sc.surface.withValues(alpha: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: sc.textSecondary, size: 16),
            const SizedBox(width: 10),
            Text(
              'ЗАБЛОКИРОВАНО',
              style: TextStyle(
                color: sc.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
            const Spacer(),
            Text(
              'Разведать',
              style: TextStyle(color: sc.accent, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Task Tile ────────────────────────────────────────────────────────────────

class _TaskTile extends ConsumerWidget {
  const _TaskTile({
    super.key,
    required this.task,
    required this.subGoal,
    required this.goal,
    required this.sc,
    this.reorderIndex = 0,
    this.canEdit = true,
  });

  final PlanningTask task;
  final SubGoal subGoal;
  final Goal goal;
  final SieColors sc;
  final int reorderIndex;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = task;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          if (canEdit) ...[
            ReorderableDragStartListener(
              index: reorderIndex,
              child: Icon(Icons.drag_handle, size: 16, color: sc.textSecondary),
            ),
            const SizedBox(width: 6),
          ],
          GestureDetector(
            onTap: canEdit
                ? () => ref
                    .read(planningProvider.notifier)
                    .toggleTask(t.id, subGoal.id, goal.id)
                : null,
            child: Icon(
              t.isCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: t.isCompleted ? goal.color : sc.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        t.name,
                        style: TextStyle(
                          color: t.isCompleted
                              ? sc.textSecondary
                              : sc.textPrimary,
                          fontSize: 14,
                          decoration: t.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (t.isRecurring) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.repeat, size: 13, color: sc.accentSecondary),
                    ],
                  ],
                ),
                if (t.dueDate != null || t.isRecurring)
                  Text(
                    [
                      if (t.dueDate != null) _formatDate(t.dueDate!),
                      if (t.isRecurring) _recurrenceLabel(t.recurrenceRule!),
                    ].join(' · '),
                    style: TextStyle(color: sc.textSecondary, fontSize: 10),
                  ),
              ],
            ),
          ),
          if (t.isRecurring && canEdit) ...[
            GestureDetector(
              onTap: () =>
                  _confirmEndRecurrence(context, ref, t.id, subGoal.id, goal.id, sc),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.stop_circle_outlined,
                    size: 16, color: sc.textSecondary),
              ),
            ),
          ],
          _WeightBadge(weight: t.weight, sc: sc),
          if (canEdit) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _confirmDeleteTask(context, ref, t.id, subGoal.id, goal.id, sc),
              child: Icon(Icons.close, size: 14, color: sc.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeightBadge extends StatelessWidget {
  const _WeightBadge({required this.weight, required this.sc});

  final int weight;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    final color = switch (weight) {
      3 => const Color(0xFFC8A84B),
      5 => const Color(0xFFE07830),
      _ => const Color(0xFF888898),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '×$weight',
        style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _AddChildSubGoalRow extends ConsumerWidget {
  const _AddChildSubGoalRow(
      {required this.subGoal, required this.goal, required this.sc, this.canEdit = true});

  final SubGoal subGoal;
  final Goal goal;
  final SieColors sc;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canEdit) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: TextButton.icon(
        onPressed: () => _showAddSubGoalSheet(context, ref, goal, sc,
            parentSubGoalId: subGoal.id),
        icon: Icon(Icons.account_tree_outlined, size: 13, color: sc.textSecondary),
        label: Text(
          'Добавить под-этап',
          style: TextStyle(color: sc.textSecondary, fontSize: 12),
        ),
        style: TextButton.styleFrom(padding: const EdgeInsets.all(8)),
      ),
    );
  }
}

class _AddTaskRow extends ConsumerWidget {
  const _AddTaskRow(
      {required this.subGoal, required this.goal, required this.sc, this.canEdit = true});

  final SubGoal subGoal;
  final Goal goal;
  final SieColors sc;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canEdit) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: TextButton.icon(
        onPressed: () => _showAddTaskSheet(context, ref, subGoal, goal, sc),
        icon: Icon(Icons.add, size: 14, color: sc.accent),
        label: Text(
          'Добавить задачу',
          style: TextStyle(color: sc.accent, fontSize: 13),
        ),
        style: TextButton.styleFrom(padding: const EdgeInsets.all(8)),
      ),
    );
  }
}

// ─── Milestones Section ───────────────────────────────────────────────────────

class _MilestonesSection extends ConsumerWidget {
  const _MilestonesSection({
    required this.goal,
    required this.sc,
    this.canEdit = true,
  });

  final Goal goal;
  final SieColors sc;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'КОНТРОЛЬНЫЕ ТОЧКИ',
          icon: Icons.flag_outlined,
          count: goal.milestones.length,
          sc: sc,
          onAdd: canEdit
              ? () => _showAddMilestoneSheet(context, ref, goal, sc)
              : null,
        ),
        ...goal.milestones.map((m) => _MilestoneTile(
              milestone: m,
              goal: goal,
              sc: sc,
              canEdit: canEdit,
            )),
      ],
    );
  }
}

class _MilestoneTile extends ConsumerWidget {
  const _MilestoneTile({
    required this.milestone,
    required this.goal,
    required this.sc,
    this.canEdit = true,
  });

  final Milestone milestone;
  final Goal goal;
  final SieColors sc;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = milestone;
    if (m.isMetric) return _MetricMilestoneTile(milestone: m, goal: goal, sc: sc, canEdit: canEdit);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: canEdit && !m.isCompleted
                ? () => ref
                    .read(planningProvider.notifier)
                    .completeMilestone(m.id, goal.id)
                : null,
            child: Icon(
              m.isCompleted ? Icons.flag : Icons.outlined_flag,
              color: m.isCompleted ? goal.color : sc.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  style: TextStyle(
                    color: m.isCompleted ? sc.textSecondary : sc.textPrimary,
                    fontSize: 14,
                    decoration:
                        m.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (m.targetDate != null)
                  Text(
                    _formatDate(m.targetDate!),
                    style: TextStyle(color: sc.textSecondary, fontSize: 10),
                  ),
              ],
            ),
          ),
          if (canEdit && !m.isCompleted)
            GestureDetector(
              onTap: () => _confirmDeleteMilestone(
                  context, ref, m.id, goal.id, sc),
              child:
                  Icon(Icons.close, size: 14, color: sc.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _MetricMilestoneTile extends ConsumerWidget {
  const _MetricMilestoneTile({
    required this.milestone,
    required this.goal,
    required this.sc,
    this.canEdit = true,
  });

  final Milestone milestone;
  final Goal goal;
  final SieColors sc;
  final bool canEdit;

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = milestone;
    final logsAsync = ref.watch(milestoneLogsProvider(m.id));
    final progress = metricProgress(m);
    final pct = (progress * 100).round();
    final unit = m.unit ?? '';

    final currentStr = m.currentValue != null
        ? '${_fmt(m.currentValue!)}${unit.isNotEmpty ? ' $unit' : ''}'
        : '—';
    final targetStr = m.targetValue != null
        ? _fmt(m.targetValue!)
        : '?';

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => MilestoneMetricScreen(
                  milestone: m, goalId: goal.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: sc.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sc.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    m.isCompleted ? Icons.flag : Icons.flag_outlined,
                    color: m.isCompleted ? sc.accent : sc.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m.name,
                      style: TextStyle(
                        color: m.isCompleted
                            ? sc.textSecondary
                            : sc.textPrimary,
                        fontSize: 14,
                        decoration: m.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  // Sparkline
                  logsAsync.when(
                    loading: () => const SizedBox(width: 80, height: 28),
                    error: (_, __) => const SizedBox(width: 80, height: 28),
                    data: (logs) => logs.length >= 2
                        ? Sparkline(
                            values: logs.map((l) => l.value).toList(),
                            color: m.isCompleted
                                ? sc.success
                                : sc.accentSecondary,
                            width: 80,
                            height: 28,
                          )
                        : const SizedBox(width: 80, height: 28),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: sc.border,
                            valueColor: AlwaysStoppedAnimation(
                                m.isCompleted ? sc.success : sc.accent),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$currentStr / $targetStr${unit.isNotEmpty ? ' $unit' : ''} · $pct%',
                          style: TextStyle(
                              color: sc.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (canEdit && !m.isCompleted)
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _LogMeasurementSheet(
                              milestone: m, goalId: goal.id, sc: sc),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: sc.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text('ЗАМЕР',
                            style: TextStyle(
                                color: sc.accent,
                                fontSize: 10,
                                letterSpacing: 1)),
                      ),
                    ),
                  if (canEdit)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: GestureDetector(
                        onTap: () => _confirmDeleteMilestone(
                            context, ref, m.id, goal.id, sc),
                        child: Icon(Icons.close,
                            size: 14, color: sc.textSecondary),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Inline log sheet (reused from MilestoneMetricScreen context).
class _LogMeasurementSheet extends ConsumerStatefulWidget {
  const _LogMeasurementSheet(
      {required this.milestone, required this.goalId, required this.sc});
  final Milestone milestone;
  final String goalId;
  final SieColors sc;

  @override
  ConsumerState<_LogMeasurementSheet> createState() =>
      _LogMeasurementSheetState();
}

class _LogMeasurementSheetState
    extends ConsumerState<_LogMeasurementSheet> {
  late final TextEditingController _ctrl;
  double? _parsed;

  @override
  void initState() {
    super.initState();
    final initial = widget.milestone.currentValue;
    _ctrl = TextEditingController(
        text: initial != null ? _fmtV(initial) : '');
    _parsed = initial;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmtV(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  void _applyDelta(double delta) {
    final current = _parsed ?? widget.milestone.currentValue ?? 0;
    final next = current + delta;
    setState(() {
      _parsed = next;
      _ctrl.text = _fmtV(next);
      _ctrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _ctrl.text.length));
    });
  }

  void _onChanged(String s) {
    setState(() => _parsed = double.tryParse(s.replaceAll(',', '.')));
  }

  @override
  Widget build(BuildContext context) {
    final sc = widget.sc;
    final ms = widget.milestone;
    final unit = ms.unit ?? '';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      decoration: BoxDecoration(
        color: sc.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: sc.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ВНЕСТИ ЗАМЕР',
              style: TextStyle(
                  color: sc.textSecondary,
                  fontSize: 11,
                  letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(ms.name,
              style: TextStyle(
                  color: sc.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          Row(
            children: [
              _MeasureStepBtn(label: '−0.1', sc: sc, onTap: () => _applyDelta(-0.1)),
              const SizedBox(width: 8),
              _MeasureStepBtn(label: '−1', sc: sc, onTap: () => _applyDelta(-1)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: sc.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    suffixText: unit,
                    suffixStyle:
                        TextStyle(color: sc.textSecondary, fontSize: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: sc.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: sc.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: sc.accent)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                  onChanged: _onChanged,
                ),
              ),
              const SizedBox(width: 12),
              _MeasureStepBtn(label: '+1', sc: sc, onTap: () => _applyDelta(1)),
              const SizedBox(width: 8),
              _MeasureStepBtn(label: '+0.1', sc: sc, onTap: () => _applyDelta(0.1)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _parsed == null
                  ? null
                  : () {
                      ref
                          .read(planningProvider.notifier)
                          .addMilestoneLog(ms.id, widget.goalId, _parsed!);
                      SieHaptics.success();
                      Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: sc.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('СОХРАНИТЬ',
                  style: TextStyle(
                      letterSpacing: 1.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasureStepBtn extends StatelessWidget {
  const _MeasureStepBtn(
      {required this.label, required this.sc, required this.onTap});
  final String label;
  final SieColors sc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: sc.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sc.border),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: sc.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

// ─── Habit Synergy Section ────────────────────────────────────────────────────

class _HabitSynergySection extends ConsumerWidget {
  const _HabitSynergySection({required this.goal, required this.sc});

  final Goal goal;
  final SieColors sc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits =
        ref.watch(habitsProvider).valueOrNull?.habits ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'СИНЕРГИЯ ПРИВЫЧЕК',
          icon: Icons.link,
          count: goal.habitLinks.length,
          sc: sc,
          onAdd: () => _showHabitPickerSheet(context, ref, goal, habits, sc),
        ),
        ...goal.habitLinks.map((link) {
          final habit = habits.cast<Habit?>().firstWhere(
                (h) => h?.id == link.habitId,
                orElse: () => null,
              );
          return _HabitLinkTile(
              link: link, habit: habit, goal: goal, sc: sc);
        }),
      ],
    );
  }
}

class _HabitLinkTile extends ConsumerWidget {
  const _HabitLinkTile(
      {required this.link, required this.habit, required this.goal, required this.sc});

  final GoalHabitLink link;
  final Habit? habit;
  final Goal goal;
  final SieColors sc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.repeat, size: 18, color: goal.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              habit?.title ?? link.habitId,
              style: TextStyle(color: sc.textPrimary, fontSize: 14),
            ),
          ),
          GestureDetector(
            onTap: () => ref
                .read(planningProvider.notifier)
                .unlinkHabit(link.id, goal.id),
            child: Icon(Icons.link_off, size: 14, color: sc.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Entry Bar ──────────────────────────────────────────────────────────

enum _QuickEntryMode { subGoal, task, milestone }

class _QuickEntryBar extends ConsumerStatefulWidget {
  const _QuickEntryBar({
    required this.goal,
    required this.sc,
    required this.selectedSubGoalId,
    required this.onSubGoalSelected,
    required this.bottomInset,
  });

  final Goal goal;
  final SieColors sc;
  final String? selectedSubGoalId;
  final void Function(String?) onSubGoalSelected;
  final double bottomInset;

  @override
  ConsumerState<_QuickEntryBar> createState() => _QuickEntryBarState();
}

class _QuickEntryBarState extends ConsumerState<_QuickEntryBar> {
  final _ctrl = TextEditingController();
  _QuickEntryMode _mode = _QuickEntryMode.subGoal;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    final notifier = ref.read(planningProvider.notifier);
    switch (_mode) {
      case _QuickEntryMode.subGoal:
        notifier.addSubGoal(widget.goal.id, name);
      case _QuickEntryMode.task:
        final sgId = widget.selectedSubGoalId ??
            (widget.goal.subGoals.isNotEmpty
                ? widget.goal.subGoals.first.id
                : null);
        if (sgId != null) {
          notifier.addTask(
              goalId: widget.goal.id, subGoalId: sgId, name: name);
        }
      case _QuickEntryMode.milestone:
        notifier.addMilestone(widget.goal.id, name);
    }
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final sc = widget.sc;
    final goal = widget.goal;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final effectiveBottom =
        math.max(widget.bottomInset, 0.0) + keyboardInset;

    return Container(
      decoration: BoxDecoration(
        color: sc.surface,
        border: Border(top: BorderSide(color: sc.border)),
      ),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + effectiveBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _ModeChip(
                label: 'ЭТАП',
                mode: _QuickEntryMode.subGoal,
                selected: _mode == _QuickEntryMode.subGoal,
                sc: sc,
                onTap: () => setState(() => _mode = _QuickEntryMode.subGoal),
              ),
              const SizedBox(width: 6),
              _ModeChip(
                label: 'ЗАДАЧА',
                mode: _QuickEntryMode.task,
                selected: _mode == _QuickEntryMode.task,
                sc: sc,
                onTap: () => setState(() => _mode = _QuickEntryMode.task),
              ),
              const SizedBox(width: 6),
              _ModeChip(
                label: 'ТОЧКА',
                mode: _QuickEntryMode.milestone,
                selected: _mode == _QuickEntryMode.milestone,
                sc: sc,
                onTap: () =>
                    setState(() => _mode = _QuickEntryMode.milestone),
              ),
            ],
          ),
          if (_mode == _QuickEntryMode.task &&
              goal.subGoals.isNotEmpty) ...[
            const SizedBox(height: 4),
            _SubGoalSelector(
              subGoals: goal.subGoals,
              selectedId: widget.selectedSubGoalId,
              onSelect: widget.onSubGoalSelected,
              sc: sc,
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: TextStyle(color: sc.textPrimary, fontSize: 14),
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: switch (_mode) {
                      _QuickEntryMode.subGoal => 'Новый этап...',
                      _QuickEntryMode.task => 'Новая задача...',
                      _QuickEntryMode.milestone => 'Контрольная точка...',
                    },
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: sc.textSecondary),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _submit,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: goal.color,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.mode,
    required this.selected,
    required this.sc,
    required this.onTap,
  });

  final String label;
  final _QuickEntryMode mode;
  final bool selected;
  final SieColors sc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? sc.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
              color: selected ? sc.accent : sc.border, width: selected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? sc.accent : sc.textSecondary,
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _SubGoalSelector extends StatelessWidget {
  const _SubGoalSelector({
    required this.subGoals,
    required this.selectedId,
    required this.onSelect,
    required this.sc,
  });

  final List<SubGoal> subGoals;
  final String? selectedId;
  final void Function(String?) onSelect;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    final effectiveId = selectedId ?? subGoals.first.id;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: subGoals
            .map((sg) => GestureDetector(
                  onTap: () => onSelect(sg.id),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: effectiveId == sg.id
                          ? sc.accent.withValues(alpha: 0.1)
                          : Colors.transparent,
                      border: Border.all(
                          color: effectiveId == sg.id
                              ? sc.accent
                              : sc.border),
                    ),
                    child: Text(
                      sg.name,
                      style: TextStyle(
                        color: effectiveId == sg.id
                            ? sc.accent
                            : sc.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.count,
    required this.sc,
    this.onAdd,
    this.onInfo,
  });

  final String title;
  final IconData icon;
  final int count;
  final SieColors sc;
  final VoidCallback? onAdd;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: sc.textSecondary),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: sc.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: sc.border,
            ),
            child: Text(
              '$count',
              style: TextStyle(color: sc.textSecondary, fontSize: 9),
            ),
          ),
          const Spacer(),
          if (onInfo != null) ...[
            GestureDetector(
              onTap: onInfo,
              child: Tooltip(
                message: 'Туман войны активен',
                child: Icon(Icons.info_outline,
                    size: 14, color: sc.accent.withValues(alpha: 0.7)),
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (onAdd != null)
            GestureDetector(
              onTap: onAdd,
              child: Icon(Icons.add, size: 18, color: sc.accent),
            ),
        ],
      ),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.sc});

  final String status;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'completed' => ('ЗАВЕРШЕНА', const Color(0xFF5AADA0)),
      'frozen' => ('ЗАМОРОЖЕНА', const Color(0xFF6A8ED8)),
      'failed' => ('ПРОВАЛЕНА', const Color(0xFFE03050)),
      _ => ('АКТИВНА', const Color(0xFF5AADA0)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _DeadlineChip extends StatelessWidget {
  const _DeadlineChip({
    required this.daysLeft,
    required this.isOverdue,
    required this.sc,
  });

  final int daysLeft;
  final bool isOverdue;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    final color =
        isOverdue ? const Color(0xFFE03050) : const Color(0xFF5AADA0);
    final label = isOverdue
        ? 'просрочено ${daysLeft.abs()} дн.'
        : 'через $daysLeft дн.';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ─── Arc Painters ─────────────────────────────────────────────────────────────

class _SmallArcPainter extends CustomPainter {
  const _SmallArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 8) / 2;
    const strokeWidth = 4.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);
    if (progress > 0) {
      canvas.drawArc(
          rect, -math.pi / 2, math.pi * 2 * progress, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(_SmallArcPainter old) =>
      old.progress != progress || old.color != color;
}

// ─── Bottom Sheets ────────────────────────────────────────────────────────────

void _showAddSubGoalSheet(
    BuildContext context, WidgetRef ref, Goal goal, SieColors sc,
    {String? parentSubGoalId}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddSubGoalSheet(
        goal: goal, sc: sc, parentSubGoalId: parentSubGoalId),
  );
}

void _showAddTaskSheet(BuildContext context, WidgetRef ref, SubGoal sg,
    Goal goal, SieColors sc) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddTaskSheet(subGoal: sg, goal: goal, sc: sc),
  );
}

void _showAddMilestoneSheet(
    BuildContext context, WidgetRef ref, Goal goal, SieColors sc) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddMilestoneSheet(goal: goal, sc: sc),
  );
}

void _showHabitPickerSheet(BuildContext context, WidgetRef ref, Goal goal,
    List<Habit> habits, SieColors sc) {
  final linkedIds = goal.habitLinks.map((l) => l.habitId).toSet();
  final available = habits.where((h) => !linkedIds.contains(h.id)).toList();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _HabitPickerSheet(
        goal: goal, available: available, sc: sc),
  );
}

void _showSubGoalOptionsSheet(BuildContext context, WidgetRef ref,
    SubGoal sg, Goal goal, SieColors sc) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _SubGoalOptionsSheet(
      subGoal: sg,
      goal: goal,
      sc: sc,
      onComplete: () {
        Navigator.pop(context);
        ref
            .read(planningProvider.notifier)
            .completeSubGoal(sg.id, goal.id);
      },
      onUnparent: sg.parentSubGoalId == null
          ? null
          : () {
              Navigator.pop(context);
              ref.read(planningProvider.notifier).unparentSubGoal(sg.id);
            },
      onDelete: () async {
        Navigator.pop(context);
        final confirm = await confirmDestructive(
          context,
          ref,
          title: 'Удалить этап?',
          message: 'Этап «${sg.name}» и все его задачи будут удалены.',
        );
        if (confirm) {
          ref
              .read(planningProvider.notifier)
              .deleteSubGoal(sg.id, goal.id);
        }
      },
    ),
  );
}

Future<void> _confirmDeleteTask(BuildContext context, WidgetRef ref,
    String taskId, String subGoalId, String goalId, SieColors sc) async {
  final confirm = await confirmDestructive(
    context,
    ref,
    title: 'Удалить задачу?',
    message: 'Задача будет удалена без возможности восстановления.',
  );
  if (confirm) {
    ref.read(planningProvider.notifier).deleteTask(taskId, subGoalId, goalId);
  }
}

Future<void> _confirmEndRecurrence(BuildContext context, WidgetRef ref,
    String taskId, String subGoalId, String goalId, SieColors sc) async {
  final confirm = await confirmDestructive(
    context,
    ref,
    title: 'Завершить серию?',
    message:
        'Текущая задача останется, но новые повторы создаваться не будут.',
  );
  if (confirm) {
    ref
        .read(planningProvider.notifier)
        .endRecurrence(taskId, subGoalId, goalId);
  }
}

/// Human-readable label for a recurrence rule (compact format).
String _recurrenceLabel(String rule) {
  final parts = rule.split(':');
  final arg = parts.length > 1 ? parts[1] : '';
  switch (parts[0]) {
    case 'daily':
      return '↻ ежедневно';
    case 'every':
      return '↻ каждые $arg дн.';
    case 'monthly':
      return '↻ ежемесячно ($arg)';
    case 'weekly':
      const names = {
        '1': 'Пн',
        '2': 'Вт',
        '3': 'Ср',
        '4': 'Чт',
        '5': 'Пт',
        '6': 'Сб',
        '7': 'Вс'
      };
      final days = arg.split(',').map((d) => names[d.trim()] ?? d).join(',');
      return '↻ $days';
    default:
      return '↻';
  }
}

Future<void> _confirmDeleteMilestone(BuildContext context, WidgetRef ref,
    String milestoneId, String goalId, SieColors sc) async {
  final confirm = await confirmDestructive(
    context,
    ref,
    title: 'Удалить контрольную точку?',
    message: 'Контрольная точка будет удалена без возможности восстановления.',
  );
  if (confirm) {
    ref
        .read(planningProvider.notifier)
        .deleteMilestone(milestoneId, goalId);
  }
}

// ─── Sheet widgets ────────────────────────────────────────────────────────────

class _AddSubGoalSheet extends ConsumerStatefulWidget {
  const _AddSubGoalSheet(
      {required this.goal, required this.sc, this.parentSubGoalId});

  final Goal goal;
  final SieColors sc;
  final String? parentSubGoalId;

  @override
  ConsumerState<_AddSubGoalSheet> createState() => _AddSubGoalSheetState();
}

class _AddSubGoalSheetState extends ConsumerState<_AddSubGoalSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sc = widget.sc;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return _SheetContainer(
      sc: sc,
      bottomInset: bottomInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetTitle('НОВЫЙ ЭТАП', sc),
          const SizedBox(height: 12),
          _SheetTextField('Название этапа', _ctrl, sc),
          const SizedBox(height: 20),
          _SheetSubmitButton(
            label: 'СОЗДАТЬ ЭТАП',
            sc: sc,
            onTap: () {
              final name = _ctrl.text.trim();
              if (name.isEmpty) return;
              ref
                  .read(planningProvider.notifier)
                  .addSubGoal(widget.goal.id, name,
                      parentSubGoalId: widget.parentSubGoalId);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _RecurChip extends StatelessWidget {
  const _RecurChip(this.label, this.value, this.current, this.sc, this.onTap);

  final String label;
  final String value;
  final String current;
  final SieColors sc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = current == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? sc.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? sc.accent : sc.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? sc.accent : sc.textSecondary,
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton(
      {required this.icon, required this.sc, required this.onTap});

  final IconData icon;
  final SieColors sc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: sc.border),
        ),
        child: Icon(icon, size: 16, color: sc.textPrimary),
      ),
    );
  }
}

class _AddTaskSheet extends ConsumerStatefulWidget {
  const _AddTaskSheet(
      {required this.subGoal, required this.goal, required this.sc});

  final SubGoal subGoal;
  final Goal goal;
  final SieColors sc;

  @override
  ConsumerState<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<_AddTaskSheet> {
  final _ctrl = TextEditingController();
  int _weight = 1;
  DateTime? _dueDate;
  String _recur = 'none'; // none|daily|weekly|monthly|every
  int _everyN = 3;

  String? _buildRule() {
    final anchor = _dueDate ?? DateTime.now();
    switch (_recur) {
      case 'daily':
        return 'daily';
      case 'weekly':
        return 'weekly:${anchor.weekday}';
      case 'monthly':
        return 'monthly:${anchor.day}';
      case 'every':
        return 'every:$_everyN';
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sc = widget.sc;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return _SheetContainer(
      sc: sc,
      bottomInset: bottomInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetTitle('НОВАЯ ЗАДАЧА', sc),
          const SizedBox(height: 12),
          _SheetTextField('Название задачи', _ctrl, sc, autofocus: true),
          const SizedBox(height: 16),
          Text('СЛОЖНОСТЬ',
              style: TextStyle(
                  color: sc.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              _WeightButton(
                  label: 'Лёгкая',
                  value: 1,
                  selected: _weight == 1,
                  sc: sc,
                  onTap: () => setState(() => _weight = 1)),
              const SizedBox(width: 6),
              _WeightButton(
                  label: 'Средняя',
                  value: 3,
                  selected: _weight == 3,
                  sc: sc,
                  onTap: () => setState(() => _weight = 3)),
              const SizedBox(width: 6),
              _WeightButton(
                  label: 'Сложная',
                  value: 5,
                  selected: _weight == 5,
                  sc: sc,
                  onTap: () => setState(() => _weight = 5)),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: ColorScheme.dark(primary: sc.accent),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _dueDate = picked);
            },
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 14, color: sc.accent),
                const SizedBox(width: 6),
                Text(
                  _dueDate != null
                      ? 'Дедлайн: ${_formatDate(_dueDate!)}'
                      : 'Добавить дедлайн (необязательно)',
                  style: TextStyle(color: sc.accent, fontSize: 13),
                ),
                if (_dueDate != null) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _dueDate = null),
                    child:
                        Icon(Icons.close, size: 12, color: sc.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('ПОВТОР',
              style: TextStyle(
                  color: sc.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _RecurChip('Нет', 'none', _recur, sc,
                  () => setState(() => _recur = 'none')),
              _RecurChip('Ежедневно', 'daily', _recur, sc,
                  () => setState(() => _recur = 'daily')),
              _RecurChip('Еженедельно', 'weekly', _recur, sc,
                  () => setState(() => _recur = 'weekly')),
              _RecurChip('Ежемесячно', 'monthly', _recur, sc,
                  () => setState(() => _recur = 'monthly')),
              _RecurChip('Каждые N дней', 'every', _recur, sc,
                  () => setState(() => _recur = 'every')),
            ],
          ),
          if (_recur == 'every') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Каждые', style: TextStyle(color: sc.textSecondary, fontSize: 13)),
                const SizedBox(width: 10),
                _StepperButton(
                    icon: Icons.remove,
                    sc: sc,
                    onTap: () => setState(
                        () => _everyN = _everyN > 1 ? _everyN - 1 : 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('$_everyN',
                      style: TextStyle(
                          color: sc.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
                _StepperButton(
                    icon: Icons.add,
                    sc: sc,
                    onTap: () => setState(
                        () => _everyN = _everyN < 99 ? _everyN + 1 : 99)),
                const SizedBox(width: 10),
                Text('дней', style: TextStyle(color: sc.textSecondary, fontSize: 13)),
              ],
            ),
          ],
          if (_recur != 'none' && _recur != 'daily' && _recur != 'every')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _recur == 'weekly'
                    ? 'Повтор в этот день недели (по дате дедлайна)'
                    : 'Повтор в это число месяца (по дате дедлайна)',
                style: TextStyle(color: sc.textSecondary, fontSize: 11),
              ),
            ),
          const SizedBox(height: 20),
          _SheetSubmitButton(
            label: 'ДОБАВИТЬ ЗАДАЧУ',
            sc: sc,
            onTap: () {
              final name = _ctrl.text.trim();
              if (name.isEmpty) return;
              ref.read(planningProvider.notifier).addTask(
                    goalId: widget.goal.id,
                    subGoalId: widget.subGoal.id,
                    name: name,
                    weight: _weight,
                    dueDate: _dueDate,
                    recurrenceRule: _buildRule(),
                  );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _WeightButton extends StatelessWidget {
  const _WeightButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.sc,
    required this.onTap,
  });

  final String label;
  final int value;
  final bool selected;
  final SieColors sc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (value) {
      3 => const Color(0xFFC8A84B),
      5 => const Color(0xFFE07830),
      _ => const Color(0xFF888898),
    };
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
            border: Border.all(
                color: selected ? color : sc.border,
                width: selected ? 1.5 : 1),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? color : sc.textSecondary,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddMilestoneSheet extends ConsumerStatefulWidget {
  const _AddMilestoneSheet({required this.goal, required this.sc});

  final Goal goal;
  final SieColors sc;

  @override
  ConsumerState<_AddMilestoneSheet> createState() =>
      _AddMilestoneSheetState();
}

class _AddMilestoneSheetState extends ConsumerState<_AddMilestoneSheet> {
  final _nameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  DateTime? _targetDate;
  String _kind = 'binary'; // 'binary' | 'metric'
  String _direction = 'up'; // 'up' | 'down'

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _startCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sc = widget.sc;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return _SheetContainer(
      sc: sc,
      bottomInset: bottomInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetTitle('КОНТРОЛЬНАЯ ТОЧКА', sc),
          const SizedBox(height: 12),
          _SheetTextField('Название точки', _nameCtrl, sc, autofocus: true),
          const SizedBox(height: 16),

          // Kind selector.
          Row(
            children: [
              _KindChip(
                label: 'Бинарная',
                selected: _kind == 'binary',
                sc: sc,
                onTap: () => setState(() => _kind = 'binary'),
              ),
              const SizedBox(width: 8),
              _KindChip(
                label: 'Метрика',
                selected: _kind == 'metric',
                sc: sc,
                onTap: () => setState(() => _kind = 'metric'),
              ),
            ],
          ),

          // Metric fields.
          if (_kind == 'metric') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SheetTextField('Старт', _startCtrl, sc,
                      keyboard: const TextInputType.numberWithOptions(decimal: true)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SheetTextField('Цель', _targetCtrl, sc,
                      keyboard: const TextInputType.numberWithOptions(decimal: true)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SheetTextField('Ед. (кг, \$, км)', _unitCtrl, sc),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Направление:',
                    style: TextStyle(color: sc.textSecondary, fontSize: 12)),
                const SizedBox(width: 12),
                _KindChip(
                  label: '↑ Увеличивать',
                  selected: _direction == 'up',
                  sc: sc,
                  onTap: () => setState(() => _direction = 'up'),
                ),
                const SizedBox(width: 8),
                _KindChip(
                  label: '↓ Уменьшать',
                  selected: _direction == 'down',
                  sc: sc,
                  onTap: () => setState(() => _direction = 'down'),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 14)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: ColorScheme.dark(primary: sc.accent),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _targetDate = picked);
            },
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 14, color: sc.accent),
                const SizedBox(width: 6),
                Text(
                  _targetDate != null
                      ? 'Дата: ${_formatDate(_targetDate!)}'
                      : 'Добавить дату (необязательно)',
                  style: TextStyle(color: sc.accent, fontSize: 13),
                ),
                if (_targetDate != null) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _targetDate = null),
                    child:
                        Icon(Icons.close, size: 12, color: sc.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SheetSubmitButton(
            label: 'ДОБАВИТЬ ТОЧКУ',
            sc: sc,
            onTap: () {
              final name = _nameCtrl.text.trim();
              if (name.isEmpty) return;
              final startV =
                  double.tryParse(_startCtrl.text.replaceAll(',', '.'));
              final targetV =
                  double.tryParse(_targetCtrl.text.replaceAll(',', '.'));
              final unit = _unitCtrl.text.trim();
              if (_kind == 'metric' && (startV == null || targetV == null)) {
                return; // Require numeric fields for metric.
              }
              ref.read(planningProvider.notifier).addMilestone(
                    widget.goal.id,
                    name,
                    targetDate: _targetDate,
                    kind: _kind,
                    unit: unit.isEmpty ? null : unit,
                    startValue: startV,
                    targetValue: targetV,
                    direction: _direction,
                  );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip(
      {required this.label,
      required this.selected,
      required this.sc,
      required this.onTap});
  final String label;
  final bool selected;
  final SieColors sc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? sc.accent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? sc.accent : sc.border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: selected ? sc.accent : sc.textSecondary,
              fontSize: 12),
        ),
      ),
    );
  }
}

class _HabitPickerSheet extends ConsumerWidget {
  const _HabitPickerSheet(
      {required this.goal, required this.available, required this.sc});

  final Goal goal;
  final List<Habit> available;
  final SieColors sc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SheetContainer(
      sc: sc,
      bottomInset: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetTitle('ПРИВЯЗАТЬ ПРИВЫЧКУ', sc),
          const SizedBox(height: 12),
          if (available.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Нет доступных привычек',
                  style: TextStyle(color: sc.textSecondary, fontSize: 14),
                ),
              ),
            )
          else
            ...available.map((h) => InkWell(
                  onTap: () {
                    ref
                        .read(planningProvider.notifier)
                        .linkHabit(goal.id, h.id);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.repeat, size: 18, color: sc.accent),
                        const SizedBox(width: 12),
                        Text(h.title,
                            style: TextStyle(
                                color: sc.textPrimary, fontSize: 15)),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

class _SubGoalOptionsSheet extends StatelessWidget {
  const _SubGoalOptionsSheet({
    required this.subGoal,
    required this.goal,
    required this.sc,
    required this.onComplete,
    required this.onDelete,
    this.onUnparent,
  });

  final SubGoal subGoal;
  final Goal goal;
  final SieColors sc;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final VoidCallback? onUnparent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: sc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sc.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: sc.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              subGoal.name,
              style: TextStyle(
                  color: sc.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Divider(height: 1, color: sc.border),
          if (!subGoal.isCompleted)
            _OptionTile(
              icon: Icons.check_circle_outline,
              label: 'Завершить этап',
              color: const Color(0xFF5AADA0),
              onTap: onComplete,
            ),
          if (onUnparent != null)
            _OptionTile(
              icon: Icons.arrow_upward_outlined,
              label: 'Вынести на уровень выше',
              color: const Color(0xFF888898),
              onTap: onUnparent!,
            ),
          _OptionTile(
            icon: Icons.delete_outline,
            label: 'Удалить этап',
            color: const Color(0xFFE03050),
            onTap: onDelete,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Fog of War Info ──────────────────────────────────────────────────────────

void _showFogOfWarInfo(BuildContext context, SieColors sc) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _FogOfWarInfoSheet(sc: sc),
  );
}

class _FogOfWarInfoSheet extends StatelessWidget {
  const _FogOfWarInfoSheet({required this.sc});
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: sc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sc.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: sc.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.filter_drama_outlined, color: sc.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'ТУМАН ВОЙНЫ',
                style: TextStyle(
                  color: sc.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Режим «Туман войны» скрывает этапы операции до их разблокировки. '
            'Чтобы увидеть следующий этап, нажми «Разведать» на заблокированном элементе.\n\n'
            'Этот режим помогает сосредоточиться на текущих задачах, '
            'постепенно раскрывая план по мере продвижения.',
            style: TextStyle(color: sc.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: sc.border),
                foregroundColor: sc.textSecondary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('ПОНЯТНО'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sheet helpers ────────────────────────────────────────────────────────────

class _SheetContainer extends StatelessWidget {
  const _SheetContainer(
      {required this.child, required this.sc, required this.bottomInset});

  final Widget child;
  final SieColors sc;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: sc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sc.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: sc.border,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.title, this.sc);

  final String title;
  final SieColors sc;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: TextStyle(
          color: sc.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.5,
        ),
      );
}

class _SheetTextField extends StatelessWidget {
  const _SheetTextField(this.hint, this.ctrl, this.sc,
      {this.autofocus = false, this.keyboard});

  final String hint;
  final TextEditingController ctrl;
  final SieColors sc;
  final bool autofocus;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        autofocus: autofocus,
        keyboardType: keyboard,
        style: TextStyle(color: sc.textPrimary, fontSize: 16),
        textCapitalization: keyboard != null
            ? TextCapitalization.none
            : TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: sc.textSecondary, fontSize: 16),
          enabledBorder:
              UnderlineInputBorder(borderSide: BorderSide(color: sc.border)),
          focusedBorder:
              UnderlineInputBorder(borderSide: BorderSide(color: sc.accent)),
        ),
      );
}

class _SheetSubmitButton extends StatelessWidget {
  const _SheetSubmitButton(
      {required this.label, required this.sc, required this.onTap});

  final String label;
  final SieColors sc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: sc.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5),
          ),
        ),
      );
}

// ─── Goal Settings Sheet ──────────────────────────────────────────────────────

void _showGoalSettingsSheet(BuildContext context, Goal goal, SieColors sc,
    {Set<String> onlineUserIds = const {}}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => GoalSettingsScreen(
        goal: goal,
        onlineUserIds: onlineUserIds,
      ),
    ),
  );
}

class GoalSettingsScreen extends ConsumerStatefulWidget {
  const GoalSettingsScreen({
    super.key,
    required this.goal,
    this.onlineUserIds = const {},
  });

  final Goal goal;
  final Set<String> onlineUserIds;

  @override
  ConsumerState<GoalSettingsScreen> createState() => _GoalSettingsScreenState();
}

class _GoalSettingsScreenState extends ConsumerState<GoalSettingsScreen> {
  late GoalSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.goal.settings;
  }

  @override
  Widget build(BuildContext context) {
    final sc = ref.watch(sieColorsProvider);
    final goal = ref.watch(planningProvider).valueOrNull
            ?.goals.firstWhere((g) => g.id == widget.goal.id,
                orElse: () => widget.goal) ??
        widget.goal;
    final isFrozen = goal.status == 'frozen';

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: sc.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: sc.textPrimary),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
          title: Text(
            'НАСТРОЙКИ МИССИИ',
            style: TextStyle(
              color: sc.textSecondary,
              fontSize: 12,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: sc.border),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                goal.name,
                style: TextStyle(
                    color: sc.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Создано: ${_formatDate(goal.createdAt)}',
                style: TextStyle(color: sc.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Divider(height: 1, color: sc.border),
              const SizedBox(height: 16),
              // Fog of War toggle
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Туман войны',
                          style: TextStyle(
                              color: sc.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Скрывает этапы до их разблокировки',
                          style: TextStyle(color: sc.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _settings.isFogOfWarEnabled,
                    onChanged: (v) => setState(
                        () => _settings = _settings.copyWith(isFogOfWarEnabled: v)),
                    activeColor: sc.accent,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Hide completed tasks toggle
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Скрыть выполненные задачи',
                      style: TextStyle(
                          color: sc.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  Switch(
                    value: _settings.hideCompletedTasks,
                    onChanged: (v) => setState(
                        () => _settings = _settings.copyWith(hideCompletedTasks: v)),
                    activeColor: sc.accent,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Remind before deadline stepper
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Напомнить за дней до дедлайна',
                      style: TextStyle(
                          color: sc.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  _StepperWidget(
                    value: _settings.remindBeforeDeadlineDays,
                    min: 1,
                    max: 30,
                    sc: sc,
                    onChanged: (v) => setState(() =>
                        _settings = _settings.copyWith(remindBeforeDeadlineDays: v)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(height: 1, color: sc.border),
              const SizedBox(height: 16),
              // Category picker
              Text(
                'Категория миссии',
                style: TextStyle(
                    color: sc.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CategoryChip(
                    label: 'Нет',
                    icon: Icons.remove_circle_outline,
                    color: sc.textSecondary,
                    selected: _settings.category == null,
                    onTap: () => setState(
                        () => _settings = _settings.copyWith(category: null)),
                    sc: sc,
                  ),
                  ...GoalCategory.values.map((cat) => _CategoryChip(
                        label: _categoryLabel(cat),
                        icon: _categoryIcon(cat)!,
                        color: _categoryColor(cat),
                        selected: _settings.category == cat,
                        onTap: () => setState(
                            () => _settings = _settings.copyWith(category: cat)),
                        sc: sc,
                      )),
                ],
              ),
              const SizedBox(height: 20),
              Divider(height: 1, color: sc.border),
              const SizedBox(height: 12),
              // Status actions
              _SettingsActionRow(
                icon: isFrozen ? Icons.play_arrow_outlined : Icons.ac_unit,
                label: isFrozen ? 'Разморозить миссию' : 'Заморозить миссию',
                color: const Color(0xFF6A8ED8),
                onTap: () {
                  final newStatus = isFrozen ? 'active' : 'frozen';
                  ref
                      .read(planningProvider.notifier)
                      .updateGoalStatus(goal.id, newStatus);
                  Navigator.pop(context);
                },
              ),
              if (goal.status != 'completed')
                _SettingsActionRow(
                  icon: Icons.check_circle_outline,
                  label: 'Завершить миссию',
                  color: const Color(0xFF5AADA0),
                  onTap: () async {
                    final medal = await ref
                        .read(planningProvider.notifier)
                        .updateGoalStatus(goal.id, 'completed');
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MissionAccomplishedScreen(
                          xpGained: goalCompletionBaseXp(goal) + (medal?.xpBonus ?? 100),
                          dpGained: _categoryDp(goal.settings.category),
                          medal: medal,
                          subtitle: 'МИССИЯ ЗАВЕРШЕНА',
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 20),
              Divider(height: 1, color: sc.border),
              const SizedBox(height: 16),
              _CollaborationSection(
                goal: goal,
                sc: sc,
                onlineUserIds: widget.onlineUserIds,
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: FilledButton(
              onPressed: () {
                ref
                    .read(planningProvider.notifier)
                    .updateGoalSettings(goal.id, _settings);
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: sc.accent,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'ПРИМЕНИТЬ',
                style: TextStyle(
                    fontWeight: FontWeight.w700, letterSpacing: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Collaboration Section ────────────────────────────────────────────────────

class _CollaborationSection extends ConsumerWidget {
  const _CollaborationSection({
    required this.goal,
    required this.sc,
    required this.onlineUserIds,
  });

  final Goal goal;
  final SieColors sc;
  final Set<String> onlineUserIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(goalCollaborationProvider);
    final liveGoal = ref.watch(planningProvider).valueOrNull
            ?.goals.firstWhere((g) => g.id == goal.id,
                orElse: () => goal) ??
        goal;
    final accepted =
        liveGoal.collaborators.where((c) => c.status == 'accepted').toList();
    final pending =
        liveGoal.collaborators.where((c) => c.status == 'pending').toList();
    final canInviteMore = (accepted.length + pending.length) < 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people_outlined, size: 14, color: sc.textSecondary),
            const SizedBox(width: 6),
            Text(
              'СОВМЕСТНАЯ РАБОТА',
              style: TextStyle(
                  color: sc.textSecondary,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...accepted.map((c) => _CollaboratorRow(
              collaborator: c,
              sc: sc,
              isOnline: onlineUserIds.contains(c.userId),
              onRoleChange: (newRole) =>
                  notifier.updateRole(liveGoal.id, c.userId, newRole),
              onRemove: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Удалить участника?'),
                    content: Text(
                        'Убрать ${c.profile?.username ?? c.userId} из совместной работы?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Отмена')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Удалить')),
                    ],
                  ),
                );
                if (ok == true) notifier.remove(liveGoal.id, c.userId);
              },
            )),
        ...pending.map((c) => _PendingCollaboratorRow(
              collaborator: c,
              sc: sc,
              onRevoke: () => notifier.remove(liveGoal.id, c.userId),
            )),
        const SizedBox(height: 8),
        if (canInviteMore)
          TextButton.icon(
            icon: Icon(Icons.person_add_outlined, size: 16, color: sc.accent),
            label: Text('Пригласить друга',
                style: TextStyle(color: sc.accent, fontSize: 13)),
            onPressed: () => _showCollaboratorPickerSheet(context, ref, liveGoal, sc),
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 0)),
          ),
      ],
    );
  }
}

class _CollaboratorRow extends StatelessWidget {
  const _CollaboratorRow({
    required this.collaborator,
    required this.sc,
    required this.isOnline,
    required this.onRoleChange,
    required this.onRemove,
  });

  final GoalCollaborator collaborator;
  final SieColors sc;
  final bool isOnline;
  final void Function(String) onRoleChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = collaborator;
    final url = c.profile?.avatarUrl;
    final name = c.profile?.username ?? c.userId.substring(0, 8);
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sc.surface,
                    border: Border.all(color: sc.border)),
                child: ClipOval(
                  child: url != null && url.isNotEmpty
                      ? Image.network(url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                              child: Text(letter,
                                  style: TextStyle(color: sc.accent))))
                      : Center(
                          child: Text(letter,
                              style: TextStyle(
                                  color: sc.accent, fontWeight: FontWeight.w600))),
                ),
              ),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: sc.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: TextStyle(
                    color: sc.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
          DropdownButton<String>(
            value: c.role,
            underline: const SizedBox(),
            isDense: true,
            style: TextStyle(color: sc.textSecondary, fontSize: 12),
            dropdownColor: sc.surface,
            items: const [
              DropdownMenuItem(value: 'viewer', child: Text('Просмотр')),
              DropdownMenuItem(value: 'editor', child: Text('Редактор')),
            ],
            onChanged: (v) {
              if (v != null && v != c.role) onRoleChange(v);
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.person_remove_outlined,
                size: 16, color: sc.textSecondary),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _PendingCollaboratorRow extends StatelessWidget {
  const _PendingCollaboratorRow({
    required this.collaborator,
    required this.sc,
    required this.onRevoke,
  });

  final GoalCollaborator collaborator;
  final SieColors sc;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final c = collaborator;
    final name = c.profile?.username ?? c.userId.substring(0, 8);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 16, color: sc.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                      text: name,
                      style: TextStyle(color: sc.textPrimary, fontSize: 13)),
                  TextSpan(
                      text: '  ожидает ответа',
                      style: TextStyle(
                          color: sc.textSecondary,
                          fontSize: 11,
                          fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: onRevoke,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero),
            child: Text('Отозвать',
                style: TextStyle(color: sc.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

void _showCollaboratorPickerSheet(
    BuildContext context, WidgetRef ref, Goal goal, SieColors sc) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (_) => _CollaboratorPickerSheet(goal: goal, sc: sc),
  );
}

class _CollaboratorPickerSheet extends ConsumerStatefulWidget {
  const _CollaboratorPickerSheet({required this.goal, required this.sc});

  final Goal goal;
  final SieColors sc;

  @override
  ConsumerState<_CollaboratorPickerSheet> createState() =>
      _CollaboratorPickerSheetState();
}

class _CollaboratorPickerSheetState
    extends ConsumerState<_CollaboratorPickerSheet> {
  String _selectedRole = 'viewer';
  String? _invitingUserId;

  Future<void> _invite(BuildContext context, String goalId, String userId) async {
    setState(() => _invitingUserId = userId);
    await ref.read(goalCollaborationProvider).invite(goalId, userId, _selectedRole);
    await ref.read(planningProvider.future);
    if (mounted) setState(() => _invitingUserId = null);
  }

  @override
  Widget build(BuildContext context) {
    final sc = widget.sc;
    final liveGoal = ref.watch(planningProvider).valueOrNull
            ?.goals.firstWhere((g) => g.id == widget.goal.id,
                orElse: () => widget.goal) ??
        widget.goal;
    final friends =
        ref.watch(friendsProvider).valueOrNull?.friends ?? [];
    final acceptedIds = liveGoal.collaborators
        .where((c) => c.status == 'accepted')
        .map((c) => c.userId)
        .toSet();
    final pendingIds = liveGoal.collaborators
        .where((c) => c.status == 'pending')
        .map((c) => c.userId)
        .toSet();
    final available =
        friends.where((f) => !acceptedIds.contains(f.otherUser.id)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (sheetContext, controller) => Container(
        decoration: BoxDecoration(
          color: sc.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: sc.border),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: sc.border,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ПРИГЛАСИТЬ ДРУГА',
                      style: TextStyle(
                          color: sc.textSecondary,
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Права:',
                          style: TextStyle(
                              color: sc.textPrimary, fontSize: 13)),
                      const SizedBox(width: 12),
                      _RoleChip(
                        label: 'Просмотр',
                        selected: _selectedRole == 'viewer',
                        sc: sc,
                        onTap: () =>
                            setState(() => _selectedRole = 'viewer'),
                      ),
                      const SizedBox(width: 8),
                      _RoleChip(
                        label: 'Редактор',
                        selected: _selectedRole == 'editor',
                        sc: sc,
                        onTap: () =>
                            setState(() => _selectedRole = 'editor'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: sc.border, height: 1),
            Expanded(
              child: available.isEmpty
                  ? Center(
                      child: Text('Нет доступных друзей',
                          style: TextStyle(
                              color: sc.textSecondary, fontSize: 14)),
                    )
                  : ListView.builder(
                      controller: controller,
                      itemCount: available.length,
                      itemBuilder: (_, i) {
                        final friend = available[i];
                        final profile = friend.otherUser;
                        final url = profile.avatarUrl;
                        final name = profile.username ?? profile.id;
                        final letter = name.isNotEmpty
                            ? name[0].toUpperCase()
                            : '?';
                        final isInviting = _invitingUserId == profile.id;
                        final isPending = pendingIds.contains(profile.id);
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: sc.surface,
                                border: Border.all(color: sc.border)),
                            child: ClipOval(
                              child: url != null && url.isNotEmpty
                                  ? Image.network(url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Center(
                                              child: Text(letter,
                                                  style: TextStyle(
                                                      color: sc.accent))))
                                  : Center(
                                      child: Text(letter,
                                          style: TextStyle(
                                              color: sc.accent))),
                            ),
                          ),
                          title: Text(name,
                              style: TextStyle(
                                  color: sc.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text(
                              'LVL ${profile.level} · ${profile.totalXp} XP',
                              style: TextStyle(
                                  color: sc.textSecondary, fontSize: 11)),
                          trailing: SizedBox(
                            height: 36,
                            child: FilledButton(
                              onPressed: (isPending || _invitingUserId != null)
                                  ? null
                                  : () => _invite(context, liveGoal.id, profile.id),
                              style: FilledButton.styleFrom(
                                backgroundColor: sc.accent,
                                disabledBackgroundColor: sc.accent.withValues(alpha: 0.4),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                minimumSize: const Size(72, 36),
                              ),
                              child: isInviting
                                  ? const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : Text(isPending ? 'Отправлено' : 'Позвать',
                                      style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.selected,
    required this.sc,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final SieColors sc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? sc.accent : sc.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? sc.accent : sc.border),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : sc.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
      );
}

class _StepperWidget extends StatelessWidget {
  const _StepperWidget({
    required this.value,
    required this.min,
    required this.max,
    required this.sc,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final SieColors sc;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBtn(
          icon: Icons.remove,
          enabled: value > min,
          sc: sc,
          onTap: () => onChanged(value - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '$value',
            style: TextStyle(
                color: sc.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
        ),
        _StepBtn(
          icon: Icons.add,
          enabled: value < max,
          sc: sc,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn(
      {required this.icon,
      required this.enabled,
      required this.sc,
      required this.onTap});

  final IconData icon;
  final bool enabled;
  final SieColors sc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: enabled
                  ? sc.accent.withValues(alpha: 0.5)
                  : sc.border),
        ),
        child: Icon(icon,
            size: 14,
            color: enabled ? sc.accent : sc.textSecondary),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.sc,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: selected ? color : sc.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: selected ? color : sc.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : sc.textSecondary,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
