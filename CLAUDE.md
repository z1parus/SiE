# SiE — Claude Instructions

## Режим планирования

**Активация:** когда пользователь говорит **"Переходим в режим планирования"**, немедленно войти в этот режим.

### Правила режима планирования

1. **Читать можно** — любые файлы кодовой базы для понимания архитектуры и логики.
2. **Писать/изменять можно** — только `.md` файлы в директории `planningSources/`.
3. **Запрещено** — любые изменения кода (`.dart`, `.yaml`, `.json`, `.sql`, конфиги и т.д.).
4. Каждый план — отдельный файл в `planningSources/` с говорящим именем, например `planningSources/feature-habit-streaks.md`.

### Структура файла плана

```
# [Название фичи / баг-фикса]

## Описание
Что это и зачем нужно.

## Пользовательский сценарий
Как это выглядит и работает в приложении глазами пользователя.

## Логика и поведение
Детальное описание логики: состояния, переходы, edge cases.

## Затрагиваемые модули
Какие файлы/пакеты/экраны будут изменены.

## Схема данных (если нужно)
Новые таблицы, поля, Supabase-функции.

## Открытые вопросы
Что требует уточнения перед реализацией.
```

**Выход из режима планирования:** пользователь явно говорит об этом ("выходим из режима планирования", "начинаем реализацию" и т.п.).

---

## Команда "Делай релиз"

**Активация:** когда пользователь говорит **"Делай релиз"**, выполнить следующие шаги строго по порядку.

### Шаги релиза

1. **Коммит и пуш всех изменений**
   - Закоммитить все незакоммиченные изменения в ветку `dev`
   - Запушить в GitHub (`git push -u origin dev`)

2. **Проверка кода**
   - Запустить `flutter analyze` в `apps/central_hub`
   - Если есть **ошибки** (`error`) — исправить, закоммитить и запушить снова
   - Предупреждения уровня `info`/`warning` не блокируют релиз

3. **Определить следующую версию**
   - Прочитать текущую версию из `apps/central_hub/pubspec.yaml` (поле `version: X.Y.Z+N`)
   - Следующая версия: увеличить patch (`Z + 1`), build number (`N + 1`)
   - Обновить `version` в `pubspec.yaml` и закоммитить

4. **Сборка APK**
   ```bash
   export PATH="/opt/flutter/bin:/opt/android/cmdline-tools/latest/bin:/opt/android/platform-tools:$PATH"
   export ANDROID_HOME=/opt/android
   git config --global --add safe.directory /opt/flutter
   cd apps/central_hub
   flutter build apk --release
   ```
   - Готовый файл: `apps/central_hub/build/app/outputs/flutter-apk/app-release.apk`
   - Переименовать в `SiE-Hub-vX.Y.Z.apk` (по новой версии)
   - Скопировать в корень репозитория

5. **Создать релиз на GitHub**
   - Использовать MCP-инструменты GitHub (`mcp__github__*`) или `gh` CLI
   - Тег: `vX.Y.Z`
   - Название: `SiE Hub vX.Y.Z`
   - Описание релиза: **на русском языке**, перечислить что было добавлено/исправлено в этой версии (изучить коммиты с прошлого релиза через `git log`)
   - Прикрепить APK-файл к релизу

### Важно
- Всегда работать в ветке `dev`
- APK копируется в корень репозитория и коммитится вместе с обновлённым `pubspec.yaml`
- Если сборка APK упала — разобраться с ошибкой до создания релиза

---

## Структура проекта

- `apps/central_hub` — основное Flutter-приложение
- `packages/sie_core` — общий Flutter-пакет (модели, провайдеры, база данных)
- `supabase/` — конфигурация Supabase (миграции, Edge Functions, схема)
- `planningSources/` — планы разработки в формате Markdown

## Технологический стек

- **Flutter** 3.32.3 / **Dart** 3.8.1
- **State management:** Riverpod
- **Local DB:** Drift (SQLite), кодогенерация через build_runner
- **Backend:** Supabase (PostgreSQL, Edge Functions, RLS)
- **Offline-first:** локальный Drift + синхронизация с Supabase

## Окружение (remote)

- Flutter SDK: `/opt/flutter`
- Android SDK: `/opt/android` (`ANDROID_HOME`)
- Supabase CLI: залогинен, проект `bvqlqvzcqfgojzxztvrm` (West EU)
- GitHub CLI: залогинен как `z1parus`

---

## Дизайн-система (обязательно к исполнению)

У проекта **уже есть** полноценная дизайн-система в `packages/sie_core/lib/src/theme/` и `.../widgets/`. Главное правило качества UI — **использовать её, а не писать цвета и компоненты с нуля**. Несогласованность и «некрасивый» вид возникают именно из-за хардкод-цветов `Color(0x...)` и самописных карточек поверх готовых.

### 1. Цвета — только через токены, без хардкода

Доступ к палитре в любом виджете:
```dart
final c = ref.watch(sieColorsProvider); // SieColors
// или без Riverpod, если ref недоступен:
// SieColors.forMode(SieThemeMode.classicDark)
```

**Запрещено** использовать `Color(0xRRGGBB)` и `Colors.white/black` напрямую в коде экранов и виджетов — только токены `SieColors`. Также **не использовать** статические константы `SieTheme.cd*` / `SieTheme.cl*` и legacy «Cyber-Space»-палитру (`SieTheme.accent` = cyan) для UI — это низкоуровневые исходники темы; runtime-токены живут в `SieColors`.

Токены `SieColors`:
- поверхности: `background`, `surface`
- акценты: `accent` (gold-sand `#C8A84B`), `accentSecondary`, `dp`
- текст: `textPrimary`, `textSecondary`
- линии/иконки: `border`, `iconMuted`
- семантика: `warning`, `success`, `danger`, `info`, `focusBreak`
- ранги: `rankGold`, `rankSilver`, `rankBronze`
- `isLightMode` — признак светлой темы для ветвления стиля

### 2. Хелперы `SieColors` — переиспользовать, не дублировать

- `c.flatCard({double radius = 16})` — стандартная плоская карточка (тёмная: surface + border; светлая: surface + мягкая тень)
- `c.subtleContainer({double radius = 20})` — полупрозрачный «стеклянный» контейнер
- `c.priorityColor(int priority)` — цвет приоритета цели (1..4). **Не** плодить `switch` по приоритетам в экранах
- `c.rankColor(int rank)` — цвет медали/ранга (1..3, дальше `textSecondary`)

### 3. Готовые виджеты — предпочитать самописным

Прежде чем писать новый `Container`/`Card`/пустой стейт, проверить наличие готового в `sie_core`:
- `SieGlassCard` — стеклянная карточка
- `SectionHeader` — заголовок секции
- `SieSkeleton` — скелетон загрузки
- `SieEmptyState` / `SieErrorState` — пустое состояние / ошибка
- `SieFeedback` — снеки/тосты (через `SieColors`-палитру)
- `SieBackground` / `StarrySkyBackground` — фон экрана
- `BranchCard`, `HabitCard`, `ProfileHeroCard`, `AchievementBadge`, `MissionMedalBadge` — доменные карточки
- `OfflineBanner` — баннер оффлайна

### 4. Типографика — через `Theme.of(context).textTheme`

Тема уже задаёт стили (`headlineLarge/Medium`, `titleLarge/Medium`, `bodyLarge/Medium`, `labelSmall` с правильными цветами, весами и трекингом). **Не** задавать `TextStyle(color: ..., fontSize: ...)` вручную там, где подходит стиль темы. Цвет текста берётся из темы/`SieColors`, а не хардкодится.

### 5. Анимации и тактильность

- Длительности — `SieMotion.fast` (150ms) / `base` (250ms) / `slow` (400ms), не магические числа
- Декоративные/циклические анимации гейтить на `SieMotion.enabled(context)` (уважает системный «reduce motion»)
- `AnimatedFoo`/неявные переходы — оборачивать длительность через `SieMotion.duration(context, d)`
- Тактильный отклик — через `SieHaptics`

### 6. Дизайн-язык

Тёмный антрацит (`#1C1C22`) + gold-sand акцент (`#C8A84B`), **плоский** стиль (elevation 0), тонкие бордеры вместо теней, скругления 16 (карточки) / 20 (стекло), много воздуха, Cupertino-переходы между экранами. Светлый режим — зеркальный по тем же токенам.

### 7. Контроль качества (чек-лист перед завершением задачи)

- В изменённых файлах **нет** новых `Color(0x` и `Colors.white`/`Colors.black` (кроме `withValues(alpha:)` поверх токенов):
  ```bash
  grep -rn "Color(0x" apps/central_hub/lib --include="*.dart"
  ```
- Контейнеры/карточки — через `flatCard()`/`subtleContainer()` или готовые виджеты, не самописные `DecoratedBox`
- Приоритеты/ранги — через `priorityColor()`/`rankColor()`
- Текст — через `Theme.of(context).textTheme` + токены цвета
- Анимации — через `SieMotion`, тактика — через `SieHaptics`
