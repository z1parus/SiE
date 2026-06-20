import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../local/app_database.dart';
import 'widget_config.dart';
import 'widget_config_store.dart';
import 'widget_registry.dart';
import 'widget_size_bucket.dart';
import 'widget_theme_bridge.dart';

class WidgetRenderService {
  static const _sigKey = 'widget_sig_';

  static Future<void> refresh(int appWidgetId, AppDatabase db) async {
    final cfg = await WidgetConfigStore.load(appWidgetId);
    if (cfg == null) return;

    final provider = WidgetRegistry.instance.get(cfg.moduleId);
    if (provider == null) return;

    final ctx = await WidgetThemeBridge.resolve(cfg);
    final data = await provider.loadData(db, cfg);

    // Tap zones + deep-link host are written every refresh (cheap) so the
    // native side always has the latest entity ids even if the PNG is cached.
    final zones = provider.tapZones(cfg, data);
    await HomeWidget.saveWidgetData(
        'widget_host_$appWidgetId', provider.resolveDeepLinkHost(cfg));
    await HomeWidget.saveWidgetData(
        'widget_zones_$appWidgetId',
        jsonEncode(zones.map((z) => z.toMap()).toList()));

    // Size bucket lets the native layer pick the matching layout (and so the
    // correct position for live overlays like the Focus chronometer).
    await HomeWidget.saveWidgetData(
        'widget_size_$appWidgetId', cfg.sizeBucket.name);

    // Live native overlays (e.g. ticking Focus timer). Always written — an
    // empty value tells the native side to hide the overlay.
    final extras = provider.nativeExtras(ctx, cfg, data);
    for (final entry in extras.entries) {
      await HomeWidget.saveWidgetData(
          'widget_${entry.key}_$appWidgetId', entry.value);
    }

    final sig = '${cfg.signature}:${data.signature}:${ctx.colors.mode.name}';
    final prevSig =
        await HomeWidget.getWidgetData<String>('$_sigKey$appWidgetId');
    final unchanged = sig == prevSig;

    if (!unchanged) {
      final size = await _resolveRenderSize(appWidgetId, cfg.sizeBucket);
      final widget = provider.render(ctx, cfg, data);

      await HomeWidget.renderFlutterWidget(
        widget,
        logicalSize: size,
        key: 'widget_img_$appWidgetId',
        pixelRatio: ctx.pixelRatio,
      );
      await HomeWidget.saveWidgetData('$_sigKey$appWidgetId', sig);
    }

    await HomeWidget.updateWidget(
      androidName: provider.androidProviderClass,
      iOSName: 'HomeWidget',
    );
  }

  /// Returns the actual widget size in logical pixels (dp) if the native side
  /// has saved it, otherwise falls back to the bucket default. The native layer
  /// writes `widget_px_w/h_<id>` from [OPTION_APPWIDGET_MAX_WIDTH/HEIGHT] in
  /// `onUpdate` and `onAppWidgetOptionsChanged`, so this reflects any user resize.
  static Future<Size> _resolveRenderSize(int id, WidgetSizeBucket bucket) async {
    final w = await HomeWidget.getWidgetData<int>('widget_px_w_$id');
    final h = await HomeWidget.getWidgetData<int>('widget_px_h_$id');
    if (w != null && h != null && w > 0 && h > 0) {
      return Size(w.toDouble(), h.toDouble());
    }
    return _sizeForBucket(bucket);
  }

  static Size _sizeForBucket(WidgetSizeBucket bucket) => switch (bucket) {
        WidgetSizeBucket.small => const Size(160, 160),
        WidgetSizeBucket.medium => const Size(320, 160),
        WidgetSizeBucket.large => const Size(320, 320),
      };

  static Future<void> refreshAll(AppDatabase db) async {
    final ids = await WidgetConfigStore.allIds();
    for (final id in ids) {
      await refresh(id, db);
    }
  }

  /// Event-driven refresh: re-render only the active widgets belonging to
  /// [moduleId]. Call from in-app providers right after a relevant mutation
  /// (e.g. habits toggle) so the home screen stays in sync instantly.
  static Future<void> notifyModuleChanged(
      String moduleId, AppDatabase db) async {
    final ids = await WidgetConfigStore.allIds();
    for (final id in ids) {
      final cfg = await WidgetConfigStore.load(id);
      if (cfg?.moduleId == moduleId) {
        await refresh(id, db);
      }
    }
  }
}
