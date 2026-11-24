-- DRAFT ONLY. Run as supabase_admin or a role that is a member of supabase_admin.
-- This separate owner-scoped step is required because the recovery CLI role
-- cannot change another role's default privileges.

BEGIN;

DO $preflight$
BEGIN
  IF current_user <> 'supabase_admin'
     AND NOT pg_has_role(current_user, 'supabase_admin', 'MEMBER') THEN
    RAISE EXCEPTION 'Run as supabase_admin or a member of supabase_admin; current role is %',
      current_user;
  END IF;
END
$preflight$;

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public
  REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public
  REVOKE ALL ON FUNCTIONS FROM PUBLIC, anon, authenticated;

COMMIT;
