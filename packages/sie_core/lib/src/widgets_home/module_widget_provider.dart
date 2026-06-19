import 'package:flutter/material.dart';
import '../local/app_database.dart';
import 'widget_config.dart';
import 'widget_size_bucket.dart';
import 'widget_theme_bridge.dart';
import 'widget_option_spec.dart';

abstract class WidgetData {
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

abstract class ModuleWidgetProvider<T extends WidgetData> {
  String get moduleId;
  String get displayName;
  IconData get glyph;
  List<WidgetSizeBucket> get supportedSizes;

  Future<T> loadData(AppDatabase db, WidgetConfig cfg);
  Widget render(WidgetRenderContext ctx, WidgetConfig cfg, T data);
  List<WidgetOptionSpec> optionSchema(WidgetSizeBucket size) => const [];
  List<WidgetQuickAction> quickActions(WidgetConfig cfg) => const [];

  T sampleData(WidgetSizeBucket size);
}
