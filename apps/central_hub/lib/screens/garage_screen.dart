import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

import 'breathing_exercise_screen.dart';
import 'focus_protocol_screen.dart';
import 'habit_tracker_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GarageScreen — Introductory Bootcamp
// ─────────────────────────────────────────────────────────────────────────────

class GarageScreen extends ConsumerStatefulWidget {
  const GarageScreen({super.key, this.asTab = false});

  final bool asTab;

  @override
  ConsumerState<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends ConsumerState<GarageScreen> {
  /// Which day is currently displayed in the main content area.
  int? _selectedDay;

  /// On first load, snap _selectedDay to the progress activeDay.
  int _resolveSelectedDay(BootcampProgress p) {
    _selectedDay ??= p.activeDay.clamp(1, 7);
    return _selectedDay!;
  }

  /// Navigate to a tool screen; invalidate the activity provider on return
  /// so auto-completion status refreshes immediately.
  Future<void> _navigate(
      BuildContext ctx, BootcampTaskDestination dest) async {
    final Widget screen = switch (dest) {
      BootcampTaskDestination.breathing    => const BreathingExerciseScreen(),
      BootcampTaskDestination.focusForge   => const FocusProtocolScreen(),
      BootcampTaskDestination.habitArchive => const HabitTrackerScreen(),
    };
    final nav = Navigator.of(ctx);
    await nav.push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) ref.invalidate(bootcampDailyActivityProvider);
  }

  @override
  Widget build(BuildContext context) {
    final c            = ref.watch(sieColorsProvider);
    final progressAsync = ref.watch(bootcampProgressProvider);
    final activityAsync = ref.watch(bootcampDailyActivityProvider);

    final body = SafeArea(
      bottom: false,
      child: progressAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: c.accent, strokeWidth: 1.5,
          ),
        ),
        error: (e, _) => Center(
          child: Text(
            'СИСТЕМА НЕДОСТУПНА',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        data: (progress) {
          final selectedDay = _resolveSelectedDay(progress);
          final dayData     = kBootcampCourse[selectedDay - 1];
          final activity    = activityAsync.valueOrNull;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _GarageHeader(c: c, progress: progress),
              ),
              const SizedBox(height: 20),

              // ── Day Progress Pipeline ────────────────────────────────────
              _DayPipeline(
                progress: progress,
                selectedDay: selectedDay,
                onDayTap: (day) {
                  if (progress.isDayUnlocked(day)) {
                    setState(() => _selectedDay = day);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text(
                        'Завершите предыдущий день, чтобы разблокировать',
                      ),
                      duration: const Duration(seconds: 2),
                    ));
                  }
                },
                c: c,
              ),
              const SizedBox(height: 20),

              // ── Scrollable Day Content ───────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(bootcampProgressProvider);
                    ref.invalidate(bootcampDailyActivityProvider);
                    await ref.read(bootcampProgressProvider.future);
                  },
                  color: c.accent,
                  backgroundColor: c.isLightMode ? Colors.white : const Color(0xFF0D1B2A),
                  child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                  child: progress.courseComplete &&
                          selectedDay == progress.activeDay
                      ? _CourseCompletedView(c: c, progress: progress)
                      : _DayContent(
                          dayData: dayData,
                          progress: progress,
                          c: c,
                          isActiveDay: selectedDay == progress.activeDay,
                          activity: activity,
                          onNavigate: (dest) => _navigate(context, dest),
                          onClaimReward: () async {
                            final daysClaimed  = progress.claimedDays.length;
                            final act = activity ?? BootcampDailyActivity.empty;
                            final ok = await ref
                                .read(bootcampProgressProvider.notifier)
                                .claimDayReward(
                                    selectedDay, dayData.tasks, act);
                            if (!mounted) return;
                            if (ok) {
                              setState(() => _selectedDay = null);
                              _showRewardDialog(
                                  selectedDay, daysClaimed + 1 >= 7);
                            }
                          },
                        ),
                ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (widget.asTab) {
      return Scaffold(backgroundColor: Colors.transparent, body: body);
    }
    return SieBackground(
      child: Scaffold(backgroundColor: Colors.transparent, body: body),
    );
  }

  void _showRewardDialog(int day, bool courseComplete) {
    final c = ref.read(sieColorsProvider);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => _RewardDialog(
        day: day,
        courseComplete: courseComplete,
        c: c,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Garage Header
// ─────────────────────────────────────────────────────────────────────────────

class _GarageHeader extends StatelessWidget {
  final SieColors c;
  final BootcampProgress progress;

  const _GarageHeader({required this.c, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme          = Theme.of(context);
    final completedCount = progress.claimedDays.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'SiE ',
                style: TextStyle(
                  color: c.accent,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  shadows: null,
                ),
              ),
              TextSpan(
                text: 'GARAGE',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 3,
              height: 13,
              color: c.accent.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 8),
            Text(
              progress.courseComplete
                  ? 'ПРОТОКОЛ ЗАВЕРШЁН'
                  : 'ВВОДНЫЙ КУРС — ДЕНЬ $completedCount/7',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day Progress Pipeline
// ─────────────────────────────────────────────────────────────────────────────

class _DayPipeline extends StatelessWidget {
  final BootcampProgress progress;
  final int selectedDay;
  final ValueChanged<int> onDayTap;
  final SieColors c;

  const _DayPipeline({
    required this.progress,
    required this.selectedDay,
    required this.onDayTap,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 7,
        separatorBuilder: (_, _) => _PipelineConnector(c: c),
        itemBuilder: (_, i) {
          final day        = i + 1;
          final isCompleted = progress.isDayCompleted(day);
          final isActive    = day == progress.activeDay && !isCompleted;
          final isSelected  = day == selectedDay;
          final isUnlocked  = progress.isDayUnlocked(day);

          return _DayNode(
            day: day,
            isCompleted: isCompleted,
            isActive: isActive,
            isSelected: isSelected,
            isUnlocked: isUnlocked,
            c: c,
            onTap: () => onDayTap(day),
          );
        },
      ),
    );
  }
}

// ── Connector line between nodes ──────────────────────────────────────────────

class _PipelineConnector extends StatelessWidget {
  final SieColors c;
  const _PipelineConnector({required this.c});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: 18,
        height: 1.5,
        color: c.border,
      ),
    );
  }
}

// ── Individual day node ────────────────────────────────────────────────────────

class _DayNode extends StatefulWidget {
  final int day;
  final bool isCompleted;
  final bool isActive;
  final bool isSelected;
  final bool isUnlocked;
  final SieColors c;
  final VoidCallback onTap;

  const _DayNode({
    required this.day,
    required this.isCompleted,
    required this.isActive,
    required this.isSelected,
    required this.isUnlocked,
    required this.c,
    required this.onTap,
  });

  @override
  State<_DayNode> createState() => _DayNodeState();
}

class _DayNodeState extends State<_DayNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulse = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.isActive) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_DayNode old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.isActive && old.isActive) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;

    Color nodeColor;
    Widget nodeChild;

    if (widget.isCompleted) {
      nodeColor = c.accent;
      nodeChild = Icon(
        Icons.check,
        color: c.isLightMode ? Colors.white : const Color(0xFF0A0E1A),
        size: 14,
      );
    } else if (widget.isActive) {
      nodeColor = Colors.transparent;
      nodeChild = Text(
        '${widget.day}',
        style: TextStyle(
          color: c.accent,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          shadows: null,
        ),
      );
    } else if (widget.isUnlocked) {
      nodeColor = c.surface;
      nodeChild = Text(
        '${widget.day}',
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );
    } else {
      nodeColor = c.surface;
      nodeChild = Icon(
        Icons.lock_outline,
        color: c.border,
        size: 13,
      );
    }

    final nodeWidget = GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Pulse ring (active only)
              if (widget.isActive)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c.accent.withValues(alpha: _pulse.value * 0.6),
                      width: 1.5,
                    ),
                  ),
                ),
              // Main circle
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: nodeColor,
                  border: Border.all(
                    color: widget.isCompleted
                        ? c.accent
                        : widget.isActive
                            ? c.accent
                            : widget.isSelected
                                ? c.accent.withValues(alpha: 0.6)
                                : c.border,
                    width: 1.5,
                  ),
                  boxShadow: null,
                ),
                child: Center(child: nodeChild),
              ),
            ],
          );
        },
      ),
    );

    // Day label below
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 44, height: 44, child: nodeWidget),
        const SizedBox(height: 4),
        Text(
          'ДЕНЬ ${widget.day}',
          style: TextStyle(
            color: widget.isSelected ? c.accent : c.textSecondary,
            fontSize: 8,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day Content (Story Terminal + Tasks + Claim)
// ─────────────────────────────────────────────────────────────────────────────

class _DayContent extends StatelessWidget {
  final BootcampDay dayData;
  final BootcampProgress progress;
  final SieColors c;
  final bool isActiveDay;

  /// Real tool-usage snapshot for today; null while still loading.
  final BootcampDailyActivity? activity;

  final ValueChanged<BootcampTaskDestination> onNavigate;
  final VoidCallback onClaimReward;

  const _DayContent({
    required this.dayData,
    required this.progress,
    required this.c,
    required this.isActiveDay,
    required this.onNavigate,
    required this.onClaimReward,
    this.activity,
  });

  @override
  Widget build(BuildContext context) {
    final act        = activity ?? BootcampDailyActivity.empty;
    final day        = dayData.dayNumber;
    final isCompleted = progress.isDayCompleted(day);
    final isLocked   = !progress.isDayUnlocked(day);
    final canClaim   = isActiveDay &&
        !isCompleted &&
        progress.canClaimDay(day, dayData.tasks, act);
    final isDayLocked = !isCompleted &&
        !isLocked &&
        progress.isDayLockedUntilTomorrow(day);

    final completedCount =
        dayData.tasks.where((t) => t.isAutoComplete(act)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Story Terminal ─────────────────────────────────────────────────
        _StoryTerminal(dayData: dayData, c: c, isLocked: isLocked),
        const SizedBox(height: 14),

        // ── Tasks Section Header ───────────────────────────────────────────
        Row(
          children: [
            Container(width: 3, height: 12, color: c.accent),
            const SizedBox(width: 8),
            Text(
              'ОПЕРАТИВНЫЕ ЗАДАЧИ',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
            const Spacer(),
            if (!isLocked) ...[
              Text(
                '$completedCount/${dayData.tasks.length}',
                style: TextStyle(
                  color: isCompleted ? c.accent : c.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        // ── Task Cards ────────────────────────────────────────────────────
        if (isLocked)
          _LockedDayCard(c: c)
        else ...[
          ...dayData.tasks.map((task) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TaskCard(
                  task: task,
                  isDone: task.isAutoComplete(act),
                  isLaunchable: isActiveDay && !isCompleted,
                  c: c,
                  onNavigate: () => onNavigate(task.destination),
                ),
              )),

          // ── Status / CTA ────────────────────────────────────────────────
          if (isCompleted)
            _CompletedBadge(c: c)
          else if (isDayLocked) ...[
            const SizedBox(height: 6),
            _DayLockBanner(c: c),
          ] else if (canClaim) ...[
            const SizedBox(height: 6),
            _ClaimButton(c: c, onClaim: onClaimReward),
          ],
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Story Terminal
// ─────────────────────────────────────────────────────────────────────────────

class _StoryTerminal extends StatelessWidget {
  final BootcampDay dayData;
  final SieColors c;
  final bool isLocked;

  const _StoryTerminal({
    required this.dayData,
    required this.c,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final accentAlpha = 0.07;

    return SieGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Terminal header
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accent,
                  boxShadow: null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dayData.title,
                  style: TextStyle(
                    color: c.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    shadows: null,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: accentAlpha),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: c.accent.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  'ДЕНЬ ${dayData.dayNumber}',
                  style: TextStyle(
                    color: c.accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: c.border, height: 1),
          const SizedBox(height: 12),

          // Story text (blurred if locked)
          isLocked
              ? _LockedTransmissionText(c: c)
              : Text(
                  dayData.storyTransmission,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    height: 1.65,
                    letterSpacing: 0.3,
                  ),
                ),
        ],
      ),
    );
  }
}

class _LockedTransmissionText extends StatelessWidget {
  final SieColors c;
  const _LockedTransmissionText({required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, color: c.border, size: 14),
            const SizedBox(width: 8),
            Text(
              'СЕКРЕТНО',
              style: TextStyle(
                color: c.border,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Завершите предыдущий протокол для получения доступа\nк этой трансмиссии.',
          style: TextStyle(
            color: c.border,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task Card
// ─────────────────────────────────────────────────────────────────────────────

class _TaskCard extends StatefulWidget {
  final BootcampTask task;

  /// True when today's real tool usage already satisfies this task.
  final bool isDone;

  /// True when this is the active (not yet claimed) day — show launch button.
  final bool isLaunchable;

  final SieColors c;
  final VoidCallback onNavigate;

  const _TaskCard({
    required this.task,
    required this.isDone,
    required this.isLaunchable,
    required this.c,
    required this.onNavigate,
  });

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync: this, value: 0);
    _pressAnim =
        CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  String get _destinationLabel => switch (widget.task.destination) {
        BootcampTaskDestination.breathing    => 'ДЫХАНИЕ',
        BootcampTaskDestination.focusForge   => 'FOCUS FORGE',
        BootcampTaskDestination.habitArchive => 'ПРИВЫЧКИ',
      };

  @override
  Widget build(BuildContext context) {
    final c      = widget.c;
    final isDone = widget.isDone;

    return SieGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Task icon ──────────────────────────────────────────────────
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isDone
                  ? c.accent.withValues(alpha: 0.15)
                  : c.accent.withValues(alpha: 0.07),
              border: Border.all(
                color: isDone
                    ? c.accent.withValues(alpha: 0.4)
                    : c.border,
                width: 0.8,
              ),
            ),
            child: Icon(
              widget.task.icon,
              color: isDone ? c.accent : c.textSecondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),

          // ── Title, description, launch button ──────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.task.title,
                  style: TextStyle(
                    color: isDone ? c.textSecondary : c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.task.description,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),

                // Launch button — always visible when day is active
                if (widget.isLaunchable) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTapDown: (_) => _pressCtrl.animateTo(1.0,
                        duration: const Duration(milliseconds: 80)),
                    onTapUp: (_) {
                      _pressCtrl.animateTo(0.0,
                          duration: const Duration(milliseconds: 200));
                      widget.onNavigate();
                    },
                    onTapCancel: () => _pressCtrl.animateTo(0.0,
                        duration: const Duration(milliseconds: 200)),
                    child: AnimatedBuilder(
                      animation: _pressAnim,
                      builder: (_, child) => Transform.scale(
                        scale: 1.0 - 0.03 * _pressAnim.value,
                        child: child,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: c.accent.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'ЗАПУСТИТЬ → $_destinationLabel',
                          style: TextStyle(
                            color: c.accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Done indicator ─────────────────────────────────────────────
          if (isDone) ...[
            const SizedBox(width: 10),
            Icon(Icons.check_circle, color: c.accent, size: 20),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Locked Day placeholder card
// ─────────────────────────────────────────────────────────────────────────────

class _LockedDayCard extends StatelessWidget {
  final SieColors c;
  const _LockedDayCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return SieGlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, color: c.border, size: 18),
          const SizedBox(width: 10),
          Text(
            'ЗАВЕРШИТЕ ПРЕДЫДУЩИЙ ДЕНЬ',
            style: TextStyle(
              color: c.border,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day Lock Banner — shown when previous day was claimed today
// ─────────────────────────────────────────────────────────────────────────────

class _DayLockBanner extends StatelessWidget {
  final SieColors c;
  const _DayLockBanner({required this.c});

  @override
  Widget build(BuildContext context) {
    const lockColor = Color(0xFFFF9800); // amber

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: lockColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: lockColor.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_clock_outlined,
              color: lockColor.withValues(alpha: 0.8), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'СЛЕДУЮЩИЙ ДЕНЬ ОТКРОЕТСЯ ЗАВТРА',
                  style: TextStyle(
                    color: lockColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Вы закрыли предыдущий день сегодня. Возвращайтесь завтра.',
                  style: TextStyle(
                    color: lockColor.withValues(alpha: 0.7),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Completed Badge (shown when day is already claimed)
// ─────────────────────────────────────────────────────────────────────────────

class _CompletedBadge extends StatelessWidget {
  final SieColors c;
  const _CompletedBadge({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_outlined, color: c.accent, size: 16),
          const SizedBox(width: 10),
          Text(
            'ДЕНЬ ЗАВЕРШЁН · +1000 DP ПОЛУЧЕНО',
            style: TextStyle(
              color: c.accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Claim Reward Button
// ─────────────────────────────────────────────────────────────────────────────

class _ClaimButton extends StatefulWidget {
  final SieColors c;
  final VoidCallback onClaim;
  const _ClaimButton({required this.c, required this.onClaim});

  @override
  State<_ClaimButton> createState() => _ClaimButtonState();
}

class _ClaimButtonState extends State<_ClaimButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimCtrl;
  late final Animation<double> _shimAnim;

  @override
  void initState() {
    super.initState();
    _shimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _shimAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _shimCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;

    return AnimatedBuilder(
      animation: _shimAnim,
      builder: (_, child) => GestureDetector(
        onTap: widget.onClaim,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: c.accent.withValues(alpha: _shimAnim.value * 0.9),
              width: 1.5,
            ),
            color: c.accent.withValues(alpha: 0.08),
            boxShadow: null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '✦  ПОЛУЧИТЬ НАГРАДУ  ✦',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                  shadows: null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '+ 1 000 DP DESIGN POINTS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.dp,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
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
// Course Completed View
// ─────────────────────────────────────────────────────────────────────────────

class _CourseCompletedView extends StatefulWidget {
  final SieColors c;
  final BootcampProgress progress;

  const _CourseCompletedView(
      {required this.c, required this.progress});

  @override
  State<_CourseCompletedView> createState() =>
      _CourseCompletedViewState();
}

class _CourseCompletedViewState extends State<_CourseCompletedView>
    with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final AnimationController _glowCtrl;
  late final Animation<double> _fade;
  late final Animation<double> _slide;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _fade  = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slide = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut),
    );
    _glow = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;

    return AnimatedBuilder(
      animation: _enterCtrl,
      builder: (_, child) => FadeTransition(
        opacity: _fade,
        child: Transform.translate(
          offset: Offset(0, _slide.value),
          child: child,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),

          // Badge glow container
          AnimatedBuilder(
            animation: _glow,
            builder: (_, _) => Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.dp.withValues(alpha: 0.08),
                border: Border.all(
                  color: c.dp.withValues(alpha: _glow.value * 0.7),
                  width: 1.5,
                ),
                boxShadow: null,
              ),
              child: const Center(
                child: Text('🛡️', style: TextStyle(fontSize: 48)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Badge name
          Text(
            'ИСПЫТАТЕЛЬ',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.dp,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 4.0,
              shadows: null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ЛЕГЕНДАРНЫЙ ЗНАЧОК',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.0,
            ),
          ),
          const SizedBox(height: 24),

          // Divider
          Container(height: 1, color: c.border),
          const SizedBox(height: 20),

          // Achievement description
          SieGlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 3, height: 14, color: c.dp),
                    const SizedBox(width: 10),
                    Text(
                      'СЕРТИФИКАТ КОРПОРАЦИИ SiE',
                      style: TextStyle(
                        color: c.dp,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Вы успешно завершили 7-дневный вводный протокол Корпорации SiE. '
                  'Базовый стек инструментов саморазвития освоен и интегрирован '
                  'в ваш ежедневный рабочий процесс.',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: c.border, height: 1),
                const SizedBox(height: 14),
                _StatRow(
                  label: 'ДНЕЙ ЗАВЕРШЕНО',
                  value: '7 / 7',
                  c: c,
                  useAccent: false,
                ),
                const SizedBox(height: 10),
                _StatRow(
                  label: 'ПОЛУЧЕНО DP',
                  value: '7 000',
                  c: c,
                  useAccent: true,
                ),
                const SizedBox(height: 10),
                _StatRow(
                  label: 'СТАТУС',
                  value: 'CERTIFIED',
                  c: c,
                  useAccent: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Следите за обновлениями — новые курсы\nи вызовы скоро появятся в Garage.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
              height: 1.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final SieColors c;
  final bool useAccent;

  const _StatRow({
    required this.label,
    required this.value,
    required this.c,
    required this.useAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: useAccent ? c.dp : c.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reward Dialog (shown after claiming a day)
// ─────────────────────────────────────────────────────────────────────────────

class _RewardDialog extends StatefulWidget {
  final int day;
  final bool courseComplete;
  final SieColors c;

  const _RewardDialog({
    required this.day,
    required this.courseComplete,
    required this.c,
  });

  @override
  State<_RewardDialog> createState() => _RewardDialogState();
}

class _RewardDialogState extends State<_RewardDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => FadeTransition(
          opacity: _fade,
          child: Transform.scale(scale: _scale.value, child: child),
        ),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: c.dp.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: c.isLightMode
                ? const [
                    BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 16,
                        offset: Offset(0, 4)),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.courseComplete ? '🛡️' : '⚡',
                style: const TextStyle(fontSize: 40),
              ),
              const SizedBox(height: 16),
              Text(
                widget.courseComplete
                    ? 'ПРОТОКОЛ ЗАВЕРШЁН!'
                    : 'ДЕНЬ ${widget.day} ЗАКРЫТ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.dp,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.courseComplete
                    ? 'Значок «Испытатель» разблокирован!\nВы в верхних 10%.'
                    : '+1 000 Design Points начислено\nСледующий день разблокирован.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: c.dp.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: c.dp.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    'ПРОДОЛЖИТЬ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.dp,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
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
