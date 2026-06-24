-- Расширяемые фоны профиля: медиа-типы (картинки / анимация) + удалённый
-- каталог, пополняемый разработчиком через мини-админку без обновления
-- приложения. Файлы хранятся в публичном Storage-бакете `profile-backgrounds`,
-- метаданные — в существующей таблице `profile_backgrounds`.

-- ── Расширение таблицы каталога ───────────────────────────────────────────────

ALTER TABLE public.profile_backgrounds
  ADD COLUMN IF NOT EXISTS kind          text NOT NULL DEFAULT 'gradient'
    CHECK (kind IN ('gradient','image','animated_webp','lottie')),
  ADD COLUMN IF NOT EXISTS thumbnail_url text,
  ADD COLUMN IF NOT EXISTS is_published  boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS sort_order    int NOT NULL DEFAULT 0;

-- Существующие 4 фона-градиента остаются kind = 'gradient' (DEFAULT).

-- ── Флаг администратора на profiles ───────────────────────────────────────────

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_admin boolean NOT NULL DEFAULT false;

-- ── Recursion-safe admin check ────────────────────────────────────────────────
-- SECURITY DEFINER: внутри функции RLS не применяется повторно, поэтому проверка
-- is_admin на profiles не зацикливается, когда вызывается из политик других
-- таблиц или из политик самого profiles.

CREATE OR REPLACE FUNCTION public.is_admin()
  RETURNS boolean
  LANGUAGE sql
  SECURITY DEFINER
  STABLE
  SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT p.is_admin FROM public.profiles p WHERE p.id = auth.uid()),
    false
  );
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM public;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- ── RLS: писать в каталог фонов может только администратор ─────────────────────
-- Публичное чтение уже разрешено политикой "public read profile_backgrounds".

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
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "admin delete profile_backgrounds"
  ON public.profile_backgrounds FOR DELETE
  TO authenticated
  USING (public.is_admin());

GRANT INSERT, UPDATE, DELETE ON public.profile_backgrounds TO authenticated;

-- ── Storage bucket profile-backgrounds ────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profile-backgrounds',
  'profile-backgrounds',
  true,
  15728640,   -- 15 MB (анимированный WebP / Lottie JSON могут быть крупнее JPG)
  ARRAY[
    'image/jpeg','image/png','image/webp','image/gif',
    'application/json'   -- Lottie
  ]
)
ON CONFLICT (id) DO NOTHING;

-- Публичное чтение (бакет публичный; явная политика — belt-and-suspenders).
DO $$ BEGIN
  CREATE POLICY "profile-backgrounds: public read"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'profile-backgrounds');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Загрузка — только администратор.
DO $$ BEGIN
  CREATE POLICY "profile-backgrounds: admin upload"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'profile-backgrounds' AND public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Обновление загруженного — только администратор.
DO $$ BEGIN
  CREATE POLICY "profile-backgrounds: admin update"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (bucket_id = 'profile-backgrounds' AND public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Удаление — только администратор.
DO $$ BEGIN
  CREATE POLICY "profile-backgrounds: admin delete"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (bucket_id = 'profile-backgrounds' AND public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
