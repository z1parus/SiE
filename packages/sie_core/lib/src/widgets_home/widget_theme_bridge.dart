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
