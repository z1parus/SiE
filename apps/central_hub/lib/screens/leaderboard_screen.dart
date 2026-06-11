import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sie_core/sie_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'public_profile_screen.dart';

// Rank medal colors — universal across all themes
const _kGold   = Color(0xFFFFD700);
const _kSilver = Color(0xFFC0C0C0);
const _kBronze = Color(0xFFCD7F32);

const _kLastVanguardShownKey = 'last_vanguard_shown_date';

// ─────────────────────────────────────────────────────────────────────────────
// LeaderboardScreen
// ─────────────────────────────────────────────────────────────────────────────
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key, this.asTab = false});

  final bool asTab;

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVanguard());
  }

  Future<void> _checkVanguard() async {
    try {
      final tzOffset = await ref.read(userTimezoneProvider.future);
      final utcNow = DateTime.now().toUtc();
      final localNow = utcNow.add(tzOffset);
      final todayStr = _dateStr(localNow);

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_kLastVanguardShownKey) == todayStr) return;

      // Competition date = yesterday in user's timezone
      final yesterday = localNow.subtract(const Duration(days: 1));
      final yesterdayStr = _dateStr(yesterday);

      final raw = await Supabase.instance.client.rpc('award_vanguard_cycle',
          params: {
            'p_competition_date': yesterdayStr,
            'p_tz_offset_minutes': tzOffset.inMinutes,
          });

      // Mark as shown regardless of results (even empty cycle)
      await prefs.setString(_kLastVanguardShownKey, todayStr);

      if (!mounted) return;
      final results = (raw as List?)
              ?.map((r) => VanguardResult.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [];

      if (results.isEmpty) return;

      // Refresh profile/medals for any DP or medal we just received
      ref.invalidate(userProfileProvider);
      ref.invalidate(missionMedalsProvider);

      final myId = ref.read(userProfileProvider).valueOrNull?.id;
      final myUsername = ref.read(userProfileProvider).valueOrNull?.username;

      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => _VanguardSummarySheet(
          results: results,
          competitionDate: yesterday,
          currentUserId: myId,
          currentUsername: myUsername,
        ),
      );
    } catch (e) {
      debugPrint('Vanguard check failed: $e');
    }
  }

  static String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c                = ref.watch(sieColorsProvider);
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final profileAsync     = ref.watch(userProfileProvider);
    final currentUserId    = profileAsync.valueOrNull?.id;
    final frames = ref.watch(avatarFramesProvider).valueOrNull ?? <CosmeticAsset>[];

    // When the cycle resets (timer → 0), refresh the leaderboard.
    ref.listen<AsyncValue<Duration>>(countdownProvider, (prev, curr) {
      final p = prev?.valueOrNull;
      final c = curr.valueOrNull;
      if (p != null && p > Duration.zero &&
          c != null && c <= Duration.zero) {
        ref.invalidate(leaderboardProvider);
      }
    });

    final body = SafeArea(
      bottom: false,
      child: Column(
        children: [
          _Header(showBackButton: !widget.asTab),
          const SizedBox(height: 12),
          const _CountdownPanel(),
          const SizedBox(height: 8),
          Expanded(
            child: leaderboardAsync.when(
              data: (entries) => _LeaderboardList(
                entries: entries,
                currentUserId: currentUserId,
                frames: frames,
                onRefresh: () => ref.refresh(leaderboardProvider.future),
              ),
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: c.accent,
                  strokeWidth: 1.5,
                ),
              ),
              error: (e, _) => const Center(
                child: _NoConnectionMessage(),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.asTab) {
      return Scaffold(backgroundColor: Colors.transparent, body: body);
    }

    return SieBackground(
      child: Scaffold(backgroundColor: Colors.transparent, body: body),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends ConsumerWidget {
  const _Header({this.showBackButton = true});
  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
      child: Row(
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
                        text: 'HALL ',
                        style: TextStyle(
                          color: c.accent,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          shadows: c.isLightMode
                              ? null
                              : [
                                  Shadow(color: c.accent, blurRadius: 8),
                                  Shadow(color: c.accent, blurRadius: 22),
                                ],
                        ),
                      ),
                      TextSpan(
                        text: 'OF FAME',
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(
                              color: c.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3.0,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'СУТОЧНЫЙ АВАНГАРД · РЕЙТИНГ АКТИВНОСТИ',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 10,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
          if (showBackButton)
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: c.flatCard(radius: 18),
                child: Center(
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    color: c.textSecondary,
                    size: 15,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 36),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Countdown Panel
// ─────────────────────────────────────────────────────────────────────────────
class _CountdownPanel extends ConsumerWidget {
  const _CountdownPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c              = ref.watch(sieColorsProvider);
    final countdownAsync = ref.watch(countdownProvider);

    final display = countdownAsync.when(
      data: _formatDuration,
      loading: () => '--:--:--',
      error: (_, _) => '--:--:--',
    );

    final isUrgent = countdownAsync.valueOrNull != null &&
        countdownAsync.value!.inHours < 1;

    // Urgent: alarm orange-red; normal: accent (teal in light, cyan in dark/cosmic)
    final timerColor =
        isUrgent ? const Color(0xFFFF4D00) : c.accent;

    final cardContent = Row(
          children: [
            Icon(Icons.timer_outlined, color: timerColor, size: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ДО ЗАВЕРШЕНИЯ ЦИКЛА',
                    style: TextStyle(
                      color: timerColor.withValues(alpha: 0.75),
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'DAILY RESET',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 9,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              display,
              style: TextStyle(
                color: timerColor,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 3.5,
                fontFeatures: const [FontFeature.tabularFigures()],
                shadows: c.isLightMode
                    ? null
                    : [
                        Shadow(
                          color: timerColor.withValues(alpha: 0.80),
                          blurRadius: 10,
                        ),
                        Shadow(
                          color: timerColor.withValues(alpha: 0.40),
                          blurRadius: 28,
                        ),
                      ],
              ),
            ),
          ],
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: c.flatCard(radius: 20),
        child: cardContent,
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

// ─────────────────────────────────────────────────────────────────────────────
// Leaderboard List
// ─────────────────────────────────────────────────────────────────────────────
class _LeaderboardList extends ConsumerWidget {
  final List<LeaderboardEntry> entries;
  final String? currentUserId;
  final List<CosmeticAsset> frames;
  final Future<void> Function() onRefresh;

  const _LeaderboardList({
    required this.entries,
    required this.currentUserId,
    required this.frames,
    required this.onRefresh,
  });

  static const double _rowExtent = 68;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return RefreshIndicator(
      color: c.accent,
      backgroundColor: Colors.transparent,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
        itemCount: entries.length,
        itemExtent: _rowExtent,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final frame = frames
              .where((f) => f.id == entry.equippedFrameId)
              .firstOrNull;
          return _LeaderRow(
            entry: entry,
            frame: frame,
            isSelf: entry.userId == currentUserId,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single Leaderboard Row
// ─────────────────────────────────────────────────────────────────────────────
class _LeaderRow extends ConsumerWidget {
  final LeaderboardEntry entry;
  final CosmeticAsset? frame;
  final bool isSelf;

  const _LeaderRow({
    required this.entry,
    required this.frame,
    required this.isSelf,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);

    final isTopThree = entry.rank <= 3;
    final rankColor  = _rankColor(entry.rank);

    // XP accent: rank color for top 3, accentSecondary for others, accent for self
    final xpColor = isSelf
        ? c.accent
        : isTopThree
            ? rankColor
            : c.accentSecondary;

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: c.surface,
      border: Border.all(
        color: isSelf
            ? c.accent.withValues(alpha: 0.35)
            : isTopThree
                ? rankColor.withValues(alpha: 0.30)
                : c.border,
        width: 0.8,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );

    return GestureDetector(
      onTap: () => _openProfile(context, entry),
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          decoration: decoration,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Rank indicator
                    SizedBox(
                      width: 36,
                      height: 38,
                      child: Center(
                        child: isTopThree
                            ? _RankBadge(rank: entry.rank, color: rankColor)
                            : Text(
                                '${entry.rank}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Avatar
                    _Avatar(
                      avatarUrl: entry.avatarUrl,
                      frame: frame,
                      size: 38,
                    ),
                    const SizedBox(width: 12),

                    // Username + level
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  (entry.username ?? 'OPERATIVE')
                                      .toUpperCase(),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSelf
                                        ? c.accent
                                        : isTopThree
                                            ? rankColor
                                            : c.textPrimary,
                                    fontSize: 13,
                                    height: 1.1,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    shadows: (isTopThree || isSelf) &&
                                            !c.isLightMode
                                        ? [
                                            Shadow(
                                              color: (isSelf
                                                      ? c.accent
                                                      : rankColor)
                                                  .withValues(alpha: 0.55),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                              if (isSelf) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: c.accent.withValues(alpha: 0.6),
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(
                                    'YOU',
                                    style: TextStyle(
                                      color: c.accent,
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
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 10,
                              height: 1.1,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Daily XP
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${entry.dailyXp}',
                          style: TextStyle(
                            color: xpColor,
                            fontSize: 18,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                            shadows: c.isLightMode
                                ? null
                                : [
                                    Shadow(
                                      color: xpColor.withValues(alpha: 0.65),
                                      blurRadius: 10,
                                    ),
                                  ],
                          ),
                        ),
                        Text(
                          'XP TODAY',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 8,
                            height: 1.1,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _rankColor(int rank) => switch (rank) {
        1 => _kGold,
        2 => _kSilver,
        3 => _kBronze,
        _ => SieTheme.textSecondary,
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
      MaterialPageRoute(builder: (_) => PublicProfileScreen(profile: profile)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rank Badge (top 3 only)
// ─────────────────────────────────────────────────────────────────────────────
class _RankBadge extends StatelessWidget {
  final int rank;
  final Color color;

  const _RankBadge({required this.rank, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Icon(_rankIcon(rank), color: color, size: 14),
          ],
        ),
        Text(
          '#$rank',
          style: TextStyle(
            color: color,
            fontSize: 9,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  static IconData _rankIcon(int rank) => switch (rank) {
        1 => Icons.emoji_events,
        2 => Icons.workspace_premium,
        _ => Icons.military_tech,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar with optional cosmetic frame
// ─────────────────────────────────────────────────────────────────────────────
class _Avatar extends ConsumerWidget {
  final String? avatarUrl;
  final CosmeticAsset? frame;
  final double size;

  const _Avatar({this.avatarUrl, this.frame, required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final decoration = frame != null
        ? frame!.buildFrameDecoration(surfaceColor: c.surface, suppressGlow: c.isLightMode)
        : BoxDecoration(
            shape: BoxShape.circle,
            color: c.surface,
            border: Border.all(color: c.border),
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

class _Placeholder extends ConsumerWidget {
  final double size;
  const _Placeholder({required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Container(
      color: c.surface,
      child: Icon(
        Icons.person,
        color: c.textSecondary,
        size: size * 0.55,
      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Vanguard Summary Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _VanguardSummarySheet extends ConsumerWidget {
  final List<VanguardResult> results;
  final DateTime competitionDate;
  final String? currentUserId;
  final String? currentUsername;

  const _VanguardSummarySheet({
    required this.results,
    required this.competitionDate,
    this.currentUserId,
    this.currentUsername,
  });

  static String _fmtDate(DateTime d) {
    const months = [
      '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);

    final isWinner = results.any((r) => r.userId == currentUserId);
    final myUsername = currentUsername ?? 'Оперативник';

    final sheetBg = c.isLightMode
        ? const Color(0xFFF5F7FA)
        : const Color(0xFF0D1525);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: _kGold.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 20, 24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Trophy icon
          Icon(Icons.emoji_events, color: _kGold, size: 40,
              shadows: [Shadow(color: _kGold.withValues(alpha: 0.5), blurRadius: 16)]),
          const SizedBox(height: 12),

          // Title
          Text(
            'ИТОГИ АВАНГАРДА',
            style: TextStyle(
              color: _kGold,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.5,
              shadows: c.isLightMode
                  ? null
                  : [Shadow(color: _kGold.withValues(alpha: 0.5), blurRadius: 10)],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _fmtDate(competitionDate),
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Winners list
          ...results.map((r) => _WinnerRow(result: r, c: c)),

          // Congrats message
          if (isWinner) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _kGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kGold.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_outline, color: _kGold, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Так держать, $myUsername! Сегодня вы вошли в тройку лучших оперативников!',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // CTA button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: c.isLightMode ? Colors.white : const Color(0xFF0D1525),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'НАЧАТЬ СЛЕДУЮЩИЙ АВАНГАРД',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WinnerRow extends StatelessWidget {
  final VanguardResult result;
  final SieColors c;

  const _WinnerRow({required this.result, required this.c});

  static Color _placeColor(int place) => switch (place) {
        1 => _kGold,
        2 => _kSilver,
        _ => _kBronze,
      };

  static IconData _placeIcon(int place) => switch (place) {
        1 => Icons.emoji_events,
        2 => Icons.workspace_premium,
        _ => Icons.military_tech,
      };

  @override
  Widget build(BuildContext context) {
    final color = _placeColor(result.place);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.22), width: 0.8),
        ),
        child: Row(
          children: [
            // Rank badge
            SizedBox(
              width: 32,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_placeIcon(result.place), color: color, size: 18),
                  Text(
                    '#${result.place}',
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surface,
                border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
              ),
              child: ClipOval(
                child: result.avatarUrl != null && result.avatarUrl!.isNotEmpty
                    ? Image.network(result.avatarUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(Icons.person,
                            color: c.textSecondary, size: 20))
                    : Icon(Icons.person, color: c.textSecondary, size: 20),
              ),
            ),
            const SizedBox(width: 12),

            // Username
            Expanded(
              child: Text(
                (result.username ?? 'OPERATIVE').toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),

            // DP awarded
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${result.dpAwarded}',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'DP',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 9,
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
}
