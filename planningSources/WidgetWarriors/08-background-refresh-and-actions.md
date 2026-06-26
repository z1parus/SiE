# Этап 8 — Фоновое обновление и быстрые действия

## Описание

Виджеты должны жить без открытого приложения: периодически обновлять данные и выполнять
быстрые действия (отметить привычку, старт/пауза фокуса) прямо с домашнего экрана.

## Триггеры обновления

| Триггер | Механизм | Частота |
|---|---|---|
| Периодика | `workmanager` periodic task | каждые 15–30 мин (минимум Android = 15) |
| Событие в приложении | `HomeWidget.updateWidget` сразу после мутации | мгновенно |
| Быстрая-акция с виджета | `home_widget` interactivity callback | по тапу |
| Загрузка/буст устройства | `RECEIVE_BOOT_COMPLETED` (уже есть) | разово |
| Смена темы/косметики | invalidate → перерендер всех инстансов | мгновенно |

Событийные апдейты из приложения — главные (точные и дешёвые). WorkManager — страховка,
чтобы данные не «протухали», когда приложение не открывают.

## Периодический воркер

```dart
// main(): один раз
Workmanager().initialize(widgetCallbackDispatcher);
Workmanager().registerPeriodicTask('sie_widgets_refresh', 'refresh',
    frequency: const Duration(minutes: 30),
    constraints: Constraints(networkType: NetworkType.notRequired)); // офлайн ок

@pragma('vm:entry-point')
void widgetCallbackDispatcher() {
  Workmanager().executeTask((_, __) async {
    await _bootHeadless();          // Drift + registerHomeWidgets(), без сети
    for (final id in await WidgetConfigStore.allIds()) {
      await WidgetRenderService.refresh(id);
    }
    return true;
  });
}
```

`_bootHeadless()`: `WidgetsFlutterBinding.ensureInitialized()`, открыть Drift readonly,
`registerHomeWidgets()`. **Без** Supabase-инициализации и сети — чистый офлайн-рендер.

## Быстрые действия (interactivity)

`home_widget` умеет ловить тап по элементу виджета и вызывать Dart в фоне
(`@pragma('vm:entry-point') backgroundCallback`). Поверх PNG в layout кладём прозрачные
`RemoteViews`-кнопки (этап 1, контейнер `widget_actions`) с `PendingIntent` на эти зоны.

```dart
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  // uri: sie://action/habits/toggle?widget=12&habit=abc
  await _bootHeadless();
  final action = WidgetActionRouter.parse(uri);
  await action?.run();                       // мутация в Drift (офлайн)
  await WidgetRenderService.refresh(action!.appWidgetId); // мгновенный перерендер
}
```

### Каталог действий первой волны

| Модуль | Действие | Эффект |
|---|---|---|
| Привычки | toggle привычки | запись `LocalHabitLogs` (done/undo), пересчёт стрика, перерендер |
| Фокус | старт / пауза | `focusTimerProvider` start/pause, перерендер кольца |
| Дыхание | запуск паттерна | открыть `BreathingExerciseScreen` с `pattern=<id>` (foreground) |
| Планирование | (MVP — только переход) | открыть `PlanningScreen` |

Каждое действие модуль декларирует через `ModuleWidgetProvider.quickActions(config)` —
ядро роутит, модуль исполняет. Расширяемость сохраняется.

## Синхронизация офлайн-мутаций

Toggle привычки/фокус в фоне пишутся в Drift с `synced = false`. Существующий sync-слой
приложения дольёт их в Supabase при следующем онлайне (тот же механизм, что и для обычных
офлайн-правок). Виджет не ходит в сеть сам.

## Батарея и лимиты

- `updatePeriodMillis = 0` в widget-info — системный апдейт выключен, обновляем только сами.
- Периодика не чаще 30 мин; рендер пропускается, если `signature` не изменился (этап 2).
- Тяжёлые виджеты (large c хитмапом) рендерим реже / только при событиях.
- Никаких таймеров на секунды: «живой» отсчёт фокуса обновляется раз в 30–60 c.

## Drift в фоновом изоляте

- Открываем **отдельное read-соединение** к тому же файлу БД (WAL позволяет читателю
  параллельно писателю).
- Для toggle-действий нужна запись → короткая write-транзакция; следить, чтобы приложение и
  воркер не писали одновременно (Drift сериализует через один isolate-executor — проверить).
- Риск: миграция схемы Drift в момент фонового старта. Решение: воркер открывает БД в режиме
  «не мигрировать»/после готовности; либо пропускает рендер, если версия схемы не совпала.

## Файлы

- `packages/sie_core/lib/src/widgets_home/widget_background.dart` — NEW (dispatcher, callbacks)
- `packages/sie_core/lib/src/widgets_home/widget_action_router.dart` — NEW
- `apps/central_hub/lib/main.dart` — init Workmanager + регистрация callback'ов
- хуки в провайдерах (`habitsProvider`, `focusTimerProvider`, `planningProvider`,
  `meditationStatsProvider`): после мутации — `HomeWidget.updateWidget` для затронутых инстансов

## Открытые вопросы

- Гранулярность tap-зон поверх PNG: сколько кнопок реально влезает (Android ограничивает
  число `RemoteViews`-элементов). Для medium-чек-листа привычек — по кнопке на строку.
- OEM-агрессивный энергосейв (Xiaomi/Huawei) может душить WorkManager — задокументировать,
  опираться на событийные апдейты как основной путь.
