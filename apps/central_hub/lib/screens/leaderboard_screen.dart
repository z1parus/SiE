import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:sie_core/sie_core.dart';
import 'public_profile_screen.dart';

// ── Design tokens ──────────────────────────────────────────────
const _kCyan   = Color(0xFF00E5FF);
const _kPurple = Color(0xFF9D00FF);
const _kGold   = Color(0xFFFFD700);
const _kSilver = Color(0xFFC0C0C0);
const _kBronze = Color(0xFFCD7F32);

// ── Shared GlassCard settings factory ─────────────────────────
// Matches the main Operations screen's aesthetic so all surfaces
// share the same physical refraction model.
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
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final profileAsync     = ref.watch(userProfileProvider);
    final currentUserId    = profileAsync.valueOrNull?.id;
    // Watched once here rather than inside every _LeaderRow so that a frame
    // data update rebuilds only this widget, not N shader-heavy list items.
    final frames = ref.watch(avatarFramesProvider).valueOrNull ?? <CosmeticAsset>[];

    return GlassPage(
      background: const SieSpaceBackground(),
      statusBarStyle: GlassStatusBarStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
                      const TextSpan(
                        text: 'HALL ',
                        style: TextStyle(
                          color: _kCyan,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(color: _kCyan, blurRadius: 8),
                            Shadow(color: _kCyan, blurRadius: 22),
                          ],
                        ),
                      ),
                      TextSpan(
                        text: 'OF FAME',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3.0,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'СУТОЧНЫЙ АВАНГАРД · РЕЙТИНГ АКТИВНОСТИ',
                  style: TextStyle(
                    color: SieTheme.textSecondary,
                    fontSize: 10,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
          // Back button — glass circle matching the bell on the main screen.
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: GlassCard(
              width: 36,
              height: 36,
              padding: EdgeInsets.zero,
              shape: LiquidRoundedSuperellipse(borderRadius: 18),
              useOwnLayer: true,
              quality: GlassQuality.standard,
              clipBehavior: Clip.antiAlias,
              settings: _glassSettings(blur: 2.0, glowIntensity: 0.85),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: SieTheme.textSecondary,
                  size: 15,
                ),
              ),
            ),
          ),
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
    final countdownAsync = ref.watch(countdownProvider);

    final display = countdownAsync.when(
      data: _formatDuration,
      loading: () => '--:--:--',
      error: (_, _) => '--:--:--',
    );

    final isUrgent = countdownAsync.valueOrNull != null &&
        countdownAsync.value!.inHours < 1;

    // Normal: neon cyan; urgent (< 1 h): alarm orange-red.
    final timerColor = isUrgent ? const Color(0xFFFF4D00) : _kCyan;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: LiquidRoundedSuperellipse(borderRadius: 20),
        useOwnLayer: true,
        quality: GlassQuality.standard,
        clipBehavior: Clip.antiAlias,
        settings: _glassSettings(blur: 3.5, glowIntensity: 0.92),
        child: Stack(
          children: [
            // Ambient colour bloom behind the timer — feeds into the glass
            // refraction loop so the tint is physically absorbed by the lens.
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
                      const Text(
                        'DAILY RESET',
                        style: TextStyle(
                          color: SieTheme.textSecondary,
                          fontSize: 9,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Bold monospace countdown clock.
                Text(
                  display,
                  style: TextStyle(
                    color: timerColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    shadows: [
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
        ),
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
class _LeaderboardList extends StatelessWidget {
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

  // Every row occupies exactly this vertical extent:
  //   GlassCard (38 px content + 24 px vertical padding = 62 px)
  //   + uniform top margin (6 px) = 68 px.
  // A declared constant lets ListView skip runtime height measurement
  // for every item during scroll velocity calculations.
  static const double _rowExtent = 68;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: SieTheme.accent,
      backgroundColor: Colors.transparent,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
        itemCount: entries.length,
        // Fixed per-item extent bypasses intrinsic-height measurement on
        // every scroll frame — essential for shader-heavy card lists.
        itemExtent: _rowExtent,
        itemBuilder: (context, index) {
          final entry = entries[index];
          // Frame lookup done here (O(n) but n is tiny) rather than inside
          // the row widget, so _LeaderRow can stay a StatelessWidget.
          final frame = frames
              .where((f) => f.id == entry.equippedFrameId)
              .firstOrNull;
          // RepaintBoundary promotes each glass row to its own raster cache
          // layer. The GPU compositor translates cached textures during scroll
          // instead of re-running the liquid-glass shader pipeline per frame.
          return RepaintBoundary(
            child: _LeaderRow(
              entry: entry,
              frame: frame,
              isSelf: entry.userId == currentUserId,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single Leaderboard Row
// ─────────────────────────────────────────────────────────────────────────────
class _LeaderRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final CosmeticAsset? frame;
  final bool isSelf;

  const _LeaderRow({
    required this.entry,
    required this.frame,
    required this.isSelf,
  });

  @override
  Widget build(BuildContext context) {

    final isTopThree = entry.rank <= 3;
    final rankColor  = _rankColor(entry.rank);

    // Bloom tint: rank color for top 3, cyan for self, none otherwise.
    final bloomColor = isSelf
        ? _kCyan
        : isTopThree
            ? rankColor
            : null;

    // XP accent: rank color for top 3, purple neon for everyone else.
    final xpColor = isSelf
        ? _kCyan
        : isTopThree
            ? rankColor
            : _kPurple;

    return GestureDetector(
      onTap: () => _openProfile(context, entry),
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: GlassCard(
          padding: EdgeInsets.zero,
          shape: LiquidRoundedSuperellipse(borderRadius: 16),
          useOwnLayer: true,
          quality: GlassQuality.standard,
          clipBehavior: Clip.antiAlias,
          settings: _glassSettings(
            blur: 3.0,
            // Top 3 and self get a slightly boosted specular rim.
            glowIntensity: (isTopThree || isSelf) ? 0.92 : 0.82,
          ),
          child: Stack(
            children: [
              // ── Rank / self inner glow bloom ──────────────────
              // Rendered inside the GlassCard child so the shader
              // physically absorbs the colour into the refraction pass.
              if (bloomColor != null)
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

              // ── Row content ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // ── Rank indicator ───────────────────────────
                    // height: 38 matches the avatar size so every row
                    // (top-3 badge or plain number) has identical height,
                    // enabling the ListView's itemExtent optimisation.
                    SizedBox(
                      width: 36,
                      height: 38,
                      child: Center(
                        child: isTopThree
                            ? _RankBadge(rank: entry.rank, color: rankColor)
                            : Text(
                                '${entry.rank}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: SieTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // ── Avatar ────────────────────────────────────
                    _Avatar(
                      avatarUrl: entry.avatarUrl,
                      frame: frame,
                      size: 38,
                    ),
                    const SizedBox(width: 12),

                    // ── Username + level ──────────────────────────
                    Expanded(
                      child: Column(
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
                                        ? _kCyan
                                        : isTopThree
                                            ? rankColor
                                            : SieTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    shadows: (isTopThree || isSelf)
                                        ? [
                                            Shadow(
                                              color: (isSelf
                                                      ? _kCyan
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
                                      color: _kCyan.withValues(alpha: 0.6),
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: const Text(
                                    'YOU',
                                    style: TextStyle(
                                      color: _kCyan,
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

                    // ── Daily XP ──────────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${entry.dailyXp}',
                          style: TextStyle(
                            color: xpColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                            shadows: [
                              Shadow(
                                color: xpColor.withValues(alpha: 0.65),
                                blurRadius: 10,
                              ),
                            ],
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
        // Icon in a soft glow halo circle.
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
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
            Icon(_rankIcon(rank), color: color, size: 16),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '#$rank',
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  static IconData _rankIcon(int rank) => switch (rank) {
        1 => Icons.emoji_events,   // gold trophy
        2 => Icons.workspace_premium, // silver shield/star
        _ => Icons.military_tech,  // bronze medal
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar with optional cosmetic frame
// ─────────────────────────────────────────────────────────────────────────────
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
