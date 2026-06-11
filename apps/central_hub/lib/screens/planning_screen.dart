import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mission_detail_screen.dart';
import 'mission_accomplished_screen.dart';
import 'goal_stats_screen.dart';

// ─── Color helpers ────────────────────────────────────────────────────────────

int _categoryDp(GoalCategory? cat) => switch (cat) {
      GoalCategory.project    => 50,
      GoalCategory.learning   => 40,
      GoalCategory.health     => 35,
      GoalCategory.discipline => 30,
      GoalCategory.lifestyle  => 25,
      null                    => 20,
    };

Color _priorityColor(int p) => switch (p) {
      1 => const Color(0xFF888898),
      2 => const Color(0xFFC8A84B),
      3 => const Color(0xFFE07830),
      4 => const Color(0xFFE03050),
      _ => const Color(0xFFC8A84B),
    };

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

// ─── Screen ───────────────────────────────────────────────────────────────────

class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key});

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen> {
  bool _showArchive = false;

  @override
  Widget build(BuildContext context) {
    final sc = ref.watch(sieColorsProvider);
    final planningAsync = ref.watch(planningProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: _showArchive
            ? null
            : FloatingActionButton(
                onPressed: () => _showAddGoalSheet(context),
                backgroundColor: sc.accent,
                foregroundColor: Colors.white,
                elevation: 4,
                child: const Icon(Icons.add, size: 28),
              ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _PlanningHeader(
                sc: sc,
                showArchive: _showArchive,
                onToggle: () => setState(() => _showArchive = !_showArchive),
              ),
              Expanded(
                child: planningAsync.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(
                        color: sc.accent, strokeWidth: 2),
                  ),
                  error: (e, _) => Center(
                    child: Text('Ошибка загрузки',
                        style: TextStyle(color: sc.textSecondary)),
                  ),
                  data: (state) {
                    final goals = _showArchive
                        ? state.archivedGoals
                        : state.activeGoals;
                    if (goals.isEmpty) {
                      return _EmptyState(sc: sc, isArchive: _showArchive);
                    }
                    return _GoalList(
                      goals: goals,
                      sc: sc,
                      onLongPress: (g) =>
                          _showGoalOptionsSheet(context, g),
                    );
                  },
                ),
              ),
              SizedBox(height: math.max(bottomInset, 16)),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddGoalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddGoalSheet(
        onAdd: ({
          required String name,
          String? description,
          DateTime? deadline,
          required int priority,
          required String colorHex,
        }) {
          ref.read(planningProvider.notifier).addGoal(
                name: name,
                description: description,
                deadline: deadline,
                priority: priority,
                colorHex: colorHex,
              );
        },
      ),
    );
  }

  void _showGoalOptionsSheet(BuildContext context, Goal goal) {
    final sc = ref.read(sieColorsProvider);
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = goal.userId == myId;
    final isViewer = !isOwner &&
        goal.collaborators.any((c) =>
            c.userId == myId &&
            c.status == 'accepted' &&
            c.role == 'viewer');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GoalOptionsSheet(
        goal: goal,
        sc: sc,
        isViewer: isViewer,
        onStats: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GoalStatsScreen(goal: goal),
          ),
        ),
        onPin: isViewer
            ? null
            : () => ref.read(planningProvider.notifier).toggleGoalPin(goal.id),
        onFreeze: isViewer
            ? null
            : () {
                final newStatus =
                    goal.status == 'frozen' ? 'active' : 'frozen';
                ref
                    .read(planningProvider.notifier)
                    .updateGoalStatus(goal.id, newStatus);
              },
        onComplete: isViewer
            ? null
            : () async {
                final medal = await ref
                    .read(planningProvider.notifier)
                    .updateGoalStatus(goal.id, 'completed');
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MissionAccomplishedScreen(
                      xpGained:
                          goalCompletionBaseXp(goal) + (medal?.xpBonus ?? 100),
                      dpGained: _categoryDp(goal.settings.category),
                      medal: medal,
                    ),
                  ),
                );
              },
        onLeaveOrDelete: () async {
          if (isViewer) {
            if (myId == null) return;
            ref.read(goalCollaborationProvider).remove(goal.id, myId);
            return;
          }
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: sc.surface,
              title: Text('Удалить миссию?',
                  style: TextStyle(color: sc.textPrimary)),
              content: Text(
                'Все данные цели «${goal.name}» будут удалены.',
                style: TextStyle(color: sc.textSecondary),
              ),
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
            ref.read(planningProvider.notifier).deleteGoal(goal.id);
          }
        },
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _PlanningHeader extends StatelessWidget {
  const _PlanningHeader({
    required this.sc,
    required this.showArchive,
    required this.onToggle,
  });

  final SieColors sc;
  final bool showArchive;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MISSION CONTROL',
                style: TextStyle(
                  color: sc.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                showArchive ? 'Архив миссий' : 'Активные миссии',
                style: TextStyle(
                  color: sc.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: showArchive
                      ? sc.accent.withValues(alpha: 0.5)
                      : sc.border,
                ),
                color: showArchive
                    ? sc.accent.withValues(alpha: 0.08)
                    : Colors.transparent,
              ),
              child: Icon(
                showArchive
                    ? Icons.inventory_2_outlined
                    : Icons.archive_outlined,
                color: showArchive ? sc.accent : sc.textSecondary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Goal List ────────────────────────────────────────────────────────────────

class _GoalList extends ConsumerWidget {
  const _GoalList({
    required this.goals,
    required this.sc,
    required this.onLongPress,
  });

  final List<Goal> goals;
  final SieColors sc;
  final void Function(Goal) onLongPress;

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
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
        child: Column(
          children: goals
              .map((g) => _GoalCard(
                    goal: g,
                    sc: sc,
                    onLongPress: () => onLongPress(g),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ─── Goal Card ────────────────────────────────────────────────────────────────

class _GoalCard extends ConsumerWidget {
  const _GoalCard({
    required this.goal,
    required this.sc,
    required this.onLongPress,
  });

  final Goal goal;
  final SieColors sc;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = goalProgress(goal) / 100;
    final fatigued = isGoalFatigued(goal);
    final priorityColor = _priorityColor(goal.priority);
    final goalColor = goal.color;
    final doneSubGoals = goal.completedSubGoals;
    final totalSubGoals = goal.subGoals.length;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => MissionDetailScreen(goal: goal)),
      ),
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: fatigued
                ? Colors.orange.withValues(alpha: 0.5)
                : sc.border,
          ),
          color: sc.surface,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Priority color bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
              // Card content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Status chip + pin + fatigue indicator
                      Row(
                        children: [
                          _StatusChip(status: goal.status, sc: sc),
                          if (goal.isPinned) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.push_pin,
                                size: 12, color: Color(0xFFF4C430)),
                          ],
                          const Spacer(),
                          if (fatigued)
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange, size: 14),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Goal name
                      Text(
                        goal.name,
                        style: TextStyle(
                          color: sc.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      if (goal.settings.category != null) ...[
                        const SizedBox(height: 6),
                        _CategoryBadge(
                            category: goal.settings.category!, sc: sc),
                      ],
                      Builder(builder: (context) {
                        final myId = Supabase.instance.client.auth.currentUser?.id;
                        if (myId != null && goal.userId != myId) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: sc.accent.withValues(alpha: 0.4)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.people_outlined, size: 10, color: sc.accent),
                                    const SizedBox(width: 4),
                                    Text('СОВМЕСТНАЯ',
                                        style: TextStyle(fontSize: 9, color: sc.accent, letterSpacing: 0.5)),
                                  ]),
                                ),
                              ]),
                              if (goal.ownerProfile != null) ...[
                                const SizedBox(height: 2),
                                Text('Владелец: ${goal.ownerProfile!.username ?? 'Unknown'}',
                                    style: TextStyle(fontSize: 11, color: sc.textSecondary)),
                              ],
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                      const SizedBox(height: 16),
                      // Progress arc
                      Center(
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: CustomPaint(
                            painter: _ArcPainter(
                              progress: progress,
                              color: goalColor,
                              trackColor: sc.border,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${(goalProgress(goal)).round()}%',
                                    style: TextStyle(
                                      color: goalColor,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'прогресс',
                                    style: TextStyle(
                                      color: sc.textSecondary,
                                      fontSize: 9,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Stats row
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          _MiniStat(
                            icon: Icons.checklist_rtl,
                            label: '$doneSubGoals/$totalSubGoals этапов',
                            sc: sc,
                          ),
                          _MiniStat(
                            icon: Icons.link,
                            label: '${goal.habitLinks.length} привычек',
                            sc: sc,
                          ),
                          if (goal.totalTasks > 0)
                            _MiniStat(
                              icon: Icons.task_alt,
                              label:
                                  '${goal.completedTasks}/${goal.totalTasks} задач',
                              sc: sc,
                            ),
                        ],
                      ),
                      // Deadline chip
                      if (goal.deadline != null) ...[
                        const SizedBox(height: 10),
                        _DeadlineChip(
                          daysLeft: goal.daysUntilDeadline!,
                          isOverdue: goal.isOverdue,
                          sc: sc,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Small widgets ────────────────────────────────────────────────────────────

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

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.sc,
  });

  final IconData icon;
  final String label;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: sc.textSecondary),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(color: sc.textSecondary, fontSize: 11)),
      ],
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.sc, required this.isArchive});

  final SieColors sc;
  final bool isArchive;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isArchive ? Icons.inventory_2_outlined : Icons.flag_outlined,
            size: 64,
            color: sc.border,
          ),
          const SizedBox(height: 16),
          Text(
            isArchive ? 'Архив пуст' : 'Нет активных миссий',
            style: TextStyle(color: sc.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (!isArchive)
            Text(
              'Нажмите + для создания первой цели',
              style: TextStyle(color: sc.textSecondary, fontSize: 13),
            ),
        ],
      ),
    );
  }
}

// ─── Goal Options Sheet ───────────────────────────────────────────────────────

class _GoalOptionsSheet extends StatelessWidget {
  const _GoalOptionsSheet({
    required this.goal,
    required this.sc,
    required this.isViewer,
    required this.onStats,
    this.onPin,
    this.onFreeze,
    this.onComplete,
    required this.onLeaveOrDelete,
  });

  final Goal goal;
  final SieColors sc;
  final bool isViewer;
  final VoidCallback onStats;
  final VoidCallback? onPin;
  final VoidCallback? onFreeze;
  final VoidCallback? onComplete;
  final VoidCallback onLeaveOrDelete;

  @override
  Widget build(BuildContext context) {
    final isFrozen = goal.status == 'frozen';

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
              goal.name,
              style: TextStyle(
                  color: sc.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Divider(height: 1, color: sc.border),
          _OptionTile(
            icon: Icons.bar_chart_outlined,
            label: 'Статистика миссии',
            color: const Color(0xFF6A8ED8),
            onTap: () {
              Navigator.pop(context);
              onStats();
            },
          ),
          if (onPin != null)
            _OptionTile(
              icon: goal.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              label: goal.isPinned ? 'Открепить миссию' : 'Закрепить миссию',
              color: const Color(0xFFF4C430),
              onTap: () {
                Navigator.pop(context);
                onPin!();
              },
            ),
          if (onFreeze != null)
            _OptionTile(
              icon: isFrozen ? Icons.play_arrow_outlined : Icons.ac_unit,
              label: isFrozen ? 'Разморозить миссию' : 'Заморозить миссию',
              color: const Color(0xFF6A8ED8),
              onTap: () {
                Navigator.pop(context);
                onFreeze!();
              },
            ),
          if (onComplete != null && goal.status != 'completed')
            _OptionTile(
              icon: Icons.check_circle_outline,
              label: 'Завершить миссию',
              color: const Color(0xFF5AADA0),
              onTap: () {
                Navigator.pop(context);
                onComplete!();
              },
            ),
          _OptionTile(
            icon: isViewer ? Icons.exit_to_app_outlined : Icons.delete_outline,
            label: isViewer ? 'Покинуть миссию' : 'Удалить миссию',
            color: const Color(0xFFE03050),
            onTap: () {
              Navigator.pop(context);
              onLeaveOrDelete();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
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

// ─── Add Goal Sheet ───────────────────────────────────────────────────────────

class _AddGoalSheet extends ConsumerStatefulWidget {
  const _AddGoalSheet({required this.onAdd});

  final void Function({
    required String name,
    String? description,
    DateTime? deadline,
    required int priority,
    required String colorHex,
  }) onAdd;

  @override
  ConsumerState<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<_AddGoalSheet> {
  final _nameCtrl = TextEditingController();
  int _priority = 2;
  String _colorHex = '#5AADA0';
  DateTime? _deadline;

  static const _palette = [
    '#5AADA0',
    '#6A8ED8',
    '#E07830',
    '#C8A84B',
    '#C05080',
    '#70B870',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sc = ref.watch(sieColorsProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
          Text(
            'НОВАЯ МИССИЯ',
            style: TextStyle(
              color: sc.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 12),
          // Name field
          TextField(
            controller: _nameCtrl,
            style: TextStyle(color: sc.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Название миссии',
              hintStyle:
                  TextStyle(color: sc.textSecondary, fontSize: 16),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: sc.border)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: sc.accent)),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 20),
          // Priority selector
          Text('ПРИОРИТЕТ',
              style: TextStyle(
                  color: sc.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              _PriorityBtn(
                  label: 'Низкий',
                  priority: 1,
                  selected: _priority == 1,
                  sc: sc,
                  onTap: () => setState(() => _priority = 1)),
              const SizedBox(width: 6),
              _PriorityBtn(
                  label: 'Средний',
                  priority: 2,
                  selected: _priority == 2,
                  sc: sc,
                  onTap: () => setState(() => _priority = 2)),
              const SizedBox(width: 6),
              _PriorityBtn(
                  label: 'Высокий',
                  priority: 3,
                  selected: _priority == 3,
                  sc: sc,
                  onTap: () => setState(() => _priority = 3)),
              const SizedBox(width: 6),
              _PriorityBtn(
                  label: 'Крит.',
                  priority: 4,
                  selected: _priority == 4,
                  sc: sc,
                  onTap: () => setState(() => _priority = 4)),
            ],
          ),
          const SizedBox(height: 20),
          // Color selector
          Text('ЦВЕТ МИССИИ',
              style: TextStyle(
                  color: sc.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Row(
            children: _palette
                .map((hex) => GestureDetector(
                      onTap: () => setState(() => _colorHex = hex),
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(
                              int.parse('0xFF${hex.replaceAll('#', '')}')),
                          border: _colorHex == hex
                              ? Border.all(color: Colors.white, width: 2.5)
                              : null,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          // Deadline
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate:
                    DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime.now(),
                lastDate:
                    DateTime.now().add(const Duration(days: 365 * 5)),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: ColorScheme.dark(primary: sc.accent),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _deadline = picked);
            },
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 16, color: sc.accent),
                const SizedBox(width: 8),
                Text(
                  _deadline != null
                      ? 'Дедлайн: ${_deadline!.day}.${_deadline!.month.toString().padLeft(2, '0')}.${_deadline!.year}'
                      : 'Установить дедлайн (необязательно)',
                  style: TextStyle(color: sc.accent, fontSize: 13),
                ),
                if (_deadline != null) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _deadline = null),
                    child:
                        Icon(Icons.close, size: 14, color: sc.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final name = _nameCtrl.text.trim();
                if (name.isEmpty) return;
                widget.onAdd(
                  name: name,
                  deadline: _deadline,
                  priority: _priority,
                  colorHex: _colorHex,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: sc.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'СОЗДАТЬ МИССИЮ',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityBtn extends StatelessWidget {
  const _PriorityBtn({
    required this.label,
    required this.priority,
    required this.selected,
    required this.sc,
    required this.onTap,
  });

  final String label;
  final int priority;
  final bool selected;
  final SieColors sc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(priority);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
            border: Border.all(
                color: selected ? color : sc.border, width: selected ? 1.5 : 1),
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

// ─── Arc Painter ──────────────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  const _ArcPainter({
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
    final radius = (size.width - 12) / 2;
    const strokeWidth = 7.0;

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
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}

// ─── Category Badge ───────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category, required this.sc});

  final GoalCategory category;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    final icon = _categoryIcon(category)!;
    final color = _categoryColor(category);
    final label = _categoryLabel(category);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
