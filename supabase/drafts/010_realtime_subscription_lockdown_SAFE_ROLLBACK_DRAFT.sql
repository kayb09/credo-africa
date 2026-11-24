-- DRAFT ONLY. This rollback remains fail-closed for API roles and preserves
-- trusted server/platform access. It does not restore client subscription reads.

BEGIN;

REVOKE SELECT ON TABLE realtime.subscription FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE realtime.subscription TO service_role, supabase_admin;
REVOKE ALL PRIVILEGES ON SEQUENCE realtime.subscription_id_seq
  FROM PUBLIC, anon, authenticated;
GRANT ALL PRIVILEGES ON SEQUENCE realtime.subscription_id_seq
  TO service_role, supabase_admin;

COMMIT;
