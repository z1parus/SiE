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
      'meditation'          => const _MeditationPreview(),
      _                     => const SizedBox.shrink(),
    };
  }

  String _statusLabel(WidgetRef ref) {
    switch (branch.slug) {
      case 'habit_archive':
        final habitsState = ref.watch(habitsProvider).valueOrNull;
        final streak = habitsState == null || habitsState.streaks.isEmpty
            ? 0
            : habitsState.streaks.values.reduce(math.max);
        if (streak > 0) return '🔥 $streak DAY STREAK';
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

  static const _size = 130.0;
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
                        color: const Color(0xFFC8A84B).withValues(
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

/// Consistency heatmap preview: a GitHub-style contribution grid (7 weekday rows
/// × 6 week columns, bottom-right = today) where each cell's gold intensity is
/// that day's habit-completion ratio (done / scheduled), with a flame badge for
/// the current best streak. Cells cascade in on appear, a faint shimmer sweeps
/// the grid, and today's cell gently pulses.
class _HabitMatrixPreview extends ConsumerStatefulWidget {
  const _HabitMatrixPreview();

  @override
  ConsumerState<_HabitMatrixPreview> createState() =>
      _HabitMatrixPreviewState();
}

class _HabitMatrixPreviewState extends ConsumerState<_HabitMatrixPreview>
    with TickerProviderStateMixin {
  static const _rows = 7; // weekdays Mon..Sun
  static const _cols = 6; // 6 weeks

  late final AnimationController _intro; // one-shot cascade
  late final AnimationController _loop;  // shimmer + today pulse

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SieMotion.enabled(context)) {
      if (_intro.status == AnimationStatus.dismissed) _intro.forward();
      if (!_loop.isAnimating) _loop.repeat();
    } else {
      _intro.value = 1;
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  /// Builds the [_rows]×[_cols] intensity grid (0..1), the today cell position
  /// and the best current streak from live habit data.
  ({List<double> cells, int todayRow, int todayCol, int streak}) _model(
    HabitsState? s,
  ) {
    final cells = List<double>.filled(_rows * _cols, -1); // -1 = future/none
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayRow = today.weekday - 1; // Mon=0 .. Sun=6

    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    if (s != null && s.habits.isNotEmpty) {
      for (var col = 0; col < _cols; col++) {
        for (var row = 0; row < _rows; row++) {
          final offset = (_cols - 1 - col) * 7 + (todayRow - row);
          if (offset < 0) continue; // future cell — leave as -1
          final d = today.subtract(Duration(days: offset));
          final key = fmt(d);
          var done = 0;
          for (final h in s.habits) {
            if (s.logDates[h.id]?.contains(key) ?? false) done++;
          }
          final scheduled = s.dueOn(d).length;
          final intensity = scheduled > 0
              ? (done / scheduled).clamp(0.0, 1.0)
              : (done > 0 ? 1.0 : 0.0);
          cells[row * _cols + col] = intensity;
        }
      }
    } else {
      // No habits — render an empty (but valid) past grid.
      for (var col = 0; col < _cols; col++) {
        for (var row = 0; row < _rows; row++) {
          final offset = (_cols - 1 - col) * 7 + (todayRow - row);
          if (offset >= 0) cells[row * _cols + col] = 0.0;
        }
      }
    }

    final streak = (s == null || s.streaks.isEmpty)
        ? 0
        : s.streaks.values.reduce(math.max);
    return (cells: cells, todayRow: todayRow, todayCol: _cols - 1, streak: streak);
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    final s = ref.watch(habitsProvider).valueOrNull;
    final m = _model(s);

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_intro, _loop]),
                builder: (_, _) => CustomPaint(
                  painter: _HabitHeatmapPainter(
                    cells: m.cells,
                    rows: _rows,
                    cols: _cols,
                    todayRow: m.todayRow,
                    todayCol: m.todayCol,
                    intro: _intro.value,
                    loop: _loop.value,
                    accent: c.accent,
                    track: c.border,
                  ),
                ),
              ),
            ),
            if (m.streak > 0)
              Positioned(
                top: -6,
                right: -8,
                child: _FlameBadge(streak: m.streak, loop: _loop, c: c),
              ),
          ],
        ),
      ),
    );
  }
}

class _FlameBadge extends StatelessWidget {
  const _FlameBadge({required this.streak, required this.loop, required this.c});

  final int streak;
  final Animation<double> loop;
  final SieColors c;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loop,
      builder: (_, _) {
        // Subtle flicker on the flame glyph.
        final flick = 0.85 + 0.15 * math.sin(loop.value * 2 * math.pi * 3);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.accent.withValues(alpha: 0.40)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: flick.clamp(0.0, 1.0),
                child: Text('🔥', style: const TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 3),
              Text(
                '$streak',
                style: TextStyle(
                  color: c.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HabitHeatmapPainter extends CustomPainter {
  final List<double> cells;
  final int rows;
  final int cols;
  final int todayRow;
  final int todayCol;
  final double intro;
  final double loop;
  final Color accent;
  final Color track;

  const _HabitHeatmapPainter({
    required this.cells,
    required this.rows,
    required this.cols,
    required this.todayRow,
    required this.todayCol,
    required this.intro,
    required this.loop,
    required this.accent,
    required this.track,
  });

  // Discrete heatmap levels → alpha.
  static double _alphaFor(double intensity) {
    if (intensity <= 0) return 0.0;
    if (intensity < 0.34) return 0.35;
    if (intensity < 0.67) return 0.55;
    if (intensity < 1.0) return 0.78;
    return 1.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 4.0;
    final cellW = (size.width - gap * (cols - 1)) / cols;
    final cellH = (size.height - gap * (rows - 1)) / rows;
    final cell = math.min(cellW, cellH);
    // Centre the grid within the available box.
    final gridW = cell * cols + gap * (cols - 1);
    final gridH = cell * rows + gap * (rows - 1);
    final ox = (size.width - gridW) / 2;
    final oy = (size.height - gridH) / 2;
    final radius = Radius.circular(cell * 0.28);
    final maxDiag = (rows - 1) + (cols - 1);

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final v = cells[row * cols + col];
        if (v < 0) continue; // future cell

        // Cascade appearance: diagonal wave past → today.
        final delay = ((row + col) / maxDiag) * 0.65;
        final appear = ((intro - delay) / 0.35).clamp(0.0, 1.0);
        if (appear <= 0) continue;

        final left = ox + col * (cell + gap);
        final top = oy + row * (cell + gap);
        final scale = 0.6 + 0.4 * appear;
        final inset = cell * (1 - scale) / 2;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left + inset, top + inset, cell * scale, cell * scale),
          radius,
        );

        var alpha = _alphaFor(v);

        // Faint diagonal shimmer sweeping across the grid.
        final diag = (row + col) / maxDiag;
        final band = 1 - (((diag - loop) % 1.0).abs() * 3).clamp(0.0, 1.0);
        final shimmer = band * 0.12;

        // Today cell breathes.
        final isToday = row == todayRow && col == todayCol;
        final pulse =
            isToday ? 0.18 * (0.5 + 0.5 * math.sin(loop * 2 * math.pi)) : 0.0;

        final paint = Paint();
        if (alpha <= 0) {
          paint.color = track.withValues(alpha: (0.45 + shimmer) * appear);
        } else {
          alpha = (alpha + shimmer + pulse).clamp(0.0, 1.0);
          paint.color = accent.withValues(alpha: alpha * appear);
        }
        canvas.drawRRect(rect, paint);

        if (isToday) {
          canvas.drawRRect(
            rect,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = accent.withValues(alpha: 0.85 * appear),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_HabitHeatmapPainter old) =>
      old.intro != intro ||
      old.loop != loop ||
      old.cells != cells ||
      old.accent != accent ||
      old.track != track;
}

/// Live focus-timer preview. Reflects the real [focusTimerProvider] state:
/// idle shows the configured work minutes + a slow "radar" standby tick; an
/// active session shows live MM:SS, a progress arc with a glowing leading tip,
/// a phase colour (gold = work, cool = break) and a minute ripple. A row of
/// dots underneath tracks today's completed pomodoros (target 4).
class _FocusRingPreview extends ConsumerStatefulWidget {
  const _FocusRingPreview();

  @override
  ConsumerState<_FocusRingPreview> createState() => _FocusRingPreviewState();
}

class _FocusRingPreviewState extends ConsumerState<_FocusRingPreview>
    with SingleTickerProviderStateMixin {
  static const _ring = 116.0;
  static const _sessionTarget = 4;

  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SieMotion.enabled(context)) {
      if (!_loop.isAnimating) _loop.repeat();
    } else {
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    final s = ref.watch(focusTimerProvider);
    final doneToday = ref
            .watch(bootcampDailyActivityProvider)
            .valueOrNull
            ?.focusSessionsToday ??
        0;
    final motion = SieMotion.enabled(context);

    final idle = s.phase == FocusPhase.idle;
    final isBreak = s.phase == FocusPhase.breakTime;
    final timeText = idle ? '${s.settings.workMinutes}:00' : s.formattedTime;
    final label = idle ? 'READY' : (isBreak ? 'BREAK' : 'WORK');
    final progress = idle ? 0.0 : s.progress;
    final phase = isBreak ? c.focusBreak : c.accent;
    final phase2 = isBreak ? c.focusBreak : c.accentSecondary;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _ring,
            height: _ring,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _loop,
                  builder: (_, _) {
                    final breathe = motion
                        ? 0.97 + 0.03 * (0.5 + 0.5 * math.sin(_loop.value * 2 * math.pi))
                        : 1.0;
                    return Transform.scale(
                      scale: breathe,
                      child: CustomPaint(
                        size: const Size(_ring, _ring),
                        painter: _FocusRingPainter(
                          progress: progress,
                          loop: _loop.value,
                          idle: idle,
                          motion: motion,
                          track: c.border,
                          phase: phase,
                          phase2: phase2,
                          glow: !c.isLightMode,
                        ),
                      ),
                    );
                  },
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeText,
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
                      label,
                      style: TextStyle(
                        color: idle ? c.iconMuted : phase,
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
          const SizedBox(height: 10),
          _SessionDots(
            done: doneToday,
            target: _sessionTarget,
            color: phase,
            track: c.border,
            loop: _loop,
            motion: motion,
          ),
        ],
      ),
    );
  }
}

class _SessionDots extends StatelessWidget {
  const _SessionDots({
    required this.done,
    required this.target,
    required this.color,
    required this.track,
    required this.loop,
    required this.motion,
  });

  final int done;
  final int target;
  final Color color;
  final Color track;
  final Animation<double> loop;
  final bool motion;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loop,
      builder: (_, _) {
        final pulse = motion ? 0.4 + 0.6 * (0.5 + 0.5 * math.sin(loop.value * 2 * math.pi)) : 1.0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(target, (i) {
            final filled = i < done;
            final isNext = i == done && done < target;
            final dotColor = filled
                ? color
                : isNext
                    ? color.withValues(alpha: 0.25 + 0.45 * pulse)
                    : track;
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
            );
          }),
        );
      },
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool idle;
  final bool motion;
  final Color track;
  final Color phase;
  final Color phase2;
  final bool glow;

  const _FocusRingPainter({
    required this.progress,
    required this.loop,
    required this.idle,
    required this.motion,
    required this.track,
    required this.phase,
    required this.phase2,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 9;
    final bounds = Rect.fromCircle(center: center, radius: radius);

    // Track.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track.withValues(alpha: idle ? 0.5 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );

    // Running minute ripple — expanding ring fading out.
    if (!idle && motion) {
      final rr = radius * (0.62 + 0.5 * loop);
      canvas.drawCircle(
        center,
        rr,
        Paint()
          ..color = phase.withValues(alpha: (1 - loop) * 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    // Progress arc + glowing leading tip.
    if (progress > 0) {
      final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
      canvas.drawArc(
        bounds,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [phase2, phase],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );

      final tipAngle = -math.pi / 2 + sweep;
      final tip = center +
          Offset(math.cos(tipAngle), math.sin(tipAngle)) * radius;
      final pulseR = 4 + (motion ? 1.6 * (0.5 + 0.5 * math.sin(loop * 2 * math.pi)) : 0.0);
      final tipPaint = Paint()..color = phase;
      if (glow) {
        tipPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      }
      canvas.drawCircle(tip, pulseR, tipPaint);
    }

    // Idle standby — a single glowing tick sweeping the track like radar.
    if (idle && motion) {
      final ang = -math.pi / 2 + loop * 2 * math.pi;
      final p = center + Offset(math.cos(ang), math.sin(ang)) * radius;
      final tickPaint = Paint()..color = phase.withValues(alpha: 0.9);
      if (glow) {
        tickPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      }
      canvas.drawCircle(p, 3.5, tickPaint);
    }
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.progress != progress ||
      old.loop != loop ||
      old.idle != idle ||
      old.motion != motion ||
      old.track != track ||
      old.phase != phase ||
      old.phase2 != phase2 ||
      old.glow != glow;
}

/// Mission-progress preview: one rotating ring per active goal. Each ring's
/// arc length encodes that goal's real progress and its colour is the goal's
/// own colour. The rings spin clockwise "like clock hands" but at staggered
/// speeds (2 / 3 / 5 turns per loop) so they never move in sync. The centre
/// shows the average progress across the displayed missions.
class _PlanningPreview extends ConsumerStatefulWidget {
  const _PlanningPreview();

  @override
  ConsumerState<_PlanningPreview> createState() => _PlanningPreviewState();
}

class _PlanningPreviewState extends ConsumerState<_PlanningPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Per-ring geometry and motion. Revolutions per loop are distinct and
  // coprime so the composite motion looks chaotic yet loops seamlessly.
  // Radii are spread wide so the centre stays clear for the progress readout.
  static const _box    = 150.0;
  static const _radii  = [42.0, 58.0, 72.0];
  static const _stroke = [6.0, 5.5, 5.0];
  static const _revs   = [2.0, 3.0, 5.0];
  static const _phase  = [0.0, 2.1, 4.0];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
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
    final rings = List.generate(3, (i) {
      final goal = i < shown.length ? shown[i] : null;
      return _PlanRing(
        radius: _radii[i],
        stroke: _stroke[i],
        revs: _revs[i],
        phase: _phase[i],
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
                  rings: rings,
                  t: _ctrl.value,
                  trackColor: c.border,
                  tickColor: c.accent.withValues(alpha: 0.30),
                  glow: !c.isLightMode,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                const SizedBox(height: 3),
                Text(
                  'PROGRESS',
                  style: TextStyle(
                    color: c.iconMuted,
                    fontSize: 8,
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

class _PlanRing {
  final double radius;
  final double stroke;
  final double revs;
  final double phase;
  final Color color;

  /// Real goal progress 0..1, or null when no goal occupies this ring.
  final double? progress;

  const _PlanRing({
    required this.radius,
    required this.stroke,
    required this.revs,
    required this.phase,
    required this.color,
    required this.progress,
  });
}

class _PlanningPreviewPainter extends CustomPainter {
  final List<_PlanRing> rings;
  final double t;
  final Color trackColor;
  final Color tickColor;
  final bool glow;

  const _PlanningPreviewPainter({
    required this.rings,
    required this.t,
    required this.trackColor,
    required this.tickColor,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    for (final ring in rings) {
      final rect = Rect.fromCircle(center: center, radius: ring.radius);

      // Faint full-circle track.
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..color = trackColor.withValues(alpha: 0.45)
          ..strokeWidth = ring.stroke
          ..style = PaintingStyle.stroke,
      );

      // Clockwise rotation, staggered per ring → "clock hands" out of sync.
      final start = -math.pi / 2 + ring.phase + 2 * math.pi * ring.revs * t;

      if (ring.progress == null) {
        // Empty ring — a small accent tick keeps it alive.
        canvas.drawArc(
          rect,
          start,
          0.05 * 2 * math.pi,
          false,
          Paint()
            ..color = tickColor
            ..strokeWidth = ring.stroke
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }

      final sweep = math.max(ring.progress!, 0.05) * 2 * math.pi;
      final arcPaint = Paint()
        ..color = ring.color
        ..strokeWidth = ring.stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      if (glow) {
        arcPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      }
      canvas.drawArc(rect, start, sweep, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(_PlanningPreviewPainter old) =>
      old.t != t ||
      old.rings != rings ||
      old.trackColor != trackColor ||
      old.tickColor != tickColor ||
      old.glow != glow;
}

/// Meditation module preview — a calm teal orb that slowly breathes while
/// concentric "clarity" ripples radiate outward (the Дефрагментация motif).
class _MeditationPreview extends StatefulWidget {
  const _MeditationPreview();

  @override
  State<_MeditationPreview> createState() => _MeditationPreviewState();
}

class _MeditationPreviewState extends State<_MeditationPreview>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _rippleCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 150,
        height: 150,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulse, _rippleCtrl]),
          builder: (_, _) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Expanding clarity ripples
                CustomPaint(
                  size: const Size(150, 150),
                  painter: _MeditationRipplePainter(progress: _rippleCtrl.value),
                ),
                // Central breathing orb
                Transform.scale(
                  scale: _pulse.value,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow halo
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: kRimTeal.withValues(alpha: 0.28),
                              blurRadius: 26,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      // Core
                      Container(
                        width: 70,
                        height: 70,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [kRimTealLight, kRimTeal, kRimTealDark],
                            stops: [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                      // Rim highlight
                      CustomPaint(
                        size: const Size(74, 74),
                        painter: SphereRimPainter(
                          lightAngle: -math.pi / 4,
                          intensity: 0.6,
                          isDark: true,
                          rimGold: kRimTeal,
                          rimBronze: kRimTealDark,
                          rimLight: kRimTealLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MeditationRipplePainter extends CustomPainter {
  final double progress; // 0..1, repeating
  const _MeditationRipplePainter({required this.progress});

  static const _count = 3;
  static const _minRadius = 36.0;
  static const _maxRadius = 72.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < _count; i++) {
      final t = (progress + i / _count) % 1.0;
      final radius = _minRadius + (_maxRadius - _minRadius) * t;
      final alpha = (1.0 - t) * 0.32;
      if (alpha <= 0.01) continue;
      final paint = Paint()
        ..color = kRimTeal.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_MeditationRipplePainter old) => old.progress != progress;
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
