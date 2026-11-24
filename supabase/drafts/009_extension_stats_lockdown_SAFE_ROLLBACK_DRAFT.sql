-- DRAFT ONLY. This rollback remains fail-closed for API roles and preserves
-- trusted server/platform access. It does not restore client statistics access.

BEGIN;

REVOKE ALL PRIVILEGES ON TABLE
  extensions.pg_stat_statements,
  extensions.pg_stat_statements_info
FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE
  extensions.pg_stat_statements,
  extensions.pg_stat_statements_info
TO service_role, supabase_admin;

REVOKE ALL PRIVILEGES ON FUNCTION extensions.pg_stat_statements(boolean)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION extensions.pg_stat_statements(boolean)
  TO service_role, supabase_admin;

REVOKE ALL PRIVILEGES ON FUNCTION extensions.pg_stat_statements_info()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION extensions.pg_stat_statements_info()
  TO service_role, supabase_admin;

COMMIT;
