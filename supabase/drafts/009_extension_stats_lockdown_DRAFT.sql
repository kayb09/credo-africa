-- DRAFT ONLY. Restricts query-statistics views/functions to trusted server
-- roles. Confirm no approved client integration depends on these objects.
-- No production schema or settings were changed during this audit.

BEGIN;

DO $preflight$
BEGIN
  IF to_regclass('extensions.pg_stat_statements') IS NULL
     OR to_regclass('extensions.pg_stat_statements_info') IS NULL
     OR to_regprocedure('extensions.pg_stat_statements(boolean)') IS NULL
     OR to_regprocedure('extensions.pg_stat_statements_info()') IS NULL THEN
    RAISE EXCEPTION 'Expected pg_stat_statements views and functions in extensions';
  END IF;
END
$preflight$;

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
