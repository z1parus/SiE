import 'package:flutter/widgets.dart';
import '../local/app_database.dart';
import 'modules/habits_widget_provider.dart';
import 'widget_action_router.dart';
import 'widget_registry.dart';
import 'widget_render_service.dart';

/// Register all module widget providers. Call once at app startup and once
/// inside [widgetInteractivityCallback] (background isolate) before any render.
void registerHomeWidgets() {
  WidgetRegistry.instance
    ..register(HabitsWidgetProvider());
}

/// Re-render every active widget. Call on app launch so the home screen
/// reflects any data that changed while the app was closed (e.g. day rollover).
/// Reads straight from the local Drift mirror — no network, no auth required.
Future<void> refreshHomeWidgetsOnLaunch(AppDatabase db) async {
  try {
    await WidgetRenderService.refreshAll(db);
  } catch (e) {
    debugPrint('SiE Widgets: launch refresh failed — $e');
  }
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
