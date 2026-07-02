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
- **Локализация (i18n):** пакет **slang**. Переводы — JSON-файлы в `packages/sie_core/lib/i18n/<locale>/<namespace>.i18n.json` (`en`, `ru`). Базовый/запасной язык — `en`, по умолчанию берётся язык устройства. Доступ через глобальный `t` (`t.namespace.key`), без `BuildContext`. Язык переключается в провайдере `localeProvider`.

## Кодогенерация

`*.g.dart` в `.gitignore` и не коммитятся — их нужно генерировать локально. После клонирования или изменения схемы Drift / JSON-переводов:

```bash
cd packages/sie_core
dart run build_runner build   # Drift (app_database.g.dart)
dart run slang                # переводы (i18n/translations*.g.dart)
```

## Окружение (remote)

- Flutter SDK: `/opt/flutter`
- Android SDK: `/opt/android` (`ANDROID_HOME`)
- Supabase CLI: залогинен, проект `bvqlqvzcqfgojzxztvrm` (West EU)
- GitHub CLI: залогинен как `z1parus`

---

## Подготовка облачного окружения Claude

Когда пользователь говорит **"Настрой окружение"** или открывается новая облачная сессия — выполнить все шаги ниже строго по порядку. Окружение: Ubuntu 24.04 x86_64, все команды от root.

### Шаг 1 — Системные зависимости

```bash
apt-get update -qq
apt-get install -y -qq git curl unzip xz-utils zip libglu1-mesa clang cmake ninja-build pkg-config libgtk-3-dev
```

### Шаг 2 — Flutter SDK 3.32.3

```bash
git config --global --add safe.directory /opt/flutter
cd /tmp
curl -fsSL -x "$HTTPS_PROXY" --cacert /root/.ccr/ca-bundle.crt \
  "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.32.3-stable.tar.xz" \
  -o flutter.tar.xz
tar -xf flutter.tar.xz -C /opt/
```

### Шаг 3 — Android SDK

```bash
mkdir -p /opt/android/cmdline-tools
cd /tmp
curl -fsSL -x "$HTTPS_PROXY" --cacert /root/.ccr/ca-bundle.crt \
  "https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip" \
  -o cmdline-tools.zip
unzip -q cmdline-tools.zip -d /tmp/cmdline-tools-tmp
mv /tmp/cmdline-tools-tmp/cmdline-tools /opt/android/cmdline-tools/latest

export ANDROID_HOME=/opt/android
export PATH="/opt/flutter/bin:/opt/android/cmdline-tools/latest/bin:/opt/android/platform-tools:$PATH"

yes | sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"
flutter config --android-sdk /opt/android
```

### Шаг 4 — Переменные окружения (постоянно)

```bash
cat >> /root/.bashrc << 'EOF'

export PATH="/opt/flutter/bin:/opt/android/cmdline-tools/latest/bin:/opt/android/platform-tools:$PATH"
export ANDROID_HOME=/opt/android
EOF
```

### Шаг 5 — GitHub CLI

```bash
curl -fsSL -x "$HTTPS_PROXY" --cacert /root/.ccr/ca-bundle.crt \
  https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt-get update -qq && apt-get install -y -qq gh
```

Авторизация через config-файл (токен от пользователя):

```bash
mkdir -p ~/.config/gh
cat > ~/.config/gh/hosts.yml << EOF
github.com:
    oauth_token: <GITHUB_TOKEN>
    user: z1parus
    git_protocol: https
EOF
```

> `gh api /user` должен вернуть `"login":"z1parus"`. GraphQL заблокирован прокси — это нормально, REST работает.

### Шаг 6 — Supabase CLI

```bash
SUPABASE_VERSION=$(curl -fsSL -x "$HTTPS_PROXY" --cacert /root/.ccr/ca-bundle.crt \
  https://api.github.com/repos/supabase/cli/releases/latest \
  | grep '"tag_name"' | cut -d'"' -f4)
curl -fsSL -x "$HTTPS_PROXY" --cacert /root/.ccr/ca-bundle.crt \
  "https://github.com/supabase/cli/releases/download/${SUPABASE_VERSION}/supabase_linux_amd64.tar.gz" \
  -o /tmp/supabase.tar.gz
tar -xzf /tmp/supabase.tar.gz -C /usr/local/bin/ supabase

supabase login --token <SUPABASE_TOKEN>
```

> **Важно:** Supabase CLI — Go-бинарник с собственным диалером, игнорирует `HTTPS_PROXY`. Команды `supabase db push` и `supabase functions deploy` **не работают** в облачном окружении. Вместо них используются скрипты `supabase/scripts/db-push.sh` и `supabase/scripts/functions-deploy.sh`.

### Шаг 7 — Зависимости Flutter-проектов

```bash
export PATH="/opt/flutter/bin:$PATH"
cd /home/user/SiE/apps/central_hub && flutter pub get
cd /home/user/SiE/packages/sie_core && flutter pub get
```

### Шаг 8 — Переменные для Supabase-скриптов

Создать файл `.env.local` в корне репозитория (в `.gitignore`, не коммитить):

```
SUPABASE_ACCESS_TOKEN=<SUPABASE_TOKEN>
SUPABASE_PROJECT_REF=bvqlqvzcqfgojzxztvrm
SSL_CERT_FILE=/root/.ccr/ca-bundle.crt
```

Использование скриптов:

```bash
source .env.local
bash supabase/scripts/db-push.sh            # применить новые миграции
bash supabase/scripts/functions-deploy.sh   # задеплоить все Edge Functions
bash supabase/scripts/functions-deploy.sh telegram-auth  # одну функцию
```

### Проверка готовности

```bash
export PATH="/opt/flutter/bin:/opt/android/cmdline-tools/latest/bin:/opt/android/platform-tools:$PATH"
export ANDROID_HOME=/opt/android
flutter doctor          # должны быть ✓ Flutter и ✓ Android toolchain
gh api /user            # должен вернуть "login":"z1parus"
supabase --version      # должна показать версию
```

### Токены (спросить у пользователя если не заданы)

| Переменная | Где взять |
|---|---|
| `GITHUB_TOKEN` | github.com → Settings → Developer settings → Personal access tokens |
| `SUPABASE_TOKEN` | supabase.com/dashboard/account/tokens |

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
