# Этап 0 — Дизайн-система и сквозные паттерны

## Описание

Сквозные проблемы, которые повторяются на 10+ экранах. Чинятся централизованно
один раз и автоматически улучшают весь продукт. Этот этап — фундамент для всех
остальных, поэтому делается первым.

---

## 0.1 — Дизайн-токены цветов 🟠 P1

### Проблема
Захардкоженные `Color(0x...)` разбросаны по экранам и дублируются:

| Цвет | Где встречается |
|---|---|
| `_kOrange 0xFFFF8C42` | operations_control (550) |
| `_kGold 0xFFFFD700` | focus_protocol (10), leaderboard (9) |
| `_kSilver / _kBronze` | leaderboard (10–11) |
| Янтарь `0xFFFF9800` / `0xFFFFB347` | garage (940), progress_analytics (235) |
| Циан `0xFF00C8FF` | public_profile (232), customization (438), progress_analytics (438) |
| `Colors.green` | friends_list (411, accept) |
| `Colors.orange` | mission_detail (384, strategic advice) |
| Priority-палитра целей | planning (22–27), mission_detail, goal_stats — **дублируется** |
| Status-chip / deadline палитры | planning (579–582), mission_detail (1663) |

Последствия: ломают переключение тем, рассинхрон визуального языка, правка
дизайна = редактирование 5+ файлов.

### Предложение
Расширить `SieColors` семантическими токенами:
```
rankGold, rankSilver, rankBronze   // лидерборд, медали
warning  (янтарь)                  // блокировки, fatigue
success  (зелёный)                 // принять заявку, выполнено
danger   (красный)                 // удаление, overdue
info     (циан-grid)               // декоративные сетки
priorityCritical/High/Medium/Low   // цели
```
Все локальные `_k*` и `Colors.*` заменить на `c.<token>`. Палитру приоритетов
вынести в один helper `PriorityPalette.of(priority)` в `sie_core`, убрав
дублирование в planning/mission_detail/goal_stats.

---

## 0.2 — Деструктивные действия: подтверждение + Undo 🔴 P0

### Проблема
Мгновенные необратимые действия без защиты:
- Архивация привычки — `habit_detail` 3128 (без подтверждения).
- Удаление пресета медитации — `meditation_hub` 574 (без подтверждения/undo).
- Удаление привычки из рутины — `routine_editor` 95 (без подтверждения/undo).
- Удаление друга в `public_profile` — без диалога (в отличие от friends_list).

### Предложение
1. Единый хелпер `confirmDestructive(context, {title, message, confirmLabel})`
   → `Future<bool>` со стилизованной красной кнопкой (паттерн уже есть в
   planning 212–238 — обобщить).
2. Паттерн **optimistic delete + Undo snackbar** для лёгких действий
   (удаление из рутины, удаление пресета): сразу убираем из UI, показываем
   `showUndoSnackbar()` на 5 сек с откатом.
3. Тяжёлые/каскадные (удаление цели с подцелями) — оставить полноценный диалог.

---

## 0.3 — Скелетоны вместо спиннеров 🟡 P2

### Проблема
Все асинхронные экраны = `CircularProgressIndicator` по центру. Пользователь
не видит будущую форму контента; ощущение «зависло».

### Предложение
Компонент `SieSkeleton` (shimmer) + готовые формы:
`SieSkeletonList`, `SieSkeletonGrid`, `SieSkeletonCard`. Применить на самых
заметных списках: operations (карусель веток), habit_tracker, planning,
leaderboard, profile (сетки медалей/ачивок), meditation_hub.

---

## 0.4 — Единые состояния Empty / Error 🟡 P2

### Проблема
Разнобой: где-то `Text('Ошибка загрузки')`, где-то полноценный
`_NoConnectionMessage`, где-то пусто. Empty-состояния часто без CTA
(planning «Нет активных миссий» без кнопки; meditation_hub «Пресеты не найдены»
показывается даже когда пресеты есть, но отфильтрованы).

### Предложение
- `SieEmptyState(icon, title, subtitle, action?)` — иконка + текст +
  опциональная кнопка-CTA.
- `SieErrorState(onRetry)` — единый офлайн/ошибка с кнопкой «Повторить».
- Различать «нет данных» и «ничего не найдено по фильтру» (разный текст + сброс
  фильтра в CTA).

---

## 0.5 — Reduce-motion и мотив-токены 🟠 P1

### Проблема
Нигде нет проверки `MediaQuery.of(context).disableAnimations`. Критично для
медитации и дыхания: пульсации орба, heartbeat, repeat-анимации,
shimmer (garage claim 2200ms), пульс в фокусе — идут всегда. Для людей с
вестибулярной чувствительностью это проблема, плюс расход батареи.

### Предложение
- Хелпер `SieMotion.enabled(context)`; при выключенной анимации заменять
  непрерывные `repeat()`-анимации статичным состоянием (или плавным fade без
  пульсации).
- Токены длительностей (`fast 150 / base 250 / slow 400`) — убрать «магические»
  числа.

---

## 0.6 — Хаптика 🟡 P2

### Проблема
Почти нет тактильной обратной связи: long-press открывает sheet без отклика,
переключатели/таймеры молчат, drag-reorder без подтверждения.

### Предложение
`SieHaptics`: `selection()` (чипы, табы), `success()` (завершение сессии,
покупка), `warning()` (заблокированное действие), `heavy()` (старт long-press,
старт drag). Подключить точечно к ключевым действиям.

---

## 0.7 — Доступность: тач-таргеты, контраст, семантика 🟠 P1

### Проблема
- Тач-таргеты < 48dp: иконки-кнопки 18–20px (friends_list 350, habit_detail
  settings), day-node 36px (garage 439), heatmap-ячейки 14px, точки rarity
  6px, achievement-grid 6 колонок (~35px) в public_profile.
- Подписи 8–10px по всему приложению.
- Иконки-кнопки без `Tooltip`/`Semantics` — скринридер не озвучивает.
- Низкий контраст вторичного текста на тёмном фоне; XP-бар 6px (profile 367).

### Предложение
- Обернуть все иконки-кнопки в зону ≥48dp (через `IconButton`/`SizedBox`),
  даже если иконка визуально мелкая.
- Поднять минимальный размер критичных подписей до 11–12px; уважать text scale.
- Добавить `Tooltip` + `Semantics(button:true, label:...)` на иконки-действия.
- XP-бары/прогресс — поднять высоту до 8–10px, проверить контраст AA.

---

## Затрагиваемые модули

- `packages/sie_core/lib/src/theme/sie_colors.dart` — новые токены.
- `packages/sie_core/lib/src/theme/` — `sie_motion.dart`, `sie_haptics.dart` (NEW).
- `packages/sie_core/lib/src/widgets/` — `sie_skeleton.dart`, `sie_empty_state.dart`,
  `sie_error_state.dart`, `confirm_destructive.dart`, `undo_snackbar.dart` (NEW).
- `packages/sie_core/lib/sie_core.dart` — экспорты.
- Затем точечная замена на всех экранах (этапы 1–5).

## Открытые вопросы
- Готовы ли к рефактору `SieColors` (миграция всех `_k*`-констант) в один
  присест, или вводим токены постепенно?
- Нужен ли полноценный shimmer или достаточно статичных серых плейсхолдеров?
