import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

class PublicProfileScreen extends ConsumerWidget {
  final PublicProfile profile;
  const PublicProfileScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: SieTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(profile: profile),
                    const SizedBox(height: 32),
                    _XpSection(profile: profile),
                    const SizedBox(height: 32),
                    const SectionHeader(title: 'AWARDS'),
                    const SizedBox(height: 16),
                    _AchievementsGrid(userId: profile.id),
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
            icon: const Icon(Icons.arrow_back_ios_new,
                color: SieTheme.textSecondary, size: 18),
          ),
          Expanded(
            child: Text(
              'PERSONNEL FILE',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ── Header (avatar + name + level) ───────────────────────────

class _Header extends StatelessWidget {
  final PublicProfile profile;
  const _Header({required this.profile});

  @override
  Widget build(BuildContext context) {
    final username = profile.username?.toUpperCase() ?? 'UNKNOWN';
    final letter = username.isNotEmpty ? username[0] : '?';

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
            child: profile.avatarUrl != null
                ? Image.network(
                    profile.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _Initials(letter: letter),
                  )
                : _Initials(letter: letter),
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
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: SieTheme.borderAccent),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  'LEVEL ${profile.level}',
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

class _Initials extends StatelessWidget {
  final String letter;
  const _Initials({required this.letter});

  @override
  Widget build(BuildContext context) => Center(
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

// ── XP Progress Bar ───────────────────────────────────────────

class _XpSection extends StatelessWidget {
  final PublicProfile profile;
  const _XpSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final xp = profile.totalXp;
    final level = profile.level;
    final xpInLevel = profile.xpInLevel;
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
            valueColor:
                const AlwaysStoppedAnimation<Color>(SieTheme.accent),
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

// ── Achievements Grid ─────────────────────────────────────────

class _AchievementsGrid extends ConsumerWidget {
  final String userId;
  const _AchievementsGrid({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achAsync = ref.watch(publicAchievementsProvider(userId));

    return achAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(
              color: SieTheme.accent, strokeWidth: 1.5),
        ),
      ),
      error: (_, _) => const Text(
        'NO AWARDS DATA',
        style: TextStyle(
            color: SieTheme.textSecondary, fontSize: 11, letterSpacing: 1),
      ),
      data: (achievements) {
        if (achievements.isEmpty) {
          return const Text(
            'NO AWARDS YET',
            style: TextStyle(
                color: SieTheme.textSecondary,
                fontSize: 11,
                letterSpacing: 1),
          );
        }
        return SizedBox(
          width: double.infinity,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.0,
            ),
            itemCount: achievements.length,
            itemBuilder: (_, i) =>
                AchievementBadge(userAchievement: achievements[i]),
          ),
        );
      },
    );
  }
}
