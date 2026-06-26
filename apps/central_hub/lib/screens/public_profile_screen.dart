import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PublicProfileScreen
// ─────────────────────────────────────────────────────────────────────────────
class PublicProfileScreen extends ConsumerWidget {
  final PublicProfile profile;
  const PublicProfileScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c           = ref.watch(sieColorsProvider);
    final frames      = ref.watch(avatarFramesProvider).valueOrNull ?? [];
    final backgrounds = ref.watch(profileBackgroundsProvider).valueOrNull ?? [];
    final styles      = ref.watch(statStylesProvider).valueOrNull ?? [];
    final patterns    = ref.watch(profilePatternsProvider).valueOrNull ?? [];

    final equipped = EquippedAssets.resolve(
      frames: frames,
      backgrounds: backgrounds,
      styles: styles,
      patterns: patterns,
      frameId: profile.equippedFrameId,
      backgroundId: profile.equippedBackgroundId,
      styleId: profile.equippedStatStyleId,
      patternId: profile.equippedPatternId,
    );

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _PublicTopBar(
                title: (profile.username ?? t.publicProfile.topBar.defaultName)
                    .toUpperCase(),
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: c.accent,
                  backgroundColor:
                      c.isLightMode ? Colors.white : const Color(0xFF0D1B2A),
                  onRefresh: () async {
                    ref.invalidate(publicStatsProvider(profile.id));
                    ref.invalidate(publicAchievementsProvider(profile.id));
                    ref.invalidate(publicMissionMedalsProvider(profile.id));
                    ref.invalidate(friendsProvider);
                    await ref.read(publicStatsProvider(profile.id).future);
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child:
                            _HeroSection(profile: profile, equipped: equipped),
                      ),
                      SliverToBoxAdapter(
                        child: _FriendActionSection(profile: profile),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _StatsRow(
                                  profile: profile,
                                  statStyle: equipped.statStyle),
                              const SizedBox(height: 16),
                              _SectionBlock(
                                title: t.publicProfile.sections.awards,
                                child: _AchievementsSection(userId: profile.id),
                              ),
                              const SizedBox(height: 16),
                              _SectionBlock(
                                title: t.publicProfile.sections.missionMedals,
                                child:
                                    _PublicMedalsSection(userId: profile.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

// ── Top Bar ───────────────────────────────────────────────────

class _PublicTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _PublicTopBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(letterSpacing: 2),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ── Hero Section ──────────────────────────────────────────────

class _HeroSection extends ConsumerWidget {
  final PublicProfile profile;
  final EquippedAssets equipped;
  const _HeroSection({required this.profile, required this.equipped});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          ProfileHeroCard(
            username: profile.username ?? '',
            avatarUrl: profile.avatarUrl,
            totalXp: profile.totalXp,
            frame: equipped.frame,
            background: equipped.background,
            pattern: equipped.pattern,
            avatarSize: 96,
          ),
          if (equipped.statStyle != null) ...[
            const SizedBox(height: 12),
            _StatStyleBanner(
              statStyle: equipped.statStyle!,
              level: profile.level,
              xp: profile.totalXp,
              c: c,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatStyleBanner extends StatelessWidget {
  final CosmeticAsset statStyle;
  final int level;
  final int xp;
  final SieColors c;
  const _StatStyleBanner({
    required this.statStyle,
    required this.level,
    required this.xp,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final accent  = statStyle.accentColor;
    final glowCol = c.isLightMode ? null : statStyle.styleGlowColor;
    final glowRad = statStyle.styleGlowRadius;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: statStyle.buildStatCardDecoration(
          surfaceColor: c.surface, isLightMode: c.isLightMode),
      child: Row(
        children: [
          Icon(Icons.bolt, color: accent, size: 14),
          const SizedBox(width: 8),
          Text(
            t.publicProfile.banner.levelXp(level: level, xp: xp),
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              shadows: (glowCol != null && glowRad > 0)
                  ? [Shadow(color: glowCol, blurRadius: glowRad)]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────

class _StatsRow extends ConsumerWidget {
  final PublicProfile profile;
  final CosmeticAsset? statStyle;
  const _StatsRow({required this.profile, this.statStyle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c         = ref.watch(sieColorsProvider);
    final statsAsync = ref.watch(publicStatsProvider(profile.id));
    final stats      = statsAsync.valueOrNull ?? PublicProfileStats.zero();

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.timer_outlined,
            value: stats.focusTime,
            label: t.publicProfile.stats.focus,
            statStyle: statStyle,
            c: c,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.checklist_outlined,
            value: stats.habitCompletions.toString(),
            label: t.publicProfile.stats.cycles,
            statStyle: statStyle,
            c: c,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.military_tech_outlined,
            value: t.publicProfile.stats.level(level: profile.level),
            label: t.publicProfile.stats.rank,
            statStyle: statStyle,
            c: c,
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
  final CosmeticAsset? statStyle;
  final SieColors c;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.c,
    this.statStyle,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor = statStyle?.accentColor ?? c.accent;

    if (statStyle != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: statStyle!.buildStatCardDecoration(surfaceColor: c.surface, isLightMode: c.isLightMode),
        child: _StatCardContent(
            icon: icon, value: value, label: label, valueColor: valueColor, c: c),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: c.flatCard(radius: 14),
      child: _StatCardContent(
          icon: icon, value: value, label: label, valueColor: valueColor, c: c),
    );
  }
}

class _StatCardContent extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color valueColor;
  final SieColors c;
  const _StatCardContent({
    required this.icon,
    required this.value,
    required this.label,
    required this.valueColor,
    required this.c,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.textSecondary, size: 14),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 8,
              letterSpacing: 1.2,
            ),
          ),
        ],
      );
}

// ── Achievements Section ──────────────────────────────────────

class _AchievementsSection extends ConsumerWidget {
  final String userId;
  const _AchievementsSection({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c        = ref.watch(sieColorsProvider);
    final achAsync = ref.watch(publicAchievementsProvider(userId));

    return achAsync.when(
      loading: () => const SieSkeletonGrid(columns: 4, count: 8),
      error: (_, _) => Text(
        t.publicProfile.achievements.dataUnavailable,
        style: TextStyle(
            color: c.textSecondary, fontSize: 11, letterSpacing: 1),
      ),
      data: (achievements) {
        if (achievements.isEmpty) {
          return Text(
            t.publicProfile.achievements.empty,
            style: TextStyle(
                color: c.textSecondary, fontSize: 11, letterSpacing: 1),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.1,
          ),
          itemCount: achievements.length,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _showDetail(context, achievements[i], c),
            child: AchievementBadge(userAchievement: achievements[i]),
          ),
        );
      },
    );
  }

  void _showDetail(BuildContext context, UserAchievement ua, SieColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: c.border),
      ),
      builder: (_) => _AchievementSheet(ua: ua),
    );
  }
}

// ── Achievement Detail Sheet ──────────────────────────────────

class _AchievementSheet extends ConsumerWidget {
  final UserAchievement ua;
  const _AchievementSheet({required this.ua});

  static IconData _icon(String slug) => switch (slug) {
        'first_breath'         => Icons.air,
        'streak_7'             => Icons.local_fire_department,
        'streak_30'            => Icons.whatshot,
        'habits_10'            => Icons.checklist,
        'xp_1000'              => Icons.bolt,
        'first_habit_created'  => Icons.add_task,
        'deep_focus_initiated' => Icons.center_focus_strong,
        _                      => Icons.emoji_events,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c      = ref.watch(sieColorsProvider);
    final ach    = ua.achievement;
    final earned = ua.earned;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 3,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: earned
                  ? c.accent.withValues(alpha: 0.12)
                  : c.background,
              border: Border.all(
                color: earned ? c.accent : c.border,
                width: earned ? 1.5 : 1,
              ),
              boxShadow: null,
            ),
            child: Icon(
              _icon(ach.slug),
              color: earned ? c.accent : c.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            ach.name.toUpperCase(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (ach.description != null) ...[
            Text(
              ach.description!,
              textAlign: TextAlign.center,
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  c.accent.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt, color: c.accent, size: 14),
              const SizedBox(width: 4),
              Text(
                t.publicProfile.achievementSheet.xpReward(xp: ach.xpReward),
                style: TextStyle(
                  color: c.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: earned ? c.accent : c.textSecondary),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  earned
                      ? t.publicProfile.achievementSheet.earned
                      : t.publicProfile.achievementSheet.notEarned,
                  style: TextStyle(
                    color: earned ? c.accent : c.textSecondary,
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
              t.publicProfile.achievementSheet
                  .date(date: _formatDate(ua.earnedAt!)),
              style: TextStyle(
                color: c.textSecondary,
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

// ── Section Block ─────────────────────────────────────────────────────────────

class _SectionBlock extends ConsumerWidget {
  final String title;
  final Widget child;
  const _SectionBlock({required this.title, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: c.flatCard(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Public Medals Section ─────────────────────────────────────────────────────

class _PublicMedalsSection extends ConsumerWidget {
  const _PublicMedalsSection({required this.userId});

  final String userId;

  void _showMedalSheet(BuildContext context, MissionMedal medal, SieColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PublicMedalDetailSheet(medal: medal, c: c),
    );
  }

  void _showMedalGroupSheet(
      BuildContext context, List<MissionMedal> group, SieColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PublicMedalGroupSheet(medals: group, c: c),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c           = ref.watch(sieColorsProvider);
    final medalsAsync = ref.watch(publicMissionMedalsProvider(userId));

    return medalsAsync.when(
      loading: () => const SieSkeletonGrid(columns: 3, count: 3, childAspectRatio: 0.82),
      error: (_, _) => const SizedBox.shrink(),
      data: (medals) {
        if (medals.isEmpty) {
          return Text(
            t.publicProfile.medals.empty,
            style: TextStyle(color: c.textSecondary, fontSize: 11, letterSpacing: 1),
          );
        }

        // Group by category + level (same logic as personal profile)
        final Map<String, List<MissionMedal>> groupMap = {};
        for (final medal in medals) {
          final key = medal.isVanguard
              ? 'vanguard_${medal.level}'
              : '${medal.category?.name ?? '_'}_${medal.level}';
          groupMap.putIfAbsent(key, () => []).add(medal);
        }
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
}

// ── Friend Action Section ─────────────────────────────────────────────────────

class _FriendActionSection extends ConsumerStatefulWidget {
  final PublicProfile profile;
  const _FriendActionSection({required this.profile});

  @override
  ConsumerState<_FriendActionSection> createState() =>
      _FriendActionSectionState();
}

class _FriendActionSectionState extends ConsumerState<_FriendActionSection> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      SieHaptics.success();
    } catch (_) {
      SieHaptics.warning();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null || myId == profile.id) return const SizedBox.shrink();

    final friendsState = ref.watch(friendsProvider).valueOrNull;
    if (friendsState == null) return const SizedBox.shrink();

    final friend = friendsState.friends
        .where((r) => r.otherUser.id == profile.id)
        .firstOrNull;
    final sent = friendsState.sentRequests
        .where((r) => r.otherUser.id == profile.id)
        .firstOrNull;
    final received = friendsState.receivedRequests
        .where((r) => r.otherUser.id == profile.id)
        .firstOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: _buildButtons(friend, sent, received),
    );
  }

  Widget _buildButtons(
    FriendRow? friend,
    FriendRow? sent,
    FriendRow? received,
  ) {
    final notifier = ref.read(friendsProvider.notifier);

    if (friend != null) {
      return _SocialBtn(
        label: t.publicProfile.friend.remove,
        icon: Icons.person_remove_outlined,
        filled: false,
        busy: _busy,
        onTap: () => _confirmRemove(friend.friendshipId),
      );
    }
    if (sent != null) {
      return _SocialBtn(
        label: t.publicProfile.friend.cancelRequest,
        icon: Icons.cancel_outlined,
        filled: false,
        busy: _busy,
        onTap: () => _run(() => notifier.cancelRequest(sent.friendshipId)),
      );
    }
    if (received != null) {
      return Row(children: [
        Expanded(
          child: _SocialBtn(
            label: t.publicProfile.friend.acceptRequest,
            icon: Icons.check,
            filled: true,
            busy: _busy,
            onTap: () => _run(() => notifier.acceptRequest(received.friendshipId)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SocialBtn(
            label: t.publicProfile.friend.decline,
            icon: Icons.close,
            filled: false,
            busy: _busy,
            onTap: () => _run(() => notifier.declineRequest(received.friendshipId)),
          ),
        ),
      ]);
    }
    return _SocialBtn(
      label: t.publicProfile.friend.add,
      icon: Icons.person_add_outlined,
      filled: true,
      busy: _busy,
      onTap: () => _run(() => notifier.sendRequest(widget.profile.id)),
    );
  }

  Future<void> _confirmRemove(String friendshipId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t.publicProfile.friend.confirmRemoveTitle),
        content: Text(
          t.publicProfile.friend.confirmRemoveBody(
            name: widget.profile.username ??
                t.publicProfile.friend.confirmRemoveDefaultName,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(t.publicProfile.friend.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(t.publicProfile.friend.removeAction)),
        ],
      ),
    );
    if (ok == true) {
      await _run(
          () => ref.read(friendsProvider.notifier).removeFriend(friendshipId));
    }
  }
}

class _SocialBtn extends ConsumerWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final bool busy;
  final VoidCallback onTap;

  const _SocialBtn({
    required this.label,
    required this.icon,
    required this.filled,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final fg = filled ? c.accent : c.textSecondary;
    return Semantics(
      button: true,
      enabled: !busy,
      label: label,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: busy ? 0.6 : 1.0,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color:
                  filled ? c.accent.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: filled ? c.accent.withValues(alpha: 0.5) : c.border),
            ),
            child: busy
                ? Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: fg, strokeWidth: 1.5),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: fg, size: 15),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: fg,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Public medal detail sheet
// ─────────────────────────────────────────────────────────────────────────────
class _PublicMedalDetailSheet extends StatelessWidget {
  const _PublicMedalDetailSheet({required this.medal, required this.c});

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
          MissionMedalBadge(medal: medal, size: 80, showLabel: false),
          const SizedBox(height: 14),
          Text(
            medal.name,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
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
            ),
            const SizedBox(height: 6),
          ],
          Text(
            t.profile.medals.completed(date: dateStr),
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MedalStatChip(
                  icon: Icons.fitness_center,
                  label: t.profile.medals.weight(weight: medal.totalTaskWeight),
                  c: c),
              _MedalStatChip(
                  icon: Icons.calendar_today_outlined,
                  label: t.profile.medals.duration(n: medal.durationDays),
                  c: c),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public medal group sheet
// ─────────────────────────────────────────────────────────────────────────────
class _PublicMedalGroupSheet extends StatelessWidget {
  const _PublicMedalGroupSheet({required this.medals, required this.c});

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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: levelColor.withValues(alpha: 0.35)),
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
            t.profile.medals.count(n: medals.length),
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
              itemBuilder: (ctx, i) {
                final medal = medals[i];
                final d = medal.earnedAt;
                final dateStr =
                    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
                final title =
                    medal.goalName.isNotEmpty ? medal.goalName : medal.name;
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (_) =>
                          _PublicMedalDetailSheet(medal: medal, c: c),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
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
                                t.profile.medals.completed(date: dateStr),
                                style: TextStyle(
                                    color: c.textSecondary, fontSize: 11),
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
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MedalStatChip extends StatelessWidget {
  const _MedalStatChip(
      {required this.icon, required this.label, required this.c});

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
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
      ],
    );
  }
}
