import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cosmetic_asset.dart';
import '../theme/sie_colors.dart';
import '../theme/sie_motion.dart';
import 'profile_pattern_layer.dart';

/// Shared "operative card" hero used by both the personal ([ProfileScreen])
/// and public ([PublicProfileScreen]) profiles.
///
/// Layered background (bottom → top):
///   0. base decoration — custom colour / gradient / themed [SieColors.flatCard]
///   1. animated pattern layer (currently the neural network; generalised to a
///      [CosmeticAsset] pattern in a later stage)
///   2. readability scrim — only when a decorative background/pattern is present
///   3. content — avatar with level ring + badge, callsign, rank, chips, XP bar
///
/// Driven purely by primitives so it is agnostic of `Profile` vs
/// `PublicProfile`.
class ProfileHeroCard extends ConsumerWidget {
  const ProfileHeroCard({
    super.key,
    required this.username,
    required this.avatarUrl,
    required this.totalXp,
    required this.designPoints,
    this.frame,
    this.background,
    this.pattern,
    this.avatarSize = 72,
    this.onAvatarTap,
  });

  final String username;
  final String? avatarUrl;
  final int totalXp;
  final int designPoints;

  /// Equipped avatar frame (border / glow), if any.
  final CosmeticAsset? frame;

  /// Equipped profile background (colour / gradient / pattern flag), if any.
  final CosmeticAsset? background;

  /// Equipped animated pattern overlay, if any.
  final CosmeticAsset? pattern;

  final double avatarSize;
  final VoidCallback? onAvatarTap;

  static String rankLabel(int level) {
    if (level <= 5) return 'Recruit';
    if (level <= 10) return 'Operative';
    if (level <= 20) return 'Explorer';
    return 'Commander';
  }

  static BoxDecoration _baseDecoration(SieColors c, CosmeticAsset? bg) {
    if (bg?.backgroundColor != null) {
      return BoxDecoration(
        color: bg!.backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: bg.accentColor.withValues(alpha: 0.25)),
      );
    }
    if (bg?.backgroundGradient != null) {
      return BoxDecoration(
        gradient: bg!.backgroundGradient,
        borderRadius: BorderRadius.circular(24),
      );
    }
    return c.flatCard(radius: 24);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);

    final name = username.toUpperCase().isEmpty ? 'UNKNOWN' : username.toUpperCase();
    final level = (totalXp ~/ 1000) + 1;
    final xpInLevel = totalXp % 1000;
    final progress = (xpInLevel / 1000.0).clamp(0.0, 1.0);
    final xpToNext = 1000 - xpInLevel;

    final hasCustomBg = background != null &&
        (background!.backgroundColor != null ||
            background!.backgroundGradient != null);
    // Legacy behaviour: backgrounds with a custom colour or the
    // `use_neural_pattern` flag rendered the neural overlay before patterns
    // existed as a first-class asset.
    final legacyNeural = background != null &&
        (background!.backgroundColor != null || background!.useNeuralPattern);
    final showPattern = pattern != null || legacyNeural;
    final decorated = hasCustomBg || showPattern;

    // With a decorative background/pattern we darken behind the text with a
    // scrim and render the copy in white for reliable contrast; otherwise the
    // themed text colours are used.
    final textMain = decorated ? Colors.white : c.textPrimary;
    final textSub = decorated ? Colors.white70 : c.textSecondary;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: SieMotion.duration(context, SieMotion.slow),
      curve: Curves.easeOutCubic,
      builder: (context, animProgress, _) {
        return Container(
          clipBehavior: Clip.hardEdge,
          decoration: _baseDecoration(c, background),
          child: Stack(
            children: [
              if (showPattern)
                Positioned.fill(
                  child: ProfilePatternLayer(
                    pattern: pattern,
                    accent: background?.accentColor ?? c.accent,
                    legacyNeural: legacyNeural,
                  ),
                ),
              if (decorated)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.34),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _LevelRingAvatar(
                          avatarUrl: avatarUrl,
                          fallbackLetter: name.isNotEmpty ? name[0] : '?',
                          frame: frame,
                          level: level,
                          progress: animProgress,
                          size: avatarSize,
                          c: c,
                          onTap: onAvatarTap,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textMain,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rankLabel(level).toUpperCase(),
                                style: TextStyle(
                                  color: textSub,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _HeroChip(
                                label: '$designPoints DP',
                                borderColor: c.dp.withValues(alpha: 0.45),
                                textColor: decorated ? Colors.white : c.dp,
                                icon: Icons.palette_outlined,
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
                          '$totalXp XP TOTAL',
                          style: TextStyle(
                            color: decorated ? Colors.white : c.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          '$xpToNext XP TO LVL ${level + 1}',
                          style: TextStyle(color: textSub, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Stack(
                        children: [
                          Container(
                            height: 10,
                            color: decorated
                                ? Colors.white.withValues(alpha: 0.18)
                                : c.border,
                          ),
                          FractionallySizedBox(
                            widthFactor: animProgress,
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [c.accent, c.accentSecondary],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%  ·  '
                      'LVL $level → LVL ${level + 1}',
                      style: TextStyle(
                        color: textSub,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Avatar with level progress ring + level badge ────────────────────────────

class _LevelRingAvatar extends StatelessWidget {
  const _LevelRingAvatar({
    required this.avatarUrl,
    required this.fallbackLetter,
    required this.frame,
    required this.level,
    required this.progress,
    required this.size,
    required this.c,
    this.onTap,
  });

  final String? avatarUrl;
  final String fallbackLetter;
  final CosmeticAsset? frame;
  final int level;
  final double progress;
  final double size;
  final SieColors c;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const ringGap = 6.0; // space between ring and avatar
    const stroke = 3.0;
    final ringSize = size + ringGap * 2 + stroke * 2;

    final frameDecoration = frame?.buildFrameDecoration(
          surfaceColor: c.surface,
          suppressGlow: c.isLightMode,
        ) ??
        BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.accent.withValues(alpha: 0.45), width: 1.5),
          color: c.surface,
        );

    final avatar = Container(
      width: size,
      height: size,
      decoration: frameDecoration,
      child: ClipOval(
        child: avatarUrl != null
            ? Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _Initials(letter: fallbackLetter, c: c),
              )
            : _Initials(letter: fallbackLetter, c: c),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: ringSize,
        height: ringSize + 8, // room for the level badge to overflow
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            SizedBox(
              width: ringSize,
              height: ringSize,
              child: CustomPaint(
                painter: _LevelRingPainter(
                  progress: progress,
                  trackColor: c.border.withValues(alpha: 0.6),
                  start: c.accent,
                  end: c.accentSecondary,
                  stroke: stroke,
                ),
                child: Center(child: avatar),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(child: _LevelBadge(level: level, c: c)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, required this.c});
  final int level;
  final SieColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.surface, width: 1.5),
      ),
      child: Text(
        'LVL $level',
        style: TextStyle(
          color: c.isLightMode ? Colors.white : c.background,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _LevelRingPainter extends CustomPainter {
  _LevelRingPainter({
    required this.progress,
    required this.trackColor,
    required this.start,
    required this.end,
    required this.stroke,
  });

  final double progress;
  final Color trackColor;
  final Color start;
  final Color end;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final sweep = 2 * math.pi * progress;
    const startAngle = -math.pi / 2;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + 2 * math.pi,
        colors: [start, end, start],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(rect);
    canvas.drawArc(rect, startAngle, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_LevelRingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.start != start ||
      old.end != end;
}

class _Initials extends StatelessWidget {
  const _Initials({required this.letter, required this.c});
  final String letter;
  final SieColors c;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: c.surface,
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: c.accent,
            fontSize: 30,
            fontWeight: FontWeight.w200,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
