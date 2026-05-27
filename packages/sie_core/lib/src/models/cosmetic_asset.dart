import 'package:flutter/material.dart';
import '../theme/sie_theme.dart';

enum AssetType { avatarFrame, profileBackground, statStyle }

extension AssetTypeX on AssetType {
  String get dbValue => switch (this) {
        AssetType.avatarFrame       => 'avatar_frame',
        AssetType.profileBackground => 'profile_background',
        AssetType.statStyle         => 'stat_style',
      };
}

enum CosmeticRarity { common, rare, epic, legendary }

class CosmeticAsset {
  final String id;
  final String slug;
  final String name;
  final String? imageUrl;
  final AssetType type;
  final CosmeticRarity rarity;
  final Map<String, dynamic> styleConfig;
  final int priceDP;

  const CosmeticAsset({
    required this.id,
    required this.slug,
    required this.name,
    this.imageUrl,
    required this.type,
    required this.rarity,
    this.styleConfig = const {},
    this.priceDP = 0,
  });

  factory CosmeticAsset.fromJson(Map<String, dynamic> json, AssetType type) {
    final raw = json['style_config'];
    final config = raw is Map<String, dynamic>
        ? raw
        : <String, dynamic>{};
    return CosmeticAsset(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String?,
      type: type,
      rarity: _parseRarity(json['rarity'] as String?),
      styleConfig: config,
      priceDP: json['price_dp'] as int? ?? 0,
    );
  }

  static CosmeticRarity _parseRarity(String? s) => switch (s) {
        'rare'      => CosmeticRarity.rare,
        'epic'      => CosmeticRarity.epic,
        'legendary' => CosmeticRarity.legendary,
        _           => CosmeticRarity.common,
      };

  // ── Rarity helpers ─────────────────────────────────────────

  Color get rarityColor => switch (rarity) {
        CosmeticRarity.common    => SieTheme.textSecondary,
        CosmeticRarity.rare      => const Color(0xFF4A90D9),
        CosmeticRarity.epic      => const Color(0xFF9B59B6),
        CosmeticRarity.legendary => const Color(0xFFFFD700),
      };

  String get rarityLabel => switch (rarity) {
        CosmeticRarity.common    => 'COMMON',
        CosmeticRarity.rare      => 'RARE',
        CosmeticRarity.epic      => 'EPIC',
        CosmeticRarity.legendary => 'LEGENDARY',
      };

  // ── Frame helpers ──────────────────────────────────────────

  Color get borderColor =>
      _hexColor(styleConfig['border_color'] as String?) ?? SieTheme.borderAccent;
  double get borderWidth =>
      (styleConfig['border_width'] as num?)?.toDouble() ?? 1.5;
  Color? get glowColor =>
      _hexColor(styleConfig['glow_color'] as String?);
  double get glowRadius =>
      (styleConfig['glow_radius'] as num?)?.toDouble() ?? 0;

  BoxDecoration buildFrameDecoration({Color? surfaceColor, bool suppressGlow = false}) =>
      BoxDecoration(
        shape: BoxShape.circle,
        color: surfaceColor ?? SieTheme.surface,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: (!suppressGlow && glowColor != null && glowRadius > 0)
            ? [BoxShadow(color: glowColor!, blurRadius: glowRadius, spreadRadius: 1)]
            : null,
      );

  // ── Background helpers ─────────────────────────────────────

  Gradient? get backgroundGradient {
    final colors = styleConfig['gradient_colors'] as List?;
    if (colors == null || colors.isEmpty) return null;
    final parsed = colors
        .map((c) => _hexColor(c as String?) ?? SieTheme.background)
        .toList();
    return LinearGradient(
      begin: _parseAlignment(styleConfig['gradient_begin'] as String?),
      end: _parseAlignment(styleConfig['gradient_end'] as String?),
      colors: parsed,
    );
  }

  // ── Stat style helpers ─────────────────────────────────────

  Color get accentColor =>
      _hexColor(styleConfig['accent_color'] as String?) ?? SieTheme.accent;
  Color get styleBorderColor =>
      _hexColor(styleConfig['border_color'] as String?) ?? SieTheme.borderDefault;
  Color? get styleGlowColor =>
      _hexColor(styleConfig['glow_color'] as String?);
  double get styleGlowRadius =>
      (styleConfig['glow_radius'] as num?)?.toDouble() ?? 0;

  BoxDecoration buildStatCardDecoration({Color? surfaceColor}) {
    final glow = styleGlowColor;
    return BoxDecoration(
      color: surfaceColor ?? SieTheme.surface,
      border: Border.all(color: styleBorderColor),
      borderRadius: BorderRadius.circular(4),
      boxShadow: glow != null && styleGlowRadius > 0
          ? [BoxShadow(color: glow, blurRadius: styleGlowRadius)]
          : null,
    );
  }

  // ── Shared helpers ─────────────────────────────────────────

  static Color? _hexColor(String? hex) {
    if (hex == null || hex == 'null') return null;
    final h = hex.startsWith('#') ? hex.substring(1) : hex;
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    if (h.length == 8) return Color(int.parse(h, radix: 16));
    return null;
  }

  static Alignment _parseAlignment(String? s) => switch (s) {
        'topLeft'      => Alignment.topLeft,
        'topRight'     => Alignment.topRight,
        'topCenter'    => Alignment.topCenter,
        'bottomLeft'   => Alignment.bottomLeft,
        'bottomRight'  => Alignment.bottomRight,
        'bottomCenter' => Alignment.bottomCenter,
        _              => Alignment.topCenter,
      };
}

// Resolved equipped assets for a profile — populated by looking up catalog lists.
class EquippedAssets {
  final CosmeticAsset? frame;
  final CosmeticAsset? background;
  final CosmeticAsset? statStyle;

  const EquippedAssets({this.frame, this.background, this.statStyle});
  static const none = EquippedAssets();

  static EquippedAssets resolve({
    required List<CosmeticAsset> frames,
    required List<CosmeticAsset> backgrounds,
    required List<CosmeticAsset> styles,
    String? frameId,
    String? backgroundId,
    String? styleId,
  }) =>
      EquippedAssets(
        frame: frameId != null
            ? frames.where((f) => f.id == frameId).firstOrNull
            : null,
        background: backgroundId != null
            ? backgrounds.where((b) => b.id == backgroundId).firstOrNull
            : null,
        statStyle: styleId != null
            ? styles.where((s) => s.id == styleId).firstOrNull
            : null,
      );
}
