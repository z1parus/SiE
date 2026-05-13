import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'breathing_exercise_screen.dart';
import 'focus_protocol_screen.dart';
import 'habit_tracker_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'user_search_screen.dart';

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
    final profileAsync = ref.watch(userProfileProvider);

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

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),
              _ScreenHeader(profileAsync: profileAsync, ref: ref),
              const SizedBox(height: 32),
              const SectionHeader(title: 'DEPARTMENTS'),
              const SizedBox(height: 16),
              _LeaderboardTile(),
              const SizedBox(height: 12),
              Expanded(
                child: branchesAsync.when(
                  data: (branches) => branches.isEmpty
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
                      : ListView.separated(
                          itemCount: branches
                              .where((b) => b.slug != 'progress_hub')
                              .length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final filtered = branches
                                .where((b) => b.slug != 'progress_hub')
                                .toList();
                            final branch = filtered[index];
                            return BranchCard(
                              name: branch.name,
                              description: branch.description,
                              onTap: () => _onBranchTap(context, branch),
                            );
                          },
                        ),
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
            ],
          ),
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

// ── Welcome Dialog ────────────────────────────────────────────

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
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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
    final name =
        widget.profile.username?.toUpperCase() ?? 'OPERATIVE';

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
              // Header bar
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 16,
                    color: SieTheme.accent,
                  ),
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
                'Вы успешно вошли в систему Корпорации SiE. Все протоколы активированы. Выполняйте задания, фиксируйте прогресс и получайте опыт.\n\nМиссия начинается сейчас.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                    ),
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
                    child: Text(
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

// ── Branch navigation ─────────────────────────────────────────

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

// ── Leaderboard Tile ──────────────────────────────────────────

class _LeaderboardTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const LeaderboardScreen(),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: SieTheme.surface,
          border: Border.all(color: const Color(0xFFFF8C42).withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF8C42).withValues(alpha: 0.07),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
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
                      color: Color(0xFFFF8C42),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Рейтинг активности за текущий цикл',
                    style: TextStyle(
                      color: SieTheme.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFFF8C42),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Screen Header ─────────────────────────────────────────────

class _ScreenHeader extends StatelessWidget {
  final AsyncValue<Profile?> profileAsync;
  final WidgetRef ref;

  const _ScreenHeader({required this.profileAsync, required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final operative = profileAsync.when(
      data: (p) => p?.username?.toUpperCase() ?? 'UNIDENTIFIED',
      loading: () => '...',
      error: (_, _) => 'UNKNOWN',
    );
    final xp = profileAsync.valueOrNull?.totalXp ?? 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OPERATIONS CONTROL',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
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
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: SieTheme.borderAccent),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text('$xp XP', style: theme.textTheme.labelSmall),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right,
                      color: SieTheme.borderAccent,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
          onPressed: () async => await SupabaseService.signOut(),
          icon: const Icon(
            Icons.logout,
            color: SieTheme.textSecondary,
            size: 20,
          ),
          tooltip: 'SIGN OUT',
        ),
      ],
    );
  }
}
