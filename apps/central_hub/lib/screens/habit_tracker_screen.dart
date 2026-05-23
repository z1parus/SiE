import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:sie_core/sie_core.dart';

// ── Design tokens ──────────────────────────────────────────────
const _kCyan = Color(0xFF00E5FF);

// ── Glass settings factory (mirrors leaderboard / ops screen) ──
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
    final habitsAsync = ref.watch(habitsProvider);
    final today      = _fmt(DateTime.now());
    final profile    = ref.watch(userProfileProvider).valueOrNull;
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
            onAdd:  () => _showHabitDialog(null),
            onInfo: () => setState(() => _showOnboardingManual = true),
          ),
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
                  return _EmptyState(onAdd: () => _showHabitDialog(null));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                  itemCount: state.habits.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    if (i == state.habits.length) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _AddButton(
                            onTap: () => _showHabitDialog(null),
                          ),
                        ),
                      );
                    }
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

    return GlassPage(
      background: const SieSpaceBackground(),
      statusBarStyle: GlassStatusBarStyle.light,
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

  // ── Dialogs (logic unchanged) ─────────────────────────────────

  void _showHabitDialog(Habit? existing) {
    showDialog<void>(
      context: context,
      builder: (_) => _HabitDialog(
        existing: existing,
        onSave: (title, description, color) {
          if (existing == null) {
            ref
                .read(habitsProvider.notifier)
                .addHabit(
                  title: title,
                  description: description,
                  color: color,
                )
                .then((awarded) {
              if (awarded && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: SieTheme.surface,
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
                              const Text(
                                'ПЕРВЫЙ ПРОТОКОЛ ДИСЦИПЛИНЫ',
                                style: TextStyle(
                                  color: SieTheme.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '+25 XP получено',
                                style: TextStyle(
                                  color: SieTheme.textSecondary,
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
                  _showHabitDialog(habit);
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
                  _confirmDelete(habit);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Habit habit) {
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

// ─────────────────────────────────────────────────────────────────────────────
// Cyberpunk Top Bar
// ─────────────────────────────────────────────────────────────────────────────
class _CyberTopBar extends StatelessWidget {
  const _CyberTopBar({required this.onAdd, required this.onInfo});
  final VoidCallback onAdd;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
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
                      const TextSpan(
                        text: 'HABIT ',
                        style: TextStyle(
                          color: _kCyan,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(color: _kCyan, blurRadius: 8),
                            Shadow(color: _kCyan, blurRadius: 22),
                          ],
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
                const Text(
                  'НЕЙРОННАЯ МАТРИЦА · АРХИВ ДИСЦИПЛИНЫ',
                  style: TextStyle(
                    color: SieTheme.textSecondary,
                    fontSize: 10,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
          _GlassIconBtn(
            icon: Icons.help_outline,
            onTap: onInfo,
            size: 18,
          ),
          const SizedBox(width: 8),
          _GlassIconBtn(
            icon: Icons.add,
            onTap: onAdd,
            color: _kCyan,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// Small glass circle button — matches leaderboard header buttons.
class _GlassIconBtn extends StatelessWidget {
  const _GlassIconBtn({
    required this.icon,
    required this.onTap,
    this.color,
    this.size = 16,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
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
        child: Center(
          child: Icon(
            icon,
            color: color ?? SieTheme.textSecondary,
            size: size,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Swipeable Habit Card (swipe logic unchanged — only inner widget replaced)
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
          final trigger   = _screenWidth * _triggerFraction;
          final progress  = (offset.abs() / trigger).clamp(0.0, 1.0);
          final isLeft    = offset < 0;
          final swiping   = progress > 0.01;

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
// Swipe Backgrounds (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _SwipePinBg extends StatelessWidget {
  final double progress;
  final bool isPinned;
  const _SwipePinBg({required this.progress, required this.isPinned});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            SieTheme.background,
            const Color(0xFFDAA520),
            SieTheme.background,
          ],
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

class _SwipeDeleteBg extends StatelessWidget {
  final double progress;
  const _SwipeDeleteBg({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            SieTheme.background,
            const Color(0xFF8B0000),
            SieTheme.background,
          ],
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
              child: const Icon(
                Icons.delete_outline,
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

// ─────────────────────────────────────────────────────────────────────────────
// Habit Matrix Card  ──  the core visual unit
// ─────────────────────────────────────────────────────────────────────────────
class _HabitMatrixCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final accentColor = _hexToColor(habit.color);
    final now  = DateTime.now();

    // Last 7 days ending today, oldest → newest.
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
            // ── Header: dot + title + pin indicator + streak badge ─
            Row(
              children: [
                // Accent energy dot
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.85),
                        blurRadius: 7,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    habit.title.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SieTheme.textPrimary,
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
                    color: SieTheme.textSecondary.withValues(alpha: 0.45),
                    size: 11,
                  ),
                ],
                if (streak > 0) ...[
                  const SizedBox(width: 8),
                  _StreakBadge(streak: streak, color: accentColor),
                ],
              ],
            ),

            // ── Optional description ───────────────────────────────
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
                    color: SieTheme.textSecondary.withValues(alpha: 0.7),
                    fontSize: 10.5,
                    letterSpacing: 0.3,
                    height: 1.2,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // ── 7-day sync header ─────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '7-DAY SYNC',
                  style: TextStyle(
                    color: SieTheme.textSecondary.withValues(alpha: 0.5),
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

            // ── Day node row ──────────────────────────────────────
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
// Day Node — individual tracking cell
// ─────────────────────────────────────────────────────────────────────────────
class _DayNode extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── The node circle ───────────────────────────────────────
        Container(
          width: 28,
          height: 28,
          decoration: isCompleted
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  // Solid energy node — fully charged
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
                  // Hollow ring — space starlight shows through
                  border: Border.all(
                    color: isToday
                        ? accentColor.withValues(alpha: 0.60)
                        : Colors.white.withValues(alpha: 0.13),
                    width: 1.5,
                  ),
                  color: isToday
                      ? accentColor.withValues(alpha: 0.07)
                      : Colors.transparent,
                ),
          child: isCompleted
              ? null
              : isToday
                  // Inner pulse dot — "awaiting activation"
                  ? Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: 0.80),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.50),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    )
                  : null,
        ),

        const SizedBox(height: 5),

        // ── Day-of-month label ────────────────────────────────────
        Text(
          '${date.day}',
          style: TextStyle(
            color: isCompleted
                ? accentColor.withValues(alpha: 0.90)
                : isToday
                    ? accentColor.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.22),
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
            Shadow(
              color: color.withValues(alpha: 0.55),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State — dormant matrix grid
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  // Lit node indices for the 5×5 diamond pattern (mirrors the carousel preview).
  static const _litNodes = {2, 6, 8, 10, 12, 14, 16, 18, 22};

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decorative dormant 5×5 matrix
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
                        ? _kCyan.withValues(alpha: 0.20)
                        : Colors.transparent,
                    border: Border.all(
                      color: lit
                          ? _kCyan.withValues(alpha: 0.40)
                          : Colors.white.withValues(alpha: 0.09),
                      width: 1.2,
                    ),
                    boxShadow: lit
                        ? [
                            BoxShadow(
                              color: _kCyan.withValues(alpha: 0.28),
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
              color: SieTheme.textSecondary.withValues(alpha: 0.50),
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
// Pulsing Add Button (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add / Edit Protocol Dialog (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
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
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: SieTheme.borderDefault),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      c.withValues(alpha: 0.10),
                      SieTheme.surface.withValues(alpha: 0.88),
                    ],
                  ),
                ),
                child: child,
              ),
            ),
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
