-- DRAFT ONLY. Supabase-managed pg_net schema ACL change; do not apply without
-- platform-owner review and confirmation that anon/authenticated do not require
-- direct net access. Move legitimate outbound HTTP operations to a server role.
-- No production schema or settings were changed during this audit.

BEGIN;

DO $preflight$
BEGIN
  IF to_regnamespace('net') IS NULL OR to_regclass('net.http_request_queue') IS NULL THEN
    RAISE EXCEPTION 'Expected the Supabase-managed net schema and request queue';
  END IF;
END
$preflight$;

REVOKE ALL ON SCHEMA net FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA net TO service_role, supabase_admin;

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA net FROM PUBLIC, anon, authenticated;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA net TO service_role, supabase_admin;

REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA net FROM PUBLIC, anon, authenticated;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA net TO service_role, supabase_admin;

REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA net FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA net TO service_role, supabase_admin;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA net
  REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA net
  REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA net
  REVOKE ALL ON FUNCTIONS FROM PUBLIC, anon, authenticated;

COMMIT;
