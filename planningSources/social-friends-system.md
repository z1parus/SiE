# Система социальных взаимодействий — Друзья и Уведомления

## Описание

Первая итерация социальной системы: список друзей, управление запросами в друзья через экран публичного профиля и функциональные уведомления о социальных событиях. Всё взаимодействие требует подключения к интернету — офлайн-кэш не предусмотрен.

---

## Пользовательский сценарий

1. Пользователь находит другого игрока через поиск (UserSearchScreen) или таблицу лидеров (LeaderboardScreen).
2. Открывает его PublicProfileScreen — видит кнопку действия под аватаром.
3. Нажимает «Добавить в друзья» — запрос отправлен, кнопка меняется на «Отменить запрос».
4. Адресат получает уведомление на колоколе Operations-экрана.
5. Адресат открывает лист уведомлений, нажимает на уведомление — попадает в профиль отправителя, где кнопка «Принять запрос».
6. После принятия оба видят друг друга в списке друзей (ProfileScreen → кнопка «Мои друзья»).
7. В списке друзей можно удалить друга (с диалогом подтверждения) или отменить исходящий запрос.

---

## Логика и поведение

### Кнопка действия на PublicProfileScreen

Состояние определяется на основе данных `friendsProvider`. Кнопка не отображается, если `profile.id == текущий userId`.

| Состояние | Вид кнопки | Действие |
|-----------|-----------|----------|
| Нет связи | FilledButton «Добавить в друзья» `Icons.person_add_outlined` | `sendRequest(userId)` |
| Я отправил запрос | OutlinedButton «Отменить запрос» `Icons.cancel_outlined` | `cancelRequest(friendshipId)` |
| Он отправил мне | FilledButton «Принять запрос» + OutlinedButton «Отклонить» | `acceptRequest` / `declineRequest` |
| Уже друзья | OutlinedButton «Удалить из друзей» `Icons.person_remove_outlined` | диалог → `removeFriend` |

### FriendsListScreen — 3 вкладки

- **ДРУЗЬЯ** — подтверждённые (status = 'accepted')
- **ИСХОДЯЩИЕ** — отправленные мной, ожидают (status = 'pending', requester = я)
- **ВХОДЯЩИЕ** — входящие ко мне (status = 'pending', addressee = я) + **бейдж с количеством** на вкладке

Строка пользователя: `44×44 ClipOval` аватар + username.toUpperCase() + «LEVEL X · Y XP» + кнопка действия справа.
- Друг: `Icons.person_remove_outlined` → `showDialog` «Удалить USERNAME из друзей?» → `removeFriend`
- Исходящий: `Icons.cancel_outlined` → немедленный `cancelRequest` (без диалога)
- Входящий: `Icons.check_circle_outlined` (зелёный) + `Icons.close` (красный) рядом

Пустое состояние: иконка + текст («Пока нет друзей» / «Нет исходящих запросов» / «Нет входящих запросов»).

### Уведомления (bottom sheet)

Открывается нажатием на колокол (`_GlassHeaderBtn`) в заголовке Operations-экрана. Красный бейдж `unreadCount` поверх иконки (если > 0).

Содержимое листа:
- Заголовок «УВЕДОМЛЕНИЯ» + кнопка «Прочитать все» (если есть непрочитанные)
- Список, новейшие первыми
- Строка: аватар отправителя + текст + «X мин. назад» + голубая точка (непрочитанное)
  - `friend_request` → «**USERNAME** отправил вам запрос в друзья»
  - `friend_request_accepted` → «**USERNAME** принял ваш запрос в друзья»
- Нажатие на строку: `markAsRead(id)` + `Navigator.push(PublicProfileScreen(profile: fromUser))`

---

## Затрагиваемые модули

### Новые файлы

| Путь | Описание |
|------|----------|
| `packages/sie_core/lib/src/models/friendship.dart` | `FriendshipStatus` enum, `FriendRow`, `FriendsState` |
| `packages/sie_core/lib/src/models/app_notification.dart` | `AppNotification`, `NotificationsState` |
| `packages/sie_core/lib/src/providers/friends_provider.dart` | `FriendsNotifier`, `friendsProvider` |
| `packages/sie_core/lib/src/providers/notifications_provider.dart` | `NotificationsNotifier`, `notificationsProvider` |
| `apps/central_hub/lib/screens/friends_list_screen.dart` | `FriendsListScreen` с 3 вкладками |
| `supabase/migrations/20260611000002_social_friends.sql` | Все таблицы, RLS, триггеры |

### Изменяемые файлы

| Путь | Что меняется |
|------|-------------|
| `packages/sie_core/lib/sie_core.dart` | экспорт новых моделей и провайдеров |
| `apps/central_hub/lib/screens/profile_screen.dart` | кнопка «Мои друзья» (`Icons.people_outlined`) в `_TopBar` справа от редактирования |
| `apps/central_hub/lib/screens/public_profile_screen.dart` | добавить `_FriendActionSection` после `_HeroSection` в `CustomScrollView` |
| `apps/central_hub/lib/screens/operations_control_screen.dart` | добавить `onTap` к колоколу + бейдж непрочитанных |

---

## Схема данных

### Supabase: таблица `friendships`

```sql
CREATE TABLE public.friendships (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  addressee_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status       TEXT NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(requester_id, addressee_id)
);
```

**RLS:**
- SELECT: `requester_id = auth.uid() OR addressee_id = auth.uid()`
- INSERT: `requester_id = auth.uid()`
- UPDATE: `addressee_id = auth.uid()` (принять/отклонить)
- DELETE: `requester_id = auth.uid() OR addressee_id = auth.uid()` (отменить/удалить)

### Supabase: таблица `notifications`

```sql
CREATE TABLE public.notifications (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type         TEXT NOT NULL,
  from_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  payload      JSONB NOT NULL DEFAULT '{}',
  is_read      BOOLEAN NOT NULL DEFAULT false,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

**RLS:**
- SELECT: `user_id = auth.uid()`
- UPDATE: `user_id = auth.uid()` (для is_read)
- INSERT: запрещено для клиента — только через SECURITY DEFINER триггер

### PostgreSQL триггер (SECURITY DEFINER)

```sql
CREATE OR REPLACE FUNCTION public.create_friendship_notifications()
  RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    -- Уведомить адресата о входящем запросе
    INSERT INTO public.notifications (user_id, type, from_user_id)
    VALUES (NEW.addressee_id, 'friend_request', NEW.requester_id);
  ELSIF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    -- Уведомить отправителя о принятом запросе
    INSERT INTO public.notifications (user_id, type, from_user_id)
    VALUES (NEW.requester_id, 'friend_request_accepted', NEW.addressee_id);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER friendship_notifications
  AFTER INSERT OR UPDATE ON public.friendships
  FOR EACH ROW EXECUTE FUNCTION public.create_friendship_notifications();
```

### Dart-модели (sie_core)

```dart
// friendship.dart
enum FriendshipStatus { pending, accepted, declined }

class FriendRow {
  final String friendshipId;
  final PublicProfile otherUser;
  final FriendshipStatus status;
  final bool iAmRequester;
  final DateTime createdAt;
}

class FriendsState {
  final List<FriendRow> friends;           // accepted
  final List<FriendRow> sentRequests;      // pending, iAmRequester = true
  final List<FriendRow> receivedRequests;  // pending, iAmRequester = false

  // Метод для быстрого поиска статуса по userId
  FriendRow? rowFor(String userId);
}

// app_notification.dart
class AppNotification {
  final String id;
  final String type;             // 'friend_request' | 'friend_request_accepted'
  final PublicProfile? fromUser;
  final bool isRead;
  final DateTime createdAt;
}

class NotificationsState {
  final List<AppNotification> notifications;
  final int get unreadCount => notifications.where((n) => !n.isRead).length;
}
```

### Провайдеры (sie_core)

```dart
// friends_provider.dart
class FriendsNotifier extends AsyncNotifier<FriendsState> {
  // Загружает friendships + JOIN с profiles для получения PublicProfile
  Future<void> load();
  Future<void> sendRequest(String userId);
  Future<void> cancelRequest(String friendshipId);
  Future<void> acceptRequest(String friendshipId);
  Future<void> declineRequest(String friendshipId);
  Future<void> removeFriend(String friendshipId);
}

final friendsProvider =
    AsyncNotifierProvider<FriendsNotifier, FriendsState>(FriendsNotifier.new);

// notifications_provider.dart
class NotificationsNotifier extends AsyncNotifier<NotificationsState> {
  RealtimeChannel? _channel;
  // Загружает notifications + JOIN profiles для fromUser
  // Подписывается на Realtime: INSERT WHERE user_id = currentUserId
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, NotificationsState>(
        NotificationsNotifier.new);
```

### Supabase-запрос для загрузки friends (JOIN)

```sql
SELECT
  f.id, f.requester_id, f.addressee_id, f.status, f.created_at,
  p.id AS profile_id, p.username, p.avatar_url, p.total_xp,
  p.equipped_frame_id, p.equipped_background_id
FROM friendships f
JOIN profiles p ON p.id = CASE
  WHEN f.requester_id = auth.uid() THEN f.addressee_id
  ELSE f.requester_id
END
WHERE f.requester_id = auth.uid() OR f.addressee_id = auth.uid();
```

Через Supabase Flutter SDK: `.from('friendships').select('*, profiles!...')`  — либо через RPC-функцию `get_my_friendships()` если JOIN окажется сложным.

### Realtime (notifications)

```dart
_channel = Supabase.instance.client
    .channel('notifications:$userId')
    .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: FilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) => _onNewNotification(payload),
    )
    .subscribe();
```

---

## Детали реализации UI

### `_TopBar` в `profile_screen.dart`

Текущий правый край: один `_GlassCircleButton(Icons.edit_outlined)`.  
Изменение: обернуть правую часть в `Row`:

```dart
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    _GlassCircleButton(icon: Icons.people_outlined, onTap: () => Navigator.push(...FriendsListScreen())),
    const SizedBox(width: 8),
    _GlassCircleButton(icon: Icons.edit_outlined, onTap: ...),
  ],
)
```

### `_FriendActionSection` в `public_profile_screen.dart`

Вставить как `SliverToBoxAdapter` между `_HeroSection` и секцией со `_StatsRow`:

```dart
// Только если profile.id != currentUserId
Consumer(builder: (ctx, ref, _) {
  final row = ref.watch(friendsProvider)
      .valueOrNull?.rowFor(profile.id);
  // определить состояние и отрисовать нужные кнопки
})
```

### Колокол в `operations_control_screen.dart`

```dart
// Было:
const _GlassHeaderBtn(icon: Icons.notifications_outlined),

// Станет:
Consumer(builder: (_, ref, __) {
  final count = ref.watch(notificationsProvider)
      .valueOrNull?.unreadCount ?? 0;
  return Stack(children: [
    _GlassHeaderBtn(
      icon: Icons.notifications_outlined,
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (_) => const _NotificationsSheet(),
      ),
    ),
    if (count > 0)
      Positioned(
        right: 0, top: 0,
        child: _UnreadBadge(count: count),
      ),
  ]);
}),
```

### `_NotificationsSheet`

`ConsumerWidget`, `showModalBottomSheet` с `isScrollControlled: true`, `maxChildSize: 0.65`.  
Список `AppNotification` из `notificationsProvider`, сортировка по `createdAt DESC`.  
Функция «X мин. назад»: `_timeAgo(DateTime d)` — простой helper.

### `FriendsListScreen`

```dart
class FriendsListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    final stateAsync = ref.watch(friendsProvider);
    final state = stateAsync.valueOrNull;
    final received = state?.receivedRequests ?? [];

    return DefaultTabController(
      length: 3,
      child: SieBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('МОИ ДРУЗЬЯ'),
            bottom: TabBar(tabs: [
              const Tab(text: 'ДРУЗЬЯ'),
              const Tab(text: 'ИСХОДЯЩИЕ'),
              Tab(child: _TabWithBadge(
                  label: 'ВХОДЯЩИЕ', count: received.length)),
            ]),
          ),
          body: TabBarView(children: [
            _FriendTab(rows: state?.friends ?? []),
            _SentTab(rows: state?.sentRequests ?? []),
            _ReceivedTab(rows: state?.receivedRequests ?? []),
          ]),
        ),
      ),
    );
  }
}
```

Строка пользователя (`_FriendTile`) — следовать паттерну `_UserTile` из `user_search_screen.dart`:
- `44×44 ClipOval` с `Image.network` + `errorBuilder` с буквой/иконкой
- `username.toUpperCase()` + «LEVEL X · Y XP» (вычислять из `totalXp`)
- Кнопки действий справа (IconButton с `padding: EdgeInsets.zero`)
- Нажатие на всю строку → `Navigator.push(PublicProfileScreen(profile: row.otherUser))`

---

## Принятые решения

1. **Дублирование запросов** — при `sendRequest` сначала проверять, есть ли входящий `pending`-запрос от этого пользователя. Если есть — автоматически принимать его (вызвать `acceptRequest`) вместо создания нового.

2. **Declined-статус** — при отклонении запроса запись **удаляется** (`DELETE`). Статус `declined` в схеме не используется, оставлен только для возможного расширения.

3. **Загрузка `PublicProfile` для уведомлений** — JOIN с `profiles` в провайдере (запрос к `notifications` + `profiles` через Supabase). `profiles` публично читаемы, сложность минимальна.

4. **Realtime на Android** — добавить `WidgetsBindingObserver` в `NotificationsNotifier`: при `AppLifecycleState.resumed` переподписываться на канал (`_channel?.unsubscribe()` + повторный `subscribe()`).

5. **Лимит уведомлений** — загружать последние **50** записей без пагинации (`.order('created_at', ascending: false).limit(50)`).

6. **«Прочитать все»** — только `UPDATE SET is_read = true`, физически не удалять. История уведомлений сохраняется.

7. **Сортировка друзей** — по дате добавления (`createdAt DESC`), самые новые сверху.
