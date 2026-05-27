import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:sie_core/sie_core.dart';
import 'public_profile_screen.dart';

// Rank medal colors — universal across all themes
const _kGold   = Color(0xFFFFD700);
const _kSilver = Color(0xFFC0C0C0);
const _kBronze = Color(0xFFCD7F32);

// Shared GlassCard settings factory
LiquidGlassSettings _glassSettings({
  double blur = 3.0,
  double glowIntensity = 0.88,
}) =>
    LiquidGlassSettings(
      blur: blur,
      thickness: 24,
      refractiveIndex: 1.45,
      glassColor: const Color(0x0A0A0E1A),
      lightAngle: GlassDefaults.lightAngle,
      lightIntensity: 0.72,
      glowIntensity: glowIntensity,
      saturation: 1.4,
      specularSharpness: GlassSpecularSharpness.sharp,
      ambientStrength: 0.08,
      chromaticAberration: 0.015,
    );

// ─────────────────────────────────────────────────────────────────────────────
// LeaderboardScreen
// ─────────────────────────────────────────────────────────────────────────────
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key, this.asTab = false});

  final bool asTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c                = ref.watch(sieColorsProvider);
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final profileAsync     = ref.watch(userProfileProvider);
    final currentUserId    = profileAsync.valueOrNull?.id;
    final frames = ref.watch(avatarFramesProvider).valueOrNull ?? <CosmeticAsset>[];

    final body = SafeArea(
      bottom: false,
      child: Column(
        children: [
          _Header(showBackButton: !asTab),
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

    if (asTab) {
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
              child: c.isCosmicMode
                  ? GlassCard(
                      width: 36,
                      height: 36,
                      padding: EdgeInsets.zero,
                      shape: LiquidRoundedSuperellipse(borderRadius: 18),
                      useOwnLayer: true,
                      quality: GlassQuality.standard,
                      clipBehavior: Clip.antiAlias,
                      settings: _glassSettings(blur: 2.0, glowIntensity: 0.85),
                      child: Center(
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: c.textSecondary,
                          size: 15,
                        ),
                      ),
                    )
                  : Container(
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

    final cardContent = Stack(
      children: [
        // Ambient colour bloom (cosmic only — feeds into glass refraction)
        if (c.isCosmicMode)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.9, 0),
                  radius: 1.0,
                  colors: [
                    timerColor.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        Row(
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
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: c.isCosmicMode
          ? GlassCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              shape: LiquidRoundedSuperellipse(borderRadius: 20),
              useOwnLayer: true,
              quality: GlassQuality.standard,
              clipBehavior: Clip.antiAlias,
              settings: _glassSettings(blur: 3.5, glowIntensity: 0.92),
              child: cardContent,
            )
          : Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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

    final bloomColor = isSelf
        ? c.accent
        : isTopThree
            ? rankColor
            : null;

    // XP accent: rank color for top 3, accentSecondary for others, accent for self
    final xpColor = isSelf
        ? c.accent
        : isTopThree
            ? rankColor
            : c.accentSecondary;

    final decoration = c.isCosmicMode
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (isSelf
                        ? c.accent
                        : isTopThree
                            ? rankColor
                            : Colors.white)
                    .withValues(alpha: isTopThree || isSelf ? 0.09 : 0.05),
                Colors.white.withValues(alpha: 0.02),
              ],
            ),
            border: Border.all(
              color: isSelf
                  ? c.accent.withValues(alpha: 0.35)
                  : isTopThree
                      ? rankColor.withValues(alpha: 0.30)
                      : Colors.white.withValues(alpha: 0.09),
              width: 0.8,
            ),
          )
        : BoxDecoration(
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
              // Bloom (cosmic only)
              if (c.isCosmicMode && bloomColor != null)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.75, 0),
                        radius: 1.3,
                        colors: [
                          bloomColor.withValues(
                            alpha: isTopThree ? 0.18 : 0.10,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

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
      PageRouteBuilder(
        pageBuilder: (_, _, _) => PublicProfileScreen(profile: profile),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
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
        ? frame!.buildFrameDecoration()
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
