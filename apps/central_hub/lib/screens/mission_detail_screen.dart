import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'tactical_map_view.dart';

// ─── Color helpers ────────────────────────────────────────────────────────────

Color _priorityColor(int p) => switch (p) {
      1 => const Color(0xFF888898),
      2 => const Color(0xFFC8A84B),
      3 => const Color(0xFFE07830),
      4 => const Color(0xFFE03050),
      _ => const Color(0xFFC8A84B),
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

  @override
  Widget build(BuildContext context) {
    final sc = ref.watch(sieColorsProvider);
    final planningAsync = ref.watch(planningProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Always use latest goal from provider if available
    final goal = planningAsync.valueOrNull?.goals
            .firstWhere((g) => g.id == widget.goal.id,
                orElse: () => widget.goal) ??
        widget.goal;

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
              ),
              Expanded(
                child: _mapMode
                    ? TacticalMapView(goal: goal)
                    : _DetailListView(
                        goal: goal,
                        sc: sc,
                        selectedSubGoalId: _selectedSubGoalId,
                        onSubGoalSelected: (id) =>
                            setState(() => _selectedSubGoalId = id),
                      ),
              ),
              _QuickEntryBar(
                goal: goal,
                sc: sc,
                selectedSubGoalId: _selectedSubGoalId,
                onSubGoalSelected: (id) =>
                    setState(() => _selectedSubGoalId = id),
                bottomInset: bottomInset,
              ),
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
  });

  final Goal goal;
  final bool mapMode;
  final VoidCallback onToggle;
  final SieColors sc;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final progress = goalProgress(goal);
    final goalColor = goal.color;
    final fatigued = isGoalFatigued(goal);

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
                    color: Colors.orange, size: 16),
              if (fatigued) const SizedBox(width: 6),
              _StatusChip(status: goal.status, sc: sc),
              const Spacer(),
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
                  color: _priorityColor(goal.priority),
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
              label: 'Список',
              active: !mapMode,
              goalColor: goalColor,
              sc: sc,
              isLeft: true,
            ),
            _ToggleSegment(
              icon: Icons.map_outlined,
              label: 'Карта',
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
    required this.label,
    required this.active,
    required this.goalColor,
    required this.sc,
    required this.isLeft,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color goalColor;
  final SieColors sc;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
              size: 14, color: active ? goalColor : sc.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? goalColor : sc.textSecondary,
              fontSize: 11,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Detail List View ─────────────────────────────────────────────────────────

class _DetailListView extends StatelessWidget {
  const _DetailListView({
    required this.goal,
    required this.sc,
    required this.selectedSubGoalId,
    required this.onSubGoalSelected,
  });

  final Goal goal;
  final SieColors sc;
  final String? selectedSubGoalId;
  final void Function(String?) onSubGoalSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SubGoalsSection(goal: goal, sc: sc),
          const SizedBox(height: 16),
          _MilestonesSection(goal: goal, sc: sc),
          const SizedBox(height: 16),
          _HabitSynergySection(goal: goal, sc: sc),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Sub-goals Section ────────────────────────────────────────────────────────

class _SubGoalsSection extends ConsumerStatefulWidget {
  const _SubGoalsSection({required this.goal, required this.sc});

  final Goal goal;
  final SieColors sc;

  @override
  ConsumerState<_SubGoalsSection> createState() => _SubGoalsSectionState();
}

class _SubGoalsSectionState extends ConsumerState<_SubGoalsSection> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final sc = widget.sc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'ОПЕРАЦИИ',
          icon: Icons.account_tree_outlined,
          count: goal.subGoals.length,
          sc: sc,
          onAdd: () => _showAddSubGoalSheet(context, ref, goal, sc),
        ),
        ...goal.subGoals.map((sg) => _SubGoalTile(
              subGoal: sg,
              goal: goal,
              sc: sc,
              isExpanded: _expanded.contains(sg.id),
              onToggle: () => setState(() {
                if (_expanded.contains(sg.id)) {
                  _expanded.remove(sg.id);
                } else {
                  _expanded.add(sg.id);
                }
              }),
            )),
      ],
    );
  }
}

class _SubGoalTile extends ConsumerWidget {
  const _SubGoalTile({
    required this.subGoal,
    required this.goal,
    required this.sc,
    required this.isExpanded,
    required this.onToggle,
  });

  final SubGoal subGoal;
  final Goal goal;
  final SieColors sc;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = subGoal;
    final done = sg.tasks.where((t) => t.isCompleted).length;
    final total = sg.tasks.length;
    final prog = subGoalProgress(sg);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
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
            onLongPress: () =>
                _showSubGoalOptionsSheet(context, ref, sg, goal, sc),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
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
                          '$done/$total задач · ${prog.round()}%',
                          style: TextStyle(
                              color: sc.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
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
                ...sg.tasks.map((t) => _TaskTile(
                      task: t,
                      subGoal: sg,
                      goal: goal,
                      sc: sc,
                    )),
                _AddTaskRow(subGoal: sg, goal: goal, sc: sc),
              ],
            ),
          ],
        ],
      ),
    );
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

// ─── Task Tile ────────────────────────────────────────────────────────────────

class _TaskTile extends ConsumerWidget {
  const _TaskTile({
    required this.task,
    required this.subGoal,
    required this.goal,
    required this.sc,
  });

  final PlanningTask task;
  final SubGoal subGoal;
  final Goal goal;
  final SieColors sc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = task;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => ref
                .read(planningProvider.notifier)
                .toggleTask(t.id, subGoal.id, goal.id),
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
                Text(
                  t.name,
                  style: TextStyle(
                    color: t.isCompleted ? sc.textSecondary : sc.textPrimary,
                    fontSize: 14,
                    decoration:
                        t.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (t.dueDate != null)
                  Text(
                    _formatDate(t.dueDate!),
                    style: TextStyle(color: sc.textSecondary, fontSize: 10),
                  ),
              ],
            ),
          ),
          _WeightBadge(weight: t.weight, sc: sc),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _confirmDeleteTask(context, ref, t.id, subGoal.id, goal.id, sc),
            child:
                Icon(Icons.close, size: 14, color: sc.textSecondary),
          ),
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

class _AddTaskRow extends ConsumerWidget {
  const _AddTaskRow(
      {required this.subGoal, required this.goal, required this.sc});

  final SubGoal subGoal;
  final Goal goal;
  final SieColors sc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
  const _MilestonesSection({required this.goal, required this.sc});

  final Goal goal;
  final SieColors sc;

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
          onAdd: () => _showAddMilestoneSheet(context, ref, goal, sc),
        ),
        ...goal.milestones.map((m) => _MilestoneTile(
              milestone: m,
              goal: goal,
              sc: sc,
            )),
      ],
    );
  }
}

class _MilestoneTile extends ConsumerWidget {
  const _MilestoneTile(
      {required this.milestone, required this.goal, required this.sc});

  final Milestone milestone;
  final Goal goal;
  final SieColors sc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = milestone;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: !m.isCompleted
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
          if (!m.isCompleted)
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
  });

  final String title;
  final IconData icon;
  final int count;
  final SieColors sc;
  final VoidCallback? onAdd;

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
    BuildContext context, WidgetRef ref, Goal goal, SieColors sc) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddSubGoalSheet(goal: goal, sc: sc),
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
      onDelete: () async {
        Navigator.pop(context);
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: sc.surface,
            title: Text('Удалить этап?',
                style: TextStyle(color: sc.textPrimary)),
            content: Text('Этап «${sg.name}» и все его задачи будут удалены.',
                style: TextStyle(color: sc.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Отмена',
                    style: TextStyle(color: sc.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить',
                    style: TextStyle(color: Color(0xFFE03050))),
              ),
            ],
          ),
        );
        if (confirm == true) {
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
  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: sc.surface,
      title:
          Text('Удалить задачу?', style: TextStyle(color: sc.textPrimary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child:
              Text('Отмена', style: TextStyle(color: sc.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Удалить',
              style: TextStyle(color: Color(0xFFE03050))),
        ),
      ],
    ),
  );
  if (confirm == true) {
    ref.read(planningProvider.notifier).deleteTask(taskId, subGoalId, goalId);
  }
}

Future<void> _confirmDeleteMilestone(BuildContext context, WidgetRef ref,
    String milestoneId, String goalId, SieColors sc) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: sc.surface,
      title: Text('Удалить контрольную точку?',
          style: TextStyle(color: sc.textPrimary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child:
              Text('Отмена', style: TextStyle(color: sc.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Удалить',
              style: TextStyle(color: Color(0xFFE03050))),
        ),
      ],
    ),
  );
  if (confirm == true) {
    ref
        .read(planningProvider.notifier)
        .deleteMilestone(milestoneId, goalId);
  }
}

// ─── Sheet widgets ────────────────────────────────────────────────────────────

class _AddSubGoalSheet extends ConsumerStatefulWidget {
  const _AddSubGoalSheet({required this.goal, required this.sc});

  final Goal goal;
  final SieColors sc;

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
                  .addSubGoal(widget.goal.id, name);
              Navigator.pop(context);
            },
          ),
        ],
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
  final _ctrl = TextEditingController();
  DateTime? _targetDate;

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
          _SheetTitle('КОНТРОЛЬНАЯ ТОЧКА', sc),
          const SizedBox(height: 12),
          _SheetTextField('Название точки', _ctrl, sc, autofocus: true),
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
              final name = _ctrl.text.trim();
              if (name.isEmpty) return;
              ref
                  .read(planningProvider.notifier)
                  .addMilestone(widget.goal.id, name,
                      targetDate: _targetDate);
              Navigator.pop(context);
            },
          ),
        ],
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
  });

  final SubGoal subGoal;
  final Goal goal;
  final SieColors sc;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

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
      {this.autofocus = false});

  final String hint;
  final TextEditingController ctrl;
  final SieColors sc;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        autofocus: autofocus,
        style: TextStyle(color: sc.textPrimary, fontSize: 16),
        textCapitalization: TextCapitalization.sentences,
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
