-- Admin RPC: set a user's design_points by username
-- Only callable by accounts where is_admin() returns true (SECURITY DEFINER check).

CREATE OR REPLACE FUNCTION public.admin_set_user_dp(
  p_username TEXT,
  p_new_dp   INT
) RETURNS TABLE(user_id UUID, old_dp INT, new_dp INT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid   UUID;
  v_old   INT;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'FORBIDDEN: caller is not an admin';
  END IF;

  SELECT id, design_points
    INTO v_uid, v_old
    FROM profiles
   WHERE username = p_username;

  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_FOUND: %', p_username;
  END IF;

  UPDATE profiles
     SET design_points = p_new_dp
   WHERE id = v_uid;

  RETURN QUERY SELECT v_uid, v_old, p_new_dp;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_user_dp(TEXT, INT) TO authenticated;
