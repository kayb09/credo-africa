-- DRAFT ONLY. Restricts direct reads of Supabase Realtime subscription state.
-- Confirm Realtime service dependencies with the platform owner before applying.
-- No production schema or settings were changed during this audit.

BEGIN;

DO $preflight$
BEGIN
  IF to_regclass('realtime.subscription') IS NULL
     OR to_regclass('realtime.messages') IS NULL
     OR to_regclass('realtime.subscription_id_seq') IS NULL THEN
    RAISE EXCEPTION 'Expected Supabase-managed realtime tables and subscription sequence';
  END IF;
END
$preflight$;

REVOKE SELECT ON TABLE realtime.subscription FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE realtime.subscription TO service_role, supabase_admin;
REVOKE ALL PRIVILEGES ON SEQUENCE realtime.subscription_id_seq
  FROM PUBLIC, anon, authenticated;
GRANT ALL PRIVILEGES ON SEQUENCE realtime.subscription_id_seq
  TO service_role, supabase_admin;

COMMIT;
