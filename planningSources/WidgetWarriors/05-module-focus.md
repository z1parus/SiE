# Этап 5 — Виджет «Фокусировка»

## Идея

Двойная роль: **витрина** (сколько фокуса сегодня/за неделю) и **пульт** (быстрый старт
сессии). Если сессия идёт — виджет показывает живое кольцо обратного отсчёта.

## Данные

Провайдеры:
- `focusTimerProvider` → `FocusTimerState { phase, secondsRemaining, isRunning,
  completedSessions, totalDurationSecs, progress, formattedTime }` — текущая сессия.
- `analyticsProvider` → `AnalyticsData { focusByDay: List<DayFocus>, totalFocusMinutes }`.
Офлайн-источник: Drift `LocalFocusSessions` (агрегируем по дням локально).

`FocusWidgetData`:
```dart
class FocusWidgetData extends WidgetData {
  final int minutesToday;          // сумма LocalFocusSessions за сегодня
  final int minutesThisWeek;       // за 7 дней
  final int sessionsToday;
  final List<int> weekMinutes;     // 7 значений для мини-бара
  // живое состояние (если приложение успело записать в shared):
  final bool sessionRunning;
  final double sessionProgress;    // 0..1
  final String? sessionTimeLabel;  // "12:30"
}
```

Живое состояние сессии: `FocusTimerState` держится в памяти/SharedPreferences. Виджет
обновляется событийно из приложения (тик раз в ~30–60 c, чтобы не жечь батарею), а в фоне —
по периодике. Точный поминутный отсчёт на виджете не нужен.

## Варианты по размеру

### Small (160×160) — «Фокус сегодня»
- Кольцо `_FocusRingPainter`: заполнение = `minutesToday / dailyGoal` (цель настраивается).
- В центре: `minutesToday` «мин».
- Если сессия идёт — кольцо переключается на `sessionProgress`, в центре `sessionTimeLabel`,
  акцент пульсирует (статично-подсвеченный кадр).

### Medium (320×160) — «Пульт фокуса»
- Слева кольцо (сессия или день).
- Справа: `minutesToday` сегодня / `sessionsToday` сессий.
- Кнопка-зона: «▶ Старт» (если idle) или «⏸ Идёт <время>» (если running) — этап 8.

### Large (320×320) — «Сводка фокуса»
- Кольцо дня + цель.
- Мини-бар недели по `weekMinutes` (7 столбиков, `accent`).
- `minutesThisWeek` всего за неделю, лучший день.
- Кнопка «Старт сессии».

## Контент-опции

- `dailyGoalMinutes`: цель дня для заполнения кольца (дефолт 120).
- `metric` (small): «минуты сегодня» | «сессии сегодня» | «минуты недели».
- `quickStart`: показывать кнопку старта (этап 8).

## Состояния

- **Сессия идёт** → приоритетный режим: кольцо отсчёта, `accent`, «Фокус · <время>».
- **Цель дня достигнута** → кольцо 100%, `success`, «Цель дня выполнена».
- **Пусто** → «0 мин · начни фокус».

## Deep-link / действия

- Тап → `sie://widget/focus` → `FocusProtocolScreen`.
- Кнопка «Старт» (этап 8) → background-action запускает сессию через `focusTimerProvider`
  и открывает экран; «Пауза» — останавливает и перерисовывает виджет.

## Файлы

- `packages/sie_core/lib/src/widgets_home/modules/focus_widget_provider.dart` — NEW
- painter из `focus_protocol_screen.dart` (`_FocusRingPainter`) → в `widgets_home/painters/`.
