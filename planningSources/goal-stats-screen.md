# Экран статистики и обзора цели

## Описание

Новый экран (или крупный bottom sheet) с детальной статистикой по конкретной цели: прогресс, задачи, контрольные точки, привязанные привычки, временные показатели. Служит как «дашборд цели» — позволяет быстро оценить состояние работы, не листая вглубь подцелей.

---

## Пользовательский сценарий

**Вход 1 — с экрана детали цели (`MissionDetailScreen`):**
В `_MissionHeader`, между кнопкой настроек (⚙️) и `_ViewToggle`, добавляется иконка `Icons.bar_chart_outlined`. Нажатие открывает `GoalStatsScreen` через `Navigator.push` (полноэкранный `Scaffold`).

**Вход 2 — с главного экрана планирования (`PlanningScreen`):**
В контекстном меню `_GoalOptionsSheet` (вызывается долгим нажатием на карточку цели) добавляется первый пункт — «Статистика миссии» с иконкой `Icons.bar_chart_outlined`. Нажатие закрывает шторку и открывает `GoalStatsScreen`.

**На экране статистики:**
Пользователь видит структурированные карточки/секции. Кнопка «назад» возвращает на предыдущий экран.

---

## Логика и поведение

### Навигация

- `GoalStatsScreen` — новый файл `apps/central_hub/lib/screens/goal_stats_screen.dart`
- `ConsumerWidget`, принимает `Goal goal` через конструктор
- Оборачивается в `SieBackground + Scaffold`
- Обновляет `goal` из `planningProvider` как в `MissionDetailScreen` (`.firstWhere` по id с `orElse`)

### Секции экрана (сверху вниз)

#### 1. Заголовок
- Кнопка «назад»
- Название цели (усечённое, 1 строка)
- Метка категории / иконка приоритета

#### 2. Прогресс-кольцо (Hero-виджет)
- Круговой индикатор `goalProgress(goal)` в %, цвет = `goal.color`
- Внутри: число процентов крупным шрифтом
- Под кольцом: статус-чип (`_StatusChip` из `mission_detail_screen.dart` — импортировать или вынести в `sie_core`)

> **Вопрос реализации:** `_StatusChip` сейчас приватный. Проще продублировать маленький виджет в новом файле, не двигая его.

#### 3. Карточка «Задачи»
Показатели в сетке 2×2:
| Ячейка | Значение |
|---|---|
| Всего задач | `goal.totalTasks` |
| Выполнено | `goal.completedTasks` |
| Лёгкие (вес 1) | count задач с `weight == 1` по всему дереву |
| Средние (вес 3) | weight == 3 |
| Тяжёлые (вес 5) | weight == 5 |
| Просроченные | задачи с `dueDate != null && !isCompleted && now.isAfter(dueDate)` |

Итого 6 ячеек — сетка 2 колонки × 3 строки.

Под сеткой: миниатюрный линейный прогресс-бар `completedTasks / totalTasks` с подписью `«X из Y»`.

#### 4. Карточка «Этапы (подцели)»
- Всего этапов: `_allSubGoals(goal.subGoals).length`
- Завершено: `goal.completedSubGoals`
- Верхнего уровня: `goal.subGoals.length`
- Вложенных: разница

#### 5. Карточка «Контрольные точки» (только если `goal.milestones.isNotEmpty`)
- Всего: `goal.milestones.length`
- Пройдено: `goal.milestones.where((m) => m.isCompleted).length`
- Ближайшая незакрытая точка с датой (если есть `targetDate`)

#### 6. Карточка «Временные показатели»
- Создана: `_formatDate(goal.createdAt)`
- Активна уже: `DateTime.now().difference(goal.createdAt).inDays` дней
- Последнее обновление: `goal.updatedAt` (если есть)
- Дедлайн: `goal.deadline` / «не задан»
- Осталось дней: `goal.daysUntilDeadline` (красный если `isOverdue`)

#### 7. Карточка «Привязанные привычки» (только если `goal.habitLinks.isNotEmpty`)
- Число привязанных привычек: `goal.habitLinks.length`
- Суммарный `boostValue` (с пояснением «суммарный буст прогресса»)

Имена привычек **не** показываем — данные о привычках (`Habit`) не загружены в `planningProvider`; пришлось бы либо кросс-читать `habitsProvider`, либо хранить имена — лишняя сложность. Достаточно числа и буста.

#### 8. Блок «Советы» (опционально)
Переиспользовать `_MissionHeader._buildAdvice(goal)` логику (вынести как top-level функцию `buildGoalAdvice(Goal g)`): если есть тревожные сигналы — показать их списком.

---

## Компоновка карточек

Каждая секция — `Container` с `BoxDecoration(color: sc.surface, borderRadius: 12, border: Border.all(sc.border))`, внутри `Padding(16)`. Весь экран — `ListView` с `padding: EdgeInsets.fromLTRB(16, 8, 16, 32)` и `gap: 12` между карточками.

Маленькие числовые ячейки — виджет `_StatCell(label, value, [color])` (приватный в файле).

---

## Затрагиваемые модули

| Файл | Изменение |
|---|---|
| `apps/central_hub/lib/screens/goal_stats_screen.dart` | **Создать** новый файл |
| `apps/central_hub/lib/screens/mission_detail_screen.dart` | Добавить `IconButton(Icons.bar_chart_outlined)` в `_MissionHeader` + импорт нового экрана |
| `apps/central_hub/lib/screens/planning_screen.dart` | Добавить `onStats` callback в `_GoalOptionsSheet`, пункт меню «Статистика миссии», вызов навигации |

### Вспомогательные функции (вынести / использовать из `sie_core`)

- `goalProgress(Goal)` — уже есть в `sie_core`
- `_allSubGoals(List<SubGoal>)` — приватная в `planning_provider.dart`; продублировать локально в новом файле (маленькая, 4 строки)
- `buildGoalAdvice(Goal g)` — вынести `_MissionHeader._buildAdvice` в top-level функцию прямо в `mission_detail_screen.dart` (или дублировать в `goal_stats_screen.dart`)

---

## Схема данных

Новые таблицы / колонки **не нужны**. Вся статистика вычисляется на клиенте из уже загруженных данных `Goal`.

---

## Открытые вопросы

1. **Полноэкранный экран или bottom sheet?** Рекомендую полноэкранный — данных много, комфортнее листать. Bottom sheet при большом контенте вызывает проблемы с scroll inside scroll.

2. **Прогресс-кольцо:** использовать `fl_chart` (`PieChart` с одним сектором) или нарисовать `CustomPaint`? `CustomPaint` — проще и без лишней зависимости. Альтернатива — `CircularProgressIndicator` с `strokeWidth: 10` и `backgroundColor`.

3. **Имена привычек:** если позже понадобятся — можно добавить кросс-чтение `ref.watch(habitsProvider)` в `GoalStatsScreen`. Сейчас — только количество и буст.

4. **`_StatusChip` и `_categoryIcon`:** дублировать в новом файле или вынести в `sie_core`? Рекомендую дублировать — виджет крошечный (15 строк), вынос создаёт публичные зависимости.
