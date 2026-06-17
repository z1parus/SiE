# Этап 1 — Холст карты: слой map-элементов + режим редактирования

## Описание

Архитектурный фундамент всего roadmap. Вводит **обобщённый слой «карта-нативных» элементов**
(`goal_map_elements`) — контента, который живёт только на тактической карте и не отображается в
списке, — и **режим редактирования карты** с плавающей палитрой инструментов.

В этом этапе пайплайн доводится до конца на **самом простом типе** контента: **заметки-стикеры и
свободные текстовые метки**. Это доказывает работоспособность всей цепочки (модель → Drift → Supabase
→ provider → sync-op → рендер-слой → drag → сохранение), после чего этапы 3 (изображения) и 4
(группы/связи) переиспользуют ту же таблицу, лишь меняя `kind`.

## Пользовательский сценарий

1. На тактической карте появляется кнопка-переключатель **«✎ Редактирование»** (только при
   `canEdit`). Нажатие включает режим: снизу выезжает **палитра инструментов** (`AnimatedSlide`):
   `Выбор` · `＋Заметка` · `T Метка` · (в будущем: Изображение, Группа, Связь) · `Готово`.
2. Пользователь выбирает `＋Заметка`, тапает по свободному месту холста → создаётся жёлтый стикер с
   плейсхолдером, открывается инлайн-ввод текста.
3. Стикер можно **перетаскивать** (как узлы), менять **цвет** (палитра из 6 акцентов) и **размер**
   (угловой хэндл), удалять. Текстовая метка — то же, но без фона (прозрачная подпись на холсте).
4. Заметки сохраняются офлайн и синхронизируются; при совместной работе их видят все участники
   (read-only для viewer).
5. В **списочном режиме заметок нет** — это инструмент мышления непосредственно на карте
   («здесь затык», «идея: спросить у Х», «зона риска»).

## Логика и поведение

### Модель `MapElement` (полиморфная)
- Дискриминатор `kind`: на этом этапе `note` | `label` (остальные — этапы 3–4).
- Позиция — в **логических координатах холста** (как у узлов: `Offset` относительно центра цели
  `(0,0)`; на экране `_cx + pos`). Хранится в самой записи (`x`,`y`), а **не** в `LocalMapPositions`
  (та — только для узлов плана; элементы самодостаточны и несут свою позицию).
- `z_index` — порядок наложения (заметки поверх узлов; группы/изображения — под, этапы 3–4).
- `content` — текст; `color_hex` — цвет; `w`/`h` — размер (для note); `style_json` — резерв на будущее.

### Рендер
- Новый слой **внутри** `ValueListenableBuilder<int>(_repaint)` в `tactical_map_view.dart`, **над**
  узлами (для `note`/`label`; группы/изображения позже встанут под узлами по `z_index`).
- Новый виджет `_NoteElement` (стикер) и `_LabelElement` (метка): `Positioned` по `_cx + pos`,
  стиль через `c.flatCard`/токены.
- Drag повторяет паттерн узлов: `onPanStart` → `setState(_draggingId=...)`; `onPanUpdate` →
  `_positions`-аналог для элементов мутируется **без setState** + `_bumpRepaint()`; `onPanEnd` →
  `_scheduleSaveElements()` (debounce 300мс, как `_scheduleSave`).
- Resize: угловой `GestureDetector` мутирует `w/h` с min-клампом, тот же debounce-сейв.

### Режим редактирования
- Состояние `_MapTool _tool` (enum: `none/select/note/label/...`) в `_TacticalMapViewState`.
- Палитра — оверлей **вне** `InteractiveViewer` (как зум-кнопки), `AnimatedSlide` снизу.
- Пока `_tool == note/label`: тап по холсту создаёт элемент в точке (через обратное преобразование
  экранных координат в логические по `_tc.value`), затем авто-возврат в `select`.
- При `_tool != none` pan/zoom холста ведёт себя как обычно; создание перехватывает только тап по
  пустому месту (`GestureDetector` фонового слоя).

### Edge cases
- **Пустой текст заметки** при потере фокуса → удалить элемент (не плодить пустышки).
- **Удаление цели** → `ON DELETE CASCADE` чистит `goal_map_elements`.
- **Viewer (read-only)** → палитра скрыта, drag/resize/правка выключены; заметки видны.
- **Производительность** — элементы рисуются в `_repaint`-слое; список элементов кэшируется,
  не пересобирается на каждый кадр drag.
- **Конфликт позиций при совместной правке** — last-write-wins по `updated_at` (как у позиций
  узлов); тонкая синхронизация в реальном времени — этап 8.

## Затрагиваемые модули

| Файл | Действие |
|---|---|
| `packages/sie_core/lib/src/local/app_database.dart` | +таблица `LocalMapElements`; `schemaVersion 31 → 32`; миграция `if (from < 32) createTable`; helper-методы `mapElementsForGoal`, `upsertMapElement`, `deleteMapElementLocally`, `unsyncedMapElements` |
| `packages/sie_core/lib/src/models/map_element.dart` | **NEW** — модель `MapElement` + enum `MapElementKind` + `fromMap`/`toMap`/`copyWith` |
| `packages/sie_core/lib/src/models/planning.dart` | `Goal` +поле `List<MapElement> mapElements` (default `[]`); прокинуть в `copyWith` |
| `packages/sie_core/lib/src/providers/planning_provider.dart` | загрузка `goal_map_elements` в `_load`/`_loadFromLocal`; методы `addMapElement`/`updateMapElement`/`deleteMapElement`/`saveMapElementPosition` (optimistic + local + online/queue) |
| `packages/sie_core/lib/src/services/sync_service.dart` | +`case 'upsert_map_element'`, `case 'delete_map_element'` |
| `packages/sie_core/lib/sie_core.dart` | export `map_element.dart` |
| `supabase/migrations/<ts>_goal_map_elements.sql` | **NEW** — таблица + RLS + индекс |
| `apps/central_hub/lib/screens/tactical_map_view.dart` | режим редактирования + палитра; слой/виджеты `_NoteElement`/`_LabelElement`; drag/resize/сейв; обратное преобразование тапа в логические координаты |

## Схема данных

### Drift (`app_database.dart`)
```dart
@DataClassName('LocalMapElement')
class LocalMapElements extends Table {
  TextColumn get id          => text()();
  TextColumn get goalId      => text()();
  TextColumn get kind        => text()();                       // note|label|image|group|connector
  RealColumn get x           => real()();
  RealColumn get y           => real()();
  RealColumn get w           => real().nullable()();
  RealColumn get h           => real().nullable()();
  IntColumn  get zIndex      => integer().withDefault(const Constant(0))();
  TextColumn get content     => text().nullable()();
  TextColumn get colorHex    => text().nullable()();
  TextColumn get mediaUrl    => text().nullable()();            // этап 3
  TextColumn get fromRef     => text().nullable()();            // этап 4 (connector)
  TextColumn get toRef       => text().nullable()();            // этап 4
  TextColumn get styleJson   => text().nullable()();            // резерв
  TextColumn get createdBy   => text()();
  IntColumn  get createdAtMs => integer()();
  IntColumn  get updatedAtMs => integer().nullable()();
  BoolColumn get synced         => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally => boolean().withDefault(const Constant(false))();
  @override Set<Column> get primaryKey => {id};
}
// schemaVersion => 32;  if (from < 32) await m.createTable(localMapElements);
// INDEX idx_map_elements_goal(goal_id)
```

### Supabase (`<ts>_goal_map_elements.sql`)
```sql
CREATE TABLE public.goal_map_elements (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id    uuid NOT NULL REFERENCES public.goals(id) ON DELETE CASCADE,
  kind       text NOT NULL CHECK (kind IN ('note','label','image','group','connector')),
  x          double precision NOT NULL,
  y          double precision NOT NULL,
  w          double precision,
  h          double precision,
  z_index    int NOT NULL DEFAULT 0,
  content    text,
  color_hex  text,
  media_url  text,
  from_ref   text,
  to_ref     text,
  style_json jsonb,
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_map_elements_goal ON public.goal_map_elements(goal_id);
ALTER TABLE public.goal_map_elements ENABLE ROW LEVEL SECURITY;

-- SELECT: владелец цели ИЛИ принятый коллаборатор (любой роли)
-- INSERT/UPDATE/DELETE: владелец ИЛИ коллаборатор-editor
-- (повторить паттерн политик из 20260612000002_goal_collaboration.sql для sub_goals)
```

`MapElement` (модель): `id, goalId, kind(enum), x, y, w?, h?, zIndex, content?, colorHex?, mediaUrl?,
fromRef?, toRef?, createdBy, createdAt, updatedAt?`.

## Открытые вопросы

1. **Отдельная таблица vs поле `Goal.mapElements`.** Рекомендация: отдельная таблица + поле-кэш в
   модели `Goal` (как `subGoals`), грузится тем же nested-select. Не складывать в `map_positions`
   (та — только координаты узлов плана).
2. **Inline-ввод текста на холсте vs bottom-sheet.** Рекомендация: лёгкий inline-`TextField` поверх
   стикера (быстро, «как в Miro»); сложное форматирование не нужно.
3. **Лимит элементов на цель** (защита от засорения/производительности)? Рекомендация: мягкий лимит
   ~200 элементов, как у позиций (>120 уже уводят сериализацию в `compute`).
4. **z-index UI** («на передний/задний план») — сразу или позже? Рекомендация: позже; на этапе 1
   фиксированный порядок по `kind` (note/label поверх узлов).
