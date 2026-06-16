# Этап 4 — Система анимированных узоров (Patterns)

> **Статус: реализовано (2026-06-14).** Узоры реализованы на `CustomPainter`
> (`ProfilePatternLayer` + `DotMatrixPainter`/`LowPolyPainter`/`IsoGridPainter`,
> нейро-нити переиспользуют `NeuralNetworkWidget`). Переход на GLSL-шейдеры для
> `low_poly`/`iso_grid` оставлен как возможная будущая оптимизация. Миграция БД
> подготовлена в `supabase/migrations/20260614000002_profile_patterns.sql` (не
> применена — по решению применяем только из .sql-файлов).

## Описание

Новый класс косметических предметов — **узоры (patterns)**, которые
**накладываются поверх** уже установленного фона профиля (цвет/градиент) в
верхней карточке (`ProfileHeroCard`, этап 1). Узоры **анимированы** и
спроектированы так, чтобы **не сливаться** с цветом фона (контрастный/аддитивный
блендинг, свечение узлов). Узоры покупаются за DP и применяются через Interface
Hub и Customization (этап 5).

Прецеденты в коде уже есть:
- `NeuralNetworkPainter` (`neural_network_painter.dart`) — анимированный
  `CustomPainter` с тикером 14с. Существующий `useNeuralPattern` станет первым
  узором новой системы (миграция без потери совместимости).
- Шейдерный пайплайн `breathing_sphere.frag` + обвязка в
  `operations_control_screen.dart:817–953` (`FragmentProgram.fromAsset` →
  `AnimationController` → `CustomPaint` с `shader.setFloat`) — основа для
  шейдерных узоров.

## Пользовательский сценарий

В разделе кастомизации появляется вкладка **«УЗОРЫ»**. Пользователь видит сетку
доступных узоров с живым превью, покупает понравившийся за DP и применяет.
Узор тут же оживает поверх фона его профиля: тонкие линии, импульсы света,
кристаллическая сетка или матрица точек — карточка «дышит». Можно «снять узор»
(none), оставив чистый фон.

## Стартовый каталог узоров

| Slug | Название | Техника | Анимация |
|---|---|---|---|
| `neural_threads` | Нейронные нити | `CustomPainter` (из существующего) | импульсы света по линиям между узлами |
| `low_poly` | Полигональная сетка | шейдер `pattern_lowpoly.frag` | медленный дрейф вершин + бегущий блик по граням |
| `iso_grid` | Изометрические кубы | шейдер `pattern_isogrid.frag` | волна подсветки граней, «дыхание» рёбер |
| `dot_matrix` | Точечный паттерн | `CustomPainter` или шейдер | мягкая бегущая волна яркости по точкам |

Все узоры используют **акцентный цвет** (`background.accentColor` либо
`c.accent`) как базу свечения и **тему** (`isDark`) для подбора прозрачностей.

> **Решения (зафиксированы 2026-06-14):**
> - Цвет узора **наследует акцент фона** (`accentColor`); отдельного
>   `pattern_color` и пользовательского выбора оттенка не вводим.
> - Узор применяется **на любом фоне, включая дефолтный** (узор самоценен).
> - Цены/редкость (**инвертированы** относительно изначального предложения):
>   `iso_grid` — 0 DP, common (**стартовый**); `low_poly` — 500 DP, rare;
>   `dot_matrix` — 1000 DP, epic; `neural_threads` — 1500 DP, epic.

### Спецификации (визуал + анти-слияние с фоном)

- **Нейронные нити** — апгрейд `NeuralNetworkPainter`: добавить редкие
  «импульсы» (яркая точка, бегущая вдоль линии, период ~3–6с, фаза по seed),
  свечение узлов (`MaskFilter.blur` лёгкий). Линии полупрозрачные, узлы ярче
  фона → читается на любом цвете.
- **Low-Poly** — триангуляция экрана (фикс-сетка вершин с лёгким джиттером),
  грани с едва заметным градиентом от акцента; раз в N секунд по случайной грани
  пробегает блик. Контраст граней к фону за счёт `+lighten` по краям
  треугольников.
- **Изо-кубы** — повторяющийся изометрический паттерн кубов (3 грани разной
  светлоты от акцента). Анимация: бегущая диагональная волна подсветки верхних
  граней. Не сливается за счёт разной яркости трёх граней.
- **Dot Matrix** — строгая сетка точек (шаг ~14–18px). Анимация: радиальная/
  линейная волна, временно повышающая яркость/радиус точек. Минималистично, не
  мешает тексту; контраст — точки чуть ярче скрима.

## Логика и поведение

### Модель данных (код, `sie_core`)

`cosmetic_asset.dart`:
```dart
enum AssetType { avatarFrame, profileBackground, statStyle, profilePattern }

extension AssetTypeX on AssetType {
  String get dbValue => switch (this) {
    ...
    AssetType.profilePattern => 'profile_pattern',
  };
}

// Геттеры узора из styleConfig:
String? get patternSlug => styleConfig['pattern_slug'] as String?;   // напр. 'low_poly'
Color   get patternColor => _hexColor(styleConfig['pattern_color']) ?? accentColor;
double  get patternOpacity => (styleConfig['opacity'] as num?)?.toDouble() ?? 0.40;
```

`profile.dart`: добавить `String? equippedPatternId` (+ парсинг из JSON
`equipped_pattern_id`).

`cosmetic_asset.dart` → `EquippedAssets`: добавить `CosmeticAsset? pattern` и
параметр `patternId` в `resolve(...)`.

`inventory_provider.dart`:
- `InventoryState` → `Set<String> ownedPatternIds` + ветка в `owns(asset)`.
- Новый провайдер `profilePatternsProvider` (читает таблицу `profile_patterns`,
  как `profileBackgroundsProvider`).
- `equipAsset` switch → `AssetType.profilePattern => 'equipped_pattern_id'`.
- `inventoryProvider` дополнить выборкой `profile_pattern` из `user_inventory`.

### Рендер — `ProfilePatternLayer`

**NEW** `packages/sie_core/lib/src/widgets/profile_pattern_layer.dart`:

```dart
class ProfilePatternLayer extends StatelessWidget {
  final CosmeticAsset? pattern;   // оснащённый узор (или null → ничего)
  final Color accent;             // база свечения
  // Диспетчер по pattern.patternSlug:
  //   'neural_threads' → NeuralNetworkWidget (существующий)
  //   'low_poly'/'iso_grid'/'dot_matrix' → _ShaderPattern(asset) или CustomPainter
}
```

- **Reduce-motion** (`SieMotion.enabled(context)`): при выключенной анимации —
  отрисовать **статичный кадр** узора (тикер не запускается), а не пустоту.
  Узор остаётся как декор, но не «дышит».
- **Один тикер на карточку.** Каждый узор-виджет владеет своим
  `AnimationController` (как `NeuralNetworkWidget`). Период 8–16с, `repeat()`.
- **Блендинг.** Слой узора рисуется поверх базы; контраст обеспечивается самой
  палитрой узора (узлы/блики ярче фона). При необходимости — `BlendMode.plus`
  для свечения на тёмной теме.
- **Производительность.** Узор клипуется радиусом карточки (`Clip.hardEdge` уже
  на контейнере hero). Тикеры приостанавливать вне видимости (карточка всегда
  вверху — некритично; для превью-сетки магазина см. ниже).

### Шейдеры

`apps/central_hub/assets/shaders/` + регистрация в `pubspec.yaml` (секция
`shaders:` строки 75–76 — добавить новые `.frag`):
```yaml
shaders:
  - assets/shaders/breathing_sphere.frag
  - assets/shaders/pattern_lowpoly.frag
  - assets/shaders/pattern_isogrid.frag
```
Конвенция uniform-ов как у `breathing_sphere.frag`:
`iTime` (0), `iResolution` (1,2), `isDark` (3), `iAccent` (vec3, 4–6),
`iOpacity` (7). Переиспользовать `hash/noise/fbm` хелперы.

> Решение шейдер vs CustomPainter: `neural_threads` и `dot_matrix` дешевле на
> `CustomPainter` (мало примитивов); `low_poly` и `iso_grid` выгоднее на шейдере
> (попиксельная заливка граней). Финальный выбор — по бенчмарку на бюджетном
> устройстве (открытый вопрос).

### Превью в сетке магазина/облика

Карточка узора в сетке (этап 5) показывает анимированный мини-превью. Чтобы не
плодить десятки тикеров, **анимировать только превью на экране**
(`VisibilityDetector`/ленивая инициализация) либо ограничить превью статичным
кадром + анимация только в полноэкранном preview-sheet.

### Миграция существующего `useNeuralPattern`

- Завести узор-ассет `neural_threads` в `profile_patterns`, выдать всем
  бесплатно (price_dp 0) либо как стартовый.
- В `ProfileHeroCard` слой узора берётся из `EquippedAssets.pattern`; если узор
  не оснащён, но у фона `useNeuralPattern == true` — фоллбэк на `neural_threads`
  (обратная совместимость со старыми фонами).

## Затрагиваемые модули

- **NEW** `packages/sie_core/lib/src/widgets/profile_pattern_layer.dart`.
- **NEW** `apps/central_hub/assets/shaders/pattern_lowpoly.frag`,
  `pattern_isogrid.frag` (+ возможно `pattern_dotmatrix.frag`).
- `apps/central_hub/pubspec.yaml` — регистрация шейдеров (75–76).
- `packages/sie_core/lib/src/models/cosmetic_asset.dart` — `profilePattern`,
  геттеры узора, `EquippedAssets.pattern`.
- `packages/sie_core/lib/src/models/profile.dart` — `equippedPatternId`.
- `packages/sie_core/lib/src/providers/inventory_provider.dart` —
  `profilePatternsProvider`, `ownedPatternIds`, `owns`, `equipAsset`, инвентарь.
- `packages/sie_core/lib/src/widgets/neural_network_painter.dart` — добавить
  импульсы/свечение (узор `neural_threads`).
- `packages/sie_core/lib/sie_core.dart` — экспорты.
- Интеграция в `ProfileHeroCard` (этап 1) и в превью магазина/облика (этап 5).

## Схема данных (Supabase)

Новая миграция `supabase/migrations/*_profile_patterns.sql`:

```sql
create table profile_patterns (
  id           uuid primary key default gen_random_uuid(),
  slug         text unique not null,         -- 'neural_threads' | 'low_poly' | ...
  name         text not null,
  image_url    text,
  rarity       text not null default 'common',
  style_config jsonb not null default '{}',  -- { pattern_slug, pattern_color, opacity }
  price_dp     integer not null default 0
);

alter table profiles add column equipped_pattern_id uuid references profile_patterns(id);
```

- RLS: чтение каталога — всем аутентифицированным (как `profile_backgrounds`).
- `user_inventory.asset_type` — допустить значение `'profile_pattern'`
  (проверить CHECK-констрейнт / RPC `purchase_asset` на валидацию типа).
- Публичная отдача профиля (`get_operative_stats` / `PublicProfile`) — добавить
  `equipped_pattern_id`, чтобы узор отображался на чужом профиле (этап 3).
- Сид-данные: 4 стартовых узора с ценами (**утверждено**):
  `iso_grid` — common, 0 DP (стартовый, выдаётся всем);
  `low_poly` — rare, 500 DP;
  `dot_matrix` — epic, 1000 DP;
  `neural_threads` — epic, 1500 DP.

## Открытые вопросы

1. Шейдер vs `CustomPainter` по каждому узору — финализировать после бенчмарка
   (особенно `low_poly`/`iso_grid` на слабых Android). _(техническое — решу сам
   в ходе реализации этапа)._
2. ~~Цены и редкость~~ — **решено** (см. блок выше: iso_grid 0 / low_poly 500 /
   dot_matrix 1000 / neural_threads 1500).
3. ~~Узор на дефолтном фоне~~ — **решено**: на любом фоне.
4. ~~Собственный цвет узора~~ — **решено**: наследует акцент фона.
5. Анимация превью в сетке: ленивая по видимости vs статичный кадр — выбрать по
   бюджету производительности списка. _(техническое — решу сам в этапе 5)._

### Открытый вопрос для пользователя
- **Применение миграции Supabase.** Когда дойду до БД-части (создание таблицы
  `profile_patterns`, колонка `equipped_pattern_id`, сид-данные): применить
  миграцию напрямую к проекту через Supabase CLI, или только подготовить
  `.sql`-файлы для ручного ревью и применения? (Спрошу отдельно перед этапом.)
