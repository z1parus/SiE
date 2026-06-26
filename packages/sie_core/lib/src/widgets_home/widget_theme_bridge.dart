import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/sie_colors.dart';
import '../theme/sie_theme.dart';
import 'widget_config.dart';

class WidgetRenderContext {
  final SieColors colors;
  final double pixelRatio;
  final WidgetConfig config;

  const WidgetRenderContext({
    required this.colors,
    required this.pixelRatio,
    required this.config,
  });

  /// Accent honouring a Studio override, falling back to the theme accent.
  Color get accent => config.accentOverride ?? colors.accent;

  /// Card decoration honouring the configured background style. Shared by all
  /// modules so the Studio's background picker affects every widget uniformly.
  BoxDecoration get surfaceDecoration {
    final c = colors;
    final radius = BorderRadius.circular(20);
    switch (config.bgStyle) {
      case WidgetBackgroundStyle.transparent:
        return BoxDecoration(borderRadius: radius);
      case WidgetBackgroundStyle.glass:
        return BoxDecoration(
          color: c.surface.withValues(alpha: 0.55),
          borderRadius: radius,
          border: Border.all(color: c.border.withValues(alpha: 0.6)),
        );
      case WidgetBackgroundStyle.gradient:
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              c.surface,
              Color.alphaBlend(accent.withValues(alpha: 0.14), c.surface),
            ],
          ),
          borderRadius: radius,
          border: Border.all(color: c.border),
        );
      case WidgetBackgroundStyle.flat:
        return BoxDecoration(
          color: c.surface,
          borderRadius: radius,
          border: Border.all(color: c.border),
        );
    }
  }
}

class WidgetThemeBridge {
  static const _prefsKey = 'sie_theme_mode';

  static Future<WidgetRenderContext> resolve(WidgetConfig cfg) async {
    final appMode = await _readAppMode();
    final mode = switch (cfg.themeOverride) {
      WidgetThemeMode.forceDark  => SieThemeMode.classicDark,
      WidgetThemeMode.forceLight => SieThemeMode.classicLight,
      WidgetThemeMode.followApp  => appMode,
    };
    return WidgetRenderContext(
      colors: SieColors.forMode(mode),
      pixelRatio: 3.0,
      config: cfg,
    );
  }

  static Future<SieThemeMode> _readAppMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return SieThemeMode.classicDark;
    return SieThemeMode.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => SieThemeMode.classicDark,
    );
  }
}
