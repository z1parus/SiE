import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import '../local/app_database.dart';
import 'modules/focus_widget_provider.dart';
import 'modules/habits_widget_provider.dart';
import 'widget_action_router.dart';
import 'widget_config.dart';
import 'widget_config_store.dart';
import 'widget_registry.dart';
import 'widget_render_service.dart';
import 'widget_size_bucket.dart';

/// Register all module widget providers. Call once at app startup and once
/// inside [widgetInteractivityCallback] (background isolate) before any render.
void registerHomeWidgets() {
  WidgetRegistry.instance
    ..register(HabitsWidgetProvider())
    ..register(FocusWidgetProvider());
}

/// Re-render every active widget. Call on app launch so the home screen
/// reflects any data that changed while the app was closed (e.g. day rollover).
/// Reads straight from the local Drift mirror — no network, no auth required.
Future<void> refreshHomeWidgetsOnLaunch(AppDatabase db) async {
  try {
    await provisionInstalledWidgets();
    await WidgetRenderService.refreshAll(db);
  } catch (e) {
    debugPrint('SiE Widgets: launch refresh failed — $e');
  }
}

/// Ensures every widget the user has placed on the home screen has a config.
/// A launcher-placed widget arrives with no [WidgetConfig] (the Studio was
/// never opened), so its PNG is never rendered and it shows up blank. Here we
/// detect such instances and seed a sensible default so they render on launch.
Future<void> provisionInstalledWidgets() async {
  final List<HomeWidgetInfo> installed;
  try {
    installed = await HomeWidget.getInstalledWidgets();
  } catch (e) {
    debugPrint('SiE Widgets: getInstalledWidgets failed — $e');
    return;
  }

  for (final info in installed) {
    final id = info.androidWidgetId;
    if (id == null) continue;
    if (await WidgetConfigStore.load(id) != null) continue;

    final moduleId = _moduleForAndroidClass(info.androidClassName);
    if (moduleId == null) continue;

    final provider = WidgetRegistry.instance.get(moduleId);
    final defaultSize = provider != null &&
            provider.supportedSizes.contains(WidgetSizeBucket.medium)
        ? WidgetSizeBucket.medium
        : (provider?.supportedSizes.first ?? WidgetSizeBucket.medium);

    await WidgetConfigStore.save(WidgetConfig(
      appWidgetId: id,
      moduleId: moduleId,
      sizeBucket: defaultSize,
    ));
  }
}

String? _moduleForAndroidClass(String? className) {
  if (className == null) return null;
  for (final provider in WidgetRegistry.instance.all) {
    if (className.endsWith(provider.androidProviderClass)) {
      return provider.moduleId;
    }
  }
  return null;
}

/// Interactivity entry point — called by `home_widget` when a widget tap-zone
/// is pressed (registered via `HomeWidget.registerInteractivityCallback`).
/// Runs the quick-action fully offline and re-renders the widget.
@pragma('vm:entry-point')
Future<void> widgetInteractivityCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  registerHomeWidgets();
  final db = AppDatabase();
  try {
    await WidgetActionRouter.run(uri, db);
  } finally {
    await db.close();
  }
}
