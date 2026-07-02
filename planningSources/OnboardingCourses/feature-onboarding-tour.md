# План: Интерактивный тур по приложению (Onboarding Tour / Coach Marks)

> **Цель:** Обучить новых пользователей основам приложения — навигации, геймификации (XP), ключевым модулям (Департаменты), лидерборду, профилю и магазину — через интерактивный overlay-тур с подсветкой реальных элементов интерфейса.

**Режим:** Планирование → Реализация
**Формат:** Интерактивный тур (coach marks / spotlight overlay) — подсветка целевого виджета «дыркой» в затемнённом фоне + карточка-подсказка рядом.

---

## 1. Описание

Новым пользователям сложно сориентироваться в наполненном приложении. Тур проводит оперативника по 4 вкладкам нижней навигации и подсвечивает ключевые элементы на каждом экране, объясняя их назначение в эстетике «киберпанк-оперативного штаба».

### Принципы
- **Привязка к реальным элементам** — подсветка живых виджетов через `GlobalKey` + `findRenderObject`, а не статичные скриншоты.
- **Киберпанк-стиль** — переиспользуем визуальный язык `OnboardingOverlay`: blur 35, золотая окантовка `c.accent`, свечением `blurRadius: 40`, лейблы-«протоколы» с `letterSpacing: 2.5`.
- **Offline-aware** — флаг тура хранится в Supabase `profiles` (как существующие `has_seen_onboarding_*`), но запуск возможен и офлайн (через локальный кеш `LocalProfiles.cachedJson`).
- **Доступность** — все анимации обёрнуты в `SieMotion.enabled` / `SieMotion.duration` (уважение reduce-motion). Хаптика на переходах (`SieHaptics.selection()`).
- **Пропускаемый** — кнопка «Пропустить» в любой момент. Тур можно повторно запустить из профиля.
- **Без сторонних библиотек** — чистый Flutter, полный контроль над стилем (аналогично существующему `OnboardingOverlay`).

---

## 2. Сценарий

### Точка запуска
После авторизации пользователь попадает на `MainNavigationShell` (вкладка Operations, индекс 1). На `OperationsControlScreen` уже существует Welcome modal (`operations_control_screen.dart:97-107`).

**Поток:**
1. Splash → Auth → `MainNavigationShell`
2. Welcome modal показывается (существующее поведение)
3. Пользователь нажимает «ПРИНЯТЬ ПРОТОКОЛ» в Welcome
4. **Новое:** если `!profile.hasSeenTour` → запускается интерактивный тур
5. Тур проходит по шагам (см. ниже)
6. По завершении → `markTourSeen()` + хаптика `SieHaptics.success()`
7. Повторный запуск — кнопка «Тур по приложению» в `ProfileScreen`

### Шаги тура (7 шагов)

| # | Вкладка | Цель (GlobalKey) | Заголовок | Суть |
|---|---------|------------------|-----------|------|
| 1 | Operations (1) | `_XpBar` | XP-прогресс | «Опыт — ваша валюта роста. 1000 XP = новый уровень. Выполняйте привычки, фокус-сессии, миссии — копите XP.» |
| 2 | Operations (1) | `_BranchCarousel` | Департаменты | «Департаменты — ваши инструменты: Планирование, Привычки, Фокус, Дыхание, Медитация. Тапните карточку, чтобы войти в модуль.» |
| 3 | Operations (1) | `_LeaderboardTile` | Авангард Суток | «Ежедневный рейтинг активности. Топ-оперативники дня получают бонус. Конкурируйте и поднимайтесь.» |
| 4 | Operations (1) | `_ShellNavBar` (вся) | Навигация | «Нижняя панель — ваша штаб-навигация. Hub, Operations, Garage, Hall of Fame.» |
| 5 | Hub (0) | `ProfileScreen` body | Досье оперативника | «Hub — ваше личное досье: уровень, награды, сейф медалей, настройки, повторный запуск этого тура.» |
| 6 | Garage (2) | `GarageScreen` body | Garage | «Магазин кастомизации: тратьте Design Points (DP) на рамки аватара, фоны профиля, стили статистики.» |
| 7 | Hall of Fame (3) | `LeaderboardScreen` body | Зал Славы | «Глобальный рейтинг всех оперативников. Сезонные награды топ-оперативникам.» |

> **Завершение:** карточка «ТУР ЗАВЕРШЁН» с кнопкой «НАЧАТЬ ОПЕРАЦИИ» → `markTourSeen()` + `SieHaptics.success()`.

### Поведение
- Кнопка **«Далее»** → следующий шаг (хаптика `selection()`)
- Кнопка **«Назад»** → предыдущий шаг
- Кнопка **«Пропустить»** → закрыть тур без записи в БД (можно перезапустить из профиля)
- При переключении вкладки (шаги 5/6/7) — анимация перехода `IndexedStack`, затем post-frame callback для замера позиции цели
- Если целевой виджет не отрисован (render box null) — пропуск шага с предупреждением в лог

---

## 3. Логика

### 3.1. TourController (Riverpod StateNotifier)

**Файл:** `packages/sie_core/lib/src/providers/tour_controller.dart`

```dart
class TourState {
  final int currentIndex;          // текущий шаг
  final bool isActive;             // тур активен
  final bool isCompleting;         // финальная карточка
  final Map<String, GlobalKey> keys; // ключи целей
}

class TourController extends StateNotifier<TourState> {
  TourController() : super(TourState.initial());

  static const steps = <TourStep>[ ... ]; // 7 шагов + финал

  void start();          // state.isActive = true, currentIndex = 0
  void next();           // currentIndex++ или complete()
  void back();           // currentIndex--
  void skip();           // isActive = false (без markTourSeen)
  void complete();       // isCompleting = true
  void finish();         // isActive = false → markTourSeen()
  GlobalKey keyFor(String id); // получить/создать GlobalKey
}

class TourStep {
  final String id;
  final int tabIndex;          // на какую вкладку переключиться
  final String targetKey;      // id GlobalKey цели
  final String titleKey;       // i18n-ключ заголовка
  final String bodyKey;        // i18n-ключ текста
  final TargetPosition position; // above / below / auto
}
```

### 3.2. Получение позиции цели

```dart
Rect? _targetRect(GlobalKey key) {
  final ctx = key.currentContext;
  if (ctx == null) return null;
  final box = ctx.findRenderObject() as RenderBox?;
  if (box == null || !box.attached) return null;
  final pos = box.localToGlobal(Offset.zero);
  return pos & box.size;
}
```

### 3.3. Переключение вкладок

Тур управляет `_currentIndex` в `MainNavigationShell`. Для этого `MainNavigationShell` должен exposing метод/коллбэк:
- Вариант A: `MainNavigationShell` слушает `tourControllerProvider`, при активном туре переключает `_currentIndex` по `state.currentIndex` шага.
- Вариант B: `tourController` хранит `tabController` ссылку (менее чисто).

**Рекомендация:** Вариант A — `MainNavigationShell` watch `tourControllerProvider.select((s) => s.isActive ? steps[s.currentIndex].tabIndex : null)`.

### 3.4. Overlay-виджет (CoachMarkOverlay)

**Файл:** `packages/sie_core/lib/src/widgets/coach_mark_overlay.dart`

Структура:
```
Overlay (Positioned.fill)
  ├─ CustomPaint (dimmed background + cutout)
  │    └─ Path: full screen MINUS RRect(target, borderRadius: 12, padding: 8)
  │    └─ BackdropFilter blur 8 (мягкое затемнение вокруг дырки)
  ├─ TooltipCard (позиционирован above/below target)
  │    ├─ лейбл-протокол (gold, letterSpacing 2.5)
  │    ├─ заголовок (textPrimary, titleMedium)
  │    ├─ body (textSecondary, bodyMedium)
  │    ├─ Row: [Пропустить] ... [Назад] [Далее]
  │    └─ индикатор шагов "3 / 7"
  └─ AnimatedOpacity (fade in/out, SieMotion.duration)
```

**Dimmed background с cutout** — `CustomPaint`:
```dart
Path full = Path()..addRect(Offset.zero & size);
Path hole = Path()..addRRect(RRect.fromRectAndRadius(targetRect.inflate(8), Radius.circular(12)));
canvas.drawPath(Path.combine(PathOperation.difference, full, hole), paint); // paint.color = black 0.68
```

**Дополнительно:** золотая обводка вокруг cutout (`drawRRect` с `Paint()..color = c.accent..style = PaintingStyle.stroke..strokeWidth = 1.5`).

**Позиционирование карточки:**
- `above` — если target.top > screenHeight * 0.45, иначе `below`
- отступ 16px от цели
- maxWidth: screenWidth - 32
- если не помещается — clamp по краям

### 3.5. Добавление GlobalKey к целям

| Цель | Файл | Изменение |
|------|------|-----------|
| `_XpBar` | `operations_control_screen.dart:1941` | добавить `key: tourKey('xp_bar')` |
| `_BranchCarousel` | `operations_control_screen.dart:619` | `key: tourKey('branch_carousel')` |
| `_LeaderboardTile` | `operations_control_screen.dart:576` | `key: tourKey('leaderboard_tile')` |
| `_ShellNavBar` | `main_navigation_shell.dart:130` | `key: tourKey('nav_bar')` |
| `ProfileScreen` body | `profile_screen.dart:16` | `key: tourKey('profile_body')` |
| `GarageScreen` body | `garage_screen.dart` | `key: tourKey('garage_body')` |
| `LeaderboardScreen` body | `leaderboard_screen.dart` | `key: tourKey('leaderboard_body')` |

Где `tourKey(id)` = `ref.read(tourControllerProvider.notifier).keyFor(id)`.

### 3.6. Флаг `hasSeenTour`

По аналогии с `has_seen_onboarding_*`:
- `Profile` model: `final bool hasSeenTour;` (default false)
- JSON-ключ: `has_seen_tour`
- Миграция Supabase: `alter table profiles add column if not exists has_seen_tour boolean not null default false;`
- `user_profile_provider.dart`: `markTourSeen()` (копия `markOnboardingSeen('tour')`, но свой метод для ясности)

### 3.7. Запуск тура

В `OperationsControlScreen` (после закрытия Welcome modal, `operations_control_screen.dart:230-239`):
```dart
if (!profile.hasSeenTour) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(tourControllerProvider.notifier).start();
  });
}
```

### 3.8. Повторный запуск из профиля

В `ProfileScreen` добавить пункт «Тур по приложению» → `ref.read(tourControllerProvider.notifier).start()`.

### 3.9. Монтирование Overlay

Overlay рендерится в `MainNavigationShell.build()` поверх `IndexedStack`:
```dart
Stack(
  children: [
    IndexedStack(...),           // существующий
    OfflineBanner(...),          // существующий
    if (tourActive) CoachMarkOverlay(...),  // новое
  ],
)
```
Где `tourActive` = `ref.watch(tourControllerProvider.select((s) => s.isActive))`.

---

## 4. Модули (затрагиваемые файлы)

### Новые файлы
| Файл | Назначение |
|------|-----------|
| `packages/sie_core/lib/src/providers/tour_controller.dart` | `TourController` (StateNotifier), `TourState`, `TourStep` |
| `packages/sie_core/lib/src/widgets/coach_mark_overlay.dart` | `CoachMarkOverlay` виджет (CustomPaint dimming + cutout + tooltip card) |
| `packages/sie_core/lib/src/widgets/coach_mark_painter.dart` | `CustomPainter` для dimmed background с cutout + золотая обводка |
| `packages/sie_core/lib/i18n/ru/tour.i18n.json` | Русская локализация шагов тура |
| `packages/sie_core/lib/i18n/en/tour.i18n.json` | Английская локализация |
| `supabase/migrations/20260627100000_tour_flag.sql` | Миграция: колонка `has_seen_tour` |

### Изменяемые файлы
| Файл | Изменение |
|------|-----------|
| `packages/sie_core/lib/sie_core.dart` | Экспорт `tour_controller.dart`, `coach_mark_overlay.dart`, `coach_mark_painter.dart` |
| `packages/sie_core/lib/src/models/profile.dart` | Добавить `hasSeenTour` поле + JSON-маппинг |
| `packages/sie_core/lib/src/providers/user_profile_provider.dart` | Добавить `markTourSeen()` |
| `supabase/schema.sql` | Добавить колонку `has_seen_tour` |
| `apps/central_hub/lib/screens/main_navigation_shell.dart` | Watch `tourControllerProvider` для переключения вкладок + монтирование `CoachMarkOverlay` в Stack |
| `apps/central_hub/lib/screens/operations_control_screen.dart` | Добавить `tourKey()` к `_XpBar`, `_BranchCarousel`, `_LeaderboardTile`; запуск тура после Welcome |
| `apps/central_hub/lib/screens/profile_screen.dart` | Добавить `tourKey()` к body; пункт «Тур по приложению» |
| `apps/central_hub/lib/screens/garage_screen.dart` | Добавить `tourKey()` к body |
| `apps/central_hub/lib/screens/leaderboard_screen.dart` | Добавить `tourKey()` к body |

---

## 5. Схема данных

### Supabase `profiles` (миграция)

```sql
-- 20260627100000_tour_flag.sql
alter table profiles
  add column if not exists has_seen_tour boolean not null default false;
```

### Drift `LocalProfiles`

Без изменений в схеме — флаг хранится в `cachedJson` (JSON-снапшот `profiles`), как и существующие `has_seen_onboarding_*`. При парсинге `Profile.fromJson` читается `has_seen_tour`.

### Модель `Profile` (`profile.dart`)

```dart
final bool hasSeenTour;  // новое поле
// fromJson: hasSeenTour: json['has_seen_tour'] ?? false,
// toJson: 'has_seen_tour': hasSeenTour,
```

### `TourStep` (in-memory, не персистится)

```dart
class TourStep {
  final String id;
  final int tabIndex;
  final String targetKey;
  final String titleKey;     // 'tour.step1.title'
  final String bodyKey;      // 'tour.step1.body'
  final TargetPosition position; // above / below / auto
}
```

---

## 6. Локализация (i18n)

### `tour.i18n.json` (ru)
```json
{
  "step1": { "title": "Опыт (XP)", "body": "Опыт — валюта вашего роста. 1000 XP = новый уровень. Выполняйте протоколы, привычки и миссии, чтобы копить XP." },
  "step2": { "title": "Департаменты", "body": "Департаменты — ваши инструменты: Планирование, Привычки, Фокус, Дыхание, Медитация. Тапните карточку для входа." },
  "step3": { "title": "Авангард Суток", "body": "Ежедневный рейтинг активности. Топ-оперативники дня получают бонусные награды." },
  "step4": { "title": "Навигация", "body": "Нижняя панель — штаб-навигация: Hub (досье), Operations (дашборд), Garage (магазин), Hall of Fame (рейтинг)." },
  "step5": { "title": "Досье", "body": "Hub — ваше личное досье: уровень, награды, сейф медалей, настройки. Здесь же можно повторить этот тур." },
  "step6": { "title": "Garage", "body": "Магазин кастомизации. Тратьте Design Points (DP) на рамки, фоны и стили профиля." },
  "step7": { "title": "Зал Славы", "body": "Глобальный рейтинг оперативников. Сезонные награды топ-оперативникам." },
  "complete": { "title": "ТУР ЗАВЕРШЁН", "body": "Вы готовы к операциям, оперативник. Удачи в саморазвитии." },
  "actions": { "next": "ДАЛЕЕ", "back": "НАЗАД", "skip": "Пропустить", "finish": "НАЧАТЬ ОПЕРАЦИИ", "step": "Шаг {n} из {total}" }
}
```

Английская версия — аналогично. После создания — запустить кодогенерацию i18n.

---

## 7. Вопросы к обсуждению

1. **Запуск тура:** после закрытия Welcome modal (рекомендую) или вместо него (заменить Welcome на тур)?
2. **Количество шагов:** 7 шагов + финал — нормально, или сократить до 5 (убрать Garage и Hall of Fame, оставить только Operations + Hub)?
3. **Хранение флага:** в Supabase `profiles.has_seen_tour` (кросс-девайс, рекомендую) или только в SharedPreferences (проще, без миграции)?
4. **Тап по цели:** разрешить тап по подсвеченному элементу (переход в модуль) или блокировать (только «Далее»)?
5. **Пакет или pure Flutter:** реализовать на чистом Flutter (рекомендую — контроль стиля) или добавить `tutorial_coach_mark` / `showcaseview`?
6. **Прокрутка карусели:** на шаге 2 (Департаменты) прокручивать карусель к конкретной карточке (напр. Planning) или показывать карусель целиком?