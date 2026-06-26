-- Fix handle_telegram_user: match by `sub` prefix instead of `provider` key.
--
-- Supabase Auth does not include a `provider` key in raw_user_meta_data for
-- custom OAuth providers; instead the `sub` claim is "telegram:<id>". This
-- updates the trigger function to detect Telegram logins by the sub prefix.

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

-- Backfill the already-created test profile from auth.users raw_user_meta_data.
UPDATE public.profiles p
   SET telegram_id       = substring(u.raw_user_meta_data ->> 'sub' from 10)::bigint,
       telegram_username = u.raw_user_meta_data ->> 'preferred_username'
  FROM auth.users u
 WHERE p.id = u.id
   AND p.telegram_id IS NULL
   AND (u.raw_user_meta_data ->> 'sub') LIKE 'telegram:%';