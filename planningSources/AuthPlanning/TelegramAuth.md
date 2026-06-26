# Авторизация через Telegram

> План реализации входа в SiE через аккаунт Telegram.

---

## 1. Описание

Добавить в приложение второй способ авторизации наряду с существующим email/password.
Пользователь нажимает кнопку «Войти через Telegram», подтверждает вход в нативном
клиенте Telegram (или через web-бота), и возвращается в SiE уже авторизованным.

Цели:
- Снизить порог входа (без регистрации с email/паролем).
- Получить верифицированный Telegram ID, который можно использовать позже для
  интеграции с ботом-уведомителем.
- Не ломать существующий email-flow — оба способа сосуществуют.

---

## 2. Сценарий

### Mobile (Android/iOS)
1. На `AuthScreen` под кнопкой submit появляется кнопка «Войти через Telegram».
2. По tap открывается приложение Telegram (через deep link `tg://` или универсальный
   `https://t.me/<bot>/login?start=<nonce>`).
3. Бот присылает в чат кнопку-URL «Подтвердить вход в SiE», ведущую на
   `https://bvqlqvzcqfgojzxztvrm.supabase.co/auth/v1/callback` с параметрами
   Telegram Login Widget (`id`, `first_name`, `auth_date`, `hash` …).
4. Supabase Auth обрабатывает callback, создаёт/находит пользователя и
   редиректит обратно в приложение по deep link `sie://auth/callback`.
5. `Supabase.instance.client.auth` ловит сессию из deep link, `authStateProvider`
   триггерит переход на `MainNavigationShell`.

### Desktop / Web
- Используется Telegram Login Widget (iframe на web) либо та же bot-flow на desktop.

---

## 3. Логика

### 3.1 Supabase-сторона
Supabase Auth **не поддерживает Telegram нативно** (его нет в списке провайдеров
Dashboard). Реализован через **Custom OAuth Provider `custom:telegram`** + Edge
Function-адаптер `supabase/functions/telegram-auth`:
- `GET /authorize` — рендерит страницу с Telegram Login Widget (HTML+JS).
- `GET /telegram-callback` — Telegram постит auth-data (`id`, `hash`,
  `auth_date`, `username`, …); функция валидирует `hash` по алгоритму Telegram
  (HMAC-SHA256 с ключом = SHA256(bot_token)), сохраняет одноразовый `code` и
  редиректит на `https://…/auth/v1/callback?code=<code>&state=<state>`.
- `POST /token` — Supabase обменивает `code` на JWT (подписан `JWT_SECRET`
  проекта) с claims `sub=telegram:<id>`, `name`, `username`.
- `GET /userinfo` — Supabase получает профиль по access_token: отдаёт
  `{sub, name, username, email, telegram_id}`.

Secrets Edge Function: `TELEGRAM_BOT_TOKEN`, `JWT_SECRET` (= JWT secret проекта
из Dashboard → Settings → API).

Для активации в Dashboard → Authentication → Providers → New Provider →
Manual configuration:
- Identifier: `custom:telegram`
- Client ID: `sie` (любой)
- Client Secret: `bot_token`
- Authorization/Token/UserInfo URL:
  `https://bvqlqvzcqfgojzxztvrm.functions.supabase.co/telegram-auth/{authorize|token|userinfo}`
- Включить **Email optional** (Advanced) — Telegram не отдаёт email.
- Redirect URLs: `sie://auth/callback` и
  `https://bvqlqvzcqfgojzxztvrm.supabase.co/auth/v1/callback`.

### 3.2 Привязка аккаунтов
- В `profiles` добавить колонки:
  - `telegram_id BIGINT UNIQUE`
  - `telegram_username TEXT`
- Триггер на `auth.users` (или handle в `signInWithOAuth` callback): при первом входе
  через Telegram создаёт запись в `profiles` с данными из `user.user_metadata`
  (`user_metadata.full_name` → `username`, `user_metadata.user_name` → `telegram_username`,
  `user_metadata.provider_id` → `telegram_id`).
- Если у пользователя уже есть email-аккаунт и он хочет привязать Telegram —
  раздел «Аккаунты» в `EditProfileScreen` с помощью
  `client.auth.identityLink(provider: 'telegram')`.

### 3.3 Flutter-сторона
- Использовать `signInWithOAuth(OAuthProvider('custom:telegram'))` из `supabase_flutter`.
- Deep-link handled через `supabase_flutter` (уже настроен в `main.dart` через
  `Supabase.initialize` с `authCallbackUrlScheme: 'sie'` — нужно проверить/добавить).
- Добавить провайдер `telegramAuthProvider`, оборачивающий вызов OAuth.

---

## 4. Модули (файлы)

| Файл | Действие |
|------|----------|
| `apps/central_hub/lib/screens/auth_screen.dart` | Добавить кнопку «Войти через Telegram» под формой. Использовать `_PressButton`-стилистику с Telegram-blue цветом. |
| `apps/central_hub/lib/main.dart` | Убедиться, что `Supabase.initialize` получает `authCallbackUrlScheme: 'sie'`. |
| `apps/central_hub/android/app/src/main/AndroidManifest.xml` | Добавить `<intent-filter>` для deep link `sie://`. |
| `apps/central_hub/ios/Runner/Info.plist` | Добавить `CFBundleURLSchemes` для `sie`. |
| `apps/central_hub/web/index.html` | Telegram Login Widget `<script>` для web-платформы. |
| `packages/sie_core/lib/src/supabase_service.dart` | Добавить метод `signInWithTelegram()` → `signInWithOAuth(OAuthProvider('custom:telegram'))`. |
| `packages/sie_core/lib/src/providers/auth_state_provider.dart` | Учесть сессии, полученные из OAuth-callback. |
| `packages/sie_core/lib/i18n/{ru,en}/auth.i18n.json` | Новые ключи: `telegramButton`, `telegramError`. |
| `supabase/migrations/<ts>_telegram_auth.sql` | Колонки `telegram_id`, `telegram_username` в `profiles`; триггер заполнения при OAuth-регистрации. |
| `supabase/config.toml` | (опц.) Раздел `[auth.external.telegram]` если self-hosted — для hosted Supabase настраивается в Dashboard. |

---

## 5. Схема данных

### `profiles` (миграция)
```sql
alter table public.profiles
  add column if not exists telegram_id bigint unique,
  add column if not exists telegram_username text;

-- Автозаполнение при первом входе через Telegram
create or replace function public.handle_telegram_user()
returns trigger
language plpgsql
security definer
as $$
begin
  if new.raw_user_meta_data->>'provider' = 'telegram' then
    insert into public.profiles (id, username, telegram_id, telegram_username)
    values (
      new.id,
      coalesce(new.raw_user_meta_data->>'full_name',
               new.raw_user_meta_data->>'user_name',
               'operative_' || substr(new.id::text, 1, 6)),
      (new.raw_user_meta_data->>'provider_id')::bigint,
      new.raw_user_meta_data->>'user_name'
    )
    on conflict (id) do update
      set telegram_id       = excluded.telegram_id,
          telegram_username = excluded.telegram_username
    where profiles.telegram_id is null;
  end if;
  return new;
end;
$$;

-- Повесить на существующий триггер handle_new_user или создать новый
```

### `auth.users`
- Supabase сам записывает `identities` с `provider = 'telegram'`.
- `raw_user_meta_data` содержит: `provider_id` (telegram id), `user_name`,
  `full_name`, `auth_date`, `hash`.

---

## 6. Потенциальные проблемы и решения

| Риск | Решение |
|------|---------|
| Не установлен клиент Telegram | Fallback на `https://oauth.telegram.org` (Login Widget) через webview. |
| Нет email в `user_metadata` → пустой `profiles.email` | Сделать `email` nullable (он и так nullable), генерировать username из `full_name`. |
| Повторный вход того же Telegram-ID после удаления аккаунта | `ON CONFLICT (telegram_id) DO UPDATE` вместо INSERT. |
| Безопасность deep link | Supabase валидирует PKCE/flow_token; `sie://` перехватывает только host `auth/callback`. |
| Telegram-bot в проде vs dev | Использовать одного бота; env-переменная `TELEGRAM_BOT_TOKEN` в Supabase Vault. |

---

## 7. Этапы реализации

1. **Подготовка инфраструктуры**
   - Создать бота через @BotFather, получить token.
   - Включить провайдер Telegram в Supabase Dashboard, указать token + redirect URLs.
2. **Backend-миграция**
   - Написать `20260626XXXXXX_telegram_auth.sql` (колонки + триггер).
   - Применить локально, протестить.
3. **Deep links**
   - Сконфигурировать `sie://` scheme в Android/iOS/Web manifests.
4. **Flutter-код**
   - `SupabaseService.signInWithTelegram()`.
   - Кнопка в `AuthScreen`, обработка ошибок.
5. **Привязка аккаунтов**
   - В `EditProfileScreen` добавить раздел «Telegram», кнопка «Привязать/отвязать».
6. **Локализация**
   - Ключи в `auth.i18n.json` (ru/en).
7. **Тестирование**
   - Android, web — вход через Telegram.
   - Повторный вход — сессия сохраняется.
   - Привязка существующего email-аккаунта.
8. **Релиз**
   - Обновить `pubspec.yaml` (version), собрать APK, release-notes.

---

## 8. Решения (ответы на вопросы)

- **Привязка аккаунтов:** одна кнопка в `EditProfileScreen` (раздел «Telegram»). Отдельное окно не нужно — проще и быстрее. При наличии привязанного аккаунта показываем состояние «Привязан: @username» с кнопкой «Отвязать».
- **Username по умолчанию:** используем `full_name` из Telegram как `username`. Если `full_name` пустой — fallback на `user_name` (никнейм), затем на `operative_<id>`.
- **Логаут:** всегда полный `signOut()`. Отвязка Telegram (`unlinkIdentity`) — только через раздел «Telegram» в `EditProfileScreen`, не из общего logout.
- **Deep link:** кастомный scheme `sie://auth/callback`. Соответствует названию приложения, конфигурируется в Android/iOS/Web manifests.