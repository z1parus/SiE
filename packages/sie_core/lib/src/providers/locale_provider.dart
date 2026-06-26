import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../i18n/translations.g.dart';

const _kLocaleKey = 'app_locale';

/// The active app language. Holds the chosen [AppLocale] and keeps slang's
/// global locale (`LocaleSettings` → the `t` accessor) and the persisted
/// preference in sync. The app root watches this so the whole tree rebuilds in
/// the new language on change.
class LocaleNotifier extends Notifier<AppLocale> {
  @override
  AppLocale build() => LocaleSettings.instance.currentLocale;

  Future<void> setLocale(AppLocale locale) async {
    if (locale == state) return;
    LocaleSettings.setLocale(locale);
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, AppLocale>(LocaleNotifier.new);

/// Restores the saved language, or falls back to the device locale (with the
/// base locale — English — as the ultimate fallback for unsupported devices).
/// Call once in `main()` before `runApp`.
Future<void> initAppLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_kLocaleKey);
  if (saved == 'ru') {
    LocaleSettings.setLocaleSync(AppLocale.ru);
  } else if (saved == 'en') {
    LocaleSettings.setLocaleSync(AppLocale.en);
  } else {
    // No explicit choice yet — match the device, fall back to English.
    LocaleSettings.useDeviceLocaleSync();
  }
}
