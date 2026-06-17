-- TacticalMapEvolution Stage 3: goal-media Storage bucket for image cards on
-- the Tactical Map canvas. Files are stored at {goal_id}/{uuid}.{ext} so RLS
-- can be scoped to collaborators of a goal in the future. Public read matches
-- the existing `avatars` bucket pattern used in the app.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'goal-media',
  'goal-media',
  true,
  5242880,  -- 5 MB per file
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- Public URL read (bucket is public, but explicit policy is belt-and-suspenders).
CREATE POLICY IF NOT EXISTS "goal-media: public read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'goal-media');

-- Any authenticated user can upload (goal membership verified app-side).
CREATE POLICY IF NOT EXISTS "goal-media: authenticated upload"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'goal-media');

-- Any authenticated user can update their uploads.
CREATE POLICY IF NOT EXISTS "goal-media: authenticated update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'goal-media');

-- Any authenticated user can delete uploads.
CREATE POLICY IF NOT EXISTS "goal-media: authenticated delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'goal-media');
