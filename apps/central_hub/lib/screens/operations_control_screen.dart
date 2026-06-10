import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

import 'breathing_exercise_screen.dart';
import 'focus_protocol_screen.dart';
import 'habit_tracker_screen.dart';
import 'leaderboard_screen.dart';
import 'planning_screen.dart';
import 'profile_screen.dart';
import 'public_profile_screen.dart';
import 'user_search_screen.dart';

const _kOrange = Color(0xFFFF8C42);

// ─────────────────────────────────────────────────────────────────────────────
// OperationsControlScreen
// ─────────────────────────────────────────────────────────────────────────────
class OperationsControlScreen extends ConsumerStatefulWidget {
  const OperationsControlScreen({super.key, this.asTab = false});

  final bool asTab;

  @override
  ConsumerState<OperationsControlScreen> createState() =>
      _OperationsControlScreenState();
}

class _OperationsControlScreenState
    extends ConsumerState<OperationsControlScreen> {
  bool _welcomeShown = false;

  @override
  Widget build(BuildContext context) {
    final c              = ref.watch(sieColorsProvider);
    final branchesAsync  = ref.watch(branchesProvider);
    final profileAsync   = ref.watch(userProfileProvider);

    ref.listen<AsyncValue<Profile?>>(userProfileProvider, (_, next) {
      if (_welcomeShown) return;
      final profile = next.valueOrNull;
      if (profile == null) return;
      _welcomeShown = true;
      if (!profile.hasSeenWelcome) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showWelcomeModal(profile);
        });
      }
    });

    final body = SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            child: _ScreenHeader(profileAsync: profileAsync),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'DEPARTMENTS'),
                const SizedBox(height: 12),
                _LeaderboardTile(),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Expanded(
            child: branchesAsync.when(
              data: (branches) {
                final filtered = branches
                    .where((b) => b.slug != 'progress_hub')
                    .toList();
                return filtered.isEmpty
                    ? Center(
                        child: Text(
                          'NO DEPARTMENTS AVAILABLE',
                          style: TextStyle(
                            color: c.textSecondary,
                            letterSpacing: 1.5,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : _BranchCarousel(
                        branches: filtered,
                        onBranchTap: (b) => _onBranchTap(context, b),
                      );
              },
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: c.accent,
                  strokeWidth: 1.5,
                ),
              ),
              error: (e, _) => const Center(
                child: _NoConnectionMessage(),
              ),
            ),
          ),
          Builder(
            builder: (context) {
              final bottomInset = MediaQuery.of(context).padding.bottom;
              return SizedBox(height: 68 + math.max(bottomInset, 16) + 16);
            },
          ),
        ],
      ),
    );

    if (widget.asTab) {
      return Scaffold(backgroundColor: Colors.transparent, body: body);
    }

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            body,
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _FloatingNavBar(),
            ),
          ],
        ),
      ),
    );
  }

  void _showWelcomeModal(Profile profile) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => _WelcomeDialog(
        profile: profile,
        onAccept: () => markWelcomeSeen(profile.id),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Welcome Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _WelcomeDialog extends ConsumerStatefulWidget {
  final Profile profile;
  final VoidCallback onAccept;

  const _WelcomeDialog({required this.profile, required this.onAccept});

  @override
  ConsumerState<_WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends ConsumerState<_WelcomeDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c    = ref.watch(sieColorsProvider);
    final name = widget.profile.username?.toUpperCase() ?? 'OPERATIVE';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => FadeTransition(
          opacity: _fade,
          child: Transform.translate(
            offset: Offset(0, _slide.value),
            child: child,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.accent.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(4),
            boxShadow: c.isLightMode
                ? const [
                    BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 12,
                        offset: Offset(0, 2))
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 3, height: 16, color: c.accent),
                  const SizedBox(width: 10),
                  Text(
                    'ВХОДЯЩЕЕ СООБЩЕНИЕ',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 2.5,
                          color: c.accent,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'ДОБРО ПОЖАЛОВАТЬ,\nОПЕРАТИВНИК $name',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 19,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 16),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 16),
              Text(
                'Вы успешно вошли в систему Корпорации SiE. Все протоколы '
                'активированы. Выполняйте задания, фиксируйте прогресс '
                'и получайте опыт.\n\nМиссия начинается сейчас.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () {
                    widget.onAccept();
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.1),
                      border: Border.all(color: c.accent),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      'ПРИНЯТЬ ЗАДАНИЕ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.5,
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

// ─────────────────────────────────────────────────────────────────────────────
// Branch navigation
// ─────────────────────────────────────────────────────────────────────────────
void _onBranchTap(BuildContext context, Branch branch) {
  Widget? screen;

  if (branch.slug == 'breathing_practices') {
    screen = const BreathingExerciseScreen();
  } else if (branch.slug == 'habit_archive') {
    screen = const HabitTrackerScreen();
  } else if (branch.slug == 'focus_protocol') {
    screen = const FocusProtocolScreen();
  } else if (branch.slug == 'planning') {
    screen = const PlanningScreen();
  }

  if (screen != null) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen!),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Department initialising...'),
      duration: Duration(seconds: 2),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating Bottom Navigation Bar
// ─────────────────────────────────────────────────────────────────────────────
class _FloatingNavBar extends ConsumerWidget {
  const _FloatingNavBar();

  static const _items = [
    (icon: Icons.language_outlined,    label: 'Hub'),
    (icon: Icons.my_location_outlined, label: 'Operations'),
    (icon: Icons.shield_outlined,      label: 'Garage'),
    (icon: Icons.star_outline,         label: 'Hall of Fame'),
  ];

  static const _activeIndex = 1;

  void _onItemTap(BuildContext context, int index) {
    final nav = Navigator.of(context);
    // Prevent stacking the same route on rapid taps
    if (nav.canPop()) {
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
    }
    switch (index) {
      case 0:
        nav.push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
      case 3:
        nav.push(MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Module initialising...'),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c           = ref.watch(sieColorsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final navContent = Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(_items.length, (i) {
        final item = _items[i];
        return _NavItem(
          icon: item.icon,
          label: item.label,
          isActive: i == _activeIndex,
          activeColor: c.accent,
          inactiveColor: c.iconMuted,
          onTap: () => _onItemTap(context, i),
        );
      }),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, math.max(bottomInset, 16)),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: c.border),
        ),
        child: navContent,
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        height: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isActive)
              Container(
                width: 28,
                height: 2,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              )
            else
              const SizedBox(height: 6),
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leaderboard Tile
// ─────────────────────────────────────────────────────────────────────────────
class _LeaderboardTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SieGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'СУТОЧНЫЙ АВАНГАРД',
                  style: TextStyle(
                    color: _kOrange,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Рейтинг активности за текущий цикл',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: _kOrange, size: 18),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Branch Horizontal Carousel
// ─────────────────────────────────────────────────────────────────────────────
class _BranchCarousel extends StatelessWidget {
  final List<Branch> branches;
  final void Function(Branch) onBranchTap;

  const _BranchCarousel({
    required this.branches,
    required this.onBranchTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.78),
        physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: branches.length,
        itemBuilder: (context, index) {
          final branch = branches[index];
          return RepaintBoundary(
            child: _BranchCarouselCard(
              branch: branch,
              onTap: () => onBranchTap(branch),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Branch Carousel Card
// ─────────────────────────────────────────────────────────────────────────────
class _BranchCarouselCard extends ConsumerWidget {
  final Branch branch;
  final VoidCallback onTap;

  const _BranchCarouselCard({
    required this.branch,
    required this.onTap,
  });

  Widget _preview() {
    return switch (branch.slug) {
      'breathing_practices' => const _BreathSpherePreview(),
      'habit_archive'       => const _HabitMatrixPreview(),
      'focus_protocol'      => const _FocusRingPreview(),
      'planning'            => const _PlanningPreview(),
      _                     => const SizedBox.shrink(),
    };
  }

  String _statusLabel(WidgetRef ref) {
    switch (branch.slug) {
      case 'habit_archive':
        final habitsState = ref.watch(habitsProvider).valueOrNull;
        final count = habitsState?.habits.length ?? 0;
        return '$count Active';
      case 'focus_protocol':
        final focus = ref.watch(focusTimerProvider);
        return '${focus.settings.workMinutes} min';
      case 'breathing_practices':
        return 'PROTOCOL READY';
      case 'planning':
        final planningState = ref.watch(planningProvider).valueOrNull;
        final count = planningState?.activeGoals.length ?? 0;
        return '$count ${count == 1 ? 'Mission' : 'Missions'}';
      default:
        return 'ACTIVE';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c     = ref.watch(sieColorsProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SieGlassCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                child: _preview(),
              ),
            ),
            Container(
              height: 1,
              color: c.border,
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      branch.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 14,
                        letterSpacing: 1.8,
                        height: 1.1,
                        shadows: c.isLightMode
                            ? null
                            : const [Shadow(color: Color(0x99000000), blurRadius: 6)],
                      ),
                    ),
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
                        Text(
                          _statusLabel(ref),
                          style: TextStyle(
                            color: c.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            height: 1.1,
                            shadows: null,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right,
                          color: c.accent,
                          size: 16,
                        ),
                      ],
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Branch preview widgets
// ─────────────────────────────────────────────────────────────────────────────

class _BreathSpherePreview extends ConsumerStatefulWidget {
  const _BreathSpherePreview();

  @override
  ConsumerState<_BreathSpherePreview> createState() =>
      _BreathSpherePreviewState();
}

class _BreathSpherePreviewState extends ConsumerState<_BreathSpherePreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.82, end: 1.0).animate(
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
    final c = ref.watch(sieColorsProvider);
    return Center(
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, _) => Transform.scale(
          scale: _scale.value,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: c.isLightMode
                  ? RadialGradient(
                      colors: [
                        Colors.white,
                        const Color(0xFFB8E8E2),
                        c.accent,
                        c.surface,
                      ],
                      stops: const [0.0, 0.28, 0.65, 1.0],
                    )
                  : const RadialGradient(
                      colors: [
                        Color(0xFFCCF8FF),
                        Color(0xFF00E5FF),
                        Color(0xFF7000FF),
                        Color(0x007000FF),
                      ],
                      stops: [0.0, 0.28, 0.68, 1.0],
                    ),
              boxShadow: [
                BoxShadow(
                  color: c.accent.withValues(alpha: c.isLightMode ? 0.15 : 0.20),
                  blurRadius: 20,
                  spreadRadius: c.isLightMode ? 2 : 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HabitMatrixPreview extends ConsumerWidget {
  const _HabitMatrixPreview();

  static const _lit = {
    (0, 2),
    (1, 1), (1, 3),
    (2, 0), (2, 2), (2, 4),
    (3, 1), (3, 3),
    (4, 2),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (col) {
                final glow = _lit.contains((row, col));
                return Container(
                  width: 11,
                  height: 11,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: glow ? c.accent : c.border,
                    boxShadow: null,
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}

class _FocusRingPreview extends ConsumerWidget {
  const _FocusRingPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Center(
      child: SizedBox(
        width: 140,
        height: 140,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(140, 140),
              painter: _ArcPainter(
                progress: 0.65,
                trackColor: c.border,
                arcStart: c.accent,
                arcEnd: c.accentSecondary,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '15:00',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'FOCUS',
                  style: TextStyle(
                    color: c.iconMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanningPreview extends StatelessWidget {
  const _PlanningPreview();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PlanningPreviewPainter(),
    );
  }
}

class _PlanningPreviewPainter extends CustomPainter {
  static const _teal = Color(0xFF5AADA0);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);

    // Concentric arc rings
    final rings = [
      (28.0, 0.75, 0.9),
      (44.0, 0.45, 0.6),
      (60.0, 0.25, 0.35),
    ];

    for (final (r, fill, alpha) in rings) {
      final trackPaint = Paint()
        ..color = _teal.withValues(alpha: 0.12)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke;
      final arcPaint = Paint()
        ..color = _teal.withValues(alpha: alpha)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: center, radius: r);
      canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);
      canvas.drawArc(
          rect, -math.pi / 2, math.pi * 2 * fill, false, arcPaint);
    }

    // Node dots at corners
    final dotPaint = Paint()
      ..color = _teal.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = _teal.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    final nodes = [
      Offset(cx - 68, cy - 40),
      Offset(cx + 68, cy - 40),
      Offset(cx - 60, cy + 50),
      Offset(cx + 60, cy + 50),
    ];

    for (final n in nodes) {
      canvas.drawLine(center, n, linePaint);
      canvas.drawCircle(n, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_PlanningPreviewPainter _) => false;
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color arcStart;
  final Color arcEnd;

  const _ArcPainter({
    required this.progress,
    required this.trackColor,
    required this.arcStart,
    required this.arcEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final bounds = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );

    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      bounds,
      -math.pi / 2,
      sweepAngle,
      false,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [arcStart, arcEnd],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress ||
      old.arcStart != arcStart ||
      old.trackColor != trackColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Offline / no-connection placeholder
// ─────────────────────────────────────────────────────────────────────────────
class _NoConnectionMessage extends ConsumerWidget {
  const _NoConnectionMessage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi_off_outlined, color: c.iconMuted, size: 36),
        const SizedBox(height: 12),
        Text(
          'Подключение к интернету отсутствует',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.iconMuted,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Header Button
// ─────────────────────────────────────────────────────────────────────────────
class _GlassHeaderBtn extends ConsumerWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  const _GlassHeaderBtn({required this.icon, this.onTap, this.size = 18});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final iconWidget = Icon(icon, color: c.textSecondary, size: size);

    final child = Container(
      width: 38,
      height: 38,
      decoration: c.flatCard(radius: 19),
      child: Center(child: iconWidget),
    );

    if (onTap == null) return child;
    return GestureDetector(onTap: onTap, child: child);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen Header
// ─────────────────────────────────────────────────────────────────────────────
class _ScreenHeader extends ConsumerWidget {
  final AsyncValue<Profile?> profileAsync;

  const _ScreenHeader({required this.profileAsync});

  static String _badge(int level) {
    if (level <= 5)  return 'Recruit';
    if (level <= 10) return 'Operative';
    if (level <= 20) return 'Explorer';
    return 'Commander';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c              = ref.watch(sieColorsProvider);
    final theme          = Theme.of(context);
    final gradientColors = [c.accent, c.accentSecondary];

    final operative = profileAsync.when(
      data: (p) => p?.username?.toUpperCase() ?? 'UNIDENTIFIED',
      loading: () => '...',
      error: (_, _) => 'UNKNOWN',
    );
    final xp = profileAsync.valueOrNull?.totalXp ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
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
                          text: 'OPERATIONS CONTROL',
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
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'OPERATIVE: $operative',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 13,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right,
                          color: gradientColors.first.withValues(alpha: 0.7),
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const _NotificationBell(),
            const SizedBox(width: 8),
            _GlassHeaderBtn(
              icon: Icons.search,
              size: 20,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserSearchScreen()),
              ),
            ),
            const SizedBox(width: 8),
            _GlassHeaderBtn(
              icon: Icons.logout,
              size: 20,
              onTap: () async {
                await SupabaseService.signOut();
                ref.invalidate(userProfileProvider);
                ref.invalidate(habitsProvider);
                ref.invalidate(branchesProvider);
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        _XpBar(
            xp: xp,
            gradientColors: gradientColors,
            badge: _badge(xp ~/ 1000),
            c: c),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// XP Progress Bar
// ─────────────────────────────────────────────────────────────────────────────
class _XpBar extends StatelessWidget {
  final int xp;
  final List<Color> gradientColors;
  final String badge;
  final SieColors c;

  const _XpBar({
    required this.xp,
    required this.gradientColors,
    required this.badge,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final level     = xp ~/ 1000;
    final xpInLevel = xp % 1000;
    final progress  = (xpInLevel / 1000.0).clamp(0.0, 1.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'XP Level $level',
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 14,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$xpInLevel / 1000 XP',
                      style: theme.textTheme.bodyMedium),
                  Text('${(progress * 100).round()}%',
                      style: theme.textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Stack(
                  children: [
                    Container(height: 4, color: c.border),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: gradientColors),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification Bell with unread badge
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final unread =
        ref.watch(notificationsProvider).valueOrNull?.unreadCount ?? 0;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _NotificationsSheet(),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: c.flatCard(radius: 19),
            child: Center(
              child: Icon(Icons.notifications_outlined,
                  color: c.textSecondary, size: 18),
            ),
          ),
          if (unread > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifications Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationsSheet extends ConsumerWidget {
  const _NotificationsSheet();

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}д назад';
    if (diff.inHours >= 1) return '${diff.inHours}ч назад';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}м назад';
    return 'только что';
  }

  static String _notifText(AppNotification n) {
    final name = n.fromUser?.username ?? 'Кто-то';
    return switch (n.type) {
      'friend_request' => '$name отправил вам запрос в друзья',
      'friend_request_accepted' => '$name принял ваш запрос в друзья',
      _ => n.type,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final notifier = ref.read(notificationsProvider.notifier);
    final stateAsync = ref.watch(notificationsProvider);
    final notifications = stateAsync.valueOrNull?.notifications ?? [];
    final unread = stateAsync.valueOrNull?.unreadCount ?? 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  Text(
                    'УВЕДОМЛЕНИЯ',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (unread > 0)
                    TextButton(
                      onPressed: notifier.markAllAsRead,
                      child: const Text('Прочитать все',
                          style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
            Divider(color: c.border, height: 1),
            Expanded(
              child: notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none,
                              size: 48,
                              color:
                                  c.textSecondary.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text('Нет уведомлений',
                              style: TextStyle(
                                  color: c.textSecondary, fontSize: 14)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: controller,
                      itemCount: notifications.length,
                      itemBuilder: (ctx, i) {
                        final n = notifications[i];
                        return _NotifTile(
                          notification: n,
                          onTap: () {
                            notifier.markAsRead(n.id);
                            if (n.fromUser != null) {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PublicProfileScreen(
                                      profile: n.fromUser!),
                                ),
                              );
                            }
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
}

class _NotifTile extends ConsumerWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotifTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final n = notification;
    final url = n.fromUser?.avatarUrl;
    final name = n.fromUser?.username ?? '?';
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surface,
                border: Border.all(color: c.border),
              ),
              child: ClipOval(
                child: url != null && url.isNotEmpty
                    ? Image.network(url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _NAvatar(letter, c))
                    : _NAvatar(letter, c),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _NotificationsSheet._notifText(n),
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textPrimary,
                      fontWeight: n.isRead
                          ? FontWeight.normal
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _NotificationsSheet._timeAgo(n.createdAt),
                    style:
                        TextStyle(fontSize: 11, color: c.textSecondary),
                  ),
                ],
              ),
            ),
            if (!n.isRead)
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: c.accent, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

class _NAvatar extends StatelessWidget {
  final String letter;
  final SieColors c;
  const _NAvatar(this.letter, this.c);

  @override
  Widget build(BuildContext context) => Center(
        child: Text(letter,
            style: TextStyle(
                color: c.accent, fontSize: 16, fontWeight: FontWeight.w200)),
      );
}
