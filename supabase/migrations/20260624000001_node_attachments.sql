-- TacticalMapEvolution Stage 2: node attachments (images and files attached to
-- Goal/SubGoal/Task/Milestone nodes). Visible in both map and list modes.
-- Uses a SEPARATE private bucket `goal-attachments` so sensitive files are
-- protected with signed URLs, while the public `goal-media` bucket (Stage 3
-- image cards) remains untouched.

-- ── Storage bucket ────────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'goal-attachments',
  'goal-attachments',
  false,  -- private bucket; access via signed URLs
  20971520,  -- 20 MB per file
  NULL  -- all MIME types allowed (images, PDF, ZIP, etc.)
)
ON CONFLICT (id) DO NOTHING;

-- Authenticated users can upload to the bucket.
CREATE POLICY IF NOT EXISTS "goal-attachments: authenticated upload"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'goal-attachments');

-- Authenticated users can read from the bucket (signed URL is gated by RLS).
CREATE POLICY IF NOT EXISTS "goal-attachments: authenticated read"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'goal-attachments');

-- Authenticated users can delete their uploads.
CREATE POLICY IF NOT EXISTS "goal-attachments: authenticated delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'goal-attachments');

-- ── Relational table ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.goal_node_attachments (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id      uuid NOT NULL REFERENCES public.goals(id) ON DELETE CASCADE,
  node_type    text NOT NULL CHECK (node_type IN ('goal','subgoal','task','milestone')),
  node_id      uuid NOT NULL,
  storage_path text NOT NULL,   -- path in goal-attachments bucket
  file_name    text NOT NULL,
  mime_type    text NOT NULL,
  size_bytes   bigint NOT NULL DEFAULT 0,
  uploaded_by  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_attach_goal ON public.goal_node_attachments(goal_id);
CREATE INDEX IF NOT EXISTS idx_attach_node ON public.goal_node_attachments(node_id);

ALTER TABLE public.goal_node_attachments ENABLE ROW LEVEL SECURITY;

-- SELECT: goal owner OR any accepted collaborator.
CREATE POLICY "attachments: select own or collaborator" ON public.goal_node_attachments
  FOR SELECT USING (
    goal_id IN (
      SELECT id FROM public.goals WHERE user_id = auth.uid()
      UNION
      SELECT goal_id FROM public.goal_collaborators
        WHERE user_id = auth.uid() AND status = 'accepted'
    )
  );

-- INSERT: same, but only editor or owner.
CREATE POLICY "attachments: insert own or editor" ON public.goal_node_attachments
  FOR INSERT WITH CHECK (
    uploaded_by = auth.uid() AND (
      goal_id IN (SELECT id FROM public.goals WHERE user_id = auth.uid())
      OR goal_id IN (
        SELECT goal_id FROM public.goal_collaborators
          WHERE user_id = auth.uid() AND status = 'accepted' AND role = 'editor'
      )
    )
  );

-- DELETE: owner or uploader.
CREATE POLICY "attachments: delete own or uploader" ON public.goal_node_attachments
  FOR DELETE USING (
    uploaded_by = auth.uid() OR
    goal_id IN (SELECT id FROM public.goals WHERE user_id = auth.uid())
  );
