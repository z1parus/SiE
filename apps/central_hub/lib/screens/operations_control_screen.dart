import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sie_core/sie_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'breathing_exercise_screen.dart';
import 'focus_protocol_screen.dart';
import 'habit_tracker_screen.dart';
import 'leaderboard_screen.dart';
import 'meditation_hub_screen.dart';
import 'planning_screen.dart';
import 'session_orb_painters.dart';
import 'profile_screen.dart';
import 'public_profile_screen.dart';
import 'user_search_screen.dart';
import '../widgets/defrag_preview.dart';
import '../widgets/focus_orbit_timer.dart';

const _kOrange = Color(0xFFFF8C42);
const _kBranchOrderKey = 'branch_order';

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
  List<String>? _orderedSlugs;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final slugs = prefs.getStringList(_kBranchOrderKey);
    if (mounted && slugs != null) setState(() => _orderedSlugs = slugs);
  }

  Future<void> _saveOrder(List<String> slugs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kBranchOrderKey, slugs);
  }

  List<Branch> _applyOrder(List<Branch> branches) {
    final slugs = _orderedSlugs;
    if (slugs == null || slugs.isEmpty) return branches;
    final indexMap = {for (var i = 0; i < slugs.length; i++) slugs[i]: i};
    return List<Branch>.from(branches)
      ..sort((a, b) {
        final aIdx = indexMap[a.slug] ?? 9999;
        final bIdx = indexMap[b.slug] ?? 9999;
        return aIdx.compareTo(bIdx);
      });
  }

  Future<void> _onRefresh() async {
    ref.invalidate(branchesProvider);
    ref.invalidate(planningProvider);
    ref.invalidate(habitsProvider);
    ref.invalidate(userProfileProvider);
    ref.invalidate(notificationsProvider);
    await ref.read(branchesProvider.future);
  }

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

    final innerBody = SafeArea(
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
                final ordered = _applyOrder(filtered);
                return ordered.isEmpty
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
                        branches: ordered,
                        onBranchTap: (b) => _onBranchTap(context, b),
                        onReorder: (oldIndex, newIndex) {
                          final prevSlugs =
                              ordered.map((b) => b.slug).toList();
                          final reordered = List<Branch>.from(ordered);
                          if (newIndex > oldIndex) newIndex--;
                          final item = reordered.removeAt(oldIndex);
                          reordered.insert(newIndex, item);
                          final slugs =
                              reordered.map((b) => b.slug).toList();
                          setState(() => _orderedSlugs = slugs);
                          _saveOrder(slugs);
                          showUndoSnackbar(
                            context,
                            ref,
                            message: 'Порядок модулей изменён',
                            onUndo: () {
                              setState(() => _orderedSlugs = prevSlugs);
                              _saveOrder(prevSlugs);
                            },
                          );
                        },
                      );
              },
              loading: () => const _BranchCarouselSkeleton(),
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

    final body = LayoutBuilder(
      builder: (_, constraints) => RefreshIndicator(
        color: c.accent,
        backgroundColor: c.isLightMode ? Colors.white : const Color(0xFF0D1B2A),
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(height: constraints.maxHeight, child: innerBody),
        ),
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
    // Shown once, but the user can dismiss it any way (button, ✕, tap-outside);
    // every exit marks it seen so it never re-appears.
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => _WelcomeDialog(profile: profile),
    ).then((_) => markWelcomeSeen(profile.id));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Welcome Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _WelcomeDialog extends ConsumerStatefulWidget {
  final Profile profile;

  const _WelcomeDialog({required this.profile});

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
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Semantics(
                      button: true,
                      label: 'Закрыть',
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close,
                            size: 20, color: c.iconMuted),
                      ),
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
                  onTap: () => Navigator.of(context).pop(),
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
  } else if (branch.slug == 'meditation') {
    screen = const MeditationHubScreen();
  }

  if (screen != null) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen!),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('Этот модуль скоро будет доступен'),
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
            behavior: SnackBarBehavior.floating,
            content: Text('Этот модуль скоро будет доступен'),
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
  final void Function(int oldIndex, int newIndex) onReorder;

  const _BranchCarousel({
    required this.branches,
    required this.onBranchTap,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth * 0.82;

    return ReorderableListView.builder(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.only(left: screenWidth * 0.09, right: 8),
      onReorder: onReorder,
      onReorderStart: (_) => SieHaptics.heavy(),
      proxyDecorator: (child, _, animation) => AnimatedBuilder(
        animation: animation,
        builder: (_, ch) {
          final t = CurvedAnimation(
              parent: animation, curve: Curves.easeOut);
          return Transform.scale(
            scale: Tween<double>(begin: 1.0, end: 1.04).evaluate(t),
            child: Material(
              elevation: Tween<double>(begin: 0, end: 16).evaluate(t),
              color: Colors.transparent,
              shadowColor: Colors.black38,
              borderRadius: BorderRadius.circular(20),
              child: ch,
            ),
          );
        },
        child: child,
      ),
      itemCount: branches.length,
      itemBuilder: (context, index) {
        final branch = branches[index];
        return SizedBox(
          key: ValueKey(branch.slug),
          width: itemWidth,
          child: _BranchCarouselCard(
            branch: branch,
            onTap: () => onBranchTap(branch),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Branch Carousel Skeleton (loading placeholder)
// ─────────────────────────────────────────────────────────────────────────────
class _BranchCarouselSkeleton extends StatelessWidget {
  const _BranchCarouselSkeleton();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth * 0.82;
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.only(left: screenWidth * 0.09, right: 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: SieSkeleton(
          width: itemWidth,
          height: double.infinity,
          radius: 20,
        ),
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
      'meditation'          => const _DefragPreview(),
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
      case 'meditation':
        return 'SESSION READY';
      case 'planning':
        final count = ref.watch(
          planningProvider.select((s) => s.valueOrNull?.activeGoals.length ?? 0),
        );
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
        glass: true,
        radius: 20,
        blurSigma: 12,
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
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _shaderCtrl;
  late final Animation<double> _pulse;
  FragmentShader? _shader;

  static const _size = 144.0;
  static const _lightAngle = -math.pi / 4;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.93, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _shaderCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program = await FragmentProgram.fromAsset(
        'assets/shaders/breathing_sphere.frag',
      );
      if (mounted) setState(() => _shader = program.fragmentShader());
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _shaderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    final fallbackColors = c.isLightMode
        ? <Color>[const Color(0xFFF1F1F5), const Color(0xFFD0D2DC)]
        : <Color>[const Color(0xFF1C2035), const Color(0xFF2A3048)];

    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _shaderCtrl]),
        builder: (_, _) {
          final shaderTime = _shaderCtrl.value * 60.0;
          return Transform.scale(
            scale: _pulse.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Layer 1 — outer golden corona
                Container(
                  width: _size + 60,
                  height: _size + 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.accent.withValues(
                            alpha: c.isLightMode ? 0.07 : 0.13),
                        blurRadius: c.isLightMode ? 18 : 22,
                      ),
                    ],
                  ),
                ),
                // Layer 2 — shader sphere
                ClipOval(
                  child: SizedBox(
                    width: _size,
                    height: _size,
                    child: _shader != null
                        ? CustomPaint(
                            painter: _PreviewShaderPainter(
                              shader: _shader!,
                              time: shaderTime,
                              sphereSize: _size,
                              isDark: !c.isLightMode,
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: fallbackColors,
                                stops: const [0.0, 1.0],
                              ),
                            ),
                          ),
                  ),
                ),
                // Layer 3 — golden rim
                CustomPaint(
                  size: const Size(_size, _size),
                  painter: SphereRimPainter(
                    lightAngle: _lightAngle,
                    intensity: 0.6,
                    isDark: !c.isLightMode,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PreviewShaderPainter extends CustomPainter {
  final FragmentShader shader;
  final double time;
  final double sphereSize;
  final bool isDark;

  const _PreviewShaderPainter({
    required this.shader,
    required this.time,
    required this.sphereSize,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    try {
      shader.setFloat(0, time);
      shader.setFloat(1, 0.3); // idle breath position
      shader.setFloat(2, size.width);
      shader.setFloat(3, size.height);
      shader.setFloat(4, isDark ? 1.0 : 0.0);
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    } catch (_) {}
  }

  @override
  bool shouldRepaint(_PreviewShaderPainter old) =>
      time != old.time || sphereSize != old.sphereSize || isDark != old.isDark;
}

/// Glassmorphic "task complete" crystal preview for the habit module: layered
/// frosted glass discs, a rotating orbital arrow (sync motif), a faceted
/// translucent crystal with a glowing mint-green core, a bold white checkmark
/// and three floating progress pills. Purely decorative; orbit + gentle float
/// animate, and freeze under reduce-motion.
class _HabitMatrixPreview extends ConsumerStatefulWidget {
  const _HabitMatrixPreview();

  @override
  ConsumerState<_HabitMatrixPreview> createState() =>
      _HabitMatrixPreviewState();
}

class _HabitMatrixPreviewState extends ConsumerState<_HabitMatrixPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 8));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SieMotion.enabled(context)) {
      if (!_ctrl.isAnimating) _ctrl.repeat();
    } else {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    final motion = SieMotion.enabled(context);
    return Center(
      child: SizedBox(
        width: 150,
        height: 150,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) => CustomPaint(
            size: const Size(150, 150),
            painter: _HabitCrystalPainter(
              t: _ctrl.value,
              motion: motion,
              isLight: c.isLightMode,
              gold: c.accent,
              gold2: c.accentSecondary,
              glass: c.glass,
            ),
          ),
        ),
      ),
    );
  }
}

class _HabitCrystalPainter extends CustomPainter {
  final double t;
  final bool motion;
  final bool isLight;
  final Color gold;
  final Color gold2;
  final Color glass;

  const _HabitCrystalPainter({
    required this.t,
    required this.motion,
    required this.isLight,
    required this.gold,
    required this.gold2,
    required this.glass,
  });

  static Offset _dir(double a) => Offset(math.cos(a), math.sin(a));

  Path _poly(Offset c, double r, int n, double rot) {
    final p = Path();
    for (var k = 0; k < n; k++) {
      final o = c + _dir(rot + k * 2 * math.pi / n) * r;
      k == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  List<Offset> _verts(Offset c, double r, int n, double rot) =>
      [for (var k = 0; k < n; k++) c + _dir(rot + k * 2 * math.pi / n) * r];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;
    final a = motion ? t * 2 * math.pi : 0.0;
    final dy = motion ? math.sin(t * 2 * math.pi) * 2.0 : 0.0;

    // Theme-aware glass (token): white highlights on dark; a cool slate on light
    // so the crystal stays visible against a light card.
    final coreLight = Color.lerp(gold2, Colors.white, 0.55)!;
    final coreDeep = Color.lerp(gold, Colors.black, 0.32)!;

    // ── 1. Frosted glass discs (depth) ──────────────────────────────────────
    void disc(double rad, double fill, double stroke) {
      canvas.drawCircle(
          center, rad, Paint()..color = glass.withValues(alpha: fill));
      canvas.drawCircle(
        center,
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = glass.withValues(alpha: stroke),
      );
    }

    disc(r * 0.96, isLight ? 0.10 : 0.05, isLight ? 0.22 : 0.10);
    disc(r * 0.80, isLight ? 0.13 : 0.07, isLight ? 0.26 : 0.13);
    // Soft plate glow behind the crystal.
    canvas.drawCircle(
      center,
      r * 0.60,
      Paint()
        ..color = glass.withValues(alpha: isLight ? 0.12 : 0.09)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // ── 2. Orbital arrows (sync motif), rotating ────────────────────────────
    _orbital(canvas, center, r * 0.92, -0.6 + a, 2.2,
        glass.withValues(alpha: isLight ? 0.55 : 0.65), r);
    _dottedArc(canvas, center, r * 0.92, math.pi - 0.2 + a, 1.9,
        glass.withValues(alpha: isLight ? 0.45 : 0.5));

    // ── group with gentle float ─────────────────────────────────────────────
    final cc = center.translate(0, dy);

    // ── 3. Faceted crystal ──────────────────────────────────────────────────
    _crystal(canvas, cc, r * 0.52, glass);

    // ── 4. Gold core (glow + body) ──────────────────────────────────────────
    final rc = r * 0.30;
    final corePath = _poly(cc, rc, 6, -math.pi / 2);
    canvas.drawPath(
      corePath,
      Paint()
        ..color = gold.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawPath(
      corePath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.4),
          radius: 0.95,
          colors: [coreLight, gold, coreDeep],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: cc, radius: rc)),
    );
    // Glossy top highlight on the core.
    canvas.drawPath(
      corePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.45),
    );

    // ── 5. Checkmark ────────────────────────────────────────────────────────
    final check = Path()
      ..moveTo(cc.dx - rc * 0.42, cc.dy + rc * 0.02)
      ..lineTo(cc.dx - rc * 0.08, cc.dy + rc * 0.34)
      ..lineTo(cc.dx + rc * 0.46, cc.dy - rc * 0.32);
    canvas.drawPath(
      check.shift(Offset(0, rc * 0.06)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rc * 0.22
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = coreDeep.withValues(alpha: 0.5),
    );
    canvas.drawPath(
      check,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rc * 0.20
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );

    // ── 6. Floating progress pills (gold "COMMANDER" gradient), appearing one
    //       after another from top to bottom in a loop. ──────────────────────
    final pillPhase = motion ? (t * 2) % 1.0 : 1.0;
    for (var i = 0; i < 3; i++) {
      double vis, pop;
      if (!motion) {
        vis = 1;
        pop = 1;
      } else {
        final start = 0.06 + i * 0.20;
        pop = ((pillPhase - start) / 0.14).clamp(0.0, 1.0);
        final out = 1 - ((pillPhase - 0.84) / 0.12).clamp(0.0, 1.0);
        vis = pop * out;
      }
      if (vis <= 0.02) continue;

      final ph = r * 0.05;
      final pw = r * 0.20 * (0.55 + 0.45 * pop);
      final px = cc.dx + r * 0.14 + i * r * 0.04;
      final py = cc.dy + r * 0.30 + i * (ph + r * 0.035);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(px, py, pw, ph),
        Radius.circular(ph),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              gold.withValues(alpha: vis),
              gold2.withValues(alpha: vis),
            ],
          ).createShader(rect.outerRect),
      );
    }
  }

  void _orbital(Canvas canvas, Offset c, double rad, double start, double sweep,
      Color color, double r) {
    final rect = Rect.fromCircle(center: c, radius: rad);
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    // Arrowhead at the end, pointing along travel.
    final endA = start + sweep;
    final tip = c + _dir(endA) * rad;
    final travel = Offset(-math.sin(endA), math.cos(endA)); // tangent (CW)
    final s = r * 0.07;
    Offset wing(double da) => Offset(
          -travel.dx * math.cos(da) + travel.dy * math.sin(da),
          -travel.dx * math.sin(da) - travel.dy * math.cos(da),
        );
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawLine(tip, tip + wing(0.5) * s, p);
    canvas.drawLine(tip, tip + wing(-0.5) * s, p);
  }

  void _dottedArc(
      Canvas canvas, Offset c, double rad, double start, double sweep, Color color) {
    const n = 16;
    final p = Paint()..color = color;
    for (var i = 0; i <= n; i++) {
      final ang = start + sweep * i / n;
      canvas.drawCircle(c + _dir(ang) * rad, 1.4, p);
    }
  }

  void _crystal(Canvas canvas, Offset cc, double r, Color glass) {
    const rot = -math.pi / 2;
    final outer = _verts(cc, r, 8, rot);
    final inner = _verts(cc, r * 0.46, 8, rot);
    final bounds = Rect.fromCircle(center: cc, radius: r);
    final lightDir = _dir(-math.pi / 2 - 0.5);

    // Base body fill.
    canvas.drawPath(
      _poly(cc, r, 8, rot),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            glass.withValues(alpha: 0.22),
            glass.withValues(alpha: 0.06),
          ],
        ).createShader(bounds),
    );

    // Side facets with directional shading.
    for (var k = 0; k < 8; k++) {
      final k2 = (k + 1) % 8;
      final mid = (outer[k] + outer[k2]) / 2;
      final normal = (mid - cc);
      final nl = normal.distance;
      final nrm = nl == 0 ? Offset.zero : normal / nl;
      final lf = ((nrm.dx * lightDir.dx + nrm.dy * lightDir.dy) + 1) / 2;
      final facet = Path()
        ..moveTo(outer[k].dx, outer[k].dy)
        ..lineTo(outer[k2].dx, outer[k2].dy)
        ..lineTo(inner[k2].dx, inner[k2].dy)
        ..lineTo(inner[k].dx, inner[k].dy)
        ..close();
      canvas.drawPath(
        facet,
        Paint()..color = glass.withValues(alpha: 0.05 + 0.17 * lf),
      );
    }

    // Ridges from inner table to outer vertices.
    final ridge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = glass.withValues(alpha: 0.18);
    for (var k = 0; k < 8; k++) {
      canvas.drawLine(inner[k], outer[k], ridge);
    }

    // Bright outer edges.
    canvas.drawPath(
      _poly(cc, r, 8, rot),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round
        ..color = glass.withValues(alpha: 0.55),
    );
    // Extra highlight on the top-left edges.
    final hl = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = glass.withValues(alpha: 0.85);
    canvas.drawLine(outer[5], outer[6], hl);
    canvas.drawLine(outer[6], outer[7], hl);
  }

  @override
  bool shouldRepaint(_HabitCrystalPainter old) =>
      old.t != t ||
      old.motion != motion ||
      old.isLight != isLight ||
      old.gold != gold ||
      old.gold2 != gold2;
}

/// Live focus-timer preview. Reflects the real [focusTimerProvider] state:
/// idle shows the configured work minutes + a slow "radar" standby tick; an
/// active session shows live MM:SS, a progress arc with a glowing leading tip,
/// a phase colour (gold = work, cool = break) and a minute ripple. A row of
/// dots underneath tracks today's completed pomodoros (target 4).
class _FocusRingPreview extends ConsumerWidget {
  const _FocusRingPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final s = ref.watch(focusTimerProvider);
    final motion = SieMotion.enabled(context);

    final idle = s.phase == FocusPhase.idle;
    final isBreak = s.phase == FocusPhase.breakTime;
    final timeText = idle ? '${s.settings.workMinutes}' : s.formattedTime;
    final gold = isBreak ? c.focusBreak : c.accent;
    final gold2 = isBreak ? c.focusBreak : c.accentSecondary;
    final glass = c.glass;

    return Center(
      child: FocusOrbitTimer(
        size: 150,
        timeText: timeText,
        subLabel: 'Min',
        motion: motion,
        gold: gold,
        gold2: gold2,
        glass: glass,
        textColor: c.textPrimary,
        subLabelColor: c.textSecondary,
        isLight: c.isLightMode,
        centerFontSize: 30,
        glow: !c.isLightMode,
      ),
    );
  }
}

/// Mission constellation preview for the planning module: a tactical orbit
/// map. Each active goal is a glowing node on its own orbit ring, positioned
/// around the ring by that goal's real progress; a bright arc traces the
/// progress from the start to the node, and a faint spoke links the gold
/// command core to every node. An outer dotted radar ring frames the field,
/// frosted-glass discs add depth, and the whole constellation drifts slowly
/// (decorative only — frozen under reduce-motion). The centre reads the
/// average progress across the displayed missions.
class _PlanningPreview extends ConsumerStatefulWidget {
  const _PlanningPreview();

  @override
  ConsumerState<_PlanningPreview> createState() => _PlanningPreviewState();
}

class _PlanningPreviewState extends ConsumerState<_PlanningPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Per-slot orbit geometry. Radii are spread wide so the central readout sits
  // in a clear "target" core; base angles stagger the nodes so they don't cluster.
  static const _box        = 150.0;
  static const _radii      = [42.0, 54.0, 66.0];
  static const _baseAngle  = [-math.pi / 2, -math.pi / 2 + 2.1, -math.pi / 2 + 4.0];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SieMotion.enabled(context)) {
      if (!_ctrl.isAnimating) _ctrl.repeat();
    } else {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    final goals = ref.watch(
      planningProvider.select(
        (s) => s.valueOrNull?.activeGoals ?? const <Goal>[],
      ),
    );

    final shown = goals.take(3).toList();
    final nodes = List.generate(3, (i) {
      final goal = i < shown.length ? shown[i] : null;
      return _PlanNode(
        radius: _radii[i],
        baseAngle: _baseAngle[i],
        color: goal?.color ?? c.accent,
        progress: goal == null
            ? null
            : (goalProgress(goal) / 100.0).clamp(0.0, 1.0),
      );
    });

    final avg = shown.isEmpty
        ? null
        : (shown.map(goalProgress).reduce((a, b) => a + b) / shown.length)
            .round();

    return Center(
      child: SizedBox(
        width: _box,
        height: _box,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) => CustomPaint(
                size: const Size(_box, _box),
                painter: _PlanningPreviewPainter(
                  nodes: nodes,
                  t: _ctrl.value,
                  motion: SieMotion.enabled(context),
                  isLight: c.isLightMode,
                  trackColor: c.border,
                  tickColor: c.accent,
                  glass: c.isLightMode ? c.textSecondary : c.textPrimary,
                  gold: c.accent,
                  gold2: c.accentSecondary,
                ),
              ),
            ),
            // Centre readout — the average progress across displayed missions.
            Text(
              avg == null ? '—' : '$avg%',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanNode {
  final double radius;
  final double baseAngle;
  final Color color;

  /// Real goal progress 0..1, or null when no goal occupies this orbit slot.
  final double? progress;

  const _PlanNode({
    required this.radius,
    required this.baseAngle,
    required this.color,
    required this.progress,
  });
}

class _PlanningPreviewPainter extends CustomPainter {
  final List<_PlanNode> nodes;
  final double t;
  final bool motion;
  final bool isLight;
  final Color trackColor;
  final Color tickColor;
  final Color glass;
  final Color gold;
  final Color gold2;

  const _PlanningPreviewPainter({
    required this.nodes,
    required this.t,
    required this.motion,
    required this.isLight,
    required this.trackColor,
    required this.tickColor,
    required this.glass,
    required this.gold,
    required this.gold2,
  });

  static Offset _dir(double a) => Offset(math.cos(a), math.sin(a));

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Slow seamless rotation of the whole constellation — exactly one full turn
    // per loop so it never snaps back. Frozen when motion is off.
    final drift = motion ? t * 2 * math.pi : 0.0;

    // ── 1. Frosted glass discs (depth) ───────────────────────────────────────
    void disc(double rad, double fill, double stroke) {
      canvas.drawCircle(
          center, rad, Paint()..color = glass.withValues(alpha: fill));
      canvas.drawCircle(
        center,
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = glass.withValues(alpha: stroke),
      );
    }

    disc(72, isLight ? 0.08 : 0.04, isLight ? 0.20 : 0.08);
    disc(52, isLight ? 0.10 : 0.05, isLight ? 0.24 : 0.10);

    // ── 2. Outer radar tick ring ─────────────────────────────────────────────
    const ticks = 36;
    const tickR = 72.0;
    for (var i = 0; i < ticks; i++) {
      final a = i * 2 * math.pi / ticks + drift;
      final cardinal = i % 9 == 0;
      final p1 = center + _dir(a) * (tickR - (cardinal ? 5 : 2.5));
      final p2 = center + _dir(a) * tickR;
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = tickColor
              .withValues(alpha: (isLight ? 0.45 : 0.40) * (cardinal ? 1 : 0.55))
          ..strokeWidth = cardinal ? 1.4 : 1
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── 3. Orbits: track + progress arc + spoke + node ───────────────────────
    for (final n in nodes) {
      final rect = Rect.fromCircle(center: center, radius: n.radius);

      // Faint full-circle track.
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..color = trackColor.withValues(alpha: 0.55)
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke,
      );

      final start = n.baseAngle + drift;
      final nodeAngle = start + (n.progress == null ? 0 : n.progress! * 2 * math.pi);
      final node = center + _dir(nodeAngle) * n.radius;

      // Progress arc along the orbit up to the node (encodes real progress).
      if (n.progress != null) {
        final sweep = math.max(n.progress!, 0.04) * 2 * math.pi;
        canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..color = n.color.withValues(alpha: isLight ? 0.75 : 0.9)
            ..strokeWidth = 2.4
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      } else {
        // Empty slot — a small accent tick at the orbit start keeps it alive.
        canvas.drawArc(
          rect,
          start,
          0.04 * 2 * math.pi,
          false,
          Paint()
            ..color = tickColor.withValues(alpha: 0.4)
            ..strokeWidth = 2.4
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      }

      // Spoke core → node (mission link).
      canvas.drawLine(
        center,
        node,
        Paint()
          ..color = glass.withValues(alpha: isLight ? 0.30 : 0.22)
          ..strokeWidth = 1,
      );

      // Node dot with glow.
      final nodeR = n.progress == null ? 3.0 : 4.5;
      if (!isLight) {
        canvas.drawCircle(
          node,
          nodeR + 2,
          Paint()
            ..color = n.color.withValues(alpha: 0.30)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
      canvas.drawCircle(node, nodeR, Paint()..color = n.color);
      canvas.drawCircle(
        node,
        nodeR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = Colors.white.withValues(alpha: 0.45),
      );
    }

    // ── 4. Command core — faint glow + stroked ring framing the readout ──────
    const coreR = 30.0;
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..color = gold.withValues(alpha: isLight ? 0.10 : 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = gold.withValues(alpha: isLight ? 0.55 : 0.7),
    );
    // Cardinal tick marks on the core ring — tactical-instrument feel.
    for (final a in [0.0, math.pi / 2, math.pi, -math.pi / 2]) {
      final p1 = center + _dir(a) * (coreR - 3);
      final p2 = center + _dir(a) * (coreR + 3);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = gold.withValues(alpha: 0.8)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_PlanningPreviewPainter old) =>
      old.t != t ||
      old.motion != motion ||
      old.isLight != isLight ||
      old.trackColor != trackColor ||
      old.tickColor != tickColor ||
      old.glass != glass ||
      old.gold != gold ||
      old.gold2 != gold2 ||
      old.nodes != nodes;
}

/// Дефрагментация module preview — binds the shared-gold [DefragPreview] to
/// the runtime theme tokens (the gold-on-anthracite language of the carousel).
class _DefragPreview extends ConsumerWidget {
  const _DefragPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return DefragPreview(
      gold: c.accent,
      gold2: c.accentSecondary,
      goldLight: kRimLight,
      cold: c.focusBreak,
      glass: c.glass,
      trackColor: c.border,
      isLight: c.isLightMode,
      motion: SieMotion.enabled(context),
    );
  }
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
                final ok = await confirmDestructive(
                  context,
                  ref,
                  title: 'Выйти из системы?',
                  message: 'Сессия будет завершена. Несинхронизированные '
                      'данные сохранятся локально.',
                  confirmLabel: 'Выйти',
                );
                if (!ok) return;
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

    return Semantics(
      button: true,
      label: unread > 0
          ? 'Уведомления, $unread непрочитанных'
          : 'Уведомления',
      child: GestureDetector(
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
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                      color: c.danger, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
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
    final goalName = n.payload['goal_name'] as String?;
    return switch (n.type) {
      'friend_request' => '$name отправил вам запрос в друзья',
      'friend_request_accepted' => '$name принял ваш запрос в друзья',
      'goal_collaboration_invite' =>
          goalName != null ? '$name приглашает вас к цели «$goalName»' : '$name приглашает вас к совместной работе',
      'goal_collaboration_accepted' =>
          goalName != null ? '$name принял приглашение к цели «$goalName»' : '$name принял ваше приглашение',
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
                            if (n.type != 'goal_collaboration_invite' &&
                                n.fromUser != null) {
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
    final isCollabInvite = n.type == 'goal_collaboration_invite';
    final goalId = n.payload['goal_id'] as String?;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  if (isCollabInvite && goalId != null) ...[
                    const SizedBox(height: 8),
                    _CollabInviteActions(
                      goalId: goalId,
                      notificationId: n.id,
                    ),
                  ],
                ],
              ),
            ),
            if (!n.isRead && !isCollabInvite)
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

class _CollabInviteActions extends ConsumerStatefulWidget {
  final String goalId;
  final String notificationId;
  const _CollabInviteActions(
      {required this.goalId, required this.notificationId});

  @override
  ConsumerState<_CollabInviteActions> createState() =>
      _CollabInviteActionsState();
}

class _CollabInviteActionsState extends ConsumerState<_CollabInviteActions> {
  bool _loading = false;

  Future<void> _handle(bool accept) async {
    setState(() => _loading = true);
    try {
      final collab = ref.read(goalCollaborationProvider);
      final status = accept ? 'accepted' : 'declined';
      if (accept) {
        await collab.accept(widget.goalId);
      } else {
        await collab.decline(widget.goalId);
      }
      await ref
          .read(notificationsProvider.notifier)
          .markAsRead(widget.notificationId);
      ref
          .read(notificationsProvider.notifier)
          .resolveInvite(widget.notificationId, status);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);

    // Check in-memory resolution stored in notification payload
    final notifications =
        ref.watch(notificationsProvider).valueOrNull?.notifications ?? [];
    final notif = notifications
        .cast<AppNotification?>()
        .firstWhere((n) => n?.id == widget.notificationId, orElse: () => null);
    final inviteStatus = notif?.payload['invite_status'] as String?;

    // Fallback for accepted: check if goal already appears in user's planning list
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final goals = ref.watch(planningProvider).valueOrNull?.goals ?? [];
    final isAcceptedViaPlanning = myId != null &&
        goals.any((g) => g.id == widget.goalId && g.userId != myId);

    final isAccepted = inviteStatus == 'accepted' || isAcceptedViaPlanning;
    final isDeclined = inviteStatus == 'declined';

    if (isAccepted || isDeclined) {
      final label =
          isAccepted ? 'Предложение принято' : 'Предложение отклонено';
      return Text(label,
          style: TextStyle(fontSize: 12, color: c.textSecondary));
    }

    if (_loading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Row(
      children: [
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(fontSize: 12),
          ),
          onPressed: () => _handle(true),
          child: const Text('Принять'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(fontSize: 12),
          ),
          onPressed: () => _handle(false),
          child: const Text('Отклонить'),
        ),
      ],
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
