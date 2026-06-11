# Защита от фарма XP при завершении цели

## Описание

Сейчас можно получить 2000 XP за секунды: создать пустую цель → сразу завершить. Нужна система условий, при невыполнении которых базовые 2000 XP не начисляются. Медальный бонус (`xpBonus`) при этом сохраняется, если медаль заработана.

---

## Пользовательский сценарий

- Пользователь создаёт цель, реально работает над ней (задачи, время) → завершает → получает полные 2000 XP.
- Пользователь создаёт пустую цель или сразу завершает → получает 0 базовых XP (только медальный бонус, если есть).
- Экран `MissionAccomplishedScreen` отображает фактически начисленный XP.

---

## Условия получения полных 2000 XP

Все три условия должны выполняться одновременно:

| # | Условие | Логика |
|---|---|---|
| 1 | Минимальный возраст | `DateTime.now().difference(goal.createdAt).inDays >= 1` |
| 2 | Есть задачи | `goal.totalTasks > 0` |
| 3 | Все задачи выполнены | `goal.completedTasks == goal.totalTasks` |

Если хотя бы одно не выполнено → `baseXp = 0`.

**Почему именно так:**
- Условие 1 блокирует "создал → сразу закрыл"
- Условие 2 блокирует пустые цели без задач
- Условие 3 требует реальной работы (все задачи закрыты)
- DP и медаль всё равно начисляются — пользователь не наказан, просто нет фарма

---

## Вспомогательная функция `goalCompletionBaseXp`

Выносим логику в отдельную top-level функцию в `planning.dart` (рядом с `goalProgress`, `isGoalFatigued`), чтобы и провайдер и UI использовали одно место:

```dart
int goalCompletionBaseXp(Goal goal) {
  final ageQualifies = DateTime.now().difference(goal.createdAt).inDays >= 1;
  final hasTasks = goal.totalTasks > 0;
  final allTasksDone = goal.completedTasks == goal.totalTasks;
  return (ageQualifies && hasTasks && allTasksDone) ? 2000 : 0;
}
```

Экспортируется через `sie_core.dart` автоматически (уже экспортируется `models/planning.dart`).

---

## Затрагиваемые файлы

### 1. `packages/sie_core/lib/src/models/planning.dart`

Добавить top-level функцию `goalCompletionBaseXp(Goal goal)` рядом с `goalProgress`.

### 2. `packages/sie_core/lib/src/providers/planning_provider.dart`

В методе `updateGoalStatus`, когда `newStatus == 'completed'`:

**Текущий код (с активной сессией):**
```dart
final xpBonus = medalXpBonus(level);
await _awardXp(2000 + xpBonus, dp);
```

**Новый код:**
```dart
final xpBonus = medalXpBonus(level);
final baseXp = goalCompletionBaseXp(goal);
await _awardXp(baseXp + xpBonus, dp);
```

**Текущий код (без сессии / офлайн):**
```dart
} else if (newStatus == 'completed' && goal != null) {
  await _awardXp(2000, 20);
}
```

**Новый код:**
```dart
} else if (newStatus == 'completed' && goal != null) {
  await _awardXp(goalCompletionBaseXp(goal), 20);
}
```

### 3. `apps/central_hub/lib/screens/planning_screen.dart`

В `onComplete` callback метода `_showGoalOptionsSheet`:

**Текущий код:**
```dart
xpGained: 2000 + (medal?.xpBonus ?? 100),
```

**Новый код:**
```dart
xpGained: goalCompletionBaseXp(goal) + (medal?.xpBonus ?? 100),
```

### 4. `apps/central_hub/lib/screens/mission_detail_screen.dart`

В `onTap` кнопки «Завершить миссию» в `_showGoalSettingsSheet`:

Та же замена: `2000 + (medal?.xpBonus ?? 100)` → `goalCompletionBaseXp(goal) + (medal?.xpBonus ?? 100)`.

---

## Схема данных

Изменений в Supabase не нужно. Проверка выполняется на клиенте на основе уже загруженных данных `Goal`.

---

## Проверка

1. Создать цель без задач → завершить → `MissionAccomplishedScreen` показывает `0 + medailBonus` XP
2. Создать цель с задачами, не закрывать → завершить → 0 базовых XP
3. Создать цель в тот же день, закрыть все задачи → 0 XP (не прошли сутки)
4. Создать цель вчера, добавить 2 задачи, закрыть обе → завершить → полные 2000 XP
5. `flutter analyze` — 0 ошибок
