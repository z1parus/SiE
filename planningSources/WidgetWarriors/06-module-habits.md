# Этап 6 — Виджет «Привычки» (эталонный)

> Реализуется первым среди модулей: богатые офлайн-данные + понятная быстрая-акция
> (отметить выполнение). На нём обкатываем весь конвейер и tap-зоны.

## Идея

Чек-лист дня прямо на домашнем экране: что осталось сделать, кольцо прогресса, стрики.
Главная ценность — **отметить привычку, не открывая приложение** (быстрая-акция).

## Данные

Провайдер: `habitsProvider` → `HabitsState { habits, logDates, streaks, logValues, ... }`.
Офлайн-источник: Drift `LocalHabits` + `LocalHabitLogs` (стрики считаются локально:
`scheduleAwareStreak()`, `resilientStreak()`).

`HabitsWidgetData`:
```dart
class HabitsWidgetData extends WidgetData {
  final List<HabitTile> dueToday;   // из HabitsState.dueOn(today)
  final int doneToday;
  final int totalDueToday;
  double get dayProgress => totalDueToday == 0 ? 1 : doneToday / totalDueToday;
}
class HabitTile {
  final String id, title;
  final bool done;                  // dateKey ∈ logDates[id]
  final int streak;                 // streaks[id]
  final String kind;                // 'binary'|'count'|'duration'
  final double? value, target;      // для count/duration
}
```

`loadData`: `HabitsState.dueOn(DateTime.now())` → для каждой привычки done/streak/value.

## Варианты по размеру

### Small (160×160) — «Кольцо дня»
- Кольцо `_StatsRingPainter` = `dayProgress`, в центре `doneToday/totalDueToday`.
- Подпись «привычек сегодня».

### Medium (320×160) — «Чек-лист» (флагман)
- Список до 4 привычек дня: точка-чекбокс + название + стрик-чип «🔥N».
- Каждая строка — tap-зона: тап по чекбоксу = отметить (этап 8), тап по тексту = открыть.
- Справа сверху мини-кольцо `dayProgress`.

### Large (320×320) — «Дашборд привычек»
- Чек-лист до 6–7 привычек (toggle).
- Полоса `AggregateHeatmap` снизу (завершённость по дням).
- Шапка: `doneToday/totalDueToday` + лучший стрик.

## Быстрые действия (этап 8)

Toggle привычки — ключевая фича. Тап по чекбоксу → `HomeWidget` background-callback →
записать `LocalHabitLogs` (entryType `done`) → пересчитать → перерисовать PNG → (при сети)
синхронизировать в Supabase позже. Полный офлайн-цикл, приложение открывать не нужно.

## Контент-опции

- `filter`: «все на сегодня» | «только закреплённые (isPinned)» | выбранный набор.
- `maxItems`: сколько строк показывать (medium 4 / large 7).
- `showStreaks`: показывать стрик-чипы.
- `hideCompleted`: прятать выполненные (фокус на остатке).

## Состояния

- **Всё выполнено** → кольцо 100% `success`, «Все привычки закрыты 🎉».
- **На сегодня ничего не запланировано** → «Сегодня отдых» (учёт rest-дней `restDates`).
- **avoid-привычки** (`polarity: 'avoid'`) → показываем абстинентный стрик, чекбокс = «срыв».

## Deep-link / действия

- Тап по виджету / строке → `sie://widget/habits` → `HabitTrackerScreen`.
- Тап по чекбоксу → background toggle (этап 8), без открытия приложения.

## Файлы

- `packages/sie_core/lib/src/widgets_home/modules/habits_widget_provider.dart` — NEW
- painter'ы: `_StatsRingPainter`, `AggregateHeatmap` → `widgets_home/painters/`.
