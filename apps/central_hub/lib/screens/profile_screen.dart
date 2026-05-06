import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'edit_profile_screen.dart';
import 'knowledge_base_screen.dart';
import 'progress_analytics_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: SieTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopBar(),
            Expanded(
              child: profileAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: SieTheme.accent,
                    strokeWidth: 1.5,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'ERROR: $e',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
                data: (profile) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderSection(profile: profile),
                      const SizedBox(height: 32),
                      _XpSection(profile: profile),
                      const SizedBox(height: 24),
                      const _ProgressHubButton(),
                      const SizedBox(height: 10),
                      const _KnowledgeBaseButton(),
                      const SizedBox(height: 32),
                      const SectionHeader(title: 'AWARDS'),
                      const SizedBox(height: 16),
                      const _AchievementsGrid(),
                    ],
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

// ── Top Bar ───────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: SieTheme.textSecondary,
              size: 18,
            ),
          ),
          Expanded(
            child: Text(
              'PERSONNEL FILE',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (_, _, _) => const EditProfileScreen(),
                transitionsBuilder: (_, anim, _, child) =>
                    FadeTransition(opacity: anim, child: child),
                transitionDuration: const Duration(milliseconds: 300),
              ),
            ),
            icon: const Icon(
              Icons.edit_outlined,
              color: SieTheme.textSecondary,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header (avatar + name + level) ───────────────────────────

class _HeaderSection extends StatelessWidget {
  final Profile? profile;
  const _HeaderSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final username = profile?.username?.toUpperCase() ?? 'UNKNOWN';
    final letter = username.isNotEmpty ? username[0] : '?';
    final xp = profile?.totalXp ?? 0;
    final level = (xp ~/ 1000) + 1;

    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: SieTheme.borderAccent, width: 1.5),
            color: SieTheme.surface,
          ),
          child: ClipOval(
            child: profile?.avatarUrl != null
                ? Image.network(
                    profile!.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _AvatarLetter(letter: letter),
                  )
                : _AvatarLetter(letter: letter),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: SieTheme.borderAccent),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  'LEVEL $level',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarLetter extends StatelessWidget {
  final String letter;
  const _AvatarLetter({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          color: SieTheme.accent,
          fontSize: 28,
          fontWeight: FontWeight.w200,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ── XP Progress Bar ───────────────────────────────────────────

class _XpSection extends StatelessWidget {
  final Profile? profile;
  const _XpSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final xp = profile?.totalXp ?? 0;
    final level = (xp ~/ 1000) + 1;
    final xpInLevel = xp % 1000;
    final progress = xpInLevel / 1000.0;
    final xpToNext = 1000 - xpInLevel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'EXPERIENCE'),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$xp XP TOTAL',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SieTheme.accent,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    fontSize: 12,
                  ),
            ),
            Text(
              '$xpToNext XP TO NEXT LEVEL',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: SieTheme.borderDefault,
            valueColor: const AlwaysStoppedAnimation<Color>(SieTheme.accent),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${(progress * 100).toStringAsFixed(0)}%  ·  LVL $level → LVL ${level + 1}',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontSize: 10, letterSpacing: 1),
        ),
      ],
    );
  }
}

// ── Progress Hub Button ───────────────────────────────────────

class _ProgressHubButton extends StatelessWidget {
  const _ProgressHubButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const ProgressAnalyticsScreen(),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: SieTheme.surface,
          border: Border.all(color: SieTheme.borderAccent),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SieTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.analytics_outlined,
                color: SieTheme.accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PROGRESS HUB',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Activity matrix, XP growth & focus stats',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                          color: SieTheme.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: SieTheme.borderAccent,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Knowledge Base Button ─────────────────────────────────────

class _KnowledgeBaseButton extends StatelessWidget {
  const _KnowledgeBaseButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const KnowledgeBaseScreen(),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: SieTheme.surface,
          border: Border.all(color: SieTheme.borderDefault),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SieTheme.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: SieTheme.accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'БАЗА ЗНАНИЙ',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Физиология, психология, XP-таблица и этика SiE',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                          color: SieTheme.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: SieTheme.borderAccent,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Achievements Grid ─────────────────────────────────────────

class _AchievementsGrid extends ConsumerWidget {
  const _AchievementsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsAsync = ref.watch(userAchievementsProvider);

    return achievementsAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(
            color: SieTheme.accent,
            strokeWidth: 1.5,
          ),
        ),
      ),
      error: (_, _) => const Text(
        'NO ACHIEVEMENTS DEFINED IN DATABASE',
        style: TextStyle(
          color: SieTheme.textSecondary,
          fontSize: 11,
          letterSpacing: 1,
        ),
      ),
      data: (achievements) {
        if (achievements.isEmpty) {
          return const Text(
            'NO AWARDS YET — COMPLETE MISSIONS TO EARN MEDALS',
            style: TextStyle(
              color: SieTheme.textSecondary,
              fontSize: 11,
              letterSpacing: 1,
            ),
          );
        }
        return SizedBox(
          width: double.infinity,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.0,
            ),
            itemCount: achievements.length,
            itemBuilder: (_, i) => AchievementBadge(userAchievement: achievements[i]),
          ),
        );
      },
    );
  }
}
