import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

import 'edit_profile_screen.dart';
import 'friends_list_screen.dart';
import 'knowledge_base_screen.dart';
import 'progress_analytics_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProfileScreen
// ─────────────────────────────────────────────────────────────────────────────
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.asTab = false});

  final bool asTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c            = ref.watch(sieColorsProvider);
    final profileAsync = ref.watch(userProfileProvider);

    final body = SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopBar(showBackButton: !asTab),
          Expanded(
            child: profileAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: c.accent,
                  strokeWidth: 1.5,
                ),
              ),
              error: (e, _) => const Center(
                child: _NoConnectionMessage(),
              ),
              data: (profile) => _ProfileContent(profile: profile),
            ),
          ),
        ],
      ),
    );

    if (asTab) {
      return Scaffold(backgroundColor: Colors.transparent, body: body);
    }

    return SieBackground(
      child: Scaffold(backgroundColor: Colors.transparent, body: body),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({required this.showBackButton});
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          if (showBackButton)
            _GlassCircleButton(
              icon: Icons.arrow_back_ios_new,
              onTap: () => Navigator.of(context).pop(),
            )
          else
            const SizedBox(width: 36),
          Expanded(
            child: Text(
              'PERSONNEL FILE',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    letterSpacing: 2,
                  ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GlassCircleButton(
                icon: Icons.people_outlined,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const FriendsListScreen()),
                ),
              ),
              const SizedBox(width: 8),
              _GlassCircleButton(
                icon: Icons.edit_outlined,
                onTap: () => Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (_, _, _) => const EditProfileScreen(),
                    transitionsBuilder: (_, anim, _, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 300),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlassCircleButton extends ConsumerWidget {
  const _GlassCircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c    = ref.watch(sieColorsProvider);
    final child = Center(
      child: Icon(icon, color: c.textSecondary, size: 15),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: c.flatCard(radius: 18),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scrollable profile body
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.profile});
  final Profile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c            = ref.watch(sieColorsProvider);
    final frames       = ref.watch(avatarFramesProvider).valueOrNull ?? [];
    final backgrounds  = ref.watch(profileBackgroundsProvider).valueOrNull ?? [];
    final styles       = ref.watch(statStylesProvider).valueOrNull ?? [];
    final patterns     = ref.watch(profilePatternsProvider).valueOrNull ?? [];

    final equipped = EquippedAssets.resolve(
      frames:       frames,
      backgrounds:  backgrounds,
      styles:       styles,
      patterns:     patterns,
      frameId:      profile?.equippedFrameId,
      backgroundId: profile?.equippedBackgroundId,
      styleId:      profile?.equippedStatStyleId,
      patternId:    profile?.equippedPatternId,
    );

    final xp    = profile?.totalXp ?? 0;
    final level = (xp ~/ 1000) + 1;

    return Stack(
      children: [
        RepaintBoundary(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userProfileProvider);
              ref.invalidate(userAchievementsProvider);
              await ref.read(userProfileProvider.future);
            },
            color: c.accent,
            backgroundColor: c.isLightMode ? Colors.white : const Color(0xFF0D1B2A),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileHeroCard(
                    username: profile?.username ?? '',
                    avatarUrl: profile?.avatarUrl,
                    totalXp: xp,
                    designPoints: profile?.designPoints ?? 0,
                    frame: equipped.frame,
                    background: equipped.background,
                    pattern: equipped.pattern,
                    avatarSize: 72,
                    onAvatarTap: () => Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (_, _, _) => const EditProfileScreen(),
                        transitionsBuilder: (_, anim, _, child) =>
                            FadeTransition(opacity: anim, child: child),
                        transitionDuration: const Duration(milliseconds: 300),
                      ),
                    ),
                  ),
                  if (equipped.statStyle != null) ...[
                    const SizedBox(height: 12),
                    _StatStyleCard(
                      statStyle: equipped.statStyle!,
                      level: level,
                      xp: xp,
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Progress Hub + База Знаний — square 2-column grid
                  Row(
                    children: [
                      Expanded(
                        child: _SquareNavButton(
                          icon: Icons.analytics_outlined,
                          label: 'PROGRESS HUB',
                          iconColor: c.accent,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ProgressAnalyticsScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SquareNavButton(
                          icon: Icons.menu_book_rounded,
                          label: 'БАЗА ЗНАНИЙ',
                          iconColor: c.accent,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const KnowledgeBaseScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const SectionHeader(title: 'AWARDS'),
                  const SizedBox(height: 16),
                  const _AchievementsGrid(),
                  const SizedBox(height: 28),
                  const SectionHeader(title: 'MEDALS VAULT'),
                const SizedBox(height: 4),
                Text(
                  'EARNED COMMENDATIONS & COMBAT DECORATIONS',
                  style: TextStyle(
                    color: c.textSecondary.withValues(alpha: 0.55),
                    fontSize: 9,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                const _MedalsVault(),
                const SizedBox(height: 96),
              ],
            ),
          ),
        ),
      ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Equipped stat-style card
// ─────────────────────────────────────────────────────────────────────────────
class _StatStyleCard extends ConsumerWidget {
  const _StatStyleCard({
    required this.statStyle,
    required this.level,
    required this.xp,
  });
  final CosmeticAsset statStyle;
  final int level;
  final int xp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c       = ref.watch(sieColorsProvider);
    final accent  = statStyle.accentColor;
    final glowCol = c.isLightMode ? null : statStyle.styleGlowColor;
    final glowRad = statStyle.styleGlowRadius;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: statStyle.buildStatCardDecoration(surfaceColor: c.surface, isLightMode: c.isLightMode),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, color: accent, size: 14),
          const SizedBox(width: 8),
          Text(
            'LEVEL $level  ·  $xp XP',
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              shadows: glowCol != null && glowRad > 0
                  ? [Shadow(color: glowCol, blurRadius: glowRad)]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Square Nav Button — used for Progress Hub / База Знаний side-by-side pair
// ─────────────────────────────────────────────────────────────────────────────
class _SquareNavButton extends ConsumerWidget {
  const _SquareNavButton({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: c.subtleContainer(radius: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
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
// Achievements grid (regular unlockable achievements)
// ─────────────────────────────────────────────────────────────────────────────
class _AchievementsGrid extends ConsumerWidget {
  const _AchievementsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c                 = ref.watch(sieColorsProvider);
    final achievementsAsync = ref.watch(userAchievementsProvider);

    return achievementsAsync.when(
      loading: () => SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(color: c.accent, strokeWidth: 1.5),
        ),
      ),
      error: (_, _) => Text(
        'NO ACHIEVEMENTS DEFINED IN DATABASE',
        style: TextStyle(color: c.textSecondary, fontSize: 11, letterSpacing: 1),
      ),
      data: (achievements) {
        if (achievements.isEmpty) {
          return Text(
            'NO ACHIEVEMENTS YET',
            style: TextStyle(color: c.textSecondary, fontSize: 11, letterSpacing: 1),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.88,
          ),
          itemCount: achievements.length,
          itemBuilder: (_, i) => AchievementBadge(userAchievement: achievements[i]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Medals Vault — 3-column mission medals grid
// ─────────────────────────────────────────────────────────────────────────────
class _MedalsVault extends ConsumerWidget {
  const _MedalsVault();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c           = ref.watch(sieColorsProvider);
    final medalsAsync = ref.watch(missionMedalsProvider);

    return medalsAsync.when(
      loading: () => SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(color: c.accent, strokeWidth: 1.5),
        ),
      ),
      error: (_, _) => Text(
        'ОШИБКА ЗАГРУЗКИ МЕДАЛЕЙ',
        style: TextStyle(color: c.textSecondary, fontSize: 11, letterSpacing: 1),
      ),
      data: (medals) {
        if (medals.isEmpty) {
          return Text(
            'NO MEDALS YET — COMPLETE MISSIONS TO EARN COMMENDATIONS',
            style:
                TextStyle(color: c.textSecondary, fontSize: 11, letterSpacing: 1),
          );
        }

        // Group by type (category + level); vanguard medals grouped separately
        final Map<String, List<MissionMedal>> groupMap = {};
        for (final medal in medals) {
          final key = medal.isVanguard
              ? 'vanguard_${medal.level}'
              : '${medal.category?.name ?? '_'}_${medal.level}';
          groupMap.putIfAbsent(key, () => []).add(medal);
        }
        // Higher level first
        final groups = groupMap.values.toList()
          ..sort((a, b) => b.first.level.compareTo(a.first.level));

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemCount: groups.length,
          itemBuilder: (_, i) {
            final group = groups[i];
            return MissionMedalBadge(
              medal: group.first,
              count: group.length,
              onTap: () => group.length == 1
                  ? _showMedalSheet(context, group.first, c)
                  : _showMedalGroupSheet(context, group, c),
            );
          },
        );
      },
    );
  }

  void _showMedalSheet(BuildContext context, MissionMedal medal, SieColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MedalDetailSheet(medal: medal, c: c),
    );
  }

  void _showMedalGroupSheet(
      BuildContext context, List<MissionMedal> group, SieColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MedalGroupSheet(medals: group, c: c),
    );
  }
}

// ─── Medal Group Sheet ────────────────────────────────────────────────────────

class _MedalGroupSheet extends StatelessWidget {
  const _MedalGroupSheet({required this.medals, required this.c});

  final List<MissionMedal> medals;
  final SieColors c;

  @override
  Widget build(BuildContext context) {
    final rep = medals.first;
    final levelColor = medalLevelColor(rep.level);
    final levelLabel = medalLevelLabel(rep.level);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: levelColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: c.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border:
                      Border.all(color: levelColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  levelLabel,
                  style: TextStyle(
                    color: levelColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                rep.name,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${medals.length} медал${_medalSuffix(medals.length)}',
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: c.border),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: medals.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: c.border),
              itemBuilder: (ctx, i) => _MedalGroupRow(
                medal: medals[i],
                c: c,
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (_) =>
                        _MedalDetailSheet(medal: medals[i], c: c),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  static String _medalSuffix(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'ь';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'и';
    }
    return 'ей';
  }
}

class _MedalGroupRow extends StatelessWidget {
  const _MedalGroupRow(
      {required this.medal, required this.c, required this.onTap});

  final MissionMedal medal;
  final SieColors c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = medal.earnedAt;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    final title =
        medal.goalName.isNotEmpty ? medal.goalName : medal.name;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            MissionMedalBadge(medal: medal, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Завершено: $dateStr',
                    style:
                        TextStyle(color: c.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_outlined,
                color: c.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Medal Detail Sheet ───────────────────────────────────────────────────────

class _MedalDetailSheet extends StatelessWidget {
  const _MedalDetailSheet({required this.medal, required this.c});

  final MissionMedal medal;
  final SieColors c;

  @override
  Widget build(BuildContext context) {
    final levelColor = medalLevelColor(medal.level);
    final levelLabel = medalLevelLabel(medal.level);
    final d = medal.earnedAt;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: levelColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: c.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          MissionMedalBadge(medal: medal, size: 80),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: levelColor.withValues(alpha: 0.12),
              border: Border.all(color: levelColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              levelLabel,
              style: TextStyle(
                  color: levelColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5),
            ),
          ),
          const SizedBox(height: 14),
          if (medal.goalName.isNotEmpty) ...[
            Text(
              medal.goalName,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
          ],
          Text(
            'Завершено: $dateStr',
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatChip(
                  icon: Icons.fitness_center,
                  label: 'Вес: ${medal.totalTaskWeight}',
                  c: c),
              _StatChip(
                  icon: Icons.calendar_today_outlined,
                  label: '${medal.durationDays} дн.',
                  c: c),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label, required this.c});

  final IconData icon;
  final String label;
  final SieColors c;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c.textSecondary),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(color: c.textSecondary, fontSize: 12)),
      ],
    );
  }
}

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
