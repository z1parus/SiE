import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:sie_core/sie_core.dart';

LiquidGlassSettings _glassSettings({
  double blur = 3.0,
  double glowIntensity = 0.88,
}) =>
    LiquidGlassSettings(
      blur: blur,
      thickness: 24,
      refractiveIndex: 1.45,
      glassColor: const Color(0x0A0A0E1A),
      lightAngle: GlassDefaults.lightAngle,
      lightIntensity: 0.72,
      glowIntensity: glowIntensity,
      saturation: 1.4,
      specularSharpness: GlassSpecularSharpness.sharp,
      ambientStrength: 0.08,
      chromaticAberration: 0.015,
    );

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

  static String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final sc           = ref.watch(sieColorsProvider);
    final habitsAsync  = ref.watch(habitsProvider);
    final today        = _fmt(DateTime.now());
    final profile      = ref.watch(userProfileProvider).valueOrNull;
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
          Expanded(
            child: habitsAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: sc.accent,
                  strokeWidth: 1.5,
                ),
              ),
              error: (e, _) => const Center(child: _NoConnectionMessage()),
              data: (state) {
                if (state.habits.isEmpty) {
                  return _EmptyState(onAdd: () => _showHabitDialog(null));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  itemCount: state.habits.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final habit    = state.habits[i];
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
                      onLongPress: () => _showHabitOptions(habit),
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
        floatingActionButton: Consumer(
          builder: (context, ref, _) {
            final sc2 = ref.watch(sieColorsProvider);
            return FloatingActionButton(
              onPressed: () => _showHabitDialog(null),
              backgroundColor: sc2.accent,
              foregroundColor: Colors.black,
              elevation: 4,
              child: const Icon(Icons.add),
            );
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
        onSave: (title, description, color) {
          if (existing == null) {
            ref
                .read(habitsProvider.notifier)
                .addHabit(title: title, description: description, color: color)
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
                );
          }
        },
      ),
    );
  }

  void _showHabitOptions(Habit habit) {
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
                    sc.isCosmicMode
                        ? const Color(0xFF0A0E1A).withValues(alpha: 0.92)
                        : sc.surface,
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
                      habit.title.toUpperCase(),
                      style: TextStyle(
                        color: sc.textSecondary.withValues(alpha: 0.80),
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  Divider(color: sc.accent.withValues(alpha: 0.15), height: 1),
                  _OptionTile(
                    icon: Icons.edit_outlined,
                    label: 'EDIT PROTOCOL',
                    color: sc.textPrimary,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showHabitDialog(habit);
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
                          .archiveHabit(habit.id);
                    },
                  ),
                  _OptionTile(
                    icon: Icons.delete_outline,
                    label: 'DELETE PROTOCOL',
                    color: Colors.redAccent,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _confirmDelete(habit);
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

  void _confirmDelete(Habit habit) {
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
                    sc.isCosmicMode
                        ? const Color(0xFF0A0E1A).withValues(alpha: 0.92)
                        : sc.surface,
                  ],
                ),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.35),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                    'Delete "${habit.title}"? All log history will be erased.',
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
                              .deleteHabit(habit.id);
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
                          shadows: sc.isCosmicMode
                              ? [
                                  Shadow(color: sc.accent, blurRadius: 8),
                                  Shadow(color: sc.accent, blurRadius: 22),
                                ]
                              : null,
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

    if (sc.isCosmicMode) {
      return GestureDetector(
        onTap: onTap,
        child: GlassCard(
          width: 36,
          height: 36,
          padding: EdgeInsets.zero,
          shape: LiquidRoundedSuperellipse(borderRadius: 18),
          useOwnLayer: true,
          quality: GlassQuality.standard,
          clipBehavior: Clip.antiAlias,
          settings: _glassSettings(blur: 2.0, glowIntensity: 0.85),
          child: child,
        ),
      );
    }

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
// Swipeable Habit Card
// ─────────────────────────────────────────────────────────────────────────────
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
                    allLogDates: widget.allLogDates,
                    onToggle: widget.onToggle,
                    onLongPress: widget.onLongPress,
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
  final Set<String> allLogDates;
  final VoidCallback onToggle;
  final VoidCallback? onLongPress;

  const _HabitMatrixCard({
    required this.habit,
    required this.completedToday,
    required this.streak,
    required this.allLogDates,
    required this.onToggle,
    this.onLongPress,
  });

  static Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '').padLeft(6, '0');
    return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF00C8FF);
  }

  static String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc          = ref.watch(sieColorsProvider);
    final accentColor = _hexToColor(habit.color);
    final now         = DateTime.now();

    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final logsThisWeek =
        days.where((d) => allLogDates.contains(_fmtDate(d))).length;

    return SieGlassCard(
      onTap: onToggle,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: GestureDetector(
        onLongPress: onLongPress,
        behavior: HitTestBehavior.translucent,
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
                    color: accentColor,
                    boxShadow: sc.isCosmicMode
                        ? [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.85),
                              blurRadius: 7,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
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
                if (streak > 0) ...[
                  const SizedBox(width: 8),
                  _StreakBadge(streak: streak, color: accentColor),
                ],
              ],
            ),
            if (habit.description != null &&
                habit.description!.isNotEmpty) ...[
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
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '7-DAY SYNC',
                  style: TextStyle(
                    color: sc.textSecondary.withValues(alpha: 0.5),
                    fontSize: 9,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$logsThisWeek / 7',
                  style: TextStyle(
                    color: accentColor.withValues(alpha: 0.85),
                    fontSize: 9,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: days.asMap().entries.map((e) {
                final isToday     = e.key == 6;
                final isCompleted = allLogDates.contains(_fmtDate(e.value));
                return _DayNode(
                  date: e.value,
                  isCompleted: isCompleted,
                  isToday: isToday,
                  accentColor: accentColor,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
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
                        : (sc.isCosmicMode
                            ? Colors.white.withValues(alpha: 0.13)
                            : sc.border),
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
                          boxShadow: sc.isCosmicMode
                              ? [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.50),
                                    blurRadius: 5,
                                  ),
                                ]
                              : null,
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
                    : (sc.isCosmicMode
                        ? Colors.white.withValues(alpha: 0.22)
                        : sc.textSecondary.withValues(alpha: 0.4)),
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
                          : (sc.isCosmicMode
                              ? Colors.white.withValues(alpha: 0.09)
                              : sc.border),
                      width: 1.2,
                    ),
                    boxShadow: lit && sc.isCosmicMode
                        ? [
                            BoxShadow(
                              color: sc.accent.withValues(alpha: 0.28),
                              blurRadius: 7,
                            ),
                          ]
                        : null,
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
          const SizedBox(height: 32),
          _AddButton(onTap: onAdd),
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
  final void Function(String title, String? description, String color) onSave;

  const _HabitDialog({this.existing, required this.onSave});

  @override
  ConsumerState<_HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends ConsumerState<_HabitDialog> {
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
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _descCtrl  = TextEditingController(text: widget.existing?.description ?? '');
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
    final sc     = ref.watch(sieColorsProvider);
    final isEdit = widget.existing != null;
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        begin: _toColor(_selectedColor),
        end: _toColor(_selectedColor),
      ),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      builder: (_, animColor, child) {
        final habitColor = animColor ?? _toColor(_selectedColor);
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
            child: Container(
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    habitColor.withValues(alpha: 0.08),
                    sc.isCosmicMode
                        ? const Color(0xFF0A0E1A).withValues(alpha: 0.92)
                        : sc.surface,
                  ],
                ),
                border: Border(
                  top: BorderSide(
                    color: habitColor.withValues(alpha: 0.50),
                    width: 1.0,
                  ),
                  left: BorderSide(
                    color: habitColor.withValues(alpha: 0.18),
                    width: 1.0,
                  ),
                  right: BorderSide(
                    color: habitColor.withValues(alpha: 0.18),
                    width: 1.0,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: habitColor.withValues(alpha: 0.12),
                    blurRadius: 40,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(24, 14, 24, 20 + keyboardBottom),
              child: child,
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Text(
            isEdit ? 'EDIT PROTOCOL' : 'NEW PROTOCOL',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          _GlowField(controller: _titleCtrl, label: 'TITLE'),
          const SizedBox(height: 8),
          _GlowField(
              controller: _descCtrl,
              label: 'DESCRIPTION (OPTIONAL)'),
          const SizedBox(height: 10),
          Consumer(builder: (_, ref2, _) {
            final sc2 = ref2.watch(sieColorsProvider);
            return Text(
              'COLOR',
              style: TextStyle(
                color: sc2.textSecondary,
                fontSize: 10,
                letterSpacing: 1.5,
              ),
            );
          }),
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
          const SizedBox(height: 16),
          Consumer(builder: (_, ref2, _) {
            final sc2 = ref2.watch(sieColorsProvider);
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _SheetTextBtn(
                  label: 'CANCEL',
                  color: sc2.textSecondary,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
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
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          }),
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

class _ColorLens extends StatefulWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ColorLens({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ColorLens> createState() => _ColorLensState();
}

class _ColorLensState extends State<_ColorLens> {
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
        child: Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.selected
                ? widget.color
                : widget.color.withValues(alpha: 0.40),
            border: widget.selected
                ? Border.all(color: Colors.white, width: 2)
                : Border.all(
                    color: widget.color.withValues(alpha: 0.50),
                    width: 1,
                  ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.65),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.30),
                      blurRadius: 20,
                    ),
                  ]
                : null,
          ),
        ),
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
                                    shadows: sc.isCosmicMode
                                        ? [
                                            Shadow(
                                                color: sc.accent,
                                                blurRadius: 8),
                                            Shadow(
                                                color: sc.accent,
                                                blurRadius: 22),
                                          ]
                                        : null,
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
                  error: (_, _) => const Center(
                    child: _NoConnectionMessage(),
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

class _ArchivedHabitCard extends ConsumerWidget {
  final Habit habit;
  final VoidCallback onRestore;

  const _ArchivedHabitCard({required this.habit, required this.onRestore});

  Color _toColor(String hex) {
    final h = hex.replaceAll('#', '').padLeft(6, '0');
    return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF00C8FF);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc         = ref.watch(sieColorsProvider);
    final habitColor = _toColor(habit.color);

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
                sc.isCosmicMode
                    ? const Color(0xFF0A0E1A).withValues(alpha: 0.85)
                    : sc.surface,
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
                  boxShadow: sc.isCosmicMode
                      ? [
                          BoxShadow(
                            color: habitColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                          )
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title.toUpperCase(),
                      style: TextStyle(
                        color: sc.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (habit.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        habit.description!,
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
                onTap: onRestore,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: sc.accent.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ВОССТАНОВИТЬ',
                    style: TextStyle(
                      color: sc.accent,
                      fontSize: 9,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
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
  const _NoConnectionMessage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi_off_outlined, color: sc.iconMuted, size: 36),
        const SizedBox(height: 12),
        Text(
          'Подключение к интернету отсутствует',
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
