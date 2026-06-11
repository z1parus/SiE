# Закрепление цели вверху списка

## Описание

В главном экране модуля планирования (`PlanningScreen`) пользователь может закрепить любую активную цель вверху списка через контекстное меню (долгое нажатие на карточку). Закреплённая цель всегда отображается первой независимо от даты создания.

---

## Пользовательский сценарий

- Долгое нажатие на карточку цели → меню → «Закрепить миссию» → цель перемещается вверх, на карточке появляется иконка 📌.
- Повторное долгое нажатие → «Открепить миссию» → цель возвращается на своё место в хронологическом порядке.
- Несколько закреплённых целей упорядочиваются по дате создания между собой.

---

## Затрагиваемые файлы

| Файл | Изменение |
|---|---|
| `packages/sie_core/lib/src/models/planning.dart` | Поле `isPinned` в `Goal` |
| `packages/sie_core/lib/src/local/app_database.dart` | Колонка + миграция + сортировка |
| `packages/sie_core/lib/src/providers/planning_provider.dart` | `toggleGoalPin`, маппинги |
| `packages/sie_core/lib/src/services/sync_service.dart` | Case `update_goal_pin` |
| `apps/central_hub/lib/screens/planning_screen.dart` | Пункт меню + иконка на карточке |
| `supabase/migrations/20260611000001_goal_pinning.sql` | Новая колонка в Supabase |

---

## Файл 1 — `models/planning.dart`

**`Goal` — добавить поле:**
```dart
const Goal({
  ...,
  this.isPinned = false,
});
final bool isPinned;

Goal copyWith({
  ...,
  bool? isPinned,
}) => Goal(
  ...,
  isPinned: isPinned ?? this.isPinned,
);
```

`fromJson` (Supabase sync): `isPinned: j['is_pinned'] as bool? ?? false,`

---

## Файл 2 — `local/app_database.dart`

**`LocalGoals` — добавить колонку:**
```dart
BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
```

**Bump `schemaVersion` 11 → 12, миграция:**
```dart
if (from < 12) {
  await m.addColumn(localGoals, localGoals.isPinned);
}
```

**`goalsForUser` — изменить сортировку** (закреплённые идут первыми, далее по дате создания):
```dart
Future<List<LocalGoal>> goalsForUser(String uid) =>
    (select(localGoals)
          ..where((t) =>
              t.userId.equals(uid) & t.deletedLocally.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.createdAtMs),
          ]))
        .get();
```

---

## Файл 3 — `providers/planning_provider.dart`

**`_loadFromLocal` — добавить маппинг:**
```dart
goals.add(Goal(
  ...,
  isPinned: rg.isPinned,
));
```

**`_mirrorToLocal` — добавить поле в companion** (метод, который синхронизирует данные с сервера в локальную БД):
```dart
isPinned: Value(g.isPinned),
```

**Новый метод `toggleGoalPin`:**
```dart
Future<void> toggleGoalPin(String goalId) async {
  final current = state.valueOrNull;
  if (current == null) return;

  final goal = current.goals.where((g) => g.id == goalId).firstOrNull;
  if (goal == null) return;
  final newPinned = !goal.isPinned;

  // Оптимистичное обновление + пересортировка
  final updated = current.goals
      .map((g) => g.id == goalId ? g.copyWith(isPinned: newPinned) : g)
      .toList()
    ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return a.createdAt.compareTo(b.createdAt);
      });
  state = AsyncData(current.copyWith(goals: updated));

  // Локальная БД
  final db = ref.read(appDatabaseProvider);
  await db.updateGoal(goalId, LocalGoalsCompanion(
      isPinned: Value(newPinned), synced: const Value(false)));

  // Supabase + офлайн очередь
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;

  final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
  if (isOnline) {
    try {
      await Supabase.instance.client
          .from('goals')
          .update({'is_pinned': newPinned})
          .eq('id', goalId)
          .eq('user_id', userId);
      await db.updateGoal(goalId,
          const LocalGoalsCompanion(synced: Value(true)));
      return;
    } catch (_) {}
  }
  await db.enqueueSyncOp('update_goal_pin',
      jsonEncode({'id': goalId, 'is_pinned': newPinned}));
}
```

---

## Файл 4 — `services/sync_service.dart`

Добавить case в switch:
```dart
case 'update_goal_pin':
  await client
      .from('goals')
      .update({'is_pinned': payload['is_pinned'] as bool})
      .eq('id', payload['id'] as String)
      .eq('user_id', userId);
  await _db.updateGoal(payload['id'] as String,
      const LocalGoalsCompanion(synced: Value(true)));
```

---

## Файл 5 — `planning_screen.dart`

### Пункт в `_GoalOptionsSheet`

Добавить `required VoidCallback onPin` в конструктор (по аналогии с остальными), добавить пункт после «Статистика миссии»:

```dart
_OptionTile(
  icon: goal.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
  label: goal.isPinned ? 'Открепить миссию' : 'Закрепить миссию',
  color: const Color(0xFFF4C430),
  onTap: () {
    Navigator.pop(context);
    onPin();
  },
),
```

В `_showGoalOptionsSheet`:
```dart
onPin: () => ref.read(planningProvider.notifier).toggleGoalPin(goal.id),
```

### Иконка на `_GoalCard`

В `_GoalCard.build`, в Row со статус-чипом (верхняя строка карточки), добавить до `Spacer()`:
```dart
if (goal.isPinned) ...[
  const SizedBox(width: 6),
  Icon(Icons.push_pin, size: 12, color: const Color(0xFFF4C430)),
],
```

---

## Файл 6 — SQL миграция

`supabase/migrations/20260611000001_goal_pinning.sql`:
```sql
ALTER TABLE public.goals
  ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT false;
```

Применить вручную через Supabase Dashboard.

---

## Проверка

1. `flutter analyze` — 0 ошибок
2. Долгое нажатие → «Закрепить» → цель поднимается вверх → иконка 📌 появляется
3. Открепить → цель возвращается на своё хронологическое место
4. Несколько закреплённых целей → все вверху, упорядочены по дате создания
5. После перезапуска приложения — порядок сохраняется (персистится в Drift)
6. Офлайн: закрепить → синхронизируется при следующем онлайне
