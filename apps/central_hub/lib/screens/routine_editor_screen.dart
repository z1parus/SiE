import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'habit_tracker_screen.dart' show HabitDetailScreen;

// ─────────────────────────────────────────────────────────────────────────────
// RoutineEditorScreen
// ─────────────────────────────────────────────────────────────────────────────

class RoutineEditorScreen extends ConsumerWidget {
  const RoutineEditorScreen({super.key, this.routineType, this.stackId})
      : assert(routineType != null || stackId != null,
            'Provide either routineType or stackId');

  final String? routineType; // 'morning' | 'evening' (legacy)
  final String? stackId; // named stack id (Stage 8b)

  bool get _isStack => stackId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc          = ref.watch(sieColorsProvider);
    final routinesVal = ref.watch(habitRoutinesProvider).valueOrNull;
    final routine     = _isStack
        ? routinesVal?.byId(stackId!)
        : (routineType == 'morning'
            ? routinesVal?.morning
            : routinesVal?.evening);
    final habits = routine?.habits ?? [];
    final title = _isStack
        ? (routine?.displayName.toUpperCase() ??
            t.routineEditor.title.stackFallback)
        : (routineType == 'morning'
            ? t.routineEditor.title.morning
            : t.routineEditor.title.evening);

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EditorTopBar(
                title: title,
                onEditMeta: _isStack && routine != null
                    ? () => _editStackMeta(context, ref, routine)
                    : null,
              ),
              if (_isStack && routine != null && routine.anchorCue != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Row(
                    children: [
                      Icon(Icons.link, size: 13,
                          color: sc.accent.withValues(alpha: 0.8)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          routine.anchorCue!,
                          style: TextStyle(
                            color: sc.textSecondary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                              t.routineEditor.empty.noHabits,
                              style: TextStyle(
                                color: sc.textSecondary,
                                fontSize: 11,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t.routineEditor.empty.addBelow,
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
                                    message: t.routineEditor.removeSnackbar,
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
        // For stacks the routine already exists, so the fallback type is unused.
        routineType: routine?.routineType ?? routineType ?? 'stack',
        currentRoutineId: routine?.id ?? stackId,
        existingHabitIds:
            routine?.habits.map((h) => h.id).toSet() ?? {},
      ),
    );
  }

  void _editStackMeta(
      BuildContext context, WidgetRef ref, HabitRoutine routine) {
    showStackMetaDialog(
      context,
      ref,
      initialName: routine.name,
      initialCue: routine.anchorCue,
      onSave: (name, cue) => ref
          .read(habitRoutinesProvider.notifier)
          .updateStackMeta(routine.id, name: name, anchorCue: cue),
    );
  }
}

/// Shared name + anchor-cue editor used when creating or editing a stack.
void showStackMetaDialog(
  BuildContext context,
  WidgetRef ref, {
  String? initialName,
  String? initialCue,
  required void Function(String name, String? cue) onSave,
  String? saveLabel,
}) {
  final resolvedSaveLabel = saveLabel ?? t.routineEditor.dialog.save;
  final sc        = ref.read(sieColorsProvider);
  final nameCtrl  = TextEditingController(text: initialName ?? '');
  final cueCtrl   = TextEditingController(text: initialCue ?? '');

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: sc.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sc.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.routineEditor.dialog.stackHeader,
                style: TextStyle(
                  color: sc.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: sc.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: t.routineEditor.dialog.nameLabel,
                  labelStyle:
                      TextStyle(color: sc.textSecondary, fontSize: 11),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: sc.border)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: sc.accent)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cueCtrl,
                style: TextStyle(color: sc.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: t.routineEditor.dialog.cueLabel,
                  hintText: t.routineEditor.dialog.cueHint,
                  hintStyle: TextStyle(
                      color: sc.textSecondary.withValues(alpha: 0.4),
                      fontSize: 12),
                  labelStyle:
                      TextStyle(color: sc.textSecondary, fontSize: 11),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: sc.border)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: sc.accent)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Text(t.routineEditor.dialog.cancel,
                          style: TextStyle(
                              color: sc.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final cue = cueCtrl.text.trim();
                      Navigator.of(ctx).pop();
                      onSave(name, cue.isEmpty ? null : cue);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: sc.accent.withValues(alpha: 0.15),
                        border: Border.all(
                            color: sc.accent.withValues(alpha: 0.6)),
                      ),
                      child: Text(resolvedSaveLabel,
                          style: TextStyle(
                              color: sc.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────────────────

class _EditorTopBar extends ConsumerWidget {
  const _EditorTopBar({required this.title, this.onEditMeta});
  final String title;
  final VoidCallback? onEditMeta;

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
          if (onEditMeta != null)
            _EditorIconBtn(
              icon: Icons.edit_outlined,
              onTap: onEditMeta!,
              size: 16,
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
                label: t.routineEditor.tile.removeFromRoutine,
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
                label: t.routineEditor.tile.dragToReorder,
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
              t.routineEditor.addHabit,
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
            t.routineEditor.picker.addToRoutine,
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
                          ? t.routineEditor.picker.createFirst
                          : t.routineEditor.picker.allAdded,
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
