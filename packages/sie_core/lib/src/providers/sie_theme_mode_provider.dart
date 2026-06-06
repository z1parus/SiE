import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/sie_theme.dart';

final sieThemeModeProvider =
    AsyncNotifierProvider<SieThemeModeNotifier, SieThemeMode>(
  SieThemeModeNotifier.new,
);

class SieThemeModeNotifier extends AsyncNotifier<SieThemeMode> {
  static const _prefsKey = 'sie_theme_mode';

  @override
  Future<SieThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    return SieThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => SieThemeMode.classicDark,
    );
  }

  Future<void> setMode(SieThemeMode mode) async {
    // Update state immediately so the UI responds before the disk write.
    state = AsyncData(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}
