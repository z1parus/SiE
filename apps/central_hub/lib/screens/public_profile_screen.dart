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
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeroSection(profile: profile),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NameSection(profile: profile),
                      const SizedBox(height: 24),
                      _StatsRow(profile: profile),
                      const SizedBox(height: 24),
                      _XpBar(profile: profile),
                      const SizedBox(height: 28),
                      const SectionHeader(title: 'AWARDS'),
                      const SizedBox(height: 16),
                      _AchievementsSection(userId: profile.id),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Back button floats above the hero
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero Section ──────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final PublicProfile profile;
  const _HeroSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image or gradient fallback
          if (profile.profileBackgroundUrl != null)
            Image.network(
              profile.profileBackgroundUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _DefaultHeroBg(),
            )
          else
            const _DefaultHeroBg(),

          // Gradient fade to background at the bottom
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  SieTheme.background.withValues(alpha: 0.4),
                  SieTheme.background,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // Avatar with frame, centered at the bottom
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: _AvatarWithFrame(profile: profile),
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultHeroBg extends StatelessWidget {
  const _DefaultHeroBg();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2A42), Color(0xFF071520)],
        ),
      ),
      child: CustomPaint(painter: _GridPainter()),
    );
  }
}

// Subtle terminal grid lines overlay for the default background
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00C8FF).withValues(alpha: 0.04)
      ..strokeWidth = 0.5;
    const step = 28.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}

// ── Avatar with Frame ─────────────────────────────────────────

class _AvatarWithFrame extends StatelessWidget {
  final PublicProfile profile;
  const _AvatarWithFrame({required this.profile});

  @override
  Widget build(BuildContext context) {
    final letter = (profile.username?.isNotEmpty == true)
        ? profile.username![0].toUpperCase()
        : '?';
    final frame = _frameDecoration(profile.avatarFrameId);

    return Container(
      width: 88,
      height: 88,
      decoration: frame,
      child: ClipOval(
        child: profile.avatarUrl != null
            ? Image.network(
                profile.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _Initials(letter: letter),
              )
            : _Initials(letter: letter),
      ),
    );
  }

  static BoxDecoration _frameDecoration(String? frameId) {
    switch (frameId) {
      case 'gold':
        return BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFD700), width: 2.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.35),
              blurRadius: 14,
              spreadRadius: 2,
            )
          ],
        );
      case 'silver':
        return BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFC0C0C0), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC0C0C0).withValues(alpha: 0.2),
              blurRadius: 8,
            )
          ],
        );
      case 'neon':
        return BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: SieTheme.accent, width: 3),
          boxShadow: [
            BoxShadow(
              color: SieTheme.accent.withValues(alpha: 0.45),
              blurRadius: 18,
              spreadRadius: 2,
            )
          ],
        );
      default:
        return BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: SieTheme.borderAccent, width: 1.5),
          color: SieTheme.surface,
        );
    }
  }
}

class _Initials extends StatelessWidget {
  final String letter;
  const _Initials({required this.letter});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: SieTheme.surface,
        child: Center(
          child: Text(
            letter,
            style: const TextStyle(
              color: SieTheme.accent,
              fontSize: 32,
              fontWeight: FontWeight.w200,
              letterSpacing: 1,
            ),
          ),
        ),
      );
}

// ── Name + Level ──────────────────────────────────────────────

class _NameSection extends StatelessWidget {
  final PublicProfile profile;
  const _NameSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final username = profile.username?.toUpperCase() ?? 'UNKNOWN';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          username,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 20,
                letterSpacing: 3,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: SieTheme.borderAccent),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            'LEVEL ${profile.level}  ·  ${profile.totalXp} XP',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  letterSpacing: 2,
                ),
          ),
        ),
      ],
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────

class _StatsRow extends ConsumerWidget {
  final PublicProfile profile;
  const _StatsRow({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(publicStatsProvider(profile.id));
    final stats = statsAsync.valueOrNull ?? PublicProfileStats.zero();

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.timer_outlined,
            value: stats.focusTime,
            label: 'КОНЦЕНТРАЦИЯ',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.checklist_outlined,
            value: stats.habitCompletions.toString(),
            label: 'ЦИКЛОВ',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.military_tech_outlined,
            value: 'LVL ${profile.level}',
            label: 'РАНГ',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatCard(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: SieTheme.surface,
        border: Border.all(color: SieTheme.borderDefault),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: SieTheme.textSecondary, size: 14),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: SieTheme.accent,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: SieTheme.textSecondary,
              fontSize: 8,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── XP Progress Bar ───────────────────────────────────────────

class _XpBar extends StatelessWidget {
  final PublicProfile profile;
  const _XpBar({required this.profile});

  @override
  Widget build(BuildContext context) {
    final xpInLevel = profile.xpInLevel;
    final progress = xpInLevel / 1000.0;
    final xpToNext = 1000 - xpInLevel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'EXPERIENCE'),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${profile.totalXp} XP TOTAL',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SieTheme.accent,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    fontSize: 11,
                  ),
            ),
            Text(
              '$xpToNext XP TO NEXT',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: SieTheme.borderDefault,
            valueColor:
                const AlwaysStoppedAnimation<Color>(SieTheme.accent),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${(progress * 100).toStringAsFixed(0)}%  ·  LVL ${profile.level} → LVL ${profile.level + 1}',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontSize: 9, letterSpacing: 1),
        ),
      ],
    );
  }
}

// ── Achievements Section ──────────────────────────────────────

class _AchievementsSection extends ConsumerWidget {
  final String userId;
  const _AchievementsSection({required this.userId});

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
        'AWARDS DATA UNAVAILABLE',
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
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 1.0,
          ),
          itemCount: achievements.length,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _showDetail(context, achievements[i]),
            child: AchievementBadge(userAchievement: achievements[i]),
          ),
        );
      },
    );
  }

  void _showDetail(BuildContext context, UserAchievement ua) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SieTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        side: BorderSide(color: SieTheme.borderDefault),
      ),
      builder: (_) => _AchievementSheet(ua: ua),
    );
  }
}

// ── Achievement Detail Sheet ──────────────────────────────────

class _AchievementSheet extends StatelessWidget {
  final UserAchievement ua;
  const _AchievementSheet({required this.ua});

  static IconData _icon(String slug) => switch (slug) {
        'first_breath'          => Icons.air,
        'streak_7'              => Icons.local_fire_department,
        'streak_30'             => Icons.whatshot,
        'habits_10'             => Icons.checklist,
        'xp_1000'               => Icons.bolt,
        'first_habit_created'   => Icons.add_task,
        'deep_focus_initiated'  => Icons.center_focus_strong,
        _                       => Icons.emoji_events,
      };

  @override
  Widget build(BuildContext context) {
    final ach = ua.achievement;
    final earned = ua.earned;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon badge
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: earned
                  ? SieTheme.accent.withValues(alpha: 0.12)
                  : SieTheme.background,
              border: Border.all(
                color: earned ? SieTheme.accent : SieTheme.borderDefault,
                width: earned ? 1.5 : 1,
              ),
              boxShadow: earned
                  ? [
                      BoxShadow(
                        color: SieTheme.accent.withValues(alpha: 0.25),
                        blurRadius: 12,
                      )
                    ]
                  : null,
            ),
            child: Icon(
              _icon(ach.slug),
              color: earned ? SieTheme.accent : SieTheme.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            ach.name.toUpperCase(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          // Description
          if (ach.description != null) ...[
            Text(
              ach.description!,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 12),
          ],

          // Neon divider
          Container(height: 1, color: SieTheme.borderAccent.withValues(alpha: 0.4)),
          const SizedBox(height: 12),

          // XP reward + status row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bolt, color: SieTheme.accent, size: 14),
              const SizedBox(width: 4),
              Text(
                '+${ach.xpReward} XP',
                style: const TextStyle(
                  color: SieTheme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: earned
                        ? SieTheme.accent
                        : SieTheme.textSecondary,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  earned ? 'ПОЛУЧЕНО' : 'НЕ ПОЛУЧЕНО',
                  style: TextStyle(
                    color: earned
                        ? SieTheme.accent
                        : SieTheme.textSecondary,
                    fontSize: 9,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          if (earned && ua.earnedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'ДАТА: ${_formatDate(ua.earnedAt!)}',
              style: const TextStyle(
                color: SieTheme.textSecondary,
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}
