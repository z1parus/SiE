# Этап 2 — Вложения на узлах (изображения и файлы)

## Описание

Возможность **прикреплять изображения и файлы к узлам плана** — цели, под-цели, задаче, вехе.
В отличие от карта-нативных элементов (этапы 1, 3, 4), вложения **привязаны к сущности плана** и
поэтому **видны в обоих режимах** (бейдж 📎 на узле карты и строка вложений в карточке списка).

Назначение: референс-скрин к задаче («так должен выглядеть результат»), PDF-бриф к цели, фото
прогресса к вехе, чертёж к под-цели. Это превращает узлы из «голых заголовков» в небольшие
рабочие карточки.

## Пользовательский сценарий

1. В bottom-sheet узла (на карте: `_SubGoalSheet`/`_TaskSheet`/`_MilestoneSheet`/`_showGoalSheet`;
   в списке — в тайле) появляется секция **«Вложения»** с превью-лентой и кнопкой **«＋»**.
2. Тап «＋» → выбор источника (`image_picker`: камера/галерея; на будущее — файлы). Изображение
   грузится в Supabase Storage, появляется превью.
3. На узле карты — компактный **бейдж 📎N** (число вложений) в углу; тап по узлу открывает sheet с
   галереей. В списке — горизонтальная лента миниатюр.
4. Тап по миниатюре → полноэкранный просмотрщик (zoom/swipe). Можно удалить (если `canEdit`).
5. Офлайн: выбранный файл кладётся в локальную очередь загрузки; превью показывается из локального
   кэша до синхронизации.

## Логика и поведение

### Хранилище
- Новый бакет Supabase Storage **`goal-media`**. Путь: `{goalId}/{attachmentId}.{ext}`.
- Загрузка повторяет паттерн `uploadAvatar` (`user_profile_provider.dart:143`):
  `storage.from('goal-media').uploadBinary(path, bytes, FileOptions(upsert:true, contentType:...))`
  → `getPublicUrl(path)`.
- Отображение через `cached_network_image` (уже в зависимостях).

### Модель вложения
- Полиморфная привязка: `node_type` (`goal|subgoal|task|milestone`) + `node_id`. Это позволяет одной
  таблицей покрыть все типы узлов (как предложено в аудите данных).
- Метаданные: `file_url`, `file_name`, `mime_type`, `size_bytes`, `uploaded_by`.

### Привязка к модели
- Вместо поля в каждой сущности — общий `Map<String, List<NodeAttachment>>` на уровне `Goal`
  (ключ — `nodeId`), заполняется одним запросом при загрузке цели. Геттер
  `attachmentsFor(nodeId)` на `Goal`. Минимально инвазивно для существующих моделей.

### Offline-first
- Локальная таблица `LocalNodeAttachments` с `synced`/`deletedLocally`.
- Для офлайн-загрузки: сохранить выбранные байты во временный файл/локальный путь, поле
  `local_path`; sync-op `upload_attachment` догружает в Storage при появлении сети и проставляет
  `file_url`.

### Edge cases
- **Большие файлы** — клампить/сжимать изображения (`image_picker` `maxWidth/imageQuality`) перед
  загрузкой; лимит размера (напр. 10 МБ) с понятной ошибкой.
- **Удаление узла/цели** — удалять вложения каскадно в БД **и** объекты в Storage (cleanup-функция
  или Edge Function по событию; в MVP — best-effort удаление из приложения).
- **Viewer** — просмотр да, добавление/удаление нет (`canEdit`).
- **Карта-производительность** — бейдж 📎 рисуется как часть узла (не отдельный слой); миниатюры
  грузятся лениво только при открытии sheet.

## Затрагиваемые модули

| Файл | Действие |
|---|---|
| `packages/sie_core/lib/src/local/app_database.dart` | +таблица `LocalNodeAttachments`; `schemaVersion → 33`; миграция; helper-методы |
| `packages/sie_core/lib/src/models/node_attachment.dart` | **NEW** — модель + `fromMap`/`toMap` |
| `packages/sie_core/lib/src/models/planning.dart` | `Goal` +`Map<String,List<NodeAttachment>> attachments` + геттер `attachmentsFor(nodeId)` |
| `packages/sie_core/lib/src/providers/planning_provider.dart` | загрузка вложений; `addAttachment(nodeType,nodeId,bytes,name)`/`deleteAttachment`; интеграция со Storage |
| `packages/sie_core/lib/src/services/sync_service.dart` | +`case 'upload_attachment'`, `case 'delete_attachment'` |
| `packages/sie_core/lib/sie_core.dart` | export модели |
| `supabase/migrations/<ts>_node_attachments.sql` | **NEW** — таблица + RLS + бакет-политики `goal-media` |
| `apps/central_hub/lib/screens/tactical_map_view.dart` | бейдж 📎 на узлах; секция «Вложения» в sheets |
| `apps/central_hub/lib/screens/mission_detail_screen.dart` | лента вложений в тайлах списка |
| `apps/central_hub/lib/widgets/attachment_gallery.dart` | **NEW** — лента превью + полноэкранный просмотрщик (переиспользуется обоими режимами) |

## Схема данных

### Drift
```dart
@DataClassName('LocalNodeAttachment')
class LocalNodeAttachments extends Table {
  TextColumn get id          => text()();
  TextColumn get goalId      => text()();
  TextColumn get nodeType    => text()();    // goal|subgoal|task|milestone
  TextColumn get nodeId      => text()();
  TextColumn get fileUrl     => text().nullable()();   // null пока не загружено
  TextColumn get localPath   => text().nullable()();   // офлайн-кэш до загрузки
  TextColumn get fileName    => text()();
  TextColumn get mimeType    => text()();
  IntColumn  get sizeBytes   => integer().withDefault(const Constant(0))();
  TextColumn get uploadedBy  => text()();
  IntColumn  get createdAtMs => integer()();
  BoolColumn get synced         => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally => boolean().withDefault(const Constant(false))();
  @override Set<Column> get primaryKey => {id};
}
// schemaVersion => 33; INDEX idx_attach_node(node_id)
```

### Supabase
```sql
CREATE TABLE public.goal_node_attachments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id     uuid NOT NULL REFERENCES public.goals(id) ON DELETE CASCADE,
  node_type   text NOT NULL CHECK (node_type IN ('goal','subgoal','task','milestone')),
  node_id     uuid NOT NULL,
  file_url    text NOT NULL,
  file_name   text NOT NULL,
  mime_type   text NOT NULL,
  size_bytes  bigint NOT NULL DEFAULT 0,
  uploaded_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_attach_goal ON public.goal_node_attachments(goal_id);
CREATE INDEX idx_attach_node ON public.goal_node_attachments(node_id);
-- RLS: SELECT — владелец/принятый коллаборатор; INSERT/DELETE — владелец/editor.
-- Storage bucket 'goal-media': политики чтения для участников цели, записи для editor/owner.
```

## Открытые вопросы

1. **Публичный или приватный бакет.** Рекомендация: приватный + подписанные URL (`createSignedUrl`)
   для безопасности совместных целей; для MVP допустим публичный (проще, как `avatars`), но это
   утечка приватных изображений по прямой ссылке — лучше сразу приватный.
2. **Только изображения или любые файлы в MVP.** Рекомендация: MVP — изображения (`image_picker`),
   архитектуру (`mime_type`, `file_name`) заложить под любые файлы; добавить `file_picker` позже.
3. **Сжатие/превью.** Рекомендация: сжимать на клиенте (`imageQuality: 70`, `maxWidth: 1600`);
   отдельные thumbnail-объекты — позже (для MVP грузим оригинал, превью через `cached_network_image`).
4. **Очистка Storage при удалении.** Рекомендация: Edge Function по триггеру удаления строки —
   надёжнее, чем клиентский best-effort; вынести в под-задачу.
