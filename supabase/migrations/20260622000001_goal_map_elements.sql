-- TacticalMapEvolution Stage 1: map-native elements (notes/labels now; image
-- cards/groups/connectors reuse this table later). These live only on the
-- Tactical Map and never appear in list mode.

CREATE TABLE IF NOT EXISTS public.goal_map_elements (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id    uuid NOT NULL REFERENCES public.goals(id) ON DELETE CASCADE,
  kind       text NOT NULL CHECK (kind IN ('note','label','image','group','connector')),
  x          double precision NOT NULL,
  y          double precision NOT NULL,
  w          double precision,
  h          double precision,
  z_index    int NOT NULL DEFAULT 0,
  content    text,
  color_hex  text,
  media_url  text,
  from_ref   text,
  to_ref     text,
  style_json jsonb,
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_map_elements_goal
  ON public.goal_map_elements(goal_id);

ALTER TABLE public.goal_map_elements ENABLE ROW LEVEL SECURITY;

-- SELECT: goal owner OR any accepted collaborator.
CREATE POLICY "map_elements_select" ON public.goal_map_elements FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.goals g
      WHERE g.id = goal_map_elements.goal_id
        AND (
          g.user_id = auth.uid() OR
          EXISTS (
            SELECT 1 FROM public.goal_collaborators gc
            WHERE gc.goal_id = g.id AND gc.user_id = auth.uid()
              AND gc.status = 'accepted'
          )
        )
    )
  );

-- INSERT/UPDATE/DELETE: goal owner OR accepted editor collaborator.
CREATE POLICY "map_elements_insert" ON public.goal_map_elements FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.goals g
      LEFT JOIN public.goal_collaborators gc
        ON gc.goal_id = g.id AND gc.user_id = auth.uid()
           AND gc.status = 'accepted' AND gc.role = 'editor'
      WHERE g.id = goal_map_elements.goal_id
        AND (g.user_id = auth.uid() OR gc.id IS NOT NULL)
    )
  );

CREATE POLICY "map_elements_update" ON public.goal_map_elements FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.goals g
      LEFT JOIN public.goal_collaborators gc
        ON gc.goal_id = g.id AND gc.user_id = auth.uid()
           AND gc.status = 'accepted' AND gc.role = 'editor'
      WHERE g.id = goal_map_elements.goal_id
        AND (g.user_id = auth.uid() OR gc.id IS NOT NULL)
    )
  );

CREATE POLICY "map_elements_delete" ON public.goal_map_elements FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.goals g
      LEFT JOIN public.goal_collaborators gc
        ON gc.goal_id = g.id AND gc.user_id = auth.uid()
           AND gc.status = 'accepted' AND gc.role = 'editor'
      WHERE g.id = goal_map_elements.goal_id
        AND (g.user_id = auth.uid() OR gc.id IS NOT NULL)
    )
  );
