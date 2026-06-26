-- Telegram OAuth: columns on profiles + auto-fill on OAuth login.
-- Adds telegram_id (unique, bigint) and telegram_username for the Telegram
-- identity provider. A trigger on auth.users fills them on first Telegram login.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS telegram_id bigint UNIQUE,
  ADD COLUMN IF NOT EXISTS telegram_username text;

-- Fill telegram_id / telegram_username on first login through Telegram provider.
-- Supabase stores the identity under raw_user_meta_data with `sub` = "telegram:<id>"
-- (no explicit `provider` key in user_meta_data, so we match by sub prefix).
-- Safe to run repeatedly (idempotent): only updates when telegram_id is NULL.
CREATE OR REPLACE FUNCTION public.handle_telegram_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_sub text;
  v_telegram_id bigint;
BEGIN
  v_sub := new.raw_user_meta_data ->> 'sub';
  IF v_sub IS NOT NULL AND v_sub LIKE 'telegram:%' THEN
    v_telegram_id := substring(v_sub from 10)::bigint;
    UPDATE public.profiles
       SET telegram_id       = v_telegram_id,
           telegram_username = new.raw_user_meta_data ->> 'preferred_username'
     WHERE id = new.id
       AND telegram_id IS NULL;
  END IF;
  RETURN new;
END;
$$;

-- Trigger runs AFTER handle_new_user (which INSERTs the profile row).
-- Keep ordering explicit via the existing trigger: we attach AFTER INSERT.
DROP TRIGGER IF EXISTS trg_on_auth_user_telegram ON auth.users;
CREATE TRIGGER trg_on_auth_user_telegram
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_telegram_user();