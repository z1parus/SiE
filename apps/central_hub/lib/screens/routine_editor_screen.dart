import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'habit_tracker_screen.dart' show HabitDetailScreen;

// ─────────────────────────────────────────────────────────────────────────────
// RoutineEditorScreen
// ─────────────────────────────────────────────────────────────────────────────

class RoutineEditorScreen extends ConsumerWidget {
  const RoutineEditorScreen({super.key, required this.routineType});

  final String routineType; // 'morning' | 'evening'

  String get _title =>
      routineType == 'morning' ? 'УТРЕННЯЯ РУТИНА' : 'ВЕЧЕРНЯЯ РУТИНА';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc          = ref.watch(sieColorsProvider);
    final routinesVal = ref.watch(habitRoutinesProvider).valueOrNull;
    final routine     = routineType == 'morning'
        ? routinesVal?.morning
        : routinesVal?.evening;
    final habits = routine?.habits ?? [];

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EditorTopBar(title: _title),
              Expanded(
                child: habits.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.list_alt_outlined,
                              size: 40,
                              color: sc.textSecondary.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'НЕТ ПРИВЫЧЕК',
                              style: TextStyle(
                                color: sc.textSecondary,
                                fontSize: 11,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Добавьте привычки ниже',
                              style: TextStyle(
                                color: sc.textSecondary.withValues(alpha: 0.55),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ReorderableListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        buildDefaultDragHandles: false,
                        proxyDecorator: (child, _, __) =>
                            Material(color: Colors.transparent, child: child),
                        onReorder: (oldIdx, newIdx) {
                          if (routine == null) return;
                          final reordered = [...habits];
                          final moved = reordered.removeAt(oldIdx);
                          reordered.insert(newIdx, moved);
                          ref
                              .read(habitRoutinesProvider.notifier)
                              .reorderMembers(
                                routine.id,
                                reordered.map((h) => h.id).toList(),
                              );
                        },
                        itemCount: habits.length,
                        itemBuilder: (context, i) => _RoutineMemberTile(
                          key: ValueKey(habits[i].id),
                          index: i,
                          habit: habits[i],
                          onRemove: routine == null
                              ? null
                              : () {
                                  final notifier = ref.read(
                                      habitRoutinesProvider.notifier);
                                  final removedId = habits[i].id;
                                  final prevOrder =
                                      habits.map((h) => h.id).toList();
                                  notifier.removeHabitFromRoutine(
                                      routine.id, removedId);
                                  showUndoSnackbar(
                                    context,
                                    ref,
                                    message: 'Привычка убрана из рутины',
                                    onUndo: () async {
                                      await notifier.addHabitToRoutine(
                                          routine.id, removedId);
                                      await notifier.reorderMembers(
                                          routine.id, prevOrder);
                                    },
                                  );
                                },
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  HabitDetailScreen(habit: habits[i]),
                            ),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: _AddHabitChip(
                  onTap: () => _openPicker(context, ref, routine),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPicker(
      BuildContext context, WidgetRef ref, HabitRoutine? routine) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width - 40,
      ),
      builder: (_) => _HabitPickerSheet(
        routineType: routineType,
        currentRoutineId: routine?.id,
        existingHabitIds:
            routine?.habits.map((h) => h.id).toSet() ?? {},
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────────────────

class _EditorTopBar extends ConsumerWidget {
  const _EditorTopBar({required this.title});
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _EditorIconBtn(
            icon: Icons.arrow_back_ios_new,
            onTap: () => Navigator.of(context).pop(),
            size: 15,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: sc.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Icon Button (same style as habit_tracker_screen _GlassIconBtn)
// ─────────────────────────────────────────────────────────────────────────────

class _EditorIconBtn extends ConsumerWidget {
  const _EditorIconBtn({
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
// Routine Member Tile
// ─────────────────────────────────────────────────────────────────────────────

class _RoutineMemberTile extends ConsumerWidget {
  const _RoutineMemberTile({
    super.key,
    required this.index,
    required this.habit,
    this.onRemove,
    this.onTap,
  });
  final int index;
  final Habit habit;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc    = ref.watch(sieColorsProvider);
    final color = hexToColor(habit.color);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SieGlassCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                habit.title.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: sc.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            if (onRemove != null)
              Semantics(
                button: true,
                label: 'Убрать из рутины',
                child: GestureDetector(
                  onTap: onRemove,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Icon(
                        Icons.remove_circle_outline,
                        color: sc.textSecondary.withValues(alpha: 0.50),
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ReorderableDragStartListener(
              index: index,
              child: Semantics(
                label: 'Перетащите для сортировки',
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Icon(
                      Icons.drag_handle,
                      color: sc.textSecondary.withValues(alpha: 0.35),
                      size: 20,
                    ),
                  ),
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
// Add Habit Chip (bottom of editor)
// ─────────────────────────────────────────────────────────────────────────────

class _AddHabitChip extends ConsumerWidget {
  const _AddHabitChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    return GestureDetector(
      onTap: onTap,
      child: SieGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: sc.accent, size: 18),
            const SizedBox(width: 8),
            Text(
              'ДОБАВИТЬ ПРИВЫЧКУ',
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Habit Picker Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _HabitPickerSheet extends ConsumerWidget {
  const _HabitPickerSheet({
    required this.routineType,
    this.currentRoutineId,
    required this.existingHabitIds,
  });

  final String routineType;
  final String? currentRoutineId;
  final Set<String> existingHabitIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc         = ref.watch(sieColorsProvider);
    final habitsAsync = ref.watch(habitsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
      child: Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: sc.surface.withValues(alpha: 0.92),
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
            'ADD TO ROUTINE',
            style: TextStyle(
              color: sc.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          habitsAsync.when(
            loading: () => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(
                    color: sc.accent, strokeWidth: 1.5),
              ),
            ),
            error: (e, _) => const SizedBox.shrink(),
            data: (state) {
              final available = state.habits
                  .where((h) => !existingHabitIds.contains(h.id))
                  .toList();
              if (available.isEmpty) {
                final noHabitsAtAll = state.habits.isEmpty;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      noHabitsAtAll
                          ? 'Сначала создайте привычки в Архиве'
                          : 'Все активные привычки уже добавлены',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: sc.textSecondary,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                );
              }
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height * 0.40,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: available.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final habit = available[i];
                    return _HabitPickerTile(
                      habit: habit,
                      onTap: () {
                        final notifier = ref
                            .read(habitRoutinesProvider.notifier);
                        final routineId = currentRoutineId;
                        Navigator.of(context).pop();
                        _doAdd(notifier, routineId, habit.id);
                      },
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    ));
  }

  Future<void> _doAdd(
    HabitRoutinesNotifier notifier,
    String? routineId,
    String habitId,
  ) async {
    String rId = routineId ?? '';
    if (rId.isEmpty) {
      rId = await notifier.createRoutine(routineType);
    }
    await notifier.addHabitToRoutine(rId, habitId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Habit Picker Tile
// ─────────────────────────────────────────────────────────────────────────────

class _HabitPickerTile extends ConsumerWidget {
  const _HabitPickerTile({required this.habit, required this.onTap});
  final Habit habit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc    = ref.watch(sieColorsProvider);
    final color = hexToColor(habit.color);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color.withValues(alpha: 0.06),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    habit.title.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: sc.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  if (habit.description != null &&
                      habit.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      habit.description!,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        color: sc.textSecondary.withValues(alpha: 0.65),
                        fontSize: 10,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.add_circle_outline, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}
