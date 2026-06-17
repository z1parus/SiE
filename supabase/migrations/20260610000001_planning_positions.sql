ALTER TABLE public.goals
  ADD COLUMN IF NOT EXISTS map_positions JSONB DEFAULT NULL;

COMMENT ON COLUMN public.goals.map_positions IS
  'Canvas positions of all map elements: {"<element_id>": {"x": float, "y": float}}';
