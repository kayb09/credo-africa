-- DRAFT ONLY. This rollback remains fail-closed for API roles and preserves
-- service/platform access. It does not restore client access to net.

BEGIN;

REVOKE ALL ON SCHEMA net FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA net TO service_role, supabase_admin;

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA net FROM PUBLIC, anon, authenticated;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA net TO service_role, supabase_admin;

REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA net FROM PUBLIC, anon, authenticated;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA net TO service_role, supabase_admin;

REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA net FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA net TO service_role, supabase_admin;

COMMIT;
