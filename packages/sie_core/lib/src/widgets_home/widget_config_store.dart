import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'widget_config.dart';

class WidgetConfigStore {
  static String _key(int id) => 'widget_cfg_$id';
  static const _allIdsKey = 'widget_all_ids';

  static Future<void> save(WidgetConfig cfg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(cfg.appWidgetId), jsonEncode(cfg.toMap()));
    final ids = await allIds();
    if (!ids.contains(cfg.appWidgetId)) {
      ids.add(cfg.appWidgetId);
      await prefs.setString(_allIdsKey, jsonEncode(ids));
    }
  }

  static Future<WidgetConfig?> load(int appWidgetId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(appWidgetId));
    if (raw == null) return null;
    try {
      return WidgetConfig.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<List<int>> allIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_allIdsKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<int>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> delete(int appWidgetId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(appWidgetId));
    final ids = await allIds();
    ids.remove(appWidgetId);
    await prefs.setString(_allIdsKey, jsonEncode(ids));
  }
}
