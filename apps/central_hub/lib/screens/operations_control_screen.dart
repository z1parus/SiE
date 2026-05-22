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

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens (local to this file)
// ─────────────────────────────────────────────────────────────────────────────
const _kCyan   = Color(0xFF00E5FF);
const _kPurple = Color(0xFF7000FF);
const _kMuted  = Color(0xFF90A4AE);
const _kOrange = Color(0xFFFF8C42);

// ─────────────────────────────────────────────────────────────────────────────
// OperationsControlScreen
// ─────────────────────────────────────────────────────────────────────────────
class OperationsControlScreen extends ConsumerStatefulWidget {
  const OperationsControlScreen({super.key});

  @override
  ConsumerState<OperationsControlScreen> createState() =>
      _OperationsControlScreenState();
}

class _OperationsControlScreenState
    extends ConsumerState<OperationsControlScreen> {
  bool _welcomeShown = false;

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(branchesProvider);
    final profileAsync  = ref.watch(userProfileProvider);

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

    // GlassPage registers SieSpaceBackground as the GPU backdrop source so
    // GlassCard's shader can physically sample and refract the star field
    // rather than synthesising a generic frost effect.
    return GlassPage(
      background: const SieSpaceBackground(),
      statusBarStyle: GlassStatusBarStyle.light,
      child: Scaffold(
        // GlassPage forces scaffoldBackgroundColor → transparent via Theme
        // override when a background is provided, so this is redundant but
        // kept for clarity if GlassPage is ever removed.
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
          // ── Main scrollable content ─────────────────────────
          SafeArea(
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
                // ── Branch carousel (edge-to-edge) ──────────
                Expanded(
                  child: branchesAsync.when(
                    data: (branches) {
                      final filtered = branches
                          .where((b) => b.slug != 'progress_hub')
                          .toList();
                      return filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'NO DEPARTMENTS AVAILABLE',
                                style: TextStyle(
                                  color: SieTheme.textSecondary,
                                  letterSpacing: 1.5,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : _BranchCarousel(
                              branches: filtered,
                              onBranchTap: (b) =>
                                  _onBranchTap(context, b),
                            );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: SieTheme.accent,
                        strokeWidth: 1.5,
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Text(
                        'ERROR: $e',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ),
                ),
                // Reserve space so last carousel card isn't hidden
                // behind the floating nav bar.
                const SizedBox(height: 96),
              ],
            ),
          ),

          // ── Floating Bottom Navigation ──────────────────────
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
// Welcome Dialog  (business logic unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _WelcomeDialog extends StatefulWidget {
  final Profile profile;
  final VoidCallback onAccept;

  const _WelcomeDialog({required this.profile, required this.onAccept});

  @override
  State<_WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<_WelcomeDialog>
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
            color: SieTheme.surface,
            border: Border.all(color: SieTheme.borderAccent),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 3, height: 16, color: SieTheme.accent),
                  const SizedBox(width: 10),
                  Text(
                    'ВХОДЯЩЕЕ СООБЩЕНИЕ',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 2.5,
                          color: SieTheme.accent,
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
              const Divider(color: SieTheme.borderDefault, height: 1),
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
                      color: SieTheme.accent.withValues(alpha: 0.1),
                      border: Border.all(color: SieTheme.accent),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text(
                      'ПРИНЯТЬ ЗАДАНИЕ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: SieTheme.accent,
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
// Branch navigation  (business logic unchanged)
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
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar();

  static const _items = [
    (icon: Icons.language_outlined,   label: 'Hub'),
    (icon: Icons.my_location_outlined, label: 'Operations'),
    (icon: Icons.shield_outlined,     label: 'Garage'),
    (icon: Icons.star_outline,        label: 'Hall of Fame'),
  ];

  // "Operations" is always the active tab on this screen.
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
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            return _NavItem(
              icon: item.icon,
              label: item.label,
              isActive: i == _activeIndex,
              onTap: () => _onItemTap(context, i),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _kCyan : _kMuted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        height: 68,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient glow bloom — diffuses cyan light through the glass
            // substrate rather than sitting as a flat overlay on top.
            if (isActive)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.3),
                      radius: 1.1,
                      colors: [
                        _kCyan.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Active indicator — gradient line at the top of the item.
                if (isActive)
                  Container(
                    width: 28,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kCyan, _kPurple],
                      ),
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: [
                        BoxShadow(
                          color: _kCyan.withValues(alpha: 0.7),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SieGlassCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Column(
          children: [
            // ── Visual preview  (≈60 % of card height) ──────
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.85,
                    colors: [
                      Color(0x0F00E5FF),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: _preview(),
              ),
            ),

            // ── Divider ──────────────────────────────────────
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),

            // ── Info section (≈40 % of card height) ─────────
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branch.name.toUpperCase(),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 14,
                            letterSpacing: 1.8,
                            shadows: const [
                              Shadow(color: Color(0x99000000), blurRadius: 6),
                            ],
                          ),
                        ),
                        if (branch.description != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            branch.description!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              shadows: const [
                                Shadow(color: Color(0x80000000), blurRadius: 4),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _kCyan,
                            boxShadow: [
                              BoxShadow(
                                color: _kCyan.withValues(alpha: 0.8),
                                blurRadius: 6,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _statusLabel(ref),
                          style: const TextStyle(
                            color: _kCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(color: _kCyan, blurRadius: 8),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.chevron_right,
                          color: _kCyan,
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

/// Breathing — radial gradient sphere with infinite scale "breath" animation.
class _BreathSpherePreview extends StatefulWidget {
  const _BreathSpherePreview();

  @override
  State<_BreathSpherePreview> createState() => _BreathSpherePreviewState();
}

class _BreathSpherePreviewState extends State<_BreathSpherePreview>
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
              gradient: const RadialGradient(
                colors: [
                  Color(0xFFCCF8FF), // bright core
                  Color(0xFF00E5FF), // neon cyan
                  Color(0xFF7000FF), // purple rim
                  Color(0x007000FF), // fade to transparent
                ],
                stops: [0.0, 0.28, 0.68, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: _kCyan.withValues(alpha: 0.35),
                  blurRadius: 40,
                  spreadRadius: 12,
                ),
                BoxShadow(
                  color: _kPurple.withValues(alpha: 0.2),
                  blurRadius: 70,
                  spreadRadius: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Habit Matrix — 5×5 dot grid with specific nodes glowing in Neon Cyan.
class _HabitMatrixPreview extends StatelessWidget {
  const _HabitMatrixPreview();

  // (row, col) of glowing nodes
  static const _lit = {
    (0, 2),
    (1, 1), (1, 3),
    (2, 0), (2, 2), (2, 4),
    (3, 1), (3, 3),
    (4, 2),
  };

  @override
  Widget build(BuildContext context) {
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
                    color: glow
                        ? _kCyan
                        : const Color(0xFF1A3A5C),
                    boxShadow: glow
                        ? [
                            BoxShadow(
                              color: _kCyan.withValues(alpha: 0.75),
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

/// Focus Forge — thin circular arc ring showing a countdown timer.
class _FocusRingPreview extends StatelessWidget {
  const _FocusRingPreview();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 140,
        height: 140,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(140, 140),
              painter: _ArcPainter(progress: 0.65),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '15:00',
                  style: TextStyle(
                    color: Colors.white,
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
                    color: _kMuted,
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
  const _ArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final bounds = Rect.fromCircle(center: center, radius: radius);

    // Track (background ring)
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF1A3A5C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );

    // Progress arc with diagonal gradient
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      bounds,
      -math.pi / 2,
      sweepAngle,
      false,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kCyan, _kPurple],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );

    // Glowing tip at arc end
    if (progress > 0.01) {
      final tipAngle = -math.pi / 2 + sweepAngle;
      final tipX = center.dx + radius * math.cos(tipAngle);
      final tipY = center.dy + radius * math.sin(tipAngle);
      canvas.drawCircle(
        Offset(tipX, tipY),
        5,
        Paint()
          ..color = _kCyan
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Bell Badge
// ─────────────────────────────────────────────────────────────────────────────
class _GlassBell extends StatelessWidget {
  const _GlassBell();

  @override
  Widget build(BuildContext context) {
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
      child: const Center(
        child: Icon(
          Icons.notifications_outlined,
          color: SieTheme.textSecondary,
          size: 18,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen Header
// ─────────────────────────────────────────────────────────────────────────────
class _ScreenHeader extends StatelessWidget {
  final AsyncValue<Profile?> profileAsync;

  const _ScreenHeader({required this.profileAsync});

  static String _badge(int level) {
    if (level <= 5)  return 'Recruit';
    if (level <= 10) return 'Operative';
    if (level <= 20) return 'Explorer';
    return 'Commander';
  }

  @override
  Widget build(BuildContext context) {
    final theme         = Theme.of(context);
    final spaceEffects  = theme.extension<SieSpaceEffects>();
    final gradientColors =
        spaceEffects?.primaryGradient ?? [SieTheme.accent, SieTheme.dp];

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
                        const TextSpan(
                          text: 'SiE ',
                          style: TextStyle(
                            color: _kCyan,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(color: _kCyan, blurRadius: 8),
                              Shadow(color: _kCyan, blurRadius: 20),
                            ],
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
                          color:
                              gradientColors.first.withValues(alpha: 0.7),
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
              icon: const Icon(
                Icons.search,
                color: SieTheme.textSecondary,
                size: 20,
              ),
              tooltip: 'NETWORK SCAN',
            ),
            IconButton(
              onPressed: () async => SupabaseService.signOut(),
              icon: const Icon(
                Icons.logout,
                color: SieTheme.textSecondary,
                size: 20,
              ),
              tooltip: 'SIGN OUT',
            ),
          ],
        ),
        const SizedBox(height: 20),
        _XpBar(xp: xp, gradientColors: gradientColors, badge: _badge(xp ~/ 1000)),
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

  const _XpBar({
    required this.xp,
    required this.gradientColors,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme      = Theme.of(context);
    final level      = xp ~/ 1000;
    final xpInLevel  = xp % 1000;
    final progress   = (xpInLevel / 1000.0).clamp(0.0, 1.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Level + badge column
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
        // Progress track
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
                    Container(
                      height: 4,
                      color: SieTheme.borderDefault,
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient:
                              LinearGradient(colors: gradientColors),
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
