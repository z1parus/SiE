import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

import 'edit_profile_screen.dart';
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

    final equipped = EquippedAssets.resolve(
      frames:       frames,
      backgrounds:  backgrounds,
      styles:       styles,
      frameId:      profile?.equippedFrameId,
      backgroundId: profile?.equippedBackgroundId,
      styleId:      profile?.equippedStatStyleId,
    );

    final frameDecoration =
        equipped.frame?.buildFrameDecoration(surfaceColor: c.surface, suppressGlow: c.isLightMode) ??
        BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.accent.withValues(alpha: 0.45), width: 1.5),
          color: c.surface,
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
                  _HeaderGlassCard(
                    profile: profile,
                    frameDecoration: frameDecoration,
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
// Header Glass Card
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderGlassCard extends ConsumerWidget {
  const _HeaderGlassCard({
    required this.profile,
    required this.frameDecoration,
  });
  final Profile? profile;
  final BoxDecoration frameDecoration;

  static String _rankLabel(int level) {
    if (level <= 5)  return 'Recruit';
    if (level <= 10) return 'Operative';
    if (level <= 20) return 'Explorer';
    return 'Commander';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c          = ref.watch(sieColorsProvider);
    final username   = profile?.username?.toUpperCase() ?? 'UNKNOWN';
    final letter     = username.isNotEmpty ? username[0] : '?';
    final xp         = profile?.totalXp ?? 0;
    final level      = (xp ~/ 1000) + 1;
    final xpInLevel  = xp % 1000;
    final progress   = (xpInLevel / 1000.0).clamp(0.0, 1.0);
    final xpToNext   = 1000 - xpInLevel;

    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: frameDecoration,
              child: ClipOval(
                child: profile?.avatarUrl != null
                    ? Image.network(
                        profile!.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _AvatarLetter(letter: letter),
                      )
                    : _AvatarLetter(letter: letter),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          fontSize: 18,
                          shadows: null,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Chip(
                        label: 'LEVEL $level',
                        borderColor: c.accent.withValues(alpha: 0.5),
                        textColor: c.accent,
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        label: '${profile?.designPoints ?? 0} DP',
                        borderColor: c.dp.withValues(alpha: 0.45),
                        textColor: c.dp,
                        icon: Icons.palette_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$xp XP TOTAL',
              style: TextStyle(
                color: c.accent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              '$xpToNext XP TO LVL ${level + 1}',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            children: [
              Container(height: 6, color: c.border),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.accent, c.accentSecondary],
                    ),
                    boxShadow: null,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${(progress * 100).toStringAsFixed(0)}%  ·  '
          '${_rankLabel(level).toUpperCase()}  ·  '
          'LVL $level → LVL ${level + 1}',
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 9,
            letterSpacing: 1,
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: c.flatCard(radius: 24),
      child: inner,
    );
  }
}

class _AvatarLetter extends ConsumerWidget {
  const _AvatarLetter({required this.letter});
  final String letter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          color: c.accent,
          fontSize: 28,
          fontWeight: FontWeight.w200,
          shadows: null,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.borderColor,
    required this.textColor,
    this.icon,
  });
  final String label;
  final Color borderColor;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: textColor),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
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
// Medals Vault — 3-column achievement grid
// ─────────────────────────────────────────────────────────────────────────────
class _MedalsVault extends ConsumerWidget {
  const _MedalsVault();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c                = ref.watch(sieColorsProvider);
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
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 11,
          letterSpacing: 1,
        ),
      ),
      data: (achievements) {
        if (achievements.isEmpty) {
          return Text(
            'NO MEDALS YET — COMPLETE MISSIONS TO EARN COMMENDATIONS',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11,
              letterSpacing: 1,
            ),
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
          itemBuilder: (_, i) =>
              AchievementBadge(userAchievement: achievements[i]),
        );
      },
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
