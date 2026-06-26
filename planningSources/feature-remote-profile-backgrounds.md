# Расширяемые фоны профиля — удалённый каталог + мини-админка

## Описание

Добавить поддержку статичных картинок и анимированных фонов (анимированный WebP,
Lottie) для карточек профиля. Новые фоны добавляются разработчиком через
мини-админку внутри приложения без обновления: файл заливается в Supabase
Storage, строка вставляется в таблицу `profile_backgrounds` — и фон сразу
появляется у всех пользователей в магазине.

---

## Пользовательский сценарий

**Пользователь (магазин):**
1. Открывает «Облик» → вкладка «Фоны».
2. Видит новые фоны-картинки/анимации рядом с существующими градиентами.
3. Покупает за DP, надевает — карточка профиля немедленно меняется.
4. Публичный профиль другого игрока тоже показывает новый фон.

**Разработчик (мини-админка):**
1. Открывает скрытый экран «Dev Studio» (кнопка на экране настроек, видна
   только при `profiles.is_admin = true`).
2. Выбирает файл (изображение или `.json` для Lottie).
3. Заполняет форму: название, slug, редкость, цена DP, тип, опциональный
   тинт-оверлей.
4. Нажимает «Опубликовать» — файл заливается в Storage, строка вставляется
   в `profile_backgrounds`. Новый фон сразу в магазине у всех.

---

## Логика и поведение

### Типы фонов (`kind`)

| kind | Формат | Рендер |
|------|--------|--------|
| `gradient` | только `style_config` | `LinearGradient` (уже есть) |
| `image` | JPG/PNG/WebP в Storage | `CachedNetworkImage`, BoxFit.cover |
| `animated_webp` | анимированный WebP в Storage | `Image.network`, автовоспроизведение |
| `lottie` | Lottie JSON в Storage | `Lottie.network()`, loop |

Шейдеры — не поддерживаем: Flutter компилирует `.frag` при сборке,
runtime-загрузка произвольного шейдера невозможна.

### `thumbnail_url`

Для анимированных фонов в сетке магазина показывается статичная превьюшка
(JPG/PNG), а не сама анимация — иначе 20 Lottie одновременно убьют CPU.
Правило: если `thumbnail_url != null` — в сетке используем его;
полный рендер (анимация) — только в активном профиле и в «живом» превью
на экране кастомизации.

### Безопасность: `is_admin`

- Новое boolean-поле `profiles.is_admin DEFAULT false`.
- RLS на `profile_backgrounds` (INSERT/UPDATE/DELETE) — только если запись
  пользователя в `profiles` имеет `is_admin = true`.
- Запись в Storage-бакет `profile-backgrounds` — аналогично.
- В приложении кнопка в Dev Studio прячется за проверкой флага.
- Обычные пользователи не имеют технической возможности добавлять фоны.

### `is_published` и `sort_order`

- `is_published = false` → фон не возвращается запросом каталога (скрытый
  черновик), но строка существует — можно редактировать.
- `sort_order int DEFAULT 0` — порядок отображения в сетке (меньше = выше).

---

## Затрагиваемые модули

| Файл | Действие |
|------|----------|
| `supabase/migrations/20260628000001_background_media.sql` | NEW — все изменения схемы |
| `packages/sie_core/lib/src/models/cosmetic_asset.dart` | Добавить `kind`, `thumbnailUrl`; обновить `fromJson` и `hasCustomBg` |
| `packages/sie_core/lib/src/widgets/profile_hero_card.dart` | Обновить `_baseDecoration` + `build()` для image/animated_webp/lottie |
| `packages/sie_core/lib/src/widgets/profile_background_view.dart` | NEW — общий виджет-рендерер фона |
| `packages/sie_core/lib/src/providers/customization_provider.dart` | Добавить фильтр `is_published = true` и сортировку по `sort_order` |
| `packages/sie_core/lib/sie_core.dart` | Экспортировать новый виджет |
| `apps/central_hub/lib/screens/customization_screen.dart` | `_AssetVisual` / `_BackgroundPreview` — показывать `thumbnail_url` если есть |
| `apps/central_hub/lib/screens/dev_studio_screen.dart` | NEW — мини-админка |
| `apps/central_hub/lib/screens/settings_screen.dart` | Добавить вход в Dev Studio при `is_admin = true` |
| `apps/central_hub/pubspec.yaml` | Добавить зависимость `lottie` |

---

## Схема данных

### Миграция `20260628000001_background_media.sql`

```sql
-- ── Расширение таблицы ────────────────────────────────────────────────────────

ALTER TABLE public.profile_backgrounds
  ADD COLUMN IF NOT EXISTS kind          text NOT NULL DEFAULT 'gradient'
    CHECK (kind IN ('gradient','image','animated_webp','lottie')),
  ADD COLUMN IF NOT EXISTS thumbnail_url text,
  ADD COLUMN IF NOT EXISTS is_published  boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS sort_order    int NOT NULL DEFAULT 0;

-- Обновить существующие 4 фона-градиента — их kind уже 'gradient' (DEFAULT).
-- Ничего делать не надо.

-- ── is_admin на profiles ──────────────────────────────────────────────────────

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_admin boolean NOT NULL DEFAULT false;

-- ── RLS: только admin может писать в каталог ──────────────────────────────────

-- Хелпер (SECURITY DEFINER, чтобы не вызывать рекурсию через profiles RLS)
CREATE OR REPLACE FUNCTION public.is_admin()
  RETURNS boolean
  LANGUAGE sql SECURITY DEFINER STABLE
  SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM public.profiles WHERE id = auth.uid()),
    false
  );
$$;
REVOKE ALL ON FUNCTION public.is_admin() FROM public;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

DROP POLICY IF EXISTS "admin insert profile_backgrounds" ON public.profile_backgrounds;
DROP POLICY IF EXISTS "admin update profile_backgrounds" ON public.profile_backgrounds;
DROP POLICY IF EXISTS "admin delete profile_backgrounds" ON public.profile_backgrounds;

CREATE POLICY "admin insert profile_backgrounds"
  ON public.profile_backgrounds FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

CREATE POLICY "admin update profile_backgrounds"
  ON public.profile_backgrounds FOR UPDATE
  TO authenticated
  USING (public.is_admin());

CREATE POLICY "admin delete profile_backgrounds"
  ON public.profile_backgrounds FOR DELETE
  TO authenticated
  USING (public.is_admin());

-- ── Storage bucket profile-backgrounds ───────────────────────────────────────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profile-backgrounds',
  'profile-backgrounds',
  true,
  15728640,   -- 15 MB (Lottie JSON + WebP могут быть крупнее JPG)
  ARRAY[
    'image/jpeg','image/png','image/webp','image/gif',
    'application/json'   -- Lottie
  ]
)
ON CONFLICT (id) DO NOTHING;

-- Публичное чтение
DO $$ BEGIN
  CREATE POLICY "profile-backgrounds: public read"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'profile-backgrounds');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Запись только admin
DO $$ BEGIN
  CREATE POLICY "profile-backgrounds: admin upload"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'profile-backgrounds' AND public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "profile-backgrounds: admin delete"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'profile-backgrounds' AND public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
```

---

## Детали реализации по файлам

### 1. `cosmetic_asset.dart`

Добавить:
```dart
enum BackgroundKind { gradient, image, animatedWebp, lottie }

class CosmeticAsset {
  // ... существующие поля ...
  final BackgroundKind backgroundKind;   // только для profileBackground
  final String? thumbnailUrl;

  // fromJson:
  backgroundKind: _parseKind(json['kind'] as String?),
  thumbnailUrl: json['thumbnail_url'] as String?,

  static BackgroundKind _parseKind(String? s) => switch (s) {
    'image'         => BackgroundKind.image,
    'animated_webp' => BackgroundKind.animatedWebp,
    'lottie'        => BackgroundKind.lottie,
    _               => BackgroundKind.gradient,
  };
}
```

Обновить существующий `hasCustomBg` getter в `ProfileHeroCard` — включить
image/animated_webp/lottie как «кастомный» фон (сейчас смотрит только на
`backgroundColor` и `backgroundGradient`).

### 2. `profile_background_view.dart` (NEW)

Общий виджет, принимающий `CosmeticAsset? background` и рисующий правильный
контент в зависимости от `backgroundKind`. Используется внутри
`ProfileHeroCard` и на экране кастомизации.

```dart
class ProfileBackgroundView extends StatelessWidget {
  final CosmeticAsset? background;
  final bool thumbnail;  // true → показывать thumbnail_url вместо анимации
  final Widget child;

  // build(): switch по backgroundKind:
  // gradient       → существующий BoxDecoration (gradient / solid color)
  // image          → CachedNetworkImage(image_url, fit: cover)
  // animated_webp  → thumbnail=true ? CachedNetworkImage(thumbnail_url)
  //                                  : Image.network(image_url)
  // lottie         → thumbnail=true ? CachedNetworkImage(thumbnail_url)
  //                                  : Lottie.network(image_url, repeat: true)
  // Поверх всегда: читаемый scrim (LinearGradient 0.0→0.0→0.2 alpha)
}
```

Ключевые детали:
- `ClipRRect` с `borderRadius: 24` (как у hero-card контейнера).
- Для Lottie: `fit: BoxFit.cover`, цикл включён, нет взаимодействия.
- Fallback при ошибке загрузки → `c.flatCard(radius: 24)` как сейчас.
- Виджет экспортируется через `sie_core.dart`.

### 3. `profile_hero_card.dart`

Заменить `_baseDecoration()` + встраивание картинки/Lottie внутрь `build()`.
Сейчас `Stack` начинается с `Container(decoration: _baseDecoration(...))`.
Нужно:
- Обернуть весь Stack в `ProfileBackgroundView(background: background, thumbnail: false, child: ...)`.
- Убрать `_baseDecoration()` (логика переехала в `ProfileBackgroundView`).
- Обновить условие `hasCustomBg` (теперь `background != null` в принципе,
  при любом kind кроме `gradient` без настроек).

### 4. `customization_provider.dart`

```dart
final profileBackgroundsProvider = FutureProvider<List<CosmeticAsset>>((ref) async {
  final data = await SupabaseService.client
      .from('profile_backgrounds')
      .select()
      .eq('is_published', true)     // ← скрытые черновики не показываем
      .order('sort_order')           // ← по явному порядку
      .order('rarity');
  ...
});
```

### 5. `customization_screen.dart` — `_AssetVisual`

В `_BackgroundPreview` (показывает фон в сетке):
```dart
// Если есть thumbnail_url — всегда используем его в сетке (безопасно для CPU)
if (asset.thumbnailUrl != null) {
  return CachedNetworkImage(imageUrl: asset.thumbnailUrl!, fit: BoxFit.cover, ...);
}
// Если есть image_url и тип image — можно показать саму картинку
if (asset.imageUrl != null && asset.backgroundKind == BackgroundKind.image) {
  return CachedNetworkImage(imageUrl: asset.imageUrl!, ...);
}
// Иначе — существующий градиентный fallback
```

### 6. `pubspec.yaml`

```yaml
lottie: ^3.1.2
```

### 7. `dev_studio_screen.dart` (NEW)

`ConsumerStatefulWidget`. Экран только для `is_admin = true`.

**Поля формы:**
- `name` (TextField)
- `slug` (TextField, auto-генерируется из name но редактируем)
- `kind` (DropdownButtonFormField: Gradient / Image / Animated WebP / Lottie)
- `rarity` (DropdownButtonFormField: common/rare/epic/legendary)
- `price_dp` (TextField, int)
- `sort_order` (TextField, int, default 0)
- `is_published` (Switch, default true)
- `style_config` (TextField JSON, только для `gradient` — показывается при kind=gradient)
- Кнопка «Выбрать файл» (FilePicker для image/webp/lottie; скрыта при gradient)
- Кнопка «Выбрать превью» (FilePicker, только для animated_webp/lottie)

**Логика сохранения (`_publish()`):**
```
1. Validate форму
2. Если kind != gradient:
     a. Upload main file → Storage 'profile-backgrounds/{kind}/{slug}.{ext}'
     b. Если выбрано превью → Upload thumbnail → 'profile-backgrounds/thumbs/{slug}.jpg'
3. INSERT INTO profile_backgrounds({all fields})
4. Invalidate profileBackgroundsProvider
5. pop + SnackBar «Фон опубликован»
```

**Список существующих фонов** (в нижней части экрана):
- `StreamBuilder` / `FutureBuilder` из `profileBackgroundsProvider`
- Каждая строка: превью + name + kind + rarity + price_dp + кнопки
  [Скрыть/Показать] (toggle `is_published`) и [Удалить] (DELETE + Storage)

### 8. `settings_screen.dart`

Найти секцию с настройками и добавить скрытую кнопку:
```dart
// Показывать только admin-пользователям
if (isAdmin)
  ListTile(
    leading: const Icon(Icons.developer_mode),
    title: const Text('Dev Studio'),
    onTap: () => Navigator.push(context, MaterialPageRoute(
      builder: (_) => const DevStudioScreen(),
    )),
  ),
```

`isAdmin` читается из `userProfileProvider` → поле `profile.isAdmin`
(нужно добавить в `PublicProfile` / `UserProfile` модели).

---

## Порядок реализации

1. **Миграция SQL** → применить `supabase db push`
2. **`cosmetic_asset.dart`** — поля `kind`, `thumbnailUrl`, enum `BackgroundKind`
3. **`profile_background_view.dart`** — новый виджет (gradle + image + webp + lottie)
4. **`profile_hero_card.dart`** — заменить `_baseDecoration` на виджет
5. **`customization_provider.dart`** — фильтр `is_published` + `sort_order`
6. **`customization_screen.dart`** — превью в сетке через thumbnail
7. **`pubspec.yaml`** — добавить `lottie`
8. **Модели профиля** — добавить `isAdmin` в `UserProfile` / `PublicProfile`
9. **`dev_studio_screen.dart`** — мини-админка
10. **`settings_screen.dart`** — точка входа в Dev Studio

---

## Открытые вопросы

- **Имя поля `is_admin` в `UserProfile`**: сейчас не ясно, какие поля
  тянет `userProfileProvider`. Нужно проверить и добавить аккуратно.
- **Lottie + фон в сетке**: если `thumbnail_url` не выставлен для Lottie-фона,
  сетка покажет пустое место. Валидировать это в форме мини-админки обязательно.
- **Размер Lottie-файлов**: некоторые Lottie весят несколько МБ. Может потребоваться
  pre-download / прогрессивная загрузка. Начнём с `Lottie.network()` и посмотрим на практике.
- **Удаление фона**: при DELETE строки из `profile_backgrounds` — что происходит с
  `profiles.equipped_background_id`? Стоит DELETE policy сделать осторожной (сначала
  `UPDATE profiles SET equipped_background_id = NULL WHERE ...`).
