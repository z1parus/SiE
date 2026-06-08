import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'routine_editor_screen.dart';

enum HabitViewMode { today, week, allTime }

// ─────────────────────────────────────────────────────────────────────────────
// HabitTrackerScreen
// ─────────────────────────────────────────────────────────────────────────────
class HabitTrackerScreen extends ConsumerStatefulWidget {
  const HabitTrackerScreen({super.key});

  @override
  ConsumerState<HabitTrackerScreen> createState() =>
      _HabitTrackerScreenState();
}

class _HabitTrackerScreenState extends ConsumerState<HabitTrackerScreen> {
  bool _onboardingDismissed = false;
  bool _showOnboardingManual = false;
  HabitViewMode _viewMode = HabitViewMode.today;

  static String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final sc            = ref.watch(sieColorsProvider);
    final habitsAsync   = ref.watch(habitsProvider);
    final routinesAsync = ref.watch(habitRoutinesProvider);
    final today         = _fmt(DateTime.now());
    final profile       = ref.watch(userProfileProvider).valueOrNull;

    final habitsData   = habitsAsync.valueOrNull;
    final routineData  = routinesAsync.valueOrNull;
    final isListEmpty  = habitsData != null && () {
      final routineIds = {
        ...?routineData?.morning?.habits.map((h) => h.id),
        ...?routineData?.evening?.habits.map((h) => h.id),
      };
      return habitsData.habits.where((h) => !routineIds.contains(h.id)).isEmpty;
    }();
    final showOnboarding = _showOnboardingManual ||
        (!_onboardingDismissed &&
            profile != null &&
            !profile.hasSeenOnboardingHabits);

    final body = SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CyberTopBar(
            onArchive: _openArchive,
            onInfo: () => setState(() => _showOnboardingManual = true),
          ),
          // ── Routine Blocks ──────────────────────────────────────
          routinesAsync.when(
            data: (routines) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoutineBlock(
                    type: 'morning',
                    routine: routines.morning,
                    habitsState: habitsAsync.valueOrNull,
                  ),
                  const SizedBox(height: 8),
                  _RoutineBlock(
                    type: 'evening',
                    routine: routines.evening,
                    habitsState: habitsAsync.valueOrNull,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            loading: () => const SizedBox(height: 8),
            error: (_, _) => const SizedBox(height: 8),
          ),
          _ViewModeToggle(
            current: _viewMode,
            onChange: (m) => setState(() => _viewMode = m),
          ),
          Expanded(
            child: habitsAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: sc.accent,
                  strokeWidth: 1.5,
                ),
              ),
              error: (e, _) => Center(child: _NoConnectionMessage(error: e)),
              data: (state) {
                final routineHabitIds = {
                  ...?routinesAsync.valueOrNull?.morning?.habits.map((h) => h.id),
                  ...?routinesAsync.valueOrNull?.evening?.habits.map((h) => h.id),
                };
                final visibleHabits = state.habits
                    .where((h) => !routineHabitIds.contains(h.id))
                    .toList();
                if (visibleHabits.isEmpty) {
                  return _EmptyState(onAdd: () => _showHabitDialog(null));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  itemCount: visibleHabits.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final habit    = visibleHabits[i];
                    final logDates = state.logDates[habit.id] ?? {};
                    final entries  = state.logEntries[habit.id] ?? [];
                    final todayEntry = entries.cast<HabitLogEntry?>()
                        .firstWhere((e) => e?.completedAt == today,
                            orElse: () => null);
                    void onTapDetail() => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => HabitDetailScreen(habit: habit),
                      ),
                    );
                    if (_viewMode == HabitViewMode.week) {
                      return _WeekViewHabitCard(
                        key: ValueKey('w_${habit.id}'),
                        habit: habit,
                        logDates: logDates,
                        streak: state.streaks[habit.id] ?? 0,
                        onTap: onTapDetail,
                      );
                    }
                    if (_viewMode == HabitViewMode.allTime) {
                      return _AllTimeHabitCard(
                        key: ValueKey('a_${habit.id}'),
                        habit: habit,
                        logDates: logDates,
                        onTap: onTapDetail,
                      );
                    }
                    return _SwipeableHabitCard(
                      key: ValueKey(habit.id),
                      habit: habit,
                      completedToday: logDates.contains(today),
                      streak: state.streaks[habit.id] ?? 0,
                      todayEmoji: todayEntry?.emoji,
                      onTap: onTapDetail,
                      onDelete: () => ref
                          .read(habitsProvider.notifier)
                          .deleteHabit(habit.id),
                      onTogglePin: () => ref
                          .read(habitsProvider.notifier)
                          .togglePin(habit.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            body,
            Positioned.fill(
              child: OnboardingOverlay(
                visible: showOnboarding,
                moduleLabel: 'ПРИВЫЧКИ',
                description: 'Архив нейронных связей.',
                benefit:
                    'Автоматизация успеха через микро-действия и систематическую '
                    'дисциплину. Формирование нейронных паттернов, не требующих '
                    'волевых ресурсов.',
                xpReward: 25,
                onAccept: () {
                  if (_showOnboardingManual) {
                    setState(() => _showOnboardingManual = false);
                  } else {
                    setState(() => _onboardingDismissed = true);
                    markOnboardingSeen('habits');
                  }
                },
              ),
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: _BottomActionBar(
                onAdd: () => _showHabitDialog(null),
                isEmpty: isListEmpty,
                onMorning: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const RoutineEditorScreen(routineType: 'morning'),
                  ),
                ),
                onEvening: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const RoutineEditorScreen(routineType: 'evening'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────

  void _openArchive() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const HabitArchiveScreen(),
      ),
    );
  }

  void _showHabitDialog(Habit? existing) {
    final sc = ref.read(sieColorsProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _HabitDialog(
        existing: existing,
        onSave: (title, description, color, icon) {
          if (existing == null) {
            ref
                .read(habitsProvider.notifier)
                .addHabit(title: title, description: description, color: color, icon: icon)
                .then((awarded) {
              if (awarded && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: sc.surface,
                    duration: const Duration(seconds: 3),
                    content: Row(
                      children: [
                        const Text('🌱', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'ПЕРВЫЙ ПРОТОКОЛ ДИСЦИПЛИНЫ',
                                style: TextStyle(
                                  color: sc.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '+25 XP получено',
                                style: TextStyle(
                                  color: sc.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            });
          } else {
            ref.read(habitsProvider.notifier).updateHabit(
                  habitId: existing.id,
                  title: title,
                  description: description,
                  color: color,
                  icon: icon,
                );
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cyberpunk Top Bar
// ─────────────────────────────────────────────────────────────────────────────
class _CyberTopBar extends ConsumerWidget {
  const _CyberTopBar({required this.onArchive, required this.onInfo});
  final VoidCallback onArchive;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GlassIconBtn(
            icon: Icons.arrow_back_ios_new,
            onTap: () => Navigator.of(context).pop(),
            size: 15,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'HABIT ',
                        style: TextStyle(
                          color: sc.accent,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          shadows: null,
                        ),
                      ),
                      TextSpan(
                        text: 'MATRIX',
                        style:
                            Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 3.0,
                                ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'НЕЙРОННАЯ МАТРИЦА · АРХИВ ДИСЦИПЛИНЫ',
                  style: TextStyle(
                    color: sc.textSecondary,
                    fontSize: 10,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
          _GlassIconBtn(icon: Icons.help_outline, onTap: onInfo, size: 18),
          const SizedBox(width: 8),
          _GlassIconBtn(
            icon: Icons.inventory_2_outlined,
            onTap: onArchive,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _GlassIconBtn extends ConsumerWidget {
  const _GlassIconBtn({
    required this.icon,
    required this.onTap,
    this.size = 16,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc    = ref.watch(sieColorsProvider);
    final child = Center(
      child: Icon(icon, color: sc.textSecondary, size: size),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: sc.flatCard(radius: 18),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Action Bar
// ─────────────────────────────────────────────────────────────────────────────
class _BottomActionBar extends ConsumerWidget {
  final VoidCallback onAdd;
  final VoidCallback onMorning;
  final VoidCallback onEvening;
  final bool isEmpty;

  const _BottomActionBar({
    required this.onAdd,
    required this.onMorning,
    required this.onEvening,
    this.isEmpty = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);

    Widget sideBtn(IconData icon, VoidCallback onTap) {
      final child = Center(
        child: Icon(icon, color: sc.textSecondary, size: 20),
      );
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: sc.flatCard(radius: 24),
          child: child,
        ),
      );
    }

    Widget centerBtn() {
      if (isEmpty) return _AddButton(onTap: onAdd);
      final child = Center(
        child: Icon(Icons.add, color: Colors.black, size: 24),
      );
      return GestureDetector(
        onTap: onAdd,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: sc.accent,
            boxShadow: [
              BoxShadow(
                color: sc.accent.withValues(alpha: 0.45),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: child,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        sideBtn(Icons.wb_sunny_outlined, onMorning),
        const SizedBox(width: 20),
        centerBtn(),
        const SizedBox(width: 20),
        sideBtn(Icons.nightlight_round, onEvening),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View Mode Toggle
// ─────────────────────────────────────────────────────────────────────────────

class _ViewModeToggle extends ConsumerWidget {
  final HabitViewMode current;
  final void Function(HabitViewMode) onChange;

  const _ViewModeToggle({required this.current, required this.onChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    const modes = [
      (HabitViewMode.today, 'СЕГОДНЯ'),
      (HabitViewMode.week, 'НЕДЕЛЯ'),
      (HabitViewMode.allTime, 'ВСЁ ВРЕМЯ'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: modes.map((m) {
          final (mode, label) = m;
          final active = current == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChange(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: active
                      ? sc.accent.withValues(alpha: 0.18)
                      : Colors.transparent,
                  border: Border.all(
                    color: active
                        ? sc.accent.withValues(alpha: 0.55)
                        : sc.border.withValues(alpha: 0.30),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    color: active ? sc.accent : sc.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Week View Habit Card
// ─────────────────────────────────────────────────────────────────────────────

class _WeekViewHabitCard extends ConsumerWidget {
  final Habit habit;
  final Set<String> logDates;
  final int streak;
  final VoidCallback onTap;

  const _WeekViewHabitCard({
    super.key,
    required this.habit,
    required this.logDates,
    required this.streak,
    required this.onTap,
  });

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    final accentColor = hexToColor(habit.color);
    final today = DateTime.now();
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    return SieGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (habit.icon != null) ...[
                Text(habit.icon!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
              ] else ...[
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  habit.title.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: sc.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              if (streak > 0) ...[
                const SizedBox(width: 6),
                _StreakBadge(streak: streak, color: accentColor),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((d) {
              final label = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'][d.weekday - 1];
              final done = logDates.contains(_fmt(d));
              final isToday = _fmt(d) == _fmt(today);
              return Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: done
                            ? accentColor.withValues(alpha: 0.80)
                            : sc.border.withValues(alpha: 0.25),
                        border: isToday
                            ? Border.all(color: accentColor.withValues(alpha: 0.70), width: 1)
                            : null,
                        boxShadow: null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: TextStyle(
                        color: isToday ? sc.accent : sc.textSecondary.withValues(alpha: 0.5),
                        fontSize: 7.5,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// All-Time Habit Card (compact heat map)
// ─────────────────────────────────────────────────────────────────────────────

class _AllTimeHabitCard extends ConsumerWidget {
  final Habit habit;
  final Set<String> logDates;
  final VoidCallback onTap;

  const _AllTimeHabitCard({
    super.key,
    required this.habit,
    required this.logDates,
    required this.onTap,
  });

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    final accentColor = hexToColor(habit.color);

    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final daysSinceMonday = (todayNorm.weekday - 1) % 7;
    final gridEnd = todayNorm.add(Duration(days: 6 - daysSinceMonday));
    final gridStart = gridEnd.subtract(const Duration(days: 7 * 13 - 1));

    const cols = 13;
    const rows = 7;
    const cellSize = 10.0;
    const gap = 2.0;

    return SieGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (habit.icon != null) ...[
                Text(habit.icon!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
              ] else ...[
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  habit.title.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: sc.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: rows * (cellSize + gap) - gap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(cols, (col) {
                final firstDay = gridStart.add(Duration(days: col * 7));
                return Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(rows, (row) {
                      final d = firstDay.add(Duration(days: row));
                      final done = logDates.contains(_fmt(d));
                      return Container(
                        width: double.infinity,
                        height: cellSize,
                        margin: EdgeInsets.only(
                          bottom: row < rows - 1 ? gap : 0,
                          right: col < cols - 1 ? gap : 0,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: done
                              ? accentColor.withValues(alpha: 0.75)
                              : sc.border.withValues(alpha: 0.20),
                          boxShadow: null,
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Swipeable Habit Card
// ─────────────────────────────────────────────────────────────────────────────
class _SwipeableHabitCard extends StatefulWidget {
  final Habit habit;
  final bool completedToday;
  final int streak;
  final String? todayEmoji;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;
  final VoidCallback onTogglePin;

  const _SwipeableHabitCard({
    super.key,
    required this.habit,
    required this.completedToday,
    required this.streak,
    required this.onTap,
    required this.onDelete,
    required this.onTogglePin,
    this.todayEmoji,
  });

  @override
  State<_SwipeableHabitCard> createState() => _SwipeableHabitCardState();
}

class _SwipeableHabitCardState extends State<_SwipeableHabitCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _snapCtrl;
  Animation<double>? _snapAnim;
  double _dragOffset = 0.0;
  bool _isSnapping = false;
  bool _isSystemGestureZone = false;

  static const _triggerFraction = 0.38;

  double get _triggerDist =>
      MediaQuery.of(context).size.width * _triggerFraction;
  double get _screenWidth => MediaQuery.of(context).size.width;

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _snapCtrl.removeStatusListener(_onSnapComplete);
    _snapCtrl.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails d) {
    if (Platform.isAndroid) {
      final insets = MediaQuery.of(context).systemGestureInsets;
      final sw = _screenWidth;
      final x = d.globalPosition.dx;
      _isSystemGestureZone = x < insets.left || x > sw - insets.right;
    } else {
      _isSystemGestureZone = false;
    }
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_isSnapping) return;
    if (_isSystemGestureZone) return;
    setState(() {
      _dragOffset = (_dragOffset + d.delta.dx)
          .clamp(-_screenWidth * 0.65, _screenWidth * 0.65);
    });
  }

  Future<void> _onDragEnd(DragEndDetails d) async {
    if (_isSnapping) return;
    if (_isSystemGestureZone) return;
    final trigger = _triggerDist;

    if (_dragOffset.abs() >= trigger) {
      if (_dragOffset < 0) {
        _isSnapping = true;
        _snapAnim =
            Tween<double>(begin: _dragOffset, end: -_screenWidth * 1.2)
                .animate(CurvedAnimation(
                    parent: _snapCtrl, curve: Curves.easeIn));
        await _snapCtrl.forward(from: 0);
        if (!mounted) return;
        await widget.onDelete();
      } else {
        widget.onTogglePin();
        _isSnapping = true;
        _snapAnim = Tween<double>(begin: _dragOffset, end: 0).animate(
            CurvedAnimation(
                parent: _snapCtrl, curve: Curves.elasticOut));
        unawaited(_snapCtrl.forward(from: 0));
        _snapCtrl.addStatusListener(_onSnapComplete);
      }
    } else {
      _isSnapping = true;
      _snapAnim = Tween<double>(begin: _dragOffset, end: 0).animate(
          CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOut));
      unawaited(_snapCtrl.forward(from: 0));
      _snapCtrl.addStatusListener(_onSnapComplete);
    }
  }

  void _onSnapComplete(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _snapCtrl.removeStatusListener(_onSnapComplete);
      if (mounted) {
        setState(() {
          _dragOffset = 0;
          _isSnapping = false;
        });
        _snapCtrl.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: AnimatedBuilder(
        animation: _snapCtrl,
        builder: (context2, snap) {
          final offset = (_isSnapping && _snapAnim != null)
              ? _snapAnim!.value
              : _dragOffset;
          final trigger  = _screenWidth * _triggerFraction;
          final progress = (offset.abs() / trigger).clamp(0.0, 1.0);
          final isLeft   = offset < 0;
          final swiping  = progress > 0.01;

          return Stack(
            children: [
              if (swiping && !isLeft)
                Positioned.fill(
                  child: _SwipePinBg(
                    progress: progress,
                    isPinned: widget.habit.isPinned,
                  ),
                ),
              if (swiping && isLeft)
                Positioned.fill(
                  child: _SwipeDeleteBg(progress: progress),
                ),
              Transform.translate(
                offset: Offset(offset, 0),
                child: Transform.scale(
                  scale: 1.0 - 0.02 * progress,
                  child: _HabitMatrixCard(
                    habit: widget.habit,
                    completedToday: widget.completedToday,
                    streak: widget.streak,
                    onTap: widget.onTap,
                    todayEmoji: widget.todayEmoji,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Swipe Backgrounds
// ─────────────────────────────────────────────────────────────────────────────
class _SwipePinBg extends ConsumerWidget {
  final double progress;
  final bool isPinned;
  const _SwipePinBg({required this.progress, required this.isPinned});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [sc.background, const Color(0xFFDAA520), sc.background],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Opacity(
            opacity: progress.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.75 + 0.25 * progress,
              child: Icon(
                isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeDeleteBg extends ConsumerWidget {
  final double progress;
  const _SwipeDeleteBg({required this.progress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [sc.background, const Color(0xFF8B0000), sc.background],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Opacity(
            opacity: progress.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.75 + 0.25 * progress,
              child: const Icon(Icons.delete_outline,
                  color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Habit Matrix Card
// ─────────────────────────────────────────────────────────────────────────────
class _HabitMatrixCard extends ConsumerWidget {
  final Habit habit;
  final bool completedToday;
  final int streak;
  final String? todayEmoji;
  final VoidCallback onTap;

  const _HabitMatrixCard({
    required this.habit,
    required this.completedToday,
    required this.streak,
    required this.onTap,
    this.todayEmoji,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc          = ref.watch(sieColorsProvider);
    final accentColor = hexToColor(habit.color);

    final card = SieGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (habit.icon != null) ...[
                Text(habit.icon!, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
              ] else ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor,
                    boxShadow: null,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  habit.title.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: sc.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    height: 1.1,
                  ),
                ),
              ),
              if (habit.isPinned) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.push_pin,
                  color: sc.textSecondary.withValues(alpha: 0.45),
                  size: 11,
                ),
              ],
              if (todayEmoji != null) ...[
                const SizedBox(width: 6),
                Text(todayEmoji!, style: const TextStyle(fontSize: 13)),
              ],
              if (streak > 0) ...[
                const SizedBox(width: 8),
                _StreakBadge(streak: streak, color: accentColor),
              ],
              if (completedToday) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle_outline,
                  color: accentColor.withValues(alpha: 0.80),
                  size: 14,
                ),
              ],
            ],
          ),
          if (habit.description != null && habit.description!.isNotEmpty) ...[
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 17),
              child: Text(
                habit.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: sc.textSecondary.withValues(alpha: 0.7),
                  fontSize: 10.5,
                  letterSpacing: 0.3,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return card;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day Node
// ─────────────────────────────────────────────────────────────────────────────
class _DayNode extends ConsumerWidget {
  final DateTime date;
  final bool isCompleted;
  final bool isToday;
  final Color accentColor;

  const _DayNode({
    required this.date,
    required this.isCompleted,
    required this.isToday,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: isCompleted
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor,
                      accentColor.withValues(alpha: 0.75),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.80),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 0,
                    ),
                  ],
                )
              : BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isToday
                        ? accentColor.withValues(alpha: 0.60)
                        : sc.border,
                    width: 1.5,
                  ),
                  color: isToday
                      ? accentColor.withValues(alpha: 0.07)
                      : Colors.transparent,
                ),
          child: isCompleted
              ? null
              : isToday
                  ? Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: 0.80),
                          boxShadow: null,
                        ),
                      ),
                    )
                  : null,
        ),
        const SizedBox(height: 5),
        Text(
          '${date.day}',
          style: TextStyle(
            color: isCompleted
                ? accentColor.withValues(alpha: 0.90)
                : isToday
                    ? accentColor.withValues(alpha: 0.65)
                    : sc.textSecondary.withValues(alpha: 0.4),
            fontSize: 8,
            height: 1.0,
            letterSpacing: 0.5,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Streak Badge
// ─────────────────────────────────────────────────────────────────────────────
class _StreakBadge extends StatelessWidget {
  final int streak;
  final Color color;
  const _StreakBadge({required this.streak, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.50)),
        color: color.withValues(alpha: 0.09),
      ),
      child: Text(
        'STREAK: $streak',
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          height: 1.1,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
          fontFeatures: const [FontFeature.tabularFigures()],
          shadows: [
            Shadow(color: color.withValues(alpha: 0.55), blurRadius: 6),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State — dormant matrix grid
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends ConsumerWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  static const _litNodes = {2, 6, 8, 10, 12, 14, 16, 18, 22};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 148,
            height: 148,
            child: GridView.count(
              crossAxisCount: 5,
              crossAxisSpacing: 7,
              mainAxisSpacing: 7,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(25, (i) {
                final lit = _litNodes.contains(i);
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: lit
                        ? sc.accent.withValues(alpha: 0.20)
                        : Colors.transparent,
                    border: Border.all(
                      color: lit
                          ? sc.accent.withValues(alpha: 0.40)
                          : sc.border,
                      width: 1.2,
                    ),
                    boxShadow: null,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'NO PROTOCOLS ACTIVE',
            style: TextStyle(
              color: sc.textSecondary,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'TAP + TO INITIALISE A HABIT',
            style: TextStyle(
              color: sc.textSecondary.withValues(alpha: 0.50),
              fontSize: 10,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing Add Button
// ─────────────────────────────────────────────────────────────────────────────
class _AddButton extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  ConsumerState<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends ConsumerState<_AddButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sc = ref.watch(sieColorsProvider);
    return AnimatedScale(
      scale: _pressed ? 0.88 : 1.0,
      duration: _pressed
          ? const Duration(milliseconds: 80)
          : const Duration(milliseconds: 500),
      curve: _pressed ? Curves.easeIn : Curves.elasticOut,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (buildCtx, _) => Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sc.accent.withValues(alpha: 0.10),
                border: Border.all(
                  color: sc.accent.withValues(alpha: 0.60),
                ),
                boxShadow: [
                  BoxShadow(
                    color: sc.accent.withValues(
                      alpha: 0.08 + 0.12 * _ctrl.value,
                    ),
                    blurRadius: 12 + 8 * _ctrl.value,
                    spreadRadius: 1 + 2 * _ctrl.value,
                  ),
                ],
              ),
              child: Icon(Icons.add, color: sc.accent, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add / Edit Protocol Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _HabitDialog extends ConsumerStatefulWidget {
  final Habit? existing;
  final void Function(String title, String? description, String color, String? icon) onSave;

  const _HabitDialog({this.existing, required this.onSave});

  @override
  ConsumerState<_HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends ConsumerState<_HabitDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late String _selectedColor;
  String? _selectedIcon;

  static const _colorOptions = [
    '#5AADA0',
    '#6A8ED8',
    '#E07830',
    '#C8A84B',
    '#C05080',
    '#70B870',
  ];

  static const _iconOptions = [
    '🏃', '🧘', '📚', '💪', '🥗', '💧', '😴', '🎯',
    '🧠', '✍️', '🎨', '🎸', '🚴', '🏊', '🌱', '🔥',
    '⚡', '🌙', '☀️', '💊',
  ];

  Color _toColor(String hex) {
    final h = hex.replaceAll('#', '').padLeft(6, '0');
    return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF5AADA0);
  }

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _descCtrl  = TextEditingController(text: widget.existing?.description ?? '');
    _selectedColor = widget.existing?.color ?? '#5AADA0';
    _selectedIcon  = widget.existing?.icon;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sc     = ref.watch(sieColorsProvider);
    final isEdit = widget.existing != null;
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + keyboardBottom),
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
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: sc.border,
              ),
            ),
          ),
          Text(
            isEdit ? 'EDIT PROTOCOL' : 'NEW PROTOCOL',
            style: TextStyle(
              color: sc.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 12),
          _GlowField(controller: _titleCtrl, label: 'TITLE'),
          const SizedBox(height: 12),
          _GlowField(
              controller: _descCtrl,
              label: 'DESCRIPTION (OPTIONAL)'),
          const SizedBox(height: 20),
          Text(
            'COLOR',
            style: TextStyle(
              color: sc.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: _colorOptions.map((hex) {
              final selected = hex == _selectedColor;
              return _ColorLens(
                color: _toColor(hex),
                selected: selected,
                onTap: () => setState(() => _selectedColor = hex),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text(
            'ICON',
            style: TextStyle(
              color: sc.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          _IconPicker(
            options: _iconOptions,
            selected: _selectedIcon,
            accentColor: _toColor(_selectedColor),
            onSelect: (v) => setState(() => _selectedIcon = v),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _SheetTextBtn(
                label: 'CANCEL',
                color: sc.textSecondary,
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 12),
              _SheetTextBtn(
                label: isEdit ? 'SAVE' : 'DEPLOY',
                color: _toColor(_selectedColor),
                onTap: () {
                  final title = _titleCtrl.text.trim();
                  if (title.isEmpty) return;
                  widget.onSave(
                    title,
                    _descCtrl.text.trim().isEmpty
                        ? null
                        : _descCtrl.text.trim(),
                    _selectedColor,
                    _selectedIcon,
                  );
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Glow Text Field ───────────────────────────────────────────

class _GlowField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String label;
  const _GlowField({required this.controller, required this.label});

  @override
  ConsumerState<_GlowField> createState() => _GlowFieldState();
}

class _GlowFieldState extends ConsumerState<_GlowField> {
  final FocusNode _focus = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _hasFocus = _focus.hasFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sc = ref.watch(sieColorsProvider);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: _hasFocus
            ? [
                BoxShadow(
                  color: sc.accent.withValues(alpha: 0.22),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        style: TextStyle(
          color: sc.textPrimary,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(
            color: _hasFocus ? sc.accent : sc.textSecondary,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: sc.border),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: sc.accent, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ── Color Lens Chip ───────────────────────────────────────────

class _ColorLens extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ColorLens({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: selected
              ? Border.all(color: Colors.white, width: 2.5)
              : null,
        ),
      ),
    );
  }
}

// ── Icon Picker ───────────────────────────────────────────────

class _IconPicker extends ConsumerWidget {
  final List<String> options;
  final String? selected;
  final Color accentColor;
  final void Function(String? value) onSelect;

  const _IconPicker({
    required this.options,
    required this.selected,
    required this.accentColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          GestureDetector(
            onTap: () => onSelect(null),
            child: Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == null
                      ? accentColor
                      : sc.textSecondary.withValues(alpha: 0.25),
                  width: selected == null ? 2 : 1,
                ),
                color: selected == null
                    ? accentColor.withValues(alpha: 0.15)
                    : Colors.transparent,
              ),
              child: Icon(
                Icons.block,
                size: 14,
                color: selected == null
                    ? accentColor
                    : sc.textSecondary.withValues(alpha: 0.4),
              ),
            ),
          ),
          ...options.map((emoji) {
            final isSelected = selected == emoji;
            return GestureDetector(
              onTap: () => onSelect(emoji),
              child: Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? accentColor
                        : sc.textSecondary.withValues(alpha: 0.20),
                    width: isSelected ? 2 : 1,
                  ),
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 17)),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Sheet Text Button ─────────────────────────────────────────

class _SheetTextBtn extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SheetTextBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_SheetTextBtn> createState() => _SheetTextBtnState();
}

class _SheetTextBtnState extends State<_SheetTextBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: _pressed
            ? const Duration(milliseconds: 80)
            : const Duration(milliseconds: 220),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.color,
              fontSize: 11,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Option Tile ───────────────────────────────────────────────

class _OptionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: _pressed
            ? const Duration(milliseconds: 80)
            : const Duration(milliseconds: 220),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _pressed
              ? widget.color.withValues(alpha: 0.06)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(widget.icon, color: widget.color, size: 18),
              const SizedBox(width: 14),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.color,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reflection Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ReflectionSheet extends ConsumerStatefulWidget {
  final Habit habit;
  final String dateStr;
  final HabitLogEntry? existing;

  const _ReflectionSheet({
    required this.habit,
    required this.dateStr,
    this.existing,
  });

  @override
  ConsumerState<_ReflectionSheet> createState() => _ReflectionSheetState();
}

class _ReflectionSheetState extends ConsumerState<_ReflectionSheet> {
  late final TextEditingController _noteCtrl;
  String? _selectedEmoji;
  bool _saving = false;

  static const _emojis = ['🔥', '🧘', '😴', '🎯', '💧', '📈', '📉'];

  static Color _habitColor(String hex) {
    final h = hex.replaceAll('#', '').padLeft(6, '0');
    return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF00C8FF);
  }

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.existing?.note ?? '');
    _selectedEmoji = widget.existing?.emoji;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _hasContent =>
      _selectedEmoji != null || _noteCtrl.text.trim().isNotEmpty;

  Future<void> _handleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final notifier = ref.read(habitsProvider.notifier);
      final date     = DateTime.parse(widget.dateStr);
      final habitsState = ref.read(habitsProvider).valueOrNull;
      final alreadyDone = habitsState?.logDates[widget.habit.id]
              ?.contains(widget.dateStr) ??
          false;

      // Complete the habit if not yet done for today.
      // toggleHabit writes to local DB before the remote call, so even if
      // the Supabase insert fails we still have a local row to attach the
      // note/emoji to — catch the exception and continue.
      if (!alreadyDone) {
        try {
          await notifier.toggleHabit(widget.habit.id, date);
        } catch (_) {}
      }

      // updateHabitLog never throws — it queues a sync op on remote failure.
      await notifier.updateHabitLog(
        habitId: widget.habit.id,
        date: date,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        emoji: _selectedEmoji,
      );

      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleRemove() async {
    if (_saving) return;
    setState(() => _saving = true);
    // updateHabitLog never throws — safe to call without extra try/catch.
    await ref.read(habitsProvider.notifier).updateHabitLog(
          habitId: widget.habit.id,
          date: DateTime.parse(widget.dateStr),
          note: null,
          emoji: null,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final sc          = ref.watch(sieColorsProvider);
    final accentColor = _habitColor(widget.habit.color);
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    final isEdit = widget.existing != null;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withValues(alpha: 0.08),
                sc.surface,
              ],
            ),
            border: Border(
              top: BorderSide(
                color: accentColor.withValues(alpha: 0.50),
                width: 1.0,
              ),
              left: BorderSide(
                color: accentColor.withValues(alpha: 0.18),
                width: 1.0,
              ),
              right: BorderSide(
                color: accentColor.withValues(alpha: 0.18),
                width: 1.0,
              ),
            ),
          ),
          padding: EdgeInsets.fromLTRB(24, 14, 24, 20 + keyboardBottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                ),
              ),
              // Title row with optional ⋯ more button
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.habit.title.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 11,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEdit ? 'UPDATE JOURNAL ENTRY' : 'ADD REFLECTION',
                          style: TextStyle(
                            color: sc.textSecondary.withValues(alpha: 0.6),
                            fontSize: 9,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Navigate to journal timeline
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              HabitDetailScreen(habit: widget.habit),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.history,
                        color: sc.textSecondary.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Emoji selector row
              Text(
                'MOOD',
                style: TextStyle(
                  color: sc.textSecondary.withValues(alpha: 0.5),
                  fontSize: 9,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: _emojis.map((e) {
                  final selected = _selectedEmoji == e;
                  return GestureDetector(
                    onTap: () => setState(
                        () => _selectedEmoji = selected ? null : e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? accentColor.withValues(alpha: 0.18)
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? accentColor.withValues(alpha: 0.55)
                              : sc.textSecondary.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(e,
                          style: TextStyle(
                              fontSize: selected ? 20 : 18)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Note field
              Text(
                'NOTE',
                style: TextStyle(
                  color: sc.textSecondary.withValues(alpha: 0.5),
                  fontSize: 9,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.25),
                  ),
                  color: accentColor.withValues(alpha: 0.04),
                ),
                child: TextField(
                  controller: _noteCtrl,
                  maxLength: 150,
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    color: sc.textPrimary,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Как всё прошло? Оставьте заметку...',
                    hintStyle: TextStyle(
                      color: sc.textSecondary.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                    counterStyle: TextStyle(
                      color: sc.textSecondary.withValues(alpha: 0.35),
                      fontSize: 9,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Button row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isEdit)
                    _SheetTextBtn(
                      label: 'REMOVE NOTE',
                      color: sc.textSecondary.withValues(alpha: 0.55),
                      onTap: _saving ? () {} : _handleRemove,
                    ),
                  if (!isEdit)
                    _SheetTextBtn(
                      label: 'CANCEL',
                      color: sc.textSecondary,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  const SizedBox(width: 8),
                  _SheetTextBtn(
                    label: _saving
                        ? '...'
                        : (isEdit ? 'UPDATE' : 'SAVE'),
                    color: _hasContent && !_saving
                        ? accentColor
                        : sc.textSecondary.withValues(alpha: 0.35),
                    onTap: _hasContent && !_saving ? _handleSave : () {},
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

// ─────────────────────────────────────────────────────────────────────────────
// Habit Archive Screen
// ─────────────────────────────────────────────────────────────────────────────

class HabitArchiveScreen extends ConsumerWidget {
  const HabitArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc       = ref.watch(sieColorsProvider);
    final archived = ref.watch(archivedHabitsProvider);

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                child: Row(
                  children: [
                    _GlassIconBtn(
                      icon: Icons.arrow_back_ios_new,
                      onTap: () => Navigator.of(context).pop(),
                      size: 15,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'HABIT ',
                                  style: TextStyle(
                                    color: sc.accent,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    shadows: null,
                                  ),
                                ),
                                TextSpan(
                                  text: 'ARCHIVE',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 3.0,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ЗАВЕРШЁННЫЕ НЕЙРОННЫЕ ПРОТОКОЛЫ',
                            style: TextStyle(
                              color: sc.textSecondary,
                              fontSize: 10,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: archived.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: sc.accent,
                      strokeWidth: 1.5,
                    ),
                  ),
                  error: (e, _) => Center(
                    child: _NoConnectionMessage(error: e),
                  ),
                  data: (habits) {
                    if (habits.isEmpty) {
                      return _ArchiveEmptyState();
                    }
                    return ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(20, 12, 20, 48),
                      itemCount: habits.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, i) => _ArchivedHabitCard(
                        habit: habits[i],
                        onRestore: () {
                          ref
                              .read(habitsProvider.notifier)
                              .restoreHabit(habits[i]);
                          ref.invalidate(archivedHabitsProvider);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchiveEmptyState extends ConsumerWidget {
  const _ArchiveEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 48, color: sc.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'АРХИВ ПУСТ',
            style: TextStyle(
              color: sc.textSecondary,
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Архивируйте выполненные привычки,\nчтобы увидеть их здесь',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: sc.textSecondary.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedHabitCard extends ConsumerStatefulWidget {
  final Habit habit;
  final VoidCallback onRestore;

  const _ArchivedHabitCard({required this.habit, required this.onRestore});

  @override
  ConsumerState<_ArchivedHabitCard> createState() => _ArchivedHabitCardState();
}

class _ArchivedHabitCardState extends ConsumerState<_ArchivedHabitCard> {
  bool _restoring = false;

  Color _toColor(String hex) {
    final h = hex.replaceAll('#', '').padLeft(6, '0');
    return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF00C8FF);
  }

  @override
  Widget build(BuildContext context) {
    final sc         = ref.watch(sieColorsProvider);
    final habitColor = _toColor(widget.habit.color);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                habitColor.withValues(alpha: 0.06),
                sc.surface,
              ],
            ),
            border: Border.all(
              color: habitColor.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: habitColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.habit.title.toUpperCase(),
                      style: TextStyle(
                        color: sc.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (widget.habit.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.habit.description!,
                        style: TextStyle(
                          color: sc.textSecondary,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _restoring ? null : () {
                  setState(() => _restoring = true);
                  widget.onRestore();
                },
                child: AnimatedOpacity(
                  opacity: _restoring ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: sc.accent.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _restoring ? 'ВОССТАНОВЛЕНИЕ...' : 'ВОССТАНОВИТЬ',
                      style: TextStyle(
                        color: sc.accent,
                        fontSize: 9,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _NoConnectionMessage extends ConsumerWidget {
  final Object? error;
  const _NoConnectionMessage({this.error});

  static bool _isNetworkError(Object? e) {
    if (e == null) return false;
    final msg = e.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('connection') ||
        msg.contains('network') ||
        msg.contains('unreachable') ||
        msg.contains('failed host lookup');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    final isNetwork = _isNetworkError(error);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isNetwork ? Icons.wifi_off_outlined : Icons.error_outline,
          color: sc.iconMuted,
          size: 36,
        ),
        const SizedBox(height: 12),
        Text(
          isNetwork
              ? 'Подключение к интернету отсутствует'
              : 'Не удалось загрузить данные',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: sc.iconMuted,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Routine Block
// ─────────────────────────────────────────────────────────────────────────────

class _RoutineBlock extends ConsumerStatefulWidget {
  const _RoutineBlock({
    required this.type,
    this.routine,
    this.habitsState,
  });

  final String type; // 'morning' | 'evening'
  final HabitRoutine? routine;
  final HabitsState? habitsState;

  @override
  ConsumerState<_RoutineBlock> createState() => _RoutineBlockState();
}

class _RoutineBlockState extends ConsumerState<_RoutineBlock> {
  final PageController _pageCtrl = PageController();
  bool _carouselActive = false;

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  bool get _isActive {
    final h = DateTime.now().hour;
    return widget.type == 'morning' ? (h >= 3 && h < 12) : (h >= 17 && h < 23);
  }

  bool _isCompleted(Habit h) =>
      widget.habitsState?.logDates[h.id]?.contains(_today()) ?? false;

  bool _isUnlocked(int index) {
    if (index == 0) return true;
    final habits = widget.routine?.habits ?? [];
    for (var i = 0; i < index; i++) {
      if (!_isCompleted(habits[i])) return false;
    }
    return true;
  }

  bool get _anyCompletedToday =>
      (widget.routine?.habits ?? []).any(_isCompleted);

  bool get _allCompletedToday {
    final habits = widget.routine?.habits ?? [];
    if (habits.isEmpty) return false;
    return habits.every(_isCompleted);
  }

  void _openEditor() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoutineEditorScreen(routineType: widget.type),
      ),
    );
  }

  void _showLongPressMenu() {
    final sc         = ref.read(sieColorsProvider);
    final editLabel  = widget.type == 'morning'
        ? 'ИЗМЕНИТЬ УТРЕННЮЮ РУТИНУ'
        : 'ИЗМЕНИТЬ ВЕЧЕРНЮЮ РУТИНУ';
    final deleteLabel = widget.type == 'morning'
        ? 'УДАЛИТЬ УТРЕННЮЮ РУТИНУ'
        : 'УДАЛИТЬ ВЕЧЕРНЮЮ РУТИНУ';
    final headerLabel = widget.type == 'morning'
        ? 'УТРЕННЯЯ РУТИНА'
        : 'ВЕЧЕРНЯЯ РУТИНА';

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    sc.accent.withValues(alpha: 0.05),
                    sc.surface,
                  ],
                ),
                border: Border.all(
                    color: sc.accent.withValues(alpha: 0.25)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Text(
                      headerLabel,
                      style: TextStyle(
                        color: sc.textSecondary.withValues(alpha: 0.80),
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  Divider(
                      color: sc.accent.withValues(alpha: 0.15),
                      height: 1),
                  _OptionTile(
                    icon: Icons.edit_outlined,
                    label: editLabel,
                    color: sc.textPrimary,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _openEditor();
                    },
                  ),
                  if (widget.routine != null)
                    _OptionTile(
                      icon: Icons.delete_outline,
                      label: deleteLabel,
                      color: Colors.redAccent,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        ref
                            .read(habitRoutinesProvider.notifier)
                            .deleteRoutine(widget.routine!.id);
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(_RoutineBlock old) {
    super.didUpdateWidget(old);
    if (old.routine != null && widget.routine == null) {
      _carouselActive = false;
    }
    final newCount = (widget.routine?.habits.length ?? 0) + 1;
    if (_pageCtrl.hasClients && (_pageCtrl.page ?? 0).round() >= newCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(0);
      });
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sc      = ref.watch(sieColorsProvider);
    final routine = widget.routine;

    if (!_isActive || routine == null) return const SizedBox.shrink();

    if (!_carouselActive && !_anyCompletedToday) {
      return _buildStartCard(sc, routine);
    }

    return _buildCarousel(sc, routine);
  }

  // ── Active, not yet started ───────────────────────────────────

  Widget _buildStartCard(SieColors sc, HabitRoutine routine) {
    final title      = widget.type == 'morning'
        ? 'УТРЕННЯЯ РУТИНА'
        : 'ВЕЧЕРНЯЯ РУТИНА';
    final startLabel = widget.type == 'morning'
        ? 'НАЧАТЬ УТРЕННЮЮ РУТИНУ'
        : 'НАЧАТЬ ВЕЧЕРНЮЮ РУТИНУ';

    return GestureDetector(
      onLongPress: _showLongPressMenu,
      child: SieGlassCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: sc.accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                shadows: null,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                if (routine.habits.isEmpty) {
                  _openEditor();
                } else {
                  setState(() => _carouselActive = true);
                }
              },
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: sc.accent.withValues(alpha: 0.10),
                  border: Border.all(
                      color: sc.accent.withValues(alpha: 0.40)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow,
                        color: sc.accent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      routine.habits.isEmpty
                          ? 'ДОБАВИТЬ ПРИВЫЧКИ'
                          : startLabel,
                      style: TextStyle(
                        color: sc.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Carousel ──────────────────────────────────────────────────

  Widget _buildCarousel(SieColors sc, HabitRoutine routine) {
    final habits    = routine.habits;
    final itemCount = habits.length + 1; // +1 for add-habit slide
    final allDone   = _allCompletedToday;

    return GestureDetector(
      onLongPress: _showLongPressMenu,
      child: SieGlassCard(
        height: 110,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: itemCount,
                itemBuilder: (ctx, i) {
                  if (i == habits.length) {
                    return _CarouselAddSlide(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RoutineEditorScreen(
                              routineType: widget.type),
                        ),
                      ),
                    );
                  }
                  final h          = habits[i];
                  final completed  = _isCompleted(h);
                  final unlocked   = _isUnlocked(i);
                  final habitColor = hexToColor(h.color);
                  return _CarouselHabitSlide(
                    habit:       h,
                    habitColor:  habitColor,
                    isCompleted: completed,
                    isUnlocked:  unlocked,
                    allDone:     allDone,
                    onComplete:  (unlocked && !completed)
                        ? () => ref
                            .read(habitsProvider.notifier)
                            .toggleHabit(h.id, DateTime.now())
                        : null,
                  );
                },
              ),
            ),
            // Page indicator dots
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RepaintBoundary(
                child: AnimatedBuilder(
                animation: _pageCtrl,
                builder: (_, _) {
                  final page = _pageCtrl.hasClients
                      ? (_pageCtrl.page ?? 0).round()
                      : 0;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(itemCount, (i) {
                      final active = i == page;
                      return AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 200),
                        width:  active ? 14 : 6,
                        height: 4,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 2),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(2),
                          color: active
                              ? sc.accent
                              : sc.textSecondary
                                  .withValues(alpha: 0.28),
                        ),
                      );
                    }),
                  );
                },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carousel — Habit Slide
// ─────────────────────────────────────────────────────────────────────────────

class _CarouselHabitSlide extends ConsumerWidget {
  const _CarouselHabitSlide({
    required this.habit,
    required this.habitColor,
    required this.isCompleted,
    required this.isUnlocked,
    required this.allDone,
    this.onComplete,
  });

  final Habit habit;
  final Color habitColor;
  final bool isCompleted;
  final bool isUnlocked;
  final bool allDone;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);

    return Opacity(
      opacity: isUnlocked ? 1.0 : 0.40,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: habitColor,
                    boxShadow: null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    habit.title.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: sc.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                if (isCompleted)
                  Icon(Icons.check_circle,
                      color: habitColor, size: 18),
              ],
            ),
            const Spacer(),
            if (isCompleted)
              Center(
                child: Text(
                  allDone ? 'РУТИНА ВЫПОЛНЕНА ✓' : 'ВЫПОЛНЕНО ✓',
                  style: TextStyle(
                    color: habitColor,
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    shadows: null,
                  ),
                ),
              )
            else if (isUnlocked)
              GestureDetector(
                onTap: onComplete,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: habitColor.withValues(alpha: 0.12),
                    border: Border.all(
                        color: habitColor.withValues(alpha: 0.45)),
                  ),
                  child: Center(
                    child: Text(
                      'ВЫПОЛНЕНО',
                      style: TextStyle(
                        color: habitColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              )
            else
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline,
                        color:
                            sc.textSecondary.withValues(alpha: 0.50),
                        size: 12),
                    const SizedBox(width: 6),
                    Text(
                      'ЗАВЕРШИТЕ ПРЕДЫДУЩЕЕ',
                      style: TextStyle(
                        color:
                            sc.textSecondary.withValues(alpha: 0.50),
                        fontSize: 9,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carousel — Add Habit Slide
// ─────────────────────────────────────────────────────────────────────────────

class _CarouselAddSlide extends ConsumerWidget {
  const _CarouselAddSlide({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: sc.accent.withValues(alpha: 0.45)),
                color: sc.accent.withValues(alpha: 0.07),
              ),
              child: Icon(Icons.add, color: sc.accent, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'ДОБАВИТЬ ПРИВЫЧКУ',
              style: TextStyle(
                color: sc.textSecondary.withValues(alpha: 0.65),
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Habit Detail Screen (Journal Timeline)
// ─────────────────────────────────────────────────────────────────────────────

class HabitDetailScreen extends ConsumerStatefulWidget {
  final Habit habit;
  const HabitDetailScreen({super.key, required this.habit});

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen> {
  static String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static Color _habitColor(String hex) {
    final h = hex.replaceAll('#', '').padLeft(6, '0');
    return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF00C8FF);
  }

  void _editHabit() {
    final sc = ref.read(sieColorsProvider);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    sc.accent.withValues(alpha: 0.05),
                    sc.surface,
                  ],
                ),
                border: Border.all(
                  color: sc.accent.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Text(
                      widget.habit.title.toUpperCase(),
                      style: TextStyle(
                        color: sc.textSecondary.withValues(alpha: 0.80),
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  Divider(
                      color: sc.accent.withValues(alpha: 0.15), height: 1),
                  _OptionTile(
                    icon: Icons.edit_outlined,
                    label: 'EDIT PROTOCOL',
                    color: sc.textPrimary,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => _HabitDialog(
                          existing: widget.habit,
                          onSave: (title, description, color, icon) {
                            ref.read(habitsProvider.notifier).updateHabit(
                                  habitId: widget.habit.id,
                                  title: title,
                                  description: description,
                                  color: color,
                                  icon: icon,
                                );
                          },
                        ),
                      );
                    },
                  ),
                  _OptionTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'ARCHIVE PROTOCOL',
                    color: sc.accent,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      ref
                          .read(habitsProvider.notifier)
                          .archiveHabit(widget.habit.id);
                      Navigator.of(context).pop();
                    },
                  ),
                  _OptionTile(
                    icon: Icons.delete_outline,
                    label: 'DELETE PROTOCOL',
                    color: Colors.redAccent,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _confirmDeleteHabit();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteHabit() {
    final sc = ref.read(sieColorsProvider);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.redAccent.withValues(alpha: 0.06),
                    sc.surface,
                  ],
                ),
                border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.35)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONFIRM DELETION',
                    style: TextStyle(
                      color: sc.textPrimary,
                      fontSize: 12,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Delete "${widget.habit.title}"? All log history will be erased.',
                    style: TextStyle(
                      color: sc.textSecondary,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _SheetTextBtn(
                        label: 'CANCEL',
                        color: sc.textSecondary,
                        onTap: () => Navigator.of(ctx).pop(),
                      ),
                      const SizedBox(width: 8),
                      _SheetTextBtn(
                        label: 'DELETE',
                        color: Colors.redAccent,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ref
                              .read(habitsProvider.notifier)
                              .deleteHabit(widget.habit.id);
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openReflection(
      String dateStr, HabitLogEntry? existing, Color accentColor) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReflectionSheet(
        habit: widget.habit,
        dateStr: dateStr,
        existing: existing,
      ),
    ).then((_) {
      ref.invalidate(habitLogEntriesProvider(widget.habit.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final sc          = ref.watch(sieColorsProvider);
    final accentColor = _habitColor(widget.habit.color);
    final habitsState = ref.watch(habitsProvider).valueOrNull;
    final entriesAsync = ref.watch(habitLogEntriesProvider(widget.habit.id));

    final today       = _fmt(DateTime.now());
    final logDates    = habitsState?.logDates[widget.habit.id] ?? {};
    final streak      = habitsState?.streaks[widget.habit.id] ?? 0;
    final logEntries  = habitsState?.logEntries[widget.habit.id] ?? [];
    final completedToday = logDates.contains(today);
    final todayEntry  = logEntries.cast<HabitLogEntry?>()
        .firstWhere((e) => e?.completedAt == today, orElse: () => null);
    final totalDone   = logDates.length;

    final now  = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                child: Row(
                  children: [
                    _GlassIconBtn(
                      icon: Icons.arrow_back_ios_new,
                      onTap: () => Navigator.of(context).pop(),
                      size: 15,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'HABIT ',
                                  style: TextStyle(
                                    color: sc.accent,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    shadows: null,
                                  ),
                                ),
                                TextSpan(
                                  text: 'DETAIL',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 3.0,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.habit.title.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 10,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _GlassIconBtn(
                      icon: Icons.more_horiz,
                      onTap: _editHabit,
                      size: 18,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ── Quick Stats ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _DetailStatCard(
                      label: 'STREAK',
                      value: '$streak',
                      color: accentColor,
                      sc: sc,
                    ),
                    const SizedBox(width: 12),
                    _DetailStatCard(
                      label: 'TOTAL',
                      value: '$totalDone',
                      color: sc.accent,
                      sc: sc,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // ── Today Status ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STATUS: ${completedToday ? "COMPLETED" : "PENDING"}',
                      style: TextStyle(
                        color: sc.textSecondary.withValues(alpha: 0.6),
                        fontSize: 9,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _TodayActionCard(
                      completed: completedToday,
                      accentColor: accentColor,
                      emoji: todayEntry?.emoji,
                      note: todayEntry?.note,
                      onToggle: () => ref
                          .read(habitsProvider.notifier)
                          .toggleHabit(widget.habit.id, DateTime.now()),
                      onOpenReflection: () => _openReflection(
                          today, todayEntry, accentColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ── Journal Timeline ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'JOURNAL TIMELINE',
                  style: TextStyle(
                    color: sc.textSecondary,
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: entriesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => Center(
                    child: Text('Error loading journal',
                        style: TextStyle(color: sc.textSecondary)),
                  ),
                  data: (entries) {
                    final reversed = entries.reversed.toList();
                    if (reversed.isEmpty) {
                      return Center(
                        child: Text(
                          'No journal entries yet',
                          style: TextStyle(
                            color: sc.textSecondary.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      itemCount: reversed.length,
                      itemBuilder: (ctx, i) => _JournalEntryTile(
                        entry: reversed[i],
                        accentColor: accentColor,
                        sc: sc,
                        onTap: () => _openReflection(
                          reversed[i].completedAt,
                          reversed[i],
                          accentColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailStatCard extends StatelessWidget {
  const _DetailStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.sc,
  });

  final String label;
  final String value;
  final Color color;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          color: color.withValues(alpha: 0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.6),
                fontSize: 9,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayActionCard extends StatelessWidget {
  const _TodayActionCard({
    required this.completed,
    required this.accentColor,
    required this.onToggle,
    required this.onOpenReflection,
    this.emoji,
    this.note,
  });

  final bool completed;
  final Color accentColor;
  final VoidCallback onToggle;
  final VoidCallback onOpenReflection;
  final String? emoji;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final sc = ProviderScope.containerOf(context).read(sieColorsProvider);

    return SieGlassCard(
      onTap: onOpenReflection,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed
                    ? accentColor.withValues(alpha: 0.15)
                    : Colors.transparent,
                border: Border.all(
                  color: completed
                      ? accentColor
                      : sc.textSecondary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(
                completed ? Icons.check : Icons.add,
                color: completed ? accentColor : sc.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  completed ? 'MISSION ACCOMPLISHED' : 'INITIALIZE PROTOCOL',
                  style: TextStyle(
                    color: completed ? accentColor : sc.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  completed
                      ? (note ?? 'Tap to add reflection')
                      : 'Mark as done for today',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: sc.textSecondary.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (emoji != null) ...[
            const SizedBox(width: 8),
            Text(emoji!, style: const TextStyle(fontSize: 20)),
          ] else if (completed) ...[
            const SizedBox(width: 8),
            Icon(Icons.edit_note,
                color: sc.textSecondary.withValues(alpha: 0.4), size: 20),
          ],
        ],
      ),
    );
  }
}

class _JournalEntryTile extends StatelessWidget {
  const _JournalEntryTile({
    required this.entry,
    required this.accentColor,
    required this.sc,
    required this.onTap,
  });

  final HabitLogEntry entry;
  final Color accentColor;
  final SieColors sc;
  final VoidCallback onTap;

  static String _fmtDate(String s) {
    final dt = DateTime.parse(s);
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: sc.border.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withValues(alpha: 0.1),
                    border: Border.all(
                        color: accentColor.withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: entry.emoji != null
                      ? Text(entry.emoji!,
                          style: const TextStyle(fontSize: 14))
                      : Icon(Icons.check, size: 14, color: accentColor),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 1,
                  height: 20,
                  color: sc.border.withValues(alpha: 0.3),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fmtDate(entry.completedAt).toUpperCase(),
                    style: TextStyle(
                      color: sc.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  if (entry.note != null && entry.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.note!,
                      style: TextStyle(
                        color: sc.textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
