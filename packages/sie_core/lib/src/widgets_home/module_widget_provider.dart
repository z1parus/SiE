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

  /// Deep-link host used when the whole widget is tapped:
  /// `sie://widget/<deepLinkHost>`.
  String get deepLinkHost => moduleId;

  Future<T> loadData(AppDatabase db, WidgetConfig cfg);
  Widget render(WidgetRenderContext ctx, WidgetConfig cfg, T data);
  List<WidgetOptionSpec> optionSchema(WidgetSizeBucket size) => const [];
  List<WidgetQuickAction> quickActions(WidgetConfig cfg) => const [];

  /// Per-row tap zones overlaid on the PNG for quick-actions. Order matches
  /// the visual top-to-bottom row order. Empty = whole-widget deep-link only.
  List<WidgetTapZone> tapZones(WidgetConfig cfg, T data) => const [];

  T sampleData(WidgetSizeBucket size);
}
