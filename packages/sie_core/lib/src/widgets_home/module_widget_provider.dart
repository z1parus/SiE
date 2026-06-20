import 'package:flutter/material.dart';
import '../local/app_database.dart';
import 'widget_config.dart';
import 'widget_size_bucket.dart';
import 'widget_theme_bridge.dart';
import 'widget_option_spec.dart';

abstract class WidgetData {
  const WidgetData();
  String get signature;
}

class WidgetQuickAction {
  final String actionId;
  final String label;
  final IconData icon;

  const WidgetQuickAction({
    required this.actionId,
    required this.label,
    required this.icon,
  });
}

/// A tappable region overlaid on the rendered widget PNG. The native side
/// builds one transparent button per zone (top-to-bottom over the checklist
/// area) wired to a background action URI:
///   `sie://action/<actionPath>?widget=<id>&id=<entityId>`
class WidgetTapZone {
  /// e.g. `'habits/toggle'` — module + action.
  final String actionPath;

  /// Entity the action targets (e.g. a habit id).
  final String entityId;

  /// Current state (e.g. habit already done) — purely informational.
  final bool active;

  const WidgetTapZone({
    required this.actionPath,
    required this.entityId,
    this.active = false,
  });

  Map<String, dynamic> toMap() =>
      {'action': actionPath, 'id': entityId, 'active': active};
}

abstract class ModuleWidgetProvider<T extends WidgetData> {
  String get moduleId;
  String get displayName;
  IconData get glyph;
  List<WidgetSizeBucket> get supportedSizes;

  /// Android `AppWidgetProvider` subclass simple name (e.g.
  /// `'HabitsWidgetProvider'`). Used to map a launcher-placed widget instance
  /// back to its module when auto-provisioning a default config.
  String get androidProviderClass;

  /// Deep-link host used when the whole widget is tapped:
  /// `sie://widget/<deepLinkHost>`.
  String get deepLinkHost => moduleId;

  /// Config-aware deep-link host. Modules whose target screen can change based
  /// on widget settings (e.g. the Breathing widget can open either the Breathing
  /// or the Meditation module) override this. Default forwards to [deepLinkHost].
  String resolveDeepLinkHost(WidgetConfig cfg) => deepLinkHost;

  Future<T> loadData(AppDatabase db, WidgetConfig cfg);
  Widget render(WidgetRenderContext ctx, WidgetConfig cfg, T data);
  List<WidgetOptionSpec> optionSchema(WidgetSizeBucket size) => const [];

  /// Async option schema for modules whose choices depend on live data (e.g. a
  /// goal picker populated from the database). The Studio prefers this over
  /// [optionSchema]; the default just forwards the static schema.
  Future<List<WidgetOptionSpec>> resolveOptionSchema(
          AppDatabase db, WidgetSizeBucket size) async =>
      optionSchema(size);

  List<WidgetQuickAction> quickActions(WidgetConfig cfg) => const [];

  /// Per-row tap zones overlaid on the PNG for quick-actions. Order matches
  /// the visual top-to-bottom row order. Empty = whole-widget deep-link only.
  List<WidgetTapZone> tapZones(WidgetConfig cfg, T data) => const [];

  /// Extra per-instance values persisted to home-widget storage for the native
  /// layer to consume (keyed `widget_<k>_<appWidgetId>`). Used for live native
  /// overlays that the static PNG cannot express — e.g. the Focus widget's
  /// ticking `Chronometer`. Default: nothing.
  Map<String, String> nativeExtras(
          WidgetRenderContext ctx, WidgetConfig cfg, T data) =>
      const {};

  T sampleData(WidgetSizeBucket size);
}
