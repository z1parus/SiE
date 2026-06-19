# Этап 4 — Виджет «Дыхательные практики»

## Идея

Спокойный якорь на домашнем экране: zen-стрик и приглашение подышать. Минимум цифр,
максимум воздуха. Тап — сразу в практику.

## Данные

Провайдер: `meditationStatsProvider` → `MeditationStats { zenStreakDays,
claritySecondsThisWeek, clarityXpLevel, totalSessionCount }`.
Офлайн-источник: Drift `LocalBreathingSessions` (+ `LocalMeditationSessions`).
Паттерны (из `meditation_session_provider`): `box` (4-4-4-4), `4-7-8`, `coherence` (5-5).

`BreathingWidgetData`:
```dart
class BreathingWidgetData extends WidgetData {
  final int zenStreakDays;
  final int minutesThisWeek;       // claritySecondsThisWeek ~/ 60
  final int totalSessions;
  final DateTime? lastSessionAt;   // из LocalBreathingSessions
  final String quickPatternId;     // дефолтный паттерн для быстрого старта
}
```

Замечание: офлайн доступна история сессий (Drift), а `zenStreakDays` приходит из профиля
(Supabase). Офлайн показываем последнее кэшированное значение стрика (сохраняем при онлайне
в SharedPreferences), чтобы виджет не «прыгал».

## Варианты по размеру

### Small (160×160) — «Дыхание»
- Орб (`SphereRimPainter`, статичный кадр) по центру, мягкий teal/`accentSecondary` глоу.
- Под орбом: `zenStreakDays` + «дней» мелко.
- Минимализм: никаких других цифр.

### Medium (320×160) — «Покой недели»
- Слева орб.
- Справа: `zenStreakDays` «дзен-стрик», `minutesThisWeek` «мин на неделе».
- Низ: чип «Подышать · <паттерн>» (быстрый старт, этап 8).

### Large (320×320) — «Дыхательная станция»
- Крупный орб-герой сверху.
- Ряд из трёх быстрых паттернов: «Бокс», «4-7-8», «Когерентность» — кнопки (tap-зоны).
- Снизу: стрик + минуты недели + всего сессий.

## Контент-опции

- `quickPattern`: какой паттерн запускать тапом по чипу.
- `metric` (small): «zen-стрик» | «минуты недели» | «последняя сессия (давно)».
- `orbStyle`: цвет глоу орба (наследовать акцент vs фирменный teal `#4ECDC4`).

## Состояния

- **Ещё не дышал** → орб + «Начни первую сессию».
- **Стрик под угрозой** (сегодня ещё не было сессии, вчера был) → мягкая подсветка орба
  `warning`, подпись «Сохрани стрик».

## Deep-link / действия

- Тап по виджету → `sie://widget/breathing` → `BreathingExerciseScreen`.
- Тап по чипу паттерна (этап 8) → открыть экран сразу с выбранным паттерном
  (через intent-extra `pattern=<id>`).

## Файлы

- `packages/sie_core/lib/src/widgets_home/modules/breathing_widget_provider.dart` — NEW
- painter орба переиспользуется из `session_orb_painters.dart` (`SphereRimPainter`).
