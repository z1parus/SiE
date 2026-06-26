# Этап 7 — «Студия виджетов»: настройка инстанса

## Описание

Глубокая кастомизация — требование заказчика. Каждый поставленный виджет имеет свой
`WidgetConfig`, который пользователь настраивает в **Студии виджетов**: при добавлении
(конфиг-активность) и потом из приложения.

## Модель конфигурации

`WidgetConfig` (JSON в SharedPreferences, ключ `widget_cfg_<appWidgetId>`):

```dart
class WidgetConfig {
  final int appWidgetId;
  final String moduleId;                 // 'habits' | 'planning' | ...
  final WidgetSizeBucket sizeBucket;     // small | medium | large
  final WidgetThemeMode themeOverride;   // followApp | forceDark | forceLight
  final Color? accentOverride;           // null = наследовать косметику/дефолт
  final WidgetBackgroundStyle bgStyle;   // flat | glass | gradient | transparent
  final Map<String, dynamic> contentOptions; // спец-опции модуля (см. этапы 3–6)
  String get signature => jsonEncode(toMap());
}
```

## Экран Студии

`apps/central_hub/lib/screens/widget_studio_screen.dart` — общий для всех модулей,
строится по дескриптору из `ModuleWidgetProvider`. Секции:

1. **Живой предпросмотр** сверху — тот же `render(ctx, cfg, sampleData)`, что и на домашнем
   экране (рендерим прямо в Flutter, без PNG). Меняется мгновенно при правках.
2. **Размер** — сегмент small/medium/large (ограничен `supportedSizes` модуля).
3. **Тема** — followApp / тёмная / светлая.
4. **Фон** — flat / glass / gradient / transparent (превью на каждом чипе).
5. **Акцент** — «как в приложении (косметика)» + палитра + кастомный цвет. Дефолт — equipped
   stat-style/background акцент пользователя, иначе `#C8A84B`.
6. **Контент** — динамические опции модуля (`contentOptions`): какие метрики, какой объект
   закреплён (конкретная цель/привычка/паттерн), лимиты списка, скрывать выполненное и т.д.

Опции 6 описывает сам модуль — у `ModuleWidgetProvider` добавляем:

```dart
List<WidgetOptionSpec> optionSchema(WidgetSizeBucket size);
// WidgetOptionSpec: id, label, тип (toggle|enum|entityPicker|number), значения/диапазон.
```

Так Студия не знает про модули — рисует форму по схеме. Новый модуль приносит свою схему,
экран не трогаем (расширяемость).

## Интеграция с косметикой

В приложении уже есть `CosmeticAsset` (stat-style/background) с `styleConfig.accent_color`,
`profile_pattern`, рамки. Для виджетов:

- по умолчанию `accentOverride == null` → берём акцент из equipped косметики профиля
  (`WidgetThemeBridge._equippedCosmeticAccent`), чтобы виджет «звучал» как профиль;
- опция `gradient`-фона может использовать `profile_background` градиент пользователя;
- паттерны профиля (`topo/radar/hud_grid`) — как опциональная тонкая подложка large-виджета
  (низкая `opacity`), но осторожно: минимализм важнее.

## Конфиг-активность при добавлении виджета

`WidgetConfigActivity` (объявлена в `widget_*_info.xml`, этап 1) — Flutter-route поверх
изолированного движка: показывает Студию для нового `appWidgetId`, по «Готово» сохраняет
конфиг, запускает первый рендер и возвращает `RESULT_OK`.

## Управление из приложения

В разделе настроек/профиля — «Мои виджеты»: список активных инстансов (по `appWidgetId`),
тап → Студия для редактирования. Удобно, т.к. лаунчеры не всегда дают перенастроить виджет.

## Файлы

- `apps/central_hub/lib/screens/widget_studio_screen.dart` — NEW
- `packages/sie_core/lib/src/widgets_home/widget_config.dart` — NEW
- `packages/sie_core/lib/src/widgets_home/widget_config_store.dart` — NEW
- `packages/sie_core/lib/src/widgets_home/widget_option_spec.dart` — NEW
- расширение `ModuleWidgetProvider.optionSchema(...)`

## Открытые вопросы

- Нужен ли live-предпросмотр всех трёх размеров сразу, или только выбранного. Предложение:
  только выбранного — проще и честнее.
- Хранить конфиги только локально (SharedPrefs) или дублировать в профиль Supabase для
  переноса между устройствами. MVP — локально; синк — на будущее.
