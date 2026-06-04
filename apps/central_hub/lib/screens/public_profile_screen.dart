import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:sie_core/sie_core.dart';

LiquidGlassSettings _glassSettings({double glowIntensity = 0.88}) =>
    LiquidGlassSettings(
      blur: 3.5,
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

    final equipped = EquippedAssets.resolve(
      frames: frames,
      backgrounds: backgrounds,
      styles: styles,
      frameId: profile.equippedFrameId,
      backgroundId: profile.equippedBackgroundId,
      styleId: profile.equippedStatStyleId,
    );

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _HeroSection(profile: profile, equipped: equipped),
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
                        _XpPanel(profile: profile),
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
    final c  = ref.watch(sieColorsProvider);
    final bg = equipped.background;
    Widget bgWidget;
    if (bg != null && bg.imageUrl != null) {
      bgWidget = Image.network(
        bg.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _DefaultHeroBg(),
      );
    } else if (bg != null && bg.backgroundGradient != null) {
      bgWidget = Container(
        decoration: BoxDecoration(gradient: bg.backgroundGradient),
        child: CustomPaint(painter: _GridPainter()),
      );
    } else {
      bgWidget = _DefaultHeroBg();
    }

    return SizedBox(
      height: 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          bgWidget,
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  c.background.withValues(alpha: 0.4),
                  c.background,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: _AvatarWithFrame(profile: profile, frame: equipped.frame),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile.username?.toUpperCase() ?? 'UNKNOWN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: c.accent.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: c.isCosmicMode
                        ? [
                            BoxShadow(
                              color: c.accent.withValues(alpha: 0.08),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    'LEVEL ${profile.level}  ·  ${profile.totalXp} XP',
                    style: TextStyle(
                      color: c.accent,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultHeroBg extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Container(
      decoration: BoxDecoration(
        gradient: c.isLightMode
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.border, c.surface],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D2A42), Color(0xFF071520)],
              ),
      ),
      child: c.isLightMode ? null : CustomPaint(painter: _GridPainter()),
    );
  }
}

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

class _AvatarWithFrame extends ConsumerWidget {
  final PublicProfile profile;
  final CosmeticAsset? frame;
  const _AvatarWithFrame({required this.profile, this.frame});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final letter = (profile.username?.isNotEmpty == true)
        ? profile.username![0].toUpperCase()
        : '?';
    final decoration = frame?.buildFrameDecoration(surfaceColor: c.surface, suppressGlow: c.isLightMode) ??
        BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.accent.withValues(alpha: 0.6), width: 1.5),
          color: c.surface,
          boxShadow: c.isCosmicMode
              ? [
                  BoxShadow(
                    color: c.accent.withValues(alpha: 0.2),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        );

    return Container(
      width: 88,
      height: 88,
      decoration: decoration,
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
}

class _Initials extends ConsumerWidget {
  final String letter;
  const _Initials({required this.letter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return ColoredBox(
      color: c.surface,
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: c.accent,
            fontSize: 32,
            fontWeight: FontWeight.w200,
            letterSpacing: 1,
          ),
        ),
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

    if (c.isCosmicMode) {
      return GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        shape: LiquidRoundedSuperellipse(borderRadius: 14),
        useOwnLayer: true,
        quality: GlassQuality.standard,
        clipBehavior: Clip.antiAlias,
        settings: _glassSettings(),
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

// ── XP Panel ─────────────────────────────────────────────────

class _XpPanel extends ConsumerWidget {
  final PublicProfile profile;
  const _XpPanel({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c          = ref.watch(sieColorsProvider);
    final xpInLevel  = profile.xpInLevel;
    final progress   = xpInLevel / 1000.0;
    final xpToNext   = 1000 - xpInLevel;

    final inner = Column(
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
                    color: c.accent,
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
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: c.border,
            valueColor: AlwaysStoppedAnimation<Color>(c.accent),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${(progress * 100).toStringAsFixed(0)}%  ·  LVL ${profile.level} → LVL ${profile.level + 1}',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontSize: 9, letterSpacing: 1),
        ),
      ],
    );

    if (c.isCosmicMode) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        shape: LiquidRoundedSuperellipse(borderRadius: 16),
        useOwnLayer: true,
        quality: GlassQuality.standard,
        clipBehavior: Clip.antiAlias,
        settings: _glassSettings(),
        child: inner,
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: c.flatCard(radius: 16),
      child: inner,
    );
  }
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
      loading: () => SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(color: c.accent, strokeWidth: 1.5),
        ),
      ),
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
            crossAxisCount: 6,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
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
              boxShadow: earned && c.isCosmicMode
                  ? [
                      BoxShadow(
                          color: c.accent.withValues(alpha: 0.25),
                          blurRadius: 16)
                    ]
                  : null,
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
