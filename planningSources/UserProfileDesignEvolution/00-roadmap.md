# User Profile Design Evolution — Roadmap

> Эволюция дизайна экранов **личного** и **публичного** профилей пользователя
> SiE: превратить их в красивые, удобные и информативные экраны, опираясь на
> уже существующий язык дизайна приложения (золотой акцент `#C8A84B`,
> «цифровой разум», шейдеры, тёмная/светлая темы).

---

## Зачем

Сейчас профили технически рабочие, но визуально «плоские» и недостаточно
премиальные:

- **Верхняя карточка** одинаково сверстана в двух файлах с расхождениями
  (личный 68×68 аватар, публичный 88×88), дублируется код.
- **Фон карточки** — это либо сплошной цвет, либо линейный градиент; поверх
  накладывается единственный декоративный слой `NeuralNetworkWidget`, и только
  когда выбран кастомный фон. Нет отдельной сущности «узор».
- **XP-бар 6px**, **чипы 10px**, **сетка ачивок 6 колонок** в публичном
  профиле — мелко, плотно, низкий контраст (см. `UX-Audit/05-social-profile.md`).
- Магазин (Interface Hub) и «облик» (Customization) умеют покупать/применять
  рамки, фоны и стили статов, но **узоров как класса предметов нет**.

Цель — единый премиальный профильный «герой», читабельная информационная
архитектура и **новая система анимированных узоров**, накладываемых поверх
фона.

---

## Принципы

1. **Один компонент — два экрана.** Верхняя карточка профиля выносится в общий
   виджет `ProfileHeroCard` в `sie_core`; личный и публичный экраны передают в
   него данные и конфиг (свой / чужой).
2. **Слоистый фон.** Фон карточки = `база (цвет/градиент)` → `узор (анимация)` →
   `скрим для читабельности` → `контент`. Каждый слой опционален и берётся из
   оснащённых ассетов.
3. **Опора на токены.** Только `SieColors` / `SieMotion` / `SieHaptics`,
   никаких новых хардкод-цветов. Reduce-motion обязателен для всех анимаций.
4. **Экономика без изменений.** Узоры используют ту же модель `CosmeticAsset` +
   `purchase_asset` / `equipAsset`, просто новый `AssetType.profilePattern`.
5. **Производительность.** Анимированные узоры — на шейдерах (как
   `breathing_sphere.frag`) либо лёгком `CustomPainter` (как
   `NeuralNetworkPainter`), один тикер на карточку, пауза вне видимости.

---

## Этапы

| # | Документ | Суть | Зависимости |
|---|----------|------|-------------|
| 1 | [`01-profile-hero-card.md`](01-profile-hero-card.md) | Общий компонент `ProfileHeroCard` + слоистый фон, ранг-кольцо аватара, жирный XP-бар, читабельные чипы | — |
| 2 | [`02-personal-profile-screen.md`](02-personal-profile-screen.md) | Редизайн экрана личного профиля: ИА, быстрые действия, статы, ачивки, медали, скелетоны | Этап 1 |
| 3 | [`03-public-profile-screen.md`](03-public-profile-screen.md) | Редизайн публичного профиля: hero со скримом, кэш изображений, соц-кнопки с состояниями, плотность ачивок | Этап 1 |
| 4 | [`04-animated-patterns-system.md`](04-animated-patterns-system.md) | **Новая фича:** анимированные узоры поверх фона (Нейронные нити, Low-Poly, Изо-кубы, Dot Matrix). Модель данных, рендер, reduce-motion | Этап 1 |
| 5 | [`05-shop-and-customization.md`](05-shop-and-customization.md) | Таб «УЗОРЫ» в Interface Hub (покупка) и Customization (применение), live-preview композита фон+узор | Этапы 1, 4 |

Рекомендуемый порядок реализации: **1 → 4 → 5 → 2 → 3**
(сначала фундамент-карточка и узоры, затем магазин/облик, затем экраны целиком).

---

## Карта затрагиваемого кода (быстрая навигация)

| Что | Файл | Строки |
|---|---|---|
| Личный профиль | `apps/central_hub/lib/screens/profile_screen.dart` | весь (1043) |
| └ верхняя карточка | `profile_screen.dart` → `_HeaderGlassCard` | 262–442 |
| Публичный профиль | `apps/central_hub/lib/screens/public_profile_screen.dart` | весь (982) |
| └ hero-секция | `public_profile_screen.dart` → `_HeroSection` | 107–283 |
| Облик (применение) | `apps/central_hub/lib/screens/customization_screen.dart` | весь (956) |
| Магазин (покупка) | `apps/central_hub/lib/screens/interface_hub_screen.dart` | весь |
| Модель ассета | `packages/sie_core/lib/src/models/cosmetic_asset.dart` | 4–193 |
| Инвентарь / покупка / equip | `packages/sie_core/lib/src/providers/inventory_provider.dart` | 19–79 |
| Профиль (поля equipped_*) | `packages/sie_core/lib/src/models/profile.dart` | — |
| Существующий узор | `packages/sie_core/lib/src/widgets/neural_network_painter.dart` | 1–107 |
| Шейдер-прецедент | `apps/central_hub/assets/shaders/breathing_sphere.frag` + `operations_control_screen.dart:817–953` | — |
| Токены | `packages/sie_core/lib/src/theme/sie_colors.dart` | 8–152 |
| Reduce-motion | `packages/sie_core/lib/src/theme/sie_motion.dart` | 11–25 |
| Хаптика | `packages/sie_core/lib/src/theme/sie_haptics.dart` | — |

---

## Новые сущности (сводно)

**Код (sie_core):**
- `AssetType.profilePattern` (+ dbValue `profile_pattern`) — `cosmetic_asset.dart`.
- `CosmeticAsset.patternSlug` / `patternConfig` геттеры — `cosmetic_asset.dart`.
- `profilePatternsProvider` + `ownedPatternIds` в `InventoryState`,
  ветка в `equipAsset` — `inventory_provider.dart`.
- `Profile.equippedPatternId` — `profile.dart`.
- `ProfileHeroCard` (общий виджет) + `ProfilePatternLayer` (диспетчер узоров) —
  `packages/sie_core/lib/src/widgets/`.
- 1–2 новых шейдера (`assets/shaders/pattern_*.frag`) или `CustomPainter`-ы.

**Supabase:**
- Таблица `profile_patterns` (id, slug, name, image_url, rarity, style_config, price_dp).
- Колонка `profiles.equipped_pattern_id`.
- RLS + сид-данные 4 стартовых узоров.
- Поддержка `profile_pattern` в RPC `purchase_asset` (если тип валидируется).

---

## Открытые вопросы (общие)

1. **Скоуп узора в публичном профиле.** Узор чужого профиля рендерится у
   зрителя (нужны publicProvider'ы для `equipped_pattern_id`) — подтвердить, что
   публичный RPC отдаёт это поле.
2. **Экономика узоров.** Стартовые цены DP и редкость для 4 узоров — задать в
   сид-данных (предложение — в этапе 4).
3. **Шейдеры vs CustomPainter.** Для каких узоров оправдан GLSL, а для каких
   достаточно `CustomPainter` (детали и бенчмарк — в этапе 4).
4. Перенос hero-карточки в `sie_core` затрагивает приватные виджеты обоих
   экранов — делать ли разом или поэкранно (этап 1).
