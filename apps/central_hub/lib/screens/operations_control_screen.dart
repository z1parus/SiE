import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

import 'breathing_exercise_screen.dart';
import 'focus_protocol_screen.dart';
import 'habit_tracker_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
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
          const SizedBox(height: 96),
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
  }

  if (screen != null) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => screen!,
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
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
    switch (index) {
      case 0:
        Navigator.of(context).push(PageRouteBuilder(
          pageBuilder: (_, _, _) => const ProfileScreen(),
          transitionsBuilder: (_, a, _, c) =>
              FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 350),
        ));
      case 3:
        Navigator.of(context).push(PageRouteBuilder(
          pageBuilder: (_, _, _) => const LeaderboardScreen(),
          transitionsBuilder: (_, a, _, c) =>
              FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 350),
        ));
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
          isCosmicMode: c.isCosmicMode,
          activeColor: c.accent,
          accentSecondary: c.accentSecondary,
          inactiveColor: c.iconMuted,
          onTap: () => _onItemTap(context, i),
        );
      }),
    );

    if (c.isCosmicMode) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, math.max(bottomInset, 16)),
        child: GlassCard(
          height: 68,
          padding: EdgeInsets.zero,
          shape: LiquidRoundedSuperellipse(borderRadius: 28),
          useOwnLayer: true,
          quality: GlassQuality.standard,
          clipBehavior: Clip.antiAlias,
          settings: LiquidGlassSettings(
            blur: 3.5,
            thickness: 24,
            refractiveIndex: 1.45,
            glassColor: const Color(0x0A0A0E1A),
            lightAngle: GlassDefaults.lightAngle,
            lightIntensity: 0.72,
            glowIntensity: 0.92,
            saturation: 1.4,
            specularSharpness: GlassSpecularSharpness.sharp,
            ambientStrength: 0.08,
            chromaticAberration: 0.015,
          ),
          child: navContent,
        ),
      );
    }

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
  final bool isCosmicMode;
  final Color activeColor;
  final Color accentSecondary;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isCosmicMode,
    required this.activeColor,
    required this.accentSecondary,
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
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isActive && isCosmicMode)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.3),
                      radius: 1.1,
                      colors: [
                        activeColor.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isActive)
                  Container(
                    width: 28,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      gradient: isCosmicMode
                          ? LinearGradient(
                              colors: [activeColor, accentSecondary])
                          : null,
                      color: isCosmicMode ? null : activeColor,
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: isCosmicMode
                          ? [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.7),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
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
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const LeaderboardScreen(),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 350),
        ),
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
                decoration: c.isCosmicMode
                    ? const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.85,
                          colors: [Color(0x0F00E5FF), Colors.transparent],
                        ),
                      )
                    : null,
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
                        shadows: const [
                          Shadow(color: Color(0x99000000), blurRadius: 6),
                        ],
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
                            boxShadow: c.isCosmicMode
                                ? [
                                    BoxShadow(
                                      color: c.accent.withValues(alpha: 0.8),
                                      blurRadius: 6,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
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
                            shadows: c.isCosmicMode
                                ? [Shadow(color: c.accent, blurRadius: 8)]
                                : null,
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
                        const Color(0xFFCCF5F2),
                        c.accent,
                        c.accentSecondary,
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.35, 0.70, 1.0],
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
              boxShadow: c.isCosmicMode
                  ? [
                      BoxShadow(
                        color: c.accent.withValues(alpha: 0.35),
                        blurRadius: 40,
                        spreadRadius: 12,
                      ),
                      BoxShadow(
                        color: c.accentSecondary.withValues(alpha: 0.2),
                        blurRadius: 70,
                        spreadRadius: 24,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: c.accent.withValues(alpha: 0.20),
                        blurRadius: 20,
                        spreadRadius: 4,
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
                    boxShadow: glow && c.isCosmicMode
                        ? [
                            BoxShadow(
                              color: c.accent.withValues(alpha: 0.75),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
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
                tipColor: c.accent,
                isCosmicMode: c.isCosmicMode,
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

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color arcStart;
  final Color arcEnd;
  final Color tipColor;
  final bool isCosmicMode;

  const _ArcPainter({
    required this.progress,
    required this.trackColor,
    required this.arcStart,
    required this.arcEnd,
    required this.tipColor,
    required this.isCosmicMode,
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

    if (progress > 0.01 && isCosmicMode) {
      final tipAngle = -math.pi / 2 + sweepAngle;
      final tipX = center.dx + radius * math.cos(tipAngle);
      final tipY = center.dy + radius * math.sin(tipAngle);
      canvas.drawCircle(
        Offset(tipX, tipY),
        5,
        Paint()
          ..color = tipColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
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
// Glass Bell Badge
// ─────────────────────────────────────────────────────────────────────────────
class _GlassBell extends ConsumerWidget {
  const _GlassBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c    = ref.watch(sieColorsProvider);
    final icon = Icon(
      Icons.notifications_outlined,
      color: c.textSecondary,
      size: 18,
    );

    if (c.isCosmicMode) {
      return GlassCard(
        width: 38,
        height: 38,
        padding: EdgeInsets.zero,
        shape: LiquidRoundedSuperellipse(borderRadius: 19),
        useOwnLayer: true,
        quality: GlassQuality.standard,
        clipBehavior: Clip.antiAlias,
        settings: LiquidGlassSettings(
          blur: 2.0,
          thickness: 20,
          refractiveIndex: 1.45,
          glassColor: const Color(0x0A0A0E1A),
          lightAngle: GlassDefaults.lightAngle,
          lightIntensity: 0.72,
          glowIntensity: 0.85,
          saturation: 1.4,
          specularSharpness: GlassSpecularSharpness.sharp,
          ambientStrength: 0.08,
          chromaticAberration: 0.015,
        ),
        child: Center(child: icon),
      );
    }

    return Container(
      width: 38,
      height: 38,
      decoration: c.flatCard(radius: 19),
      child: Center(child: icon),
    );
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
    final spaceEffects   = theme.extension<SieSpaceEffects>();
    final gradientColors = c.isCosmicMode
        ? (spaceEffects?.primaryGradient ?? [c.accent, c.dp])
        : [c.accent, c.accentSecondary];

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
                            shadows: c.isCosmicMode
                                ? [
                                    Shadow(color: c.accent, blurRadius: 8),
                                    Shadow(color: c.accent, blurRadius: 20),
                                  ]
                                : null,
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
                      PageRouteBuilder(
                        pageBuilder: (_, _, _) => const ProfileScreen(),
                        transitionsBuilder: (_, anim, _, child) =>
                            FadeTransition(opacity: anim, child: child),
                        transitionDuration: const Duration(milliseconds: 350),
                      ),
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
            const _GlassBell(),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (_, _, _) => const UserSearchScreen(),
                  transitionsBuilder: (_, anim, _, child) =>
                      FadeTransition(opacity: anim, child: child),
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              ),
              icon: Icon(Icons.search, color: c.textSecondary, size: 20),
              tooltip: 'NETWORK SCAN',
            ),
            IconButton(
              onPressed: () async => SupabaseService.signOut(),
              icon: Icon(Icons.logout, color: c.textSecondary, size: 20),
              tooltip: 'SIGN OUT',
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
