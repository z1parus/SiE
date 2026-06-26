# Этап 2 — Конвейер рендера и дизайн-система виджетов

## Описание

Унифицированный конвейер «Flutter-виджет → PNG → home screen» и дизайн-токены, общие для
всех виджетов. Здесь же — мост темы `WidgetThemeBridge`, позволяющий получить `SieColors`
без `ref`/`ProviderScope` (нужно для рендера в фоновом изоляте).

## Размерные «бакеты»

Android отдаёт размер ячеек, не пиксели. Сводим к трём бакетам:

| Бакет | Ячейки (≈) | Логич. размер рендера | Объём данных |
|---|---|---|---|
| `small` | 2×1 / 2×2 | 160×160 dp | 1 показатель |
| `medium` | 4×2 | 320×160 dp | показатель + список/кольцо |
| `large` | 4×3 / 4×4 | 320×320 dp | развёрнутый дашборд модуля |

Рендер делаем при фиксированном logicalSize и `pixelRatio = 3.0` (как в crop-инструменте
Dev Studio — проверенный путь `RepaintBoundary.toImage(pixelRatio: 3.0)` →
`toByteData(png)`), `home_widget` делает это под капотом в `renderFlutterWidget`.

## Конвейер рендера

`packages/sie_core/lib/src/widgets_home/widget_render_service.dart`

```dart
class WidgetRenderService {
  static Future<void> refresh(int appWidgetId) async {
    final cfg  = await WidgetConfigStore.read(appWidgetId);
    final prov = WidgetRegistry.byId(cfg.moduleId);
    if (prov == null) return;

    final db   = AppDatabase.readonly();           // отдельное read-соединение
    final data = await prov.loadData(db, cfg);
    final ctx  = WidgetThemeBridge.resolve(cfg);   // SieColors без ref

    // дешёвый кэш: не перерисовываем, если хэш не изменился
    final sig = Object.hash(cfg.signature, data.signature, ctx.signature);
    if (await WidgetConfigStore.lastSignature(appWidgetId) == sig) return;

    final widget = SizedBox.fromSize(
      size: cfg.sizeBucket.logicalSize,
      child: prov.render(ctx, cfg, data),
    );
    await HomeWidget.renderFlutterWidget(
      widget,
      key: 'widget_image_$appWidgetId',
      logicalSize: cfg.sizeBucket.logicalSize,
      pixelRatio: 3.0,
    );
    await HomeWidget.updateWidget(qualifiedAndroidName: prov.androidProviderClass);
    await WidgetConfigStore.saveSignature(appWidgetId, sig);
  }
}
```

Ключевое требование к `render`: **чистая функция от (ctx, config, data)** — никаких
`ref.watch`, никаких сетевых вызовов, никакого `BuildContext`-зависимого состояния. Это
делает виджеты тестируемыми и пригодными для headless-рендера.

## Мост темы — `WidgetThemeBridge`

В фоне нет `ProviderScope`, значит `sieColorsProvider` недоступен. Берём режим темы
напрямую и собираем `SieColors`:

```dart
class WidgetRenderContext {
  final SieColors colors;
  final Color accent;        // с учётом accentOverride / косметики
  final bool reducedMotion;  // статика для PNG в любом случае
  String get signature => '${colors.isLightMode}:$accent';
}

class WidgetThemeBridge {
  static WidgetRenderContext resolve(WidgetConfig cfg) {
    final mode = _readThemeMode();   // SharedPreferences key 'sie_theme_mode'
    final base = SieColors.forMode(mode);     // существующий API
    final accent = cfg.accentOverride
        ?? _equippedCosmeticAccent()          // из profile (этап 7)
        ?? base.accent;                        // дефолт #C8A84B
    return WidgetRenderContext(colors: base, accent: accent, reducedMotion: true);
  }
}
```

`themeOverride` инстанса (`followApp | forceDark | forceLight`) имеет приоритет над
сохранённым режимом.

## Дизайн-токены виджетов

Зеркалят приложение (источник — `SieColors`, проверено в коде):

| Токен | Значение (dark / light) | Назначение |
|---|---|---|
| Фон карточки | `surface` `#252529` / `#FFFFFF` | подложка виджета |
| Бордер (dark) | `border` `#3E3E48`, 1px | рамка вместо тени |
| Тень (light) | `#0F000000`, blur 12, offset (0,2) | `flatCard` light |
| Акцент | `accent` `#C8A84B` (gold sand) | прогресс, ключевое число |
| Акцент 2 | `accentSecondary` `#AA7744`/`#E5C16C` | градиенты, второстепенный прогресс |
| Текст | `textPrimary` `#E4E4EC` / `#1C1C22` | значения |
| Текст 2 | `textSecondary` `#888898` | подписи |
| Успех/опасность | `success #34C759` / `danger #E03050` | статусы (просрочка, выполнено) |

Скругления: **16dp** карточка виджета, **4–8dp** мелкие элементы, кольца — `stroke 11`
(как `_StatsRingPainter`). Типографика: caps-лейблы `letterSpacing 1.5–2.5`, значения
крупные `w700`, подписи `w600 9–11dp`. Шрифт — системный (как в приложении).

### Варианты фона виджета (настраивается, этап 7)

1. `flat` — `SieColors.flatCard(radius: 16)` (дефолт).
2. `glass` — `subtleContainer()` (фростед).
3. `gradient` — `LinearGradient([accent, accentSecondary])` приглушённый.
4. `transparent` — без подложки, только контент (минимализм на любых обоях).

## Переиспользуемые painter'ы

Готовое из приложения — переносим/обобщаем в `widgets_home/painters/`:

- `_StatsRingPainter` (goal_stats) → **кольцо прогресса** (Планирование, Привычки, Фокус).
- `HabitHeatmap`/`_HeatmapPainter`, `AggregateHeatmap` → **хитмап** (Привычки large).
- `_FocusRingPainter` (focus_protocol) → **кольцо сессии** (Фокус).
- `SphereRimPainter` (session_orb_painters) → **орб дыхания** (Дыхание).
- `MomentumChart`/`_MomentumPainter` → **мини-график** (Планирование/Фокус large).

Все они — чистый `CustomPainter`, отлично работают в headless-рендере.

## Затрагиваемые файлы

- `packages/sie_core/lib/src/widgets_home/widget_render_service.dart` — NEW
- `packages/sie_core/lib/src/widgets_home/widget_theme_bridge.dart` — NEW
- `packages/sie_core/lib/src/widgets_home/widget_size_bucket.dart` — NEW
- `packages/sie_core/lib/src/widgets_home/painters/` — NEW (перенос painter'ов)
- `packages/sie_core/lib/src/widgets_home/widget_data.dart` — базовый `WidgetData` с `signature`

## Открытые вопросы

- `AppDatabase.readonly()` — как открыть второе read-соединение к тому же файлу из изолята
  без конфликта writer'а (проверить Drift `NativeDatabase` + WAL). См. этап 8.
- Кэш PNG: чистить старые файлы по `appWidgetId` при удалении виджета (`onDeleted`).
