# Этап 5 — Магазин (Interface Hub) и Облик (Customization): узоры

## Описание

Интеграция узоров (этап 4) в два существующих экрана:
- **Interface Hub** (`interface_hub_screen.dart`) — магазин: покупка ассетов за
  DP. Сейчас 3 таба: РАМКИ / ФОНЫ / СТИЛИ (`TabController(length: 3)`).
- **Customization** (`customization_screen.dart`) — «облик»: применение
  купленных ассетов с live-preview. Тоже 3 таба.

В оба добавляется **4-й таб «УЗОРЫ»**. Live-preview облика учится показывать
**композит фон + узор**. Заодно закрываются P1-замечания `UX-Audit §5.8`
(непонятный «cryo-freeze», отсутствие цены/условия на незакупленных, тихая
отмена выбора, превью без применённого фона).

## Пользовательский сценарий

**Магазин:** пользователь открывает Interface Hub, переходит на вкладку
«УЗОРЫ», видит сетку анимированных узоров с ценой в DP и редкостью, покупает
(хаптика + звук покупки + снэкбар), затем сразу может оснастить.

**Облик:** на вкладке «УЗОРЫ» пользователь выбирает узор из купленных; верхнее
live-preview мгновенно показывает его профиль с выбранным фоном **и** наложенным
анимированным узором. Есть пункт «Без узора» (снять). Жмёт «ПРИМЕНИТЬ».

## Логика и поведение

### Interface Hub (магазин)

- `TabController(length: 3 → 4)` (строка 24); `_buildTabBar` (168–183) — таб
  `Tab(text: 'УЗОРЫ')`; `TabBarView` (128) — 4-я панель `_ShopGrid` с
  `ref.watch(profilePatternsProvider)`.
- Покупка переиспользует существующий `_onBuy` (33–66): `purchaseAsset(asset)` →
  invalidate inventory/profile → `SieHaptics.success()` →
  `audioServiceProvider.playPurchase()` → снэкбар. Узор как `AssetType` уже
  поддержан в `purchase_asset` (этап 4).
- `_ShopCard` / `_CardContent` — добавить рендер превью узора (анимированный
  мини-`ProfilePatternLayer` поверх нейтрального фона-плашки). Ленивая анимация
  по видимости (этап 4, откр. вопрос 5).
- `_onEquip` (67+) уже generic (через `equipAsset`) — работает для узора без
  изменений (после ветки `profile_pattern` в `equipAsset`, этап 4).

### Customization (облик)

- `TabController` 3 → 4 таба: РАМКИ / ФОНЫ / СТИЛИ / **УЗОРЫ**.
- Локальный выбранный `selectedPatternId` (по аналогии с frame/background/style).
- `_AssetGrid` (565–615) + `_AssetCard` (619–837) — добавить ветку превью узора
  (`_PatternPreview`, рядом с `_FramePreview`/`_BackgroundPreview`/
  `_StatStylePreview`). Добавить плитку **«Без узора»** (none) для снятия.
- **Live `_Preview`** (299–479): сейчас показывает уменьшённый hero. Доработать,
  чтобы он рендерил `ProfileHeroCard`-композит c выбранными **фоном + узором**
  одновременно (UX-Audit 5.8 #4 — превью не показывало применённый фон).
- `applyCustomization()` (`customization_provider.dart` 36–48) — расширить
  сигнатуру 4-м id `patternId`, добавить апдейт `equipped_pattern_id` и проверку
  владения через `inventory.owns`.

### Закрытие P1 из UX-Audit §5.8 (общее для обоих экранов)

1. **«Cryo-freeze» незакупленных** (opacity 0.22, строка ~655) — заменить на
   явный **бейдж замка + цена в DP** прямо на карточке (UX-Audit 5.8 #1,#2).
2. **Тихая отмена выбора** при провале проверки владения (52–66) — показывать
   снэкбар «Сначала приобретите узор» + хаптика `warning` (UX-Audit 5.8 #3).
3. **Rarity-точка 6px → крупнее/с текстом** редкости (UX-Audit 5.8 #5).
4. Циан-grid `0xFF00C8FF` (строка 438) → `c.info` (UX-Audit 5.8 #6).
5. Кнопка **«Сбросить / снять всё»** (UX-Audit 5.8 #7) — в т.ч. снять узор.
6. Скелетоны сеток (`SieSkeleton`) вместо спиннеров.

### Хаптика и звук

- Выбор в сетке — `SieHaptics.selection()`.
- Покупка — `SieHaptics.success()` + `playPurchase()` (уже в `_onBuy`).
- Недостаточно DP / залочено — `SieHaptics.warning()` (уже в `_onBuy`).
- Применение облика — `SieHaptics.success()` + снэкбар «ОСНАЩЕНИЕ ПРИМЕНЕНО».

## Затрагиваемые модули

- `apps/central_hub/lib/screens/interface_hub_screen.dart`:
  - `TabController` (24), `_buildTabBar` (168–183), `TabBarView` (128) — +таб.
  - `_ShopCard`/`_CardContent` (345–684) — превью узора.
- `apps/central_hub/lib/screens/customization_screen.dart`:
  - `TabController` (+таб), `_AssetGrid` (565–615), `_AssetCard` (619–837) —
    `_PatternPreview` + плитка «Без узора», бейдж замка+цена.
  - `_Preview` (299–479) — композит фон+узор.
  - `applyCustomization` integration.
- `apps/central_hub/lib/.../customization_provider.dart` (36–48) — +`patternId`.
- `packages/sie_core/...` — `profilePatternsProvider`, `ProfilePatternLayer`,
  `SieSkeleton`, токен `c.info` (этап 4).

## Схема данных

Использует таблицу `profile_patterns`, колонку `equipped_pattern_id` и
`user_inventory.asset_type='profile_pattern'` из этапа 4. Новых сущностей нет.

## Открытые вопросы

- Анимировать ли каждое превью в сетке (дорого) или только полноэкранный
  preview-sheet + статичный кадр в сетке (этап 4, откр. вопрос 5).
- Нужна ли узору отдельная цветовая настройка в облике (выбор оттенка узора)
  или цвет всегда наследуется от фона/акцента (этап 4, откр. вопрос 4).
- «Без узора» как отдельная плитка в сетке vs кнопка «снять» в шапке таба.
