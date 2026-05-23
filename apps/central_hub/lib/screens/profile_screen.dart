import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:sie_core/sie_core.dart';

import 'customization_screen.dart';
import 'edit_profile_screen.dart';
import 'interface_hub_screen.dart';
import 'knowledge_base_screen.dart';
import 'progress_analytics_screen.dart';

const _kCyan   = Color(0xFF00E5FF);
const _kPurple = Color(0xFF7000FF);

// ─────────────────────────────────────────────────────────────────────────────
// ProfileScreen
// ─────────────────────────────────────────────────────────────────────────────
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.asTab = false});

  /// When true the screen is mounted inside the navigation shell — skip the
  /// own GlassPage wrapper (shell provides it) and hide the back button.
  final bool asTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    final body = SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopBar(showBackButton: !asTab),
          Expanded(
            child: profileAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: SieTheme.accent,
                  strokeWidth: 1.5,
                ),
              ),
              error: (e, _) => Center(
                child: Text(
                  'ERROR: $e',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                  ),
                ),
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

    return GlassPage(
      background: const SieSpaceBackground(),
      statusBarStyle: GlassStatusBarStyle.light,
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

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        width: 36,
        height: 36,
        padding: EdgeInsets.zero,
        shape: LiquidRoundedSuperellipse(borderRadius: 18),
        useOwnLayer: true,
        quality: GlassQuality.standard,
        clipBehavior: Clip.antiAlias,
        settings: LiquidGlassSettings(
          blur: 2.0,
          thickness: 20,
          refractiveIndex: 1.45,
          glassColor: const Color(0x0A0A0E1A),
          lightAngle: GlassDefaults.lightAngle,
          lightIntensity: 0.72,
          glowIntensity: 0.85,
          saturation: 1.4,
          specularSharpness: GlassSpecularSharpness.sharp,
          ambientStrength: 0.08,
          chromaticAberration: 0.015,
        ),
        child: Center(
          child: Icon(icon, color: SieTheme.textSecondary, size: 15),
        ),
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
    final frames = ref.watch(avatarFramesProvider).valueOrNull ?? [];
    final frame = profile?.equippedFrameId != null
        ? frames
            .where((f) => f.id == profile!.equippedFrameId)
            .firstOrNull
        : null;
    final frameDecoration = frame?.buildFrameDecoration() ??
        BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _kCyan.withValues(alpha: 0.45),
            width: 1.5,
          ),
          color: SieTheme.surface,
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderGlassCard(
            profile: profile,
            frameDecoration: frameDecoration,
          ),
          const SizedBox(height: 20),
          _NavButton(
            icon: Icons.analytics_outlined,
            title: 'PROGRESS HUB',
            subtitle: 'Activity matrix, XP growth & focus stats',
            iconColor: _kCyan,
            onTap: () => Navigator.of(context).push(PageRouteBuilder(
              pageBuilder: (_, _, _) => const ProgressAnalyticsScreen(),
              transitionsBuilder: (_, a, _, c) =>
                  FadeTransition(opacity: a, child: c),
              transitionDuration: const Duration(milliseconds: 400),
            )),
          ),
          const SizedBox(height: 10),
          _NavButton(
            icon: Icons.menu_book_rounded,
            title: 'БАЗА ЗНАНИЙ',
            subtitle: 'Физиология, психология, XP-таблица и этика SiE',
            iconColor: _kCyan,
            onTap: () => Navigator.of(context).push(PageRouteBuilder(
              pageBuilder: (_, _, _) => const KnowledgeBaseScreen(),
              transitionsBuilder: (_, a, _, c) =>
                  FadeTransition(opacity: a, child: c),
              transitionDuration: const Duration(milliseconds: 400),
            )),
          ),
          const SizedBox(height: 10),
          if (profile != null)
            _NavButton(
              icon: Icons.style_outlined,
              title: 'НАСТРОЙКА ОБЛИКА',
              subtitle: 'Рамки аватара, фоны профиля и стили статистики',
              iconColor: _kCyan,
              onTap: () => Navigator.of(context).push(PageRouteBuilder(
                pageBuilder: (_, _, _) =>
                    CustomizationScreen(profile: profile!),
                transitionsBuilder: (_, a, _, c) =>
                    FadeTransition(opacity: a, child: c),
                transitionDuration: const Duration(milliseconds: 400),
              )),
            ),
          const SizedBox(height: 10),
          _NavButton(
            icon: Icons.storefront_outlined,
            title: 'ИНТЕРФЕЙС-ХАБ',
            subtitle: 'Рамки, фоны и стили за Design Points',
            iconColor: SieTheme.dp,
            onTap: () => Navigator.of(context).push(PageRouteBuilder(
              pageBuilder: (_, _, _) => const InterfaceHubScreen(),
              transitionsBuilder: (_, a, _, c) =>
                  FadeTransition(opacity: a, child: c),
              transitionDuration: const Duration(milliseconds: 400),
            )),
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: 'MEDALS VAULT'),
          const SizedBox(height: 4),
          Text(
            'EARNED COMMENDATIONS & COMBAT DECORATIONS',
            style: TextStyle(
              color: SieTheme.textSecondary.withValues(alpha: 0.55),
              fontSize: 9,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const _MedalsVault(),
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header Glass Card — avatar + chips + XP bar
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderGlassCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final username  = profile?.username?.toUpperCase() ?? 'UNKNOWN';
    final letter    = username.isNotEmpty ? username[0] : '?';
    final xp        = profile?.totalXp ?? 0;
    final level     = (xp ~/ 1000) + 1;
    final xpInLevel = xp % 1000;
    final progress  = (xpInLevel / 1000.0).clamp(0.0, 1.0);
    final xpToNext  = 1000 - xpInLevel;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      shape: LiquidRoundedSuperellipse(borderRadius: 24),
      useOwnLayer: true,
      quality: GlassQuality.standard,
      clipBehavior: Clip.antiAlias,
      settings: LiquidGlassSettings(
        blur: 3.5,
        thickness: 28,
        refractiveIndex: 1.45,
        glassColor: const Color(0x0A0A0E1A),
        lightAngle: GlassDefaults.lightAngle,
        lightIntensity: 0.72,
        glowIntensity: 0.92,
        saturation: 1.4,
        specularSharpness: GlassSpecularSharpness.sharp,
        ambientStrength: 0.08,
        chromaticAberration: 0.015,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar + name row ─────────────────────────────
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
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontSize: 18,
                                shadows: [
                                  Shadow(
                                    color: _kCyan.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Chip(
                          label: 'LEVEL $level',
                          borderColor: _kCyan.withValues(alpha: 0.5),
                          textColor: _kCyan,
                        ),
                        const SizedBox(width: 8),
                        _Chip(
                          label: '${profile?.designPoints ?? 0} DP',
                          borderColor: SieTheme.dp.withValues(alpha: 0.45),
                          textColor: SieTheme.dp,
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

          // ── XP progress bar ───────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$xp XP TOTAL',
                style: const TextStyle(
                  color: _kCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '$xpToNext XP TO LVL ${level + 1}',
                style: const TextStyle(
                  color: SieTheme.textSecondary,
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
                Container(
                  height: 6,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 6,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_kCyan, _kPurple],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x4400E5FF),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
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
            style: const TextStyle(
              color: SieTheme.textSecondary,
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarLetter extends StatelessWidget {
  const _AvatarLetter({required this.letter});
  final String letter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          color: _kCyan,
          fontSize: 28,
          fontWeight: FontWeight.w200,
          shadows: [Shadow(color: _kCyan.withValues(alpha: 0.6), blurRadius: 12)],
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
// Nav Button — SieGlassCard row with icon + title + subtitle + chevron
// ─────────────────────────────────────────────────────────────────────────────
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SieGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: iconColor == SieTheme.dp ? SieTheme.dp : null,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                        color: SieTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: iconColor.withValues(alpha: 0.5),
            size: 16,
          ),
        ],
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
    final achievementsAsync = ref.watch(userAchievementsProvider);

    return achievementsAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(
            color: SieTheme.accent,
            strokeWidth: 1.5,
          ),
        ),
      ),
      error: (_, _) => const Text(
        'NO ACHIEVEMENTS DEFINED IN DATABASE',
        style: TextStyle(
          color: SieTheme.textSecondary,
          fontSize: 11,
          letterSpacing: 1,
        ),
      ),
      data: (achievements) {
        if (achievements.isEmpty) {
          return const Text(
            'NO MEDALS YET — COMPLETE MISSIONS TO EARN COMMENDATIONS',
            style: TextStyle(
              color: SieTheme.textSecondary,
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
