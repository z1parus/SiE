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

    final sig = '${cfg.signature}:${data.signature}:${ctx.colors.mode.name}';
    final prevSig = await HomeWidget.getWidgetData<String>('$_sigKey$appWidgetId');
    if (sig == prevSig) return;

    final size = _sizeForBucket(cfg.sizeBucket);
    final widget = provider.render(ctx, cfg, data);

    await HomeWidget.renderFlutterWidget(
      widget,
      logicalSize: size,
      key: 'widget_img_$appWidgetId',
      pixelRatio: ctx.pixelRatio,
    );

    await HomeWidget.saveWidgetData('$_sigKey$appWidgetId', sig);
    await HomeWidget.updateWidget(
      name: 'HomeWidgetProvider',
      iOSName: 'HomeWidget',
    );
  }

  static Size _sizeForBucket(WidgetSizeBucket bucket) => switch (bucket) {
    WidgetSizeBucket.small  => const Size(160, 160),
    WidgetSizeBucket.medium => const Size(320, 160),
    WidgetSizeBucket.large  => const Size(320, 320),
  };

  static Future<void> refreshAll(AppDatabase db) async {
    final ids = await WidgetConfigStore.allIds();
    for (final id in ids) {
      await refresh(id, db);
    }
  }
}
