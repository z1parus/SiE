import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'breathing_exercise_screen.dart';
import 'habit_tracker_screen.dart';
import 'profile_screen.dart';

class OperationsControlScreen extends ConsumerWidget {
  const OperationsControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);
    final profileAsync = ref.watch(userProfileProvider);

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
                          itemCount: branches.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final branch = branches[index];
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
}

void _onBranchTap(BuildContext context, Branch branch) {
  Widget? screen;

  if (branch.slug == 'breathing_practices') {
    screen = const BreathingExerciseScreen();
  } else if (branch.slug == 'habit_archive') {
    screen = const HabitTrackerScreen();
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
