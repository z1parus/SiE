import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:sie_core/sie_core.dart';

import 'customization_screen.dart';
import 'edit_profile_screen.dart';
import 'interface_hub_screen.dart';
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

    if (c.isCosmicMode) {
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
          child: child,
        ),
      );
    }

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

    final frameDecoration = equipped.frame?.buildFrameDecoration() ??
        BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.accent.withValues(alpha: 0.45), width: 1.5),
          color: c.surface,
        );

    final xp    = profile?.totalXp ?? 0;
    final level = (xp ~/ 1000) + 1;

    return Stack(
      children: [
        if (equipped.background?.backgroundGradient != null && c.isCosmicMode)
          Positioned.fill(
            child: Opacity(
              opacity: 0.28,
              child: Container(
                decoration: BoxDecoration(
                  gradient: equipped.background!.backgroundGradient,
                ),
              ),
            ),
          ),
        RepaintBoundary(
          child: SingleChildScrollView(
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
                _NavButton(
                  icon: Icons.analytics_outlined,
                  title: 'PROGRESS HUB',
                  subtitle: 'Activity matrix, XP growth & focus stats',
                  iconColor: c.accent,
                  onTap: () => Navigator.of(context).push(PageRouteBuilder(
                    pageBuilder: (_, _, _) => const ProgressAnalyticsScreen(),
                    transitionsBuilder: (_, a, _, ch) =>
                        FadeTransition(opacity: a, child: ch),
                    transitionDuration: const Duration(milliseconds: 400),
                  )),
                ),
                const SizedBox(height: 10),
                _NavButton(
                  icon: Icons.menu_book_rounded,
                  title: 'БАЗА ЗНАНИЙ',
                  subtitle: 'Физиология, психология, XP-таблица и этика SiE',
                  iconColor: c.accent,
                  onTap: () => Navigator.of(context).push(PageRouteBuilder(
                    pageBuilder: (_, _, _) => const KnowledgeBaseScreen(),
                    transitionsBuilder: (_, a, _, ch) =>
                        FadeTransition(opacity: a, child: ch),
                    transitionDuration: const Duration(milliseconds: 400),
                  )),
                ),
                const SizedBox(height: 10),
                if (profile != null)
                  _NavButton(
                    icon: Icons.style_outlined,
                    title: 'НАСТРОЙКА ОБЛИКА',
                    subtitle: 'Рамки аватара, фоны профиля и стили статистики',
                    iconColor: c.accent,
                    onTap: () => Navigator.of(context).push(PageRouteBuilder(
                      pageBuilder: (_, _, _) =>
                          CustomizationScreen(profile: profile!),
                      transitionsBuilder: (_, a, _, ch) =>
                          FadeTransition(opacity: a, child: ch),
                      transitionDuration: const Duration(milliseconds: 400),
                    )),
                  ),
                const SizedBox(height: 10),
                _NavButton(
                  icon: Icons.storefront_outlined,
                  title: 'ИНТЕРФЕЙС-ХАБ',
                  subtitle: 'Рамки, фоны и стили за Design Points',
                  iconColor: c.dp,
                  highlightTitle: true,
                  onTap: () => Navigator.of(context).push(PageRouteBuilder(
                    pageBuilder: (_, _, _) => const InterfaceHubScreen(),
                    transitionsBuilder: (_, a, _, ch) =>
                        FadeTransition(opacity: a, child: ch),
                    transitionDuration: const Duration(milliseconds: 400),
                  )),
                ),
                const SizedBox(height: 28),
                const SectionHeader(title: 'РЕЖИМ ИНТЕРФЕЙСА'),
                const SizedBox(height: 4),
                Text(
                  'ГРАФИЧЕСКАЯ НАГРУЗКА И СТИЛЬ ОФОРМЛЕНИЯ',
                  style: TextStyle(
                    color: c.textSecondary.withValues(alpha: 0.55),
                    fontSize: 9,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                const _ThemeSwitcherSection(),
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
                          shadows: c.isCosmicMode
                              ? [
                                  Shadow(
                                    color: c.accent.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
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
              Container(
                height: 6,
                color: c.isCosmicMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : c.border,
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.accent, c.accentSecondary],
                    ),
                    boxShadow: c.isCosmicMode
                        ? [
                            BoxShadow(
                              color: c.accent.withValues(alpha: 0.27),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
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

    if (c.isCosmicMode) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        shape: LiquidRoundedSuperellipse(borderRadius: 24),
        useOwnLayer: false,
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
        child: inner,
      );
    }

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
          shadows: c.isCosmicMode
              ? [Shadow(color: c.accent.withValues(alpha: 0.6), blurRadius: 12)]
              : null,
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
class _StatStyleCard extends StatelessWidget {
  const _StatStyleCard({
    required this.statStyle,
    required this.level,
    required this.xp,
  });
  final CosmeticAsset statStyle;
  final int level;
  final int xp;

  @override
  Widget build(BuildContext context) {
    final accent  = statStyle.accentColor;
    final glowCol = statStyle.styleGlowColor;
    final glowRad = statStyle.styleGlowRadius;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: statStyle.buildStatCardDecoration(),
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
// Nav Button
// ─────────────────────────────────────────────────────────────────────────────
class _NavButton extends ConsumerWidget {
  const _NavButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
    this.highlightTitle = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;
  final bool highlightTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: c.subtleContainer(radius: 20),
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
                          color: highlightTitle ? iconColor : null,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                          color: c.textSecondary,
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

// ─────────────────────────────────────────────────────────────────────────────
// Theme Mode Switcher
// ─────────────────────────────────────────────────────────────────────────────
class _ThemeSwitcherSection extends ConsumerWidget {
  const _ThemeSwitcherSection();

  static const _options = [
    (
      mode: SieThemeMode.cosmicLiquidGlass,
      label: 'COSMIC LIQUID GLASS',
      description: 'Звёздное поле, стеклянные шейдеры',
      bgColor: Color(0xFF0A0E1A),
      accentColor: Color(0xFF00E5FF),
    ),
    (
      mode: SieThemeMode.classicDark,
      label: 'CLASSIC DARK',
      description: 'Антрацит + золото, без шейдеров',
      bgColor: Color(0xFF1C1C22),
      accentColor: Color(0xFFC8A84B),
    ),
    (
      mode: SieThemeMode.classicLight,
      label: 'CLASSIC LIGHT',
      description: 'Светлый фон + бирюза, без шейдеров',
      bgColor: Color(0xFFF5F6FA),
      accentColor: Color(0xFF5AADA0),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c          = ref.watch(sieColorsProvider);
    final themeAsync = ref.watch(sieThemeModeProvider);
    final current    = themeAsync.valueOrNull ?? SieThemeMode.cosmicLiquidGlass;

    return Column(
      children: [
        for (int i = 0; i < _options.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _ThemeOptionTile(
            label: _options[i].label,
            description: _options[i].description,
            bgColor: _options[i].bgColor,
            accentColor: _options[i].accentColor,
            isActive: current == _options[i].mode,
            c: c,
            onTap: current == _options[i].mode
                ? null
                : () => ref
                    .read(sieThemeModeProvider.notifier)
                    .setMode(_options[i].mode),
          ),
        ],
      ],
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.label,
    required this.description,
    required this.bgColor,
    required this.accentColor,
    required this.isActive,
    required this.c,
    this.onTap,
  });

  final String label;
  final String description;
  final Color bgColor;
  final Color accentColor;
  final bool isActive;
  final SieColors c;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: isActive
              ? accentColor.withValues(alpha: 0.07)
              : (c.isLightMode
                  ? const Color(0x0A000000)
                  : Colors.white.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? accentColor.withValues(alpha: 0.50)
                : (c.isLightMode
                    ? c.border
                    : Colors.white.withValues(alpha: 0.08)),
            width: isActive ? 1.0 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.55),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.65),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive ? accentColor : c.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      shadows: isActive && c.isCosmicMode
                          ? [
                              Shadow(
                                color: accentColor.withValues(alpha: 0.35),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: isActive
                  ? Icon(
                      Icons.check_circle_rounded,
                      key: const ValueKey(true),
                      color: accentColor,
                      size: 18,
                    )
                  : Icon(
                      Icons.radio_button_unchecked_rounded,
                      key: const ValueKey(false),
                      color: c.textSecondary.withValues(alpha: 0.35),
                      size: 18,
                    ),
            ),
          ],
        ),
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
