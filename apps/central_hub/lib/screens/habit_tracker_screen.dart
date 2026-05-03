import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

class HabitTrackerScreen extends ConsumerWidget {
  const HabitTrackerScreen({super.key});

  static String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);
    final today = _fmt(DateTime.now());

    return Scaffold(
      backgroundColor: SieTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopBar(onAdd: () => _showHabitDialog(context, ref, null)),
            Expanded(
              child: habitsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: SieTheme.accent,
                    strokeWidth: 1.5,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'ERROR: $e',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
                data: (state) {
                  if (state.habits.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'NO PROTOCOLS ACTIVE',
                            style: TextStyle(
                              color: SieTheme.textSecondary,
                              fontSize: 12,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'TAP + TO INITIALISE A HABIT',
                            style: TextStyle(
                              color: SieTheme.textSecondary
                                  .withValues(alpha: 0.5),
                              fontSize: 10,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          _AddButton(
                            onTap: () => _showHabitDialog(context, ref, null),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    itemCount: state.habits.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      if (i == state.habits.length) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _AddButton(
                              onTap: () =>
                                  _showHabitDialog(context, ref, null),
                            ),
                          ),
                        );
                      }
                      final habit = state.habits[i];
                      final logDates = state.logDates[habit.id] ?? {};
                      return _SwipeableHabitCard(
                        key: ValueKey(habit.id),
                        habit: habit,
                        completedToday: logDates.contains(today),
                        streak: state.streaks[habit.id] ?? 0,
                        allLogDates: logDates,
                        onToggle: () => ref
                            .read(habitsProvider.notifier)
                            .toggleHabit(habit.id, DateTime.now()),
                        onLongPress: () =>
                            _showHabitOptions(context, ref, habit),
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
      ),
    );
  }

  void _showHabitDialog(
    BuildContext context,
    WidgetRef ref,
    Habit? existing,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _HabitDialog(
        existing: existing,
        onSave: (title, description, color) {
          if (existing == null) {
            ref.read(habitsProvider.notifier).addHabit(
                  title: title,
                  description: description,
                  color: color,
                );
          } else {
            ref.read(habitsProvider.notifier).updateHabit(
                  habitId: existing.id,
                  title: title,
                  description: description,
                  color: color,
                );
          }
        },
      ),
    );
  }

  void _showHabitOptions(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: SieTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: SieTheme.borderDefault),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  habit.title.toUpperCase(),
                  style: const TextStyle(
                    color: SieTheme.textSecondary,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const Divider(color: SieTheme.borderDefault, height: 1),
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.edit_outlined,
                  color: SieTheme.textPrimary,
                  size: 18,
                ),
                title: const Text(
                  'EDIT PROTOCOL',
                  style: TextStyle(
                    color: SieTheme.textPrimary,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showHabitDialog(context, ref, habit);
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 18,
                ),
                title: const Text(
                  'DELETE PROTOCOL',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmDelete(context, ref, habit);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Habit habit) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: SieTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: SieTheme.borderDefault),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CONFIRM DELETION',
                style: TextStyle(
                  color: SieTheme.textPrimary,
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Delete "${habit.title}"? All log history will be erased.',
                style: const TextStyle(
                  color: SieTheme.textSecondary,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        color: SieTheme.textSecondary,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      ref
                          .read(habitsProvider.notifier)
                          .deleteHabit(habit.id);
                    },
                    child: const Text(
                      'DELETE',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                      ),
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

// ── Swipeable Card ────────────────────────────────────────────

class _SwipeableHabitCard extends StatefulWidget {
  final Habit habit;
  final bool completedToday;
  final int streak;
  final Set<String> allLogDates;
  final VoidCallback onToggle;
  final VoidCallback? onLongPress;
  final Future<void> Function() onDelete;
  final VoidCallback onTogglePin;

  const _SwipeableHabitCard({
    super.key,
    required this.habit,
    required this.completedToday,
    required this.streak,
    required this.allLogDates,
    required this.onToggle,
    this.onLongPress,
    required this.onDelete,
    required this.onTogglePin,
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

  // Action fires when swipe reaches this fraction of screen width.
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
    _snapCtrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_isSnapping) return;
    setState(() {
      _dragOffset = (_dragOffset + d.delta.dx)
          .clamp(-_screenWidth * 0.65, _screenWidth * 0.65);
    });
  }

  Future<void> _onDragEnd(DragEndDetails d) async {
    if (_isSnapping) return;
    final trigger = _triggerDist;

    if (_dragOffset.abs() >= trigger) {
      if (_dragOffset < 0) {
        // Delete: fly card off-screen, then call onDelete.
        _isSnapping = true;
        _snapAnim = Tween<double>(begin: _dragOffset, end: -_screenWidth * 1.2)
            .animate(
                CurvedAnimation(parent: _snapCtrl, curve: Curves.easeIn));
        await _snapCtrl.forward(from: 0);
        if (!mounted) return;
        await widget.onDelete();
      } else {
        // Pin: trigger action then snap back with elastic bounce.
        widget.onTogglePin();
        _isSnapping = true;
        _snapAnim = Tween<double>(begin: _dragOffset, end: 0).animate(
            CurvedAnimation(
                parent: _snapCtrl, curve: Curves.elasticOut));
        unawaited(_snapCtrl.forward(from: 0));
        _snapCtrl.addStatusListener(_onSnapComplete);
      }
    } else {
      // Below threshold: snap back.
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
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: AnimatedBuilder(
        animation: _snapCtrl,
        builder: (context2, snap) {
          final offset = (_isSnapping && _snapAnim != null)
              ? _snapAnim!.value
              : _dragOffset;
          final trigger = _screenWidth * _triggerFraction;
          final progress = (offset.abs() / trigger).clamp(0.0, 1.0);
          final isLeft = offset < 0;

          return Transform.translate(
            offset: Offset(offset, 0),
            child: Transform.scale(
              scale: 1.0 - 0.02 * progress,
              child: HabitCard(
                habit: widget.habit,
                completedToday: widget.completedToday,
                streak: widget.streak,
                allLogDates: widget.allLogDates,
                onToggle: widget.onToggle,
                onLongPress: widget.onLongPress,
                swipeProgress: progress,
                swipeIsLeft: progress > 0.01 ? isLeft : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onAdd;
  const _TopBar({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: SieTheme.textSecondary,
              size: 18,
            ),
          ),
          Expanded(
            child: Text(
              'HABIT ARCHIVE',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: onAdd,
            icon: const Icon(
              Icons.add,
              color: SieTheme.accent,
              size: 22,
            ),
            tooltip: 'ADD PROTOCOL',
          ),
        ],
      ),
    );
  }
}

// ── Pulsing Add Button ────────────────────────────────────────

class _AddButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

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
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context2, anim) => Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SieTheme.accent.withValues(alpha: 0.10),
              border: Border.all(
                color: SieTheme.accent.withValues(alpha: 0.60),
              ),
              boxShadow: [
                BoxShadow(
                  color: SieTheme.accent.withValues(
                    alpha: 0.08 + 0.12 * _ctrl.value,
                  ),
                  blurRadius: 12 + 8 * _ctrl.value,
                  spreadRadius: 1 + 2 * _ctrl.value,
                ),
              ],
            ),
            child: const Icon(
              Icons.add,
              color: SieTheme.accent,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Unified Add/Edit Dialog ───────────────────────────────────

class _HabitDialog extends StatefulWidget {
  final Habit? existing;
  final void Function(String title, String? description, String color) onSave;

  const _HabitDialog({this.existing, required this.onSave});

  @override
  State<_HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends State<_HabitDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late String _selectedColor;

  static const _colorOptions = [
    '#00C8FF',
    '#00E5A0',
    '#A78BFA',
    '#F59E0B',
  ];

  Color _toColor(String hex) {
    final h = hex.replaceAll('#', '').padLeft(6, '0');
    return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF00C8FF);
  }

  @override
  void initState() {
    super.initState();
    _titleCtrl =
        TextEditingController(text: widget.existing?.title ?? '');
    _descCtrl =
        TextEditingController(text: widget.existing?.description ?? '');
    _selectedColor = widget.existing?.color ?? '#00C8FF';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(
          begin: _toColor(_selectedColor),
          end: _toColor(_selectedColor),
        ),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        builder: (_, animColor, child) {
          final c = animColor ?? _toColor(_selectedColor);
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: SieTheme.borderDefault),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c.withValues(alpha: 0.08),
                  SieTheme.surface,
                ],
              ),
            ),
            child: child,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'EDIT PROTOCOL' : 'NEW PROTOCOL',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              _Field(controller: _titleCtrl, label: 'TITLE'),
              const SizedBox(height: 12),
              _Field(
                controller: _descCtrl,
                label: 'DESCRIPTION (OPTIONAL)',
              ),
              const SizedBox(height: 16),
              const Text(
                'COLOR',
                style: TextStyle(
                  color: SieTheme.textSecondary,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: _colorOptions.map((hex) {
                  final selected = hex == _selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _toColor(hex),
                        border: selected
                            ? Border.all(
                                color: SieTheme.textPrimary,
                                width: 2,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        color: SieTheme.textSecondary,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      final title = _titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      widget.onSave(
                        title,
                        _descCtrl.text.trim().isEmpty
                            ? null
                            : _descCtrl.text.trim(),
                        _selectedColor,
                      );
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      isEdit ? 'SAVE' : 'DEPLOY',
                      style: TextStyle(
                        color: _toColor(_selectedColor),
                        fontSize: 11,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                      ),
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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _Field({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        color: SieTheme.textPrimary,
        fontSize: 13,
        letterSpacing: 0.5,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: SieTheme.textSecondary,
          fontSize: 10,
          letterSpacing: 1.5,
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: SieTheme.borderDefault),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: SieTheme.accent),
        ),
      ),
    );
  }
}
