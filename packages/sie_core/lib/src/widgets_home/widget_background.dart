import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import '../local/app_database.dart';
import 'modules/habits_widget_provider.dart';
import 'widget_registry.dart';
import 'widget_render_service.dart';

const _taskName = 'sie_widgets_refresh';
const _taskTag = 'refresh';

/// Register all module widget providers. Call once at app startup and
/// once inside [widgetCallbackDispatcher] (background isolate).
void registerHomeWidgets() {
  WidgetRegistry.instance
    ..register(HabitsWidgetProvider());
}

/// Call once in `main()` after `WidgetsFlutterBinding.ensureInitialized()`.
Future<void> initWidgetWorkManager() async {
  await Workmanager().initialize(
    widgetCallbackDispatcher,
    isInDebugMode: false,
  );
  await Workmanager().registerPeriodicTask(
    _taskName,
    _taskTag,
    frequency: const Duration(minutes: 30),
    constraints: Constraints(networkType: NetworkType.not_required),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
}

/// Background isolate entry point — called by WorkManager every 30 min.
@pragma('vm:entry-point')
void widgetCallbackDispatcher() {
  Workmanager().executeTask((_, __) async {
    WidgetsFlutterBinding.ensureInitialized();
    registerHomeWidgets();
    final db = AppDatabase();
    try {
      await WidgetRenderService.refreshAll(db);
    } finally {
      await db.close();
    }
    return true;
  });
}
