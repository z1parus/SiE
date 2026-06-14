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
        body: Stack(
          children: [
            RefreshIndicator(
              color: c.accent,
              backgroundColor: c.isLightMode ? Colors.white : const Color(0xFF0D1B2A),
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
                  child: _HeroSection(profile: profile, equipped: equipped),
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
                            profile: profile, statStyle: equipped.statStyle),
                        const SizedBox(height: 16),
                        _SectionBlock(
                          title: 'AWARDS',
                          child: _AchievementsSection(userId: profile.id),
                        ),
                        const SizedBox(height: 16),
                        _SectionBlock(
                          title: 'MISSION MEDALS',
                          child: _PublicMedalsSection(userId: profile.id),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    color: c.isLightMode ? c.textPrimary : Colors.white,
                    size: 18,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: c.isLightMode
                        ? c.surface.withValues(alpha: 0.85)
                        : Colors.black45,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(8),
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
            designPoints: profile.designPoints,
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
            'LEVEL $level  ·  $xp XP',
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
            label: 'КОНЦЕНТРАЦИЯ',
            statStyle: statStyle,
            c: c,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.checklist_outlined,
            value: stats.habitCompletions.toString(),
            label: 'ЦИКЛОВ',
            statStyle: statStyle,
            c: c,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.military_tech_outlined,
            value: 'LVL ${profile.level}',
            label: 'РАНГ',
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
        'AWARDS DATA UNAVAILABLE',
        style: TextStyle(
            color: c.textSecondary, fontSize: 11, letterSpacing: 1),
      ),
      data: (achievements) {
        if (achievements.isEmpty) {
          return Text(
            'NO AWARDS YET',
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
            childAspectRatio: 1.0,
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
                '+${ach.xpReward} XP',
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
                  earned ? 'ПОЛУЧЕНО' : 'НЕ ПОЛУЧЕНО',
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
              'ДАТА: ${_formatDate(ua.earnedAt!)}',
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: c.flatCard(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          const SizedBox(height: 14),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c           = ref.watch(sieColorsProvider);
    final medalsAsync = ref.watch(publicMissionMedalsProvider(userId));

    return medalsAsync.when(
      loading: () => const SieSkeletonGrid(columns: 4, count: 4, childAspectRatio: 1.0),
      error: (_, _) => const SizedBox.shrink(),
      data: (medals) {
        if (medals.isEmpty) {
          return Text(
            'НЕТ МЕДАЛЕЙ',
            style:
                TextStyle(color: c.textSecondary, fontSize: 11, letterSpacing: 1),
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: medals
              .map((m) => MissionMedalBadge(medal: m, size: 56))
              .toList(),
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
        label: 'Удалить из друзей',
        icon: Icons.person_remove_outlined,
        filled: false,
        busy: _busy,
        onTap: () => _confirmRemove(friend.friendshipId),
      );
    }
    if (sent != null) {
      return _SocialBtn(
        label: 'Отменить запрос',
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
            label: 'Принять запрос',
            icon: Icons.check,
            filled: true,
            busy: _busy,
            onTap: () => _run(() => notifier.acceptRequest(received.friendshipId)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SocialBtn(
            label: 'Отклонить',
            icon: Icons.close,
            filled: false,
            busy: _busy,
            onTap: () => _run(() => notifier.declineRequest(received.friendshipId)),
          ),
        ),
      ]);
    }
    return _SocialBtn(
      label: 'Добавить в друзья',
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
        title: const Text('Удалить из друзей?'),
        content: Text(
          'Убрать ${widget.profile.username ?? 'этого оперативника'} '
          'из списка друзей?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Удалить')),
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
