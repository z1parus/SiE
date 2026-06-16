# Этап 1 — Profile Hero Card (общий «герой» профиля)

## Описание

Верхняя карточка профиля — самый заметный элемент обоих экранов и главный холст
для кастомизации (фон + узор + рамка аватара). Сейчас она сверстана **дважды**:

- личный: `profile_screen.dart` → `_HeaderGlassCard` (строки 262–442), аватар 68×68;
- публичный: `public_profile_screen.dart` → `_HeroSection` (107–283), аватар 88×88,
  свой `_AvatarWithFrame`, `_HeroChip`, `_StatStyleBanner`.

Логика фона дублируется (`_cardDecoration`, `showNeural`, адаптация текста на
белый при кастомном фоне). Цель этапа — **единый компонент `ProfileHeroCard`** в
`sie_core` со слоистым фоном и улучшенной визуальной иерархией; оба экрана
становятся его тонкими обёртками.

## Пользовательский сценарий

Пользователь открывает свой или чужой профиль. Сверху — крупная «карта
оперативника»: на фоне выбранной заливки/градиента мягко живёт анимированный
узор, поверх — затемняющий скрим, обеспечивающий читабельность. Аватар обрамлён
рамкой и **кольцом прогресса уровня** с подписью уровня в «значке-кокарде».
Рядом — позывной, ранг, чипы LEVEL и DP. Снизу — заметный XP-бар с подписями
«сколько до следующего уровня». Всё выглядит цельно и премиально, как единый
артефакт, а не набор полей.

## Логика и поведение

### Слоистая структура карточки (снизу вверх)

```
Container(clip: hardEdge, decoration: base)        // слой 0: база — цвет/градиент/flatCard
  └ Stack
      ├ ProfilePatternLayer(asset, accent)         // слой 1: узор (этап 4), опционально
      ├ _ReadabilityScrim(intensity)               // слой 2: скрим (только при custom bg/узоре)
      └ Padding → контент (аватар, тексты, XP-бар)  // слой 3: контент
```

- **База** — текущая логика `_cardDecoration` (цвет → градиент → `c.flatCard`),
  выносится в `ProfileHeroCard._baseDecoration`. Радиус 24 сохраняем.
- **Узор** — `ProfilePatternLayer` (см. этап 4). Если узор не оснащён, слой не
  строится. Существующий `NeuralNetworkWidget` поглощается этой системой как
  «узор по умолчанию» для обратной совместимости (`useNeuralPattern`).
- **Скрим** — `LinearGradient` сверху-вниз `transparent → black α≈0.28` (тёмная)
  / `transparent → black α≈0.12` (светлая) **только** когда есть кастомный фон
  или узор. Решает проблему читабельности текста и заменяет хрупкий приём
  «текст всегда белый». Текст: на кастомном фоне → `Colors.white`/`white70`, на
  дефолтном → `c.textPrimary`/`c.textSecondary` (логика как сейчас, но единая).

### Аватар + ранг-кольцо

- Размер аватара — параметр `avatarSize` (личный 72, публичный 96).
- Вокруг аватара — `CircularProgressIndicator`-подобное **кольцо прогресса
  уровня** (CustomPaint, толщина 3, градиент `accent → accentSecondary`),
  отражает `xpInLevel/1000`. На дефолтном фоне даёт «живость» даже без узора.
- Поверх кольца снизу — компактный **значок уровня** (`LVL N`), кокарда с
  заливкой `accent`, текст контрастный. Убирает необходимость дублировать
  уровень крупным чипом.
- Рамка (`frameDecoration` из `EquippedAssets.frame`) сохраняется как внешний
  слой; `Image.network` → **`CachedNetworkImage`** (пакет уже в проекте,
  используется в Interface Hub) с fallback на `_AvatarLetter`.

### Текстовый блок и чипы

- Позывной — `fontSize 18→20`, `w700`, `letterSpacing 1`.
- Под ним — строка **ранга** (`Recruit/Operative/Explorer/Commander`,
  логика `_rankLabel` переносится в компонент) как вторичный текст.
- Чипы LEVEL / DP: шрифт **10 → 12px** (UX-Audit 5.2 #2), высота ≥20, иконка DP
  `Icons.palette_outlined`. Чип LEVEL можно убрать (уровень уже в кокарде) и
  оставить только DP + «маленькие достижения» (стрик/друзья) — решается в
  этапах 2/3.

### XP-бар

- Высота **6 → 10px** (UX-Audit 5.2 #1, 0.7 #контраст), радиус скругления,
  трек `c.border`, заполнение — градиент `accent → accentSecondary`.
- Опциональная **анимация заполнения** при первом появлении
  (`TweenAnimationBuilder` 0→progress, `SieMotion.duration(context, slow)`),
  при reduce-motion — мгновенно.
- Подписи `$xp XP TOTAL` / `$xpToNext XP TO LVL N+1` — поднять минимальный
  кегль до 11px (UX-Audit 0.7).

### Параметризация компонента

```dart
ProfileHeroCard(
  username, avatarUrl, totalXp,          // данные
  frame, background, pattern,            // оснащённые ассеты (EquippedAssets)
  avatarSize: 72,                        // 72 личный / 96 публичный
  trailing: Widget?,                     // соц-кнопки (публичный) / null (личный)
  onAvatarTap: VoidCallback?,            // напр. редактирование аватара
)
```

Уровень/прогресс/ранг вычисляются внутри из `totalXp` (единый источник правды
вместо двух копий формулы `(xp ~/ 1000) + 1`).

## Затрагиваемые модули

- **NEW** `packages/sie_core/lib/src/widgets/profile_hero_card.dart` —
  `ProfileHeroCard`, `_LevelRingPainter`, `_LevelBadge`, `_ReadabilityScrim`.
- `packages/sie_core/lib/sie_core.dart` — экспорт.
- `apps/central_hub/lib/screens/profile_screen.dart` — удалить `_HeaderGlassCard`
  (262–442), `_Chip`, `_AvatarLetter`; вызвать `ProfileHeroCard(avatarSize: 72)`.
- `apps/central_hub/lib/screens/public_profile_screen.dart` — удалить `_HeroSection`
  внутренности (107–283), `_AvatarWithFrame`, `_HeroChip`; вызвать
  `ProfileHeroCard(avatarSize: 96, trailing: _FriendActionSection(...))`.
- Зависит от `ProfilePatternLayer` (этап 4) — до его готовности слой узора
  заглушается существующим `NeuralNetworkWidget`.

## Схема данных

Изменений БД нет. Используются существующие `Profile.totalXp`,
`designPoints`, `EquippedAssets` (frame/background/+pattern из этапа 4).

## Открытые вопросы

- Ранг-кольцо вокруг аватара vs отдельная круговая мини-диаграмма — кольцо
  компактнее, рекомендую кольцо.
- Высота карточки фиксированная или адаптивная при наличии `trailing`
  (соц-кнопки публичного профиля) — предлагаю `trailing` отдельной строкой под
  hero, не внутри.
- Полностью ли отказаться от «текст всегда белый» в пользу скрима, или оставить
  как фоллбэк для светлых кастомных фонов (тогда нужен расчёт яркости фона).
