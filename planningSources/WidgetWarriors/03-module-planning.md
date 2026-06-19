# Этап 3 — Виджет «Планирование»

## Идея

Держать перед глазами «пульс плана»: сколько целей активно, что горит сегодня, ближайший
milestone. Виджет — тихое напоминание о фокусе дня, тап ведёт в `PlanningScreen`.

## Данные

Провайдер: `planningProvider` → `PlanningState { goals: List<Goal> }`.
Офлайн-источник: Drift `LocalGoals`, `LocalSubGoals`, `LocalPlanningTasks`, `LocalMilestones`.
Прогресс цели: функция `goalProgress(goal)` (0–100).

`PlanningWidgetData`:
```dart
class PlanningWidgetData extends WidgetData {
  final int activeGoals;            // goals where status == 'active'
  final int tasksDueToday;          // tasks с dueDate == сегодня и !isCompleted
  final int overdueTasks;           // dueDate < now и !isCompleted
  final double topGoalProgress;     // прогресс приоритетной/ближайшей цели
  final String? topGoalName;
  final Milestone? nextMilestone;   // ближайший незавершённый по targetDate
}
```

`loadData`: читаем активные цели из Drift, считаем задачи на сегодня/просрочку,
выбираем «главную» цель (по приоритету/дедлайну), берём ближайший milestone.

## Варианты по размеру

### Small (160×160) — «Прогресс главной цели»
- Кольцо `_StatsRingPainter` с `topGoalProgress`, в центре `NN%`.
- Снизу: имя цели (1 строка, ellipsis), `textSecondary`.
- Акцент кольца — `ctx.accent`.

### Medium (320×160) — «Сегодня»
- Слева кольцо «сводки дня» (как `_DaySummary`, 56dp): % выполнения задач дня.
- Справа: крупно `tasksDueToday` «задач на сегодня», ниже строка `overdueTasks` просрочено
  (цвет `danger`, если > 0).
- Низ: чип ближайшего milestone — «🏁 <name> · <дата>».

### Large (320×320) — «Карта плана»
- Шапка: «ПЛАНИРОВАНИЕ» + `activeGoals` активных.
- Список топ-3 целей: имя + тонкий бар прогресса (`accent`→`accentSecondary`).
- Блок «Сегодня»: задачи к выполнению / просрочка.
- Опц. мини-`MomentumChart` по главной цели (если включено в contentOptions).

## Контент-опции (Студия виджетов)

- `topGoal`: «авто (по приоритету)» | выбрать конкретную цель.
- `showOverdue`: вкл/выкл строку просрочки.
- `showMilestone`: показывать ближайший milestone.
- `metric` (small): «прогресс цели» | «% задач дня».

## Состояния

- **Нет активных целей** → пустое состояние: иконка планирования + «Нет активных целей»,
  тап ведёт в `PlanningScreen` (создать цель).
- **Всё на сегодня сделано** → кольцо 100%, подпись «День закрыт», галочка `success`.

## Deep-link

Тап → `sie://widget/planning` → `PlanningScreen`. (Large, тап по конкретной цели — в будущем
через tap-зоны, этап 8; в MVP весь виджет ведёт на общий экран.)

## Файлы

- `packages/sie_core/lib/src/widgets_home/modules/planning_widget_provider.dart` — NEW
- использует painter'ы из `widgets_home/painters/` (ring, momentum)
