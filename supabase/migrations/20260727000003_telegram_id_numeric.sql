-- Telegram's native OIDC `sub` is a uint64 (e.g. 18065355168043369537) that
-- overflows Postgres `bigint` (max 9223372036854775807). The trigger cast
-- `v_sub::bigint` therefore threw and aborted user creation, so no session was
-- ever issued. Store telegram_id as `numeric` (arbitrary precision) and cast
-- defensively — never abort signup on an unexpected value.

ALTER TABLE public.profiles
  ALTER COLUMN telegram_id TYPE numeric USING telegram_id::numeric;

CREATE OR REPLACE FUNCTION public.handle_telegram_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_sub text;
  v_iss text;
  v_id  text;
  v_telegram_id numeric;
BEGIN
  v_iss := new.raw_user_meta_data ->> 'iss';
  v_sub := new.raw_user_meta_data ->> 'sub';

  -- Native Telegram OIDC: iss = oauth.telegram.org, sub = numeric id.
  IF v_iss = 'https://oauth.telegram.org' AND v_sub IS NOT NULL THEN
    v_id := v_sub;
  -- Legacy Edge Function bridge: sub = "telegram:<id>".
  ELSIF v_sub LIKE 'telegram:%' THEN
    v_id := substring(v_sub from 10);
  END IF;

  -- Only store a clean integer string; a bad value must not abort signup.
  IF v_id ~ '^[0-9]+$' THEN
    v_telegram_id := v_id::numeric;
    UPDATE public.profiles
       SET telegram_id       = v_telegram_id,
           telegram_username = new.raw_user_meta_data ->> 'preferred_username'
     WHERE id = new.id
       AND telegram_id IS NULL;
  END IF;

  RETURN new;
END;
$$;
