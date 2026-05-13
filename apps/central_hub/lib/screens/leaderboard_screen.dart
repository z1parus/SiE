import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'public_profile_screen.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final currentUserId = profileAsync.valueOrNull?.id;

    return Scaffold(
      backgroundColor: SieTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            const _CountdownPanel(),
            const SizedBox(height: 4),
            Expanded(
              child: leaderboardAsync.when(
                data: (entries) => _LeaderboardList(
                  entries: entries,
                  currentUserId: currentUserId,
                  onRefresh: () => ref.refresh(leaderboardProvider.future),
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: SieTheme.accent,
                    strokeWidth: 1.5,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'ОШИБКА СОЕДИНЕНИЯ\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      letterSpacing: 1,
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

// ── Header ────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'СУТОЧНЫЙ АВАНГАРД',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'РЕЙТИНГ АКТИВНОСТИ ЗА ТЕКУЩИЙ ЦИКЛ',
                  style: TextStyle(
                    color: SieTheme.textSecondary,
                    fontSize: 10,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.close,
              color: SieTheme.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Countdown Panel ───────────────────────────────────────────

class _CountdownPanel extends ConsumerWidget {
  const _CountdownPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countdownAsync = ref.watch(countdownProvider);

    final display = countdownAsync.when(
      data: _formatDuration,
      loading: () => '--:--:--',
      error: (_, _) => '--:--:--',
    );

    final isUrgent = countdownAsync.valueOrNull != null &&
        countdownAsync.value!.inHours < 1;

    final timerColor =
        isUrgent ? const Color(0xFFFF4D00) : const Color(0xFFFF8C42);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: SieTheme.surface,
        border: Border.all(color: timerColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: timerColor.withValues(alpha: isUrgent ? 0.15 : 0.06),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            color: timerColor,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ДО ЗАВЕРШЕНИЯ ЦИКЛА',
              style: TextStyle(
                color: timerColor.withValues(alpha: 0.7),
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            display,
            style: TextStyle(
              color: timerColor,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ── Leaderboard List ──────────────────────────────────────────

class _LeaderboardList extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final String? currentUserId;
  final Future<void> Function() onRefresh;

  const _LeaderboardList({
    required this.entries,
    required this.currentUserId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final topEntries = entries;

    return RefreshIndicator(
      color: SieTheme.accent,
      backgroundColor: SieTheme.surface,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        // +1 if self is not in the list or we want a divider separator below top 50
        itemCount: topEntries.length,
        itemBuilder: (context, index) {
          final entry = topEntries[index];
          final isSelf = entry.userId == currentUserId;
          return _LeaderRow(
            entry: entry,
            isSelf: isSelf,
            isFirst: index == 0,
          );
        },
      ),
    );
  }
}

// ── Single Leaderboard Row ────────────────────────────────────

class _LeaderRow extends ConsumerWidget {
  final LeaderboardEntry entry;
  final bool isSelf;
  final bool isFirst;

  const _LeaderRow({
    required this.entry,
    required this.isSelf,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frames = ref.watch(avatarFramesProvider).valueOrNull ?? [];
    final frame = frames
        .where((f) => f.id == entry.equippedFrameId)
        .firstOrNull;

    final rankColor = _rankColor(entry.rank);
    final isTopThree = entry.rank <= 3;

    return GestureDetector(
      onTap: () => _openProfile(context, entry),
      child: Container(
        margin: EdgeInsets.only(top: isFirst ? 8 : 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelf
              ? SieTheme.accent.withValues(alpha: 0.07)
              : SieTheme.surface,
          border: Border.all(
            color: isSelf
                ? SieTheme.accent.withValues(alpha: 0.4)
                : isTopThree
                    ? rankColor.withValues(alpha: 0.35)
                    : SieTheme.borderDefault,
          ),
          borderRadius: BorderRadius.circular(4),
          boxShadow: isTopThree
              ? [
                  BoxShadow(
                    color: rankColor.withValues(alpha: 0.08),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 32,
              child: isTopThree
                  ? Text(
                      _rankEmoji(entry.rank),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18),
                    )
                  : Text(
                      '${entry.rank}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: SieTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            // Avatar + frame
            _Avatar(
              avatarUrl: entry.avatarUrl,
              frame: frame,
              size: 36,
            ),
            const SizedBox(width: 12),
            // Name + self badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          (entry.username ?? 'OPERATIVE').toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelf
                                ? SieTheme.accent
                                : isTopThree
                                    ? rankColor
                                    : SieTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: SieTheme.accent.withValues(alpha: 0.6)),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              color: SieTheme.accent,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'LVL ${(entry.totalXp ~/ 1000) + 1}',
                    style: const TextStyle(
                      color: SieTheme.textSecondary,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            // Daily XP
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.dailyXp}',
                  style: TextStyle(
                    color: isTopThree ? rankColor : SieTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Text(
                  'XP TODAY',
                  style: TextStyle(
                    color: SieTheme.textSecondary,
                    fontSize: 8,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color _rankColor(int rank) => switch (rank) {
        1 => const Color(0xFFFFD700),
        2 => const Color(0xFFC0C0C0),
        3 => const Color(0xFFCD7F32),
        _ => SieTheme.textSecondary,
      };

  static String _rankEmoji(int rank) => switch (rank) {
        1 => '🥇',
        2 => '🥈',
        3 => '🥉',
        _ => '$rank',
      };

  void _openProfile(BuildContext context, LeaderboardEntry entry) {
    final profile = PublicProfile(
      id: entry.userId,
      username: entry.username,
      avatarUrl: entry.avatarUrl,
      equippedFrameId: entry.equippedFrameId,
      equippedBackgroundId: entry.equippedBackgroundId,
      equippedStatStyleId: entry.equippedStatStyleId,
      totalXp: entry.totalXp,
    );
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => PublicProfileScreen(profile: profile),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }
}

// ── Avatar with optional frame ────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final CosmeticAsset? frame;
  final double size;

  const _Avatar({this.avatarUrl, this.frame, required this.size});

  @override
  Widget build(BuildContext context) {
    final decoration = frame != null
        ? frame!.buildFrameDecoration()
        : BoxDecoration(
            shape: BoxShape.circle,
            color: SieTheme.surfaceAlt,
            border: Border.all(color: SieTheme.borderDefault),
          );

    return Container(
      width: size,
      height: size,
      decoration: decoration,
      child: ClipOval(
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _Placeholder(size: size),
              )
            : _Placeholder(size: size),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final double size;
  const _Placeholder({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SieTheme.surfaceAlt,
      child: Icon(
        Icons.person,
        color: SieTheme.textSecondary,
        size: size * 0.55,
      ),
    );
  }
}
