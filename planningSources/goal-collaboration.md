# Совместная работа над целью (Goal Collaboration)

## Описание

Система совместной работы позволяет владельцу цели приглашать подтверждённых друзей к совместной работе над целью. Приглашённые получают уведомление через существующую систему, принимают или отклоняют приглашение, после чего цель появляется в их списке целей с явной меткой «чужая / совместная». Владелец управляет составом участников и их правами (просмотр / редактирование) прямо из настроек цели.

---

## Пользовательский сценарий

1. Владелец открывает настройки цели (шестерёнка в `MissionDetailScreen`) → видит новый раздел **«СОВМЕСТНАЯ РАБОТА»**.
2. Нажимает «Пригласить друга» → открывается список подтверждённых друзей (без уже приглашённых).
3. Выбирает друга, выбирает права (Просмотр / Редактирование) → запрос отправлен.
4. Приглашённый видит красный бейдж на колоколе Operations, открывает лист уведомлений → строка с текстом «X приглашает вас к работе над "ИМЯ ЦЕЛИ"» и кнопками **Принять / Отклонить** прямо в листе.
5. После принятия цель появляется в `PlanningScreen` приглашённого с бейджем «СОВМЕСТНАЯ» и именем владельца под названием.
6. Владелец получает уведомление «X принял ваше приглашение».
7. Редактор видит цель в полном объёме и может создавать/изменять подцели и задачи. Читатель видит цель, но не может вносить изменения (все кнопки редактирования скрыты/заблокированы).
8. Владелец в настройках цели может менять права участника (DropdownButton «Просмотр» ↔ «Редактирование») или удалить его.

---

## Логика и поведение

### Определение прав в `MissionDetailScreen`

Вычисляется одна переменная `_canEdit`:
```
bool canEdit = goal.userId == currentUserId                          // владелец
            || goal.collaborators.any(c =>
                 c.userId == currentUserId && c.role == 'editor')   // редактор
```

При `canEdit = false`:
- Скрываются все FAB и кнопки добавления подцелей/задач/этапов
- Скрывается кнопка настроек (шестерёнка)
- Все тайлы подцелей/задач не реагируют на долгое нажатие (drag disabled)
- Задачи можно только просматривать

### Раздел «СОВМЕСТНАЯ РАБОТА» в `_GoalSettingsSheet`

Показывается **только** если `goal.userId == currentUserId`.

Структура блока:
```
─── СОВМЕСТНАЯ РАБОТА ───────────────────────────
[Avatar] USERNAME                [Просмотр ▼] [✕]
[Avatar] USERNAME2               [Редакт. ▼]  [✕]
[+ Пригласить друга]
─────────────────────────────────────────────────
```

- Каждая строка: аватар 36×36 + username + `DropdownButton` с вариантами «Просмотр» / «Редактирование» + кнопка удаления
- Смена роли → обновляет `goal_collaborators.role` на сервере немедленно
- Удаление → диалог подтверждения → DELETE из `goal_collaborators`
- Кнопка «Пригласить друга» → открывает `_CollaboratorPickerSheet`

### `_CollaboratorPickerSheet`

Список `FriendRow` из `friendsProvider.friends`, отфильтрованных: убираем тех, кто уже в `goal.collaborators`. Каждая строка: аватар + username. Нажатие → открывается выбор прав (два чипа «Просмотр» / «Редактирование») + кнопка «Пригласить».

### Лист уведомлений — новые типы

Тип `goal_collaboration_invite` → специальная строка:
```
[Avatar] X приглашает вас к совместной работе над "ИМЯ ЦЕЛИ"
[ПРИНЯТЬ]  [ОТКЛОНИТЬ]
```

После принятия/отклонения кнопки исчезают (уведомление помечается прочитанным + обновляется статус в `goal_collaborators`).

Тип `goal_collaboration_accepted` → обычная строка без кнопок:
«X принял ваше приглашение к работе над "ИМЯ ЦЕЛИ"»

### `_GoalCard` в `PlanningScreen` для shared-целей

Когда `goal.userId != currentUserId`:
- Маленький бейдж «СОВМЕСТНАЯ» цветом `c.accent.withValues(alpha: 0.7)`
- Под названием цели серым: «Владелец: USERNAME»
- Иконка `Icons.people_outlined` (16px) рядом с именем

---

## Затрагиваемые модули

### Новые файлы

| Путь | Описание |
|------|----------|
| `supabase/migrations/20260612000002_goal_collaboration.sql` | goal_collaborators, RLS, триггеры уведомлений |
| `packages/sie_core/lib/src/models/goal_collaborator.dart` | `GoalCollaborator` модель |
| `packages/sie_core/lib/src/providers/goal_collaboration_provider.dart` | `GoalCollaborationNotifier` |

### Изменяемые файлы

| Путь | Что меняется |
|------|-------------|
| `packages/sie_core/lib/src/models/planning.dart` | `Goal` — добавить `collaborators: List<GoalCollaborator>` |
| `packages/sie_core/lib/src/local/app_database.dart` | Новая колонка `isShared` + `myRole` в `LocalGoals` (для показа shared-целей offline как read-only) |
| `packages/sie_core/lib/src/providers/planning_provider.dart` | Загрузка shared-целей + мёрж + `_mirrorToLocal` для shared |
| `packages/sie_core/lib/src/providers/notifications_provider.dart` | Методы `acceptCollaborationInvite(goalId)` / `declineCollaborationInvite(goalId)` |
| `packages/sie_core/lib/sie_core.dart` | Экспорт новых моделей/провайдеров |
| `apps/central_hub/lib/screens/mission_detail_screen.dart` | Раздел СОВМЕСТНАЯ РАБОТА в `_GoalSettingsSheet` + `_canEdit` логика |
| `apps/central_hub/lib/screens/planning_screen.dart` | Бейдж «СОВМЕСТНАЯ» на `_GoalCard` |
| `apps/central_hub/lib/screens/operations_control_screen.dart` | Inline Accept/Decline в `_NotifTile` для нового типа |

---

## Схема данных

### Supabase: таблица `goal_collaborators`

```sql
CREATE TABLE public.goal_collaborators (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id     UUID NOT NULL REFERENCES public.goals(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  invited_by  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role        TEXT NOT NULL DEFAULT 'viewer' CHECK (role IN ('viewer', 'editor')),
  status      TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(goal_id, user_id)
);
```

### Обновлённые RLS для `goals`

```sql
-- Читать могут: владелец ИЛИ принятый коллаборатор
DROP POLICY "own goals" ON public.goals;

CREATE POLICY "goals_select" ON public.goals FOR SELECT
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM public.goal_collaborators gc
      WHERE gc.goal_id = goals.id
        AND gc.user_id = auth.uid()
        AND gc.status = 'accepted'
    )
  );

-- INSERT / UPDATE / DELETE — только владелец (без изменений логики)
CREATE POLICY "goals_owner_write" ON public.goals FOR ALL
  USING (auth.uid() = user_id);
```

Аналогичное расширение для `sub_goals`, `planning_tasks`, `milestones`, `goal_habit_links`:
- SELECT: владелец ИЛИ принятый коллаборатор
- INSERT/UPDATE/DELETE: владелец ИЛИ **редактор** (role = 'editor')

```sql
-- Пример для sub_goals:
CREATE POLICY "sub_goals_select" ON public.sub_goals FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.goals g
      WHERE g.id = sub_goals.goal_id
        AND (g.user_id = auth.uid() OR EXISTS (
          SELECT 1 FROM public.goal_collaborators gc
          WHERE gc.goal_id = g.id AND gc.user_id = auth.uid() AND gc.status = 'accepted'
        )))
  );

CREATE POLICY "sub_goals_editor_write" ON public.sub_goals
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.goals g
      LEFT JOIN public.goal_collaborators gc ON gc.goal_id = g.id AND gc.user_id = auth.uid()
      WHERE g.id = sub_goals.goal_id
        AND (g.user_id = auth.uid() OR (gc.role = 'editor' AND gc.status = 'accepted'))
    )
  );
-- Аналогично UPDATE / DELETE
```

### RLS для `goal_collaborators`

```sql
ALTER TABLE public.goal_collaborators ENABLE ROW LEVEL SECURITY;

-- Читать: владелец цели ИЛИ сам приглашённый
CREATE POLICY "gc_select" ON public.goal_collaborators FOR SELECT
  USING (
    auth.uid() = user_id OR
    auth.uid() = invited_by OR
    EXISTS (SELECT 1 FROM public.goals g WHERE g.id = goal_id AND g.user_id = auth.uid())
  );

-- Вставлять: только владелец цели
CREATE POLICY "gc_insert" ON public.goal_collaborators FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.goals g WHERE g.id = goal_id AND g.user_id = auth.uid())
    AND auth.uid() = invited_by
  );

-- Обновлять: владелец цели (меняет роль) ИЛИ приглашённый (меняет статус)
CREATE POLICY "gc_update" ON public.goal_collaborators FOR UPDATE
  USING (
    auth.uid() = user_id OR
    EXISTS (SELECT 1 FROM public.goals g WHERE g.id = goal_id AND g.user_id = auth.uid())
  );

-- Удалять: владелец цели ИЛИ сам участник
CREATE POLICY "gc_delete" ON public.goal_collaborators FOR DELETE
  USING (
    auth.uid() = user_id OR
    EXISTS (SELECT 1 FROM public.goals g WHERE g.id = goal_id AND g.user_id = auth.uid())
  );
```

### Триггерная функция уведомлений

```sql
CREATE OR REPLACE FUNCTION public.create_collaboration_notifications()
  RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_goal_name TEXT;
BEGIN
  SELECT name INTO v_goal_name FROM public.goals WHERE id = NEW.goal_id;

  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    -- Уведомить приглашённого
    INSERT INTO public.notifications (user_id, type, from_user_id, payload)
    VALUES (
      NEW.user_id,
      'goal_collaboration_invite',
      NEW.invited_by,
      jsonb_build_object('goal_id', NEW.goal_id, 'goal_name', v_goal_name)
    );

  ELSIF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    -- Уведомить владельца об принятии
    INSERT INTO public.notifications (user_id, type, from_user_id, payload)
    VALUES (
      NEW.invited_by,
      'goal_collaboration_accepted',
      NEW.user_id,
      jsonb_build_object('goal_id', NEW.goal_id, 'goal_name', v_goal_name)
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER collaboration_notifications
  AFTER INSERT OR UPDATE ON public.goal_collaborators
  FOR EACH ROW EXECUTE FUNCTION public.create_collaboration_notifications();
```

### Dart-модель `GoalCollaborator`

```dart
// goal_collaborator.dart
class GoalCollaborator {
  final String id;
  final String goalId;
  final String userId;
  final String invitedBy;
  final String role;   // 'viewer' | 'editor'
  final String status; // 'pending' | 'accepted' | 'declined'
  final PublicProfile? profile; // подгружается отдельно
  final DateTime createdAt;

  const GoalCollaborator({...});

  factory GoalCollaborator.fromJson(Map<String, dynamic> j) => GoalCollaborator(
    id: j['id'] as String,
    goalId: j['goal_id'] as String,
    userId: j['user_id'] as String,
    invitedBy: j['invited_by'] as String,
    role: j['role'] as String,
    status: j['status'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  GoalCollaborator copyWith({String? role, String? status, PublicProfile? profile}) =>
    GoalCollaborator(
      id: id, goalId: goalId, userId: userId, invitedBy: invitedBy,
      role: role ?? this.role,
      status: status ?? this.status,
      profile: profile ?? this.profile,
      createdAt: createdAt,
    );
}
```

### Изменения в `Goal`

```dart
// В planning.dart — добавить поле:
final List<GoalCollaborator> collaborators; // default: const []

// В fromJson:
collaborators: (j['goal_collaborators'] as List? ?? [])
    .map((c) => GoalCollaborator.fromJson(c as Map<String, dynamic>))
    .toList(),

// В Supabase SELECT запросе добавить:
'*, sub_goals(...), milestones(*), goal_habit_links(*), goal_collaborators(*)'
```

### `GoalCollaborationNotifier`

```dart
final goalCollaborationProvider = Provider<GoalCollaborationNotifier>(...);

class GoalCollaborationNotifier {
  // Пригласить друга
  Future<void> invite(String goalId, String userId, String role);
  // Удалить участника
  Future<void> remove(String goalId, String userId);
  // Изменить роль
  Future<void> updateRole(String goalId, String userId, String newRole);
  // Принять приглашение (вызывается из уведомления)
  Future<void> accept(String goalId);
  // Отклонить приглашение
  Future<void> decline(String goalId);
}
```

После любого действия — `ref.invalidate(planningProvider)` для перезагрузки списка целей.

### Изменения в `planning_provider.dart`

```dart
// Запрос — расширить SELECT:
.from('goals')
.select('*, sub_goals(*, planning_tasks(*)), milestones(*), goal_habit_links(*), goal_collaborators(*)')
// Убрать .eq('user_id', userId) — RLS теперь возвращает и shared-цели

// После загрузки — определить isOwned:
// goal.userId == userId → обычная цель
// goal.userId != userId → shared, определить myRole из collaborators
```

Для локального кэша shared-целей: добавить в `LocalGoals` колонки `isShared BOOLEAN DEFAULT false` и `myRole TEXT NULLABLE`. Shared-цели помечать `isShared = true`, синхронизировать только для чтения (не отправлять изменения через offline sync queue если `isShared = true && myRole = 'viewer'`).

---

## Детали реализации UI

### `_GoalSettingsSheet` (mission_detail_screen.dart)

В конце существующего списка настроек добавить раздел (только если `goal.userId == currentUserId`):

```
Divider
SectionLabel('СОВМЕСТНАЯ РАБОТА')
// Для каждого collaborator с status == 'accepted':
_CollaboratorRow(collaborator, onRoleChange, onRemove)
// Кнопка:
_InviteButton(onTap: () => showModalBottomSheet(_CollaboratorPickerSheet))
```

`_CollaboratorRow`:
- 36×36 аватар + username
- `DropdownButton<String>` (items: ['viewer', 'editor']) → вызывает `updateRole`
- `IconButton(Icons.person_remove_outlined)` → диалог → `remove`

### `_CollaboratorPickerSheet` (приватный виджет в mission_detail_screen.dart)

```dart
// Список друзей, отфильтрованных: убрать уже коллабораторов
final available = ref.watch(friendsProvider).valueOrNull?.friends
    .where((f) => !goal.collaborators.any((c) => c.userId == f.otherUser.id))
    .toList() ?? [];
```

Каждая строка: аватар + username + два чипа (Просмотр/Редактирование) + кнопка «Пригласить».

### `_NotifTile` в `operations_control_screen.dart`

Для `type == 'goal_collaboration_invite'` — показать кнопки:

```dart
if (notification.type == 'goal_collaboration_invite' && !notification.isRead)
  Row(children: [
    _ActionChip('ПРИНЯТЬ', onTap: () => ref.read(notificationsProvider.notifier)
        .acceptCollaborationInvite(goalId)),
    SizedBox(width: 8),
    _ActionChip('ОТКЛОНИТЬ', onTap: () => ref.read(notificationsProvider.notifier)
        .declineCollaborationInvite(goalId)),
  ]),
```

### `_GoalCard` в `planning_screen.dart`

Добавить в верхнюю часть карточки (после статус-чипа):

```dart
if (goal.userId != currentUserId)
  Container(
    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      border: Border.all(color: c.accent.withValues(alpha: 0.4)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(children: [
      Icon(Icons.people_outlined, size: 10, color: c.accent),
      SizedBox(width: 4),
      Text('СОВМЕСТНАЯ', style: TextStyle(fontSize: 9, color: c.accent)),
    ]),
  ),
// Под именем цели:
if (goal.userId != currentUserId)
  Text('Владелец: ${ownerUsername}', style: TextStyle(fontSize: 11, color: c.textSecondary)),
```

Для получения `ownerUsername` — либо хранить имя владельца в уведомлении/payload при загрузке, либо найти профиль из collaborators.`invitedBy`. Проще: загружать профиль владельца через `PublicProfile.fromJson` при разборе цели в провайдере.

Решение: добавить в `Goal` поле `ownerProfile: PublicProfile?` — подгружается при загрузке shared-целей (один батч-запрос к `profiles` по всем `goal.userId != currentUserId`).

---

## Решения по открытым вопросам

1. **Оффлайн**: кэшировать shared-цели в `LocalGoals` (read-only). `isShared = true` + `myRole TEXT`. В offline sync queue изменения shared-целей не попадают — только онлайн.

2. **Онлайн-индикация**: использовать **Supabase Realtime Presence**. Когда пользователь открывает `MissionDetailScreen`, он входит в Presence-канал `goal_presence:{goalId}` и публикует `{userId, username, avatarUrl}`. Канал закрывается при `onDispose`. Владелец и коллабораторы видят зелёные точки рядом с аватарами участников в разделе «СОВМЕСТНАЯ РАБОТА».

   Реализация:
   ```dart
   // В MissionDetailScreen (StatefulWidget или ConsumerStatefulWidget)
   RealtimeChannel? _presenceChannel;

   @override
   void initState() {
     super.initState();
     _joinPresence();
   }

   void _joinPresence() {
     final me = SupabaseService.client.auth.currentUser!;
     _presenceChannel = SupabaseService.client
       .channel('goal_presence:${widget.goal.id}')
       .onPresenceSync((_) => setState(() {}))  // перестройка UI
       .subscribe((status, _) async {
         if (status == RealtimeSubscribeStatus.subscribed) {
           await _presenceChannel!.track({'user_id': me.id});
         }
       });
   }

   Set<String> get _onlineUserIds =>
     _presenceChannel?.presenceState()
       .values.expand((list) => list)
       .map((p) => p.payload['user_id'] as String)
       .toSet() ?? {};

   @override
   void dispose() {
     _presenceChannel?.unsubscribe();
     super.dispose();
   }
   ```

   В `_CollaboratorRow`: если `collaborator.userId` в `_onlineUserIds` — показывать зелёный индикатор 8×8 поверх аватара.

3. **Real-time обновления**: только через ручной refresh в первой итерации. Добавить кнопку/pull-to-refresh в `MissionDetailScreen` для shared-целей.

4. **Pending-участники**: показывать в разделе «СОВМЕСТНАЯ РАБОТА» с пометкой «ожидает ответа» серым текстом и кнопкой «Отозвать» (DELETE из `goal_collaborators`).

5. **Задачи удалённых редакторов**: остаются в цели. CASCADE DELETE срабатывает только при удалении пользователя из `auth.users`.

6. **Лимит участников**: максимум **10 коллабораторов** на цель. Проверка на клиенте (кнопка «Пригласить» скрывается при `collaborators.length >= 10`) и в RLS/CHECK на сервере:
   ```sql
   CREATE OR REPLACE FUNCTION public.check_collaborator_limit()
     RETURNS TRIGGER LANGUAGE plpgsql AS $$
   BEGIN
     IF (SELECT COUNT(*) FROM public.goal_collaborators
         WHERE goal_id = NEW.goal_id AND status != 'declined') >= 10 THEN
       RAISE EXCEPTION 'collaborator_limit_exceeded';
     END IF;
     RETURN NEW;
   END;
   $$;

   CREATE TRIGGER collaborator_limit_check
     BEFORE INSERT ON public.goal_collaborators
     FOR EACH ROW EXECUTE FUNCTION public.check_collaborator_limit();
   ```

7. **Передача владения**: не реализуется в первой итерации.

---

## Дополнительные модули (уточнение после ответов)

### `MissionDetailScreen` — Presence

`MissionDetailScreen` становится `ConsumerStatefulWidget` (если ещё нет). Добавить `_presenceChannel` и логику из пункта 2 выше.

### `_CollaboratorRow` — онлайн-индикатор

```dart
// Аватар с онлайн-точкой
Stack(
  children: [
    _CollabAvatar(profile: collaborator.profile, size: 36),
    if (isOnline)
      Positioned(
        right: 0, bottom: 0,
        child: Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: Colors.greenAccent,
            shape: BoxShape.circle,
            border: Border.all(color: sc.surface, width: 1.5),
          ),
        ),
      ),
  ],
)
```

### Pull-to-refresh для shared-целей

В `MissionDetailScreen` для shared-целей (goal.userId != currentUserId) добавить `RefreshIndicator` или `IconButton(Icons.refresh_outlined)` в AppBar, вызывающий `ref.invalidate(planningProvider)`.
