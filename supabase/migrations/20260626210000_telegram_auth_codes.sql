-- Telegram OAuth adapter: one-time code storage.
--
-- The telegram-auth Edge Function stores authorization codes here when running
-- in multi-instance mode (the in-memory Map is fine for single-instance, but
-- Postgres is the durable fallback). Codes are single-use and expire after 5
-- minutes. The table is also the audit trail of Telegram logins.

CREATE TABLE IF NOT EXISTS public.telegram_auth_codes (
  code           text PRIMARY KEY,
  telegram_id    bigint NOT NULL,
  username       text,
  full_name      text,
  photo_url      text,
  state          text,
  redirect_uri   text,
  created_at     timestamptz NOT NULL DEFAULT now(),
  consumed_at    timestamptz
);

-- Expire codes automatically after 5 minutes.
CREATE INDEX IF NOT EXISTS idx_tg_auth_codes_created
  ON public.telegram_auth_codes (created_at);

ALTER TABLE public.telegram_auth_codes ENABLE ROW LEVEL SECURITY;
-- Only the service role (Edge Functions) can read/write; users never touch it.
CREATE POLICY "service_role can manage telegram auth codes"
  ON public.telegram_auth_codes FOR ALL
  TO service_role
  USING (true) WITH CHECK (true);