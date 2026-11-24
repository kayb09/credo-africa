-- DRAFT ONLY. Never apply to production without owner approval and a reviewed rollout.
-- Requires Supabase Auth (auth.users/auth.uid), the recovered public schema, and
-- the recovered Credo public/storage objects documented in docs/audit/milestone-2-security-audit.md.
-- Run only as a database owner able to alter postgres default privileges.
-- Separate supabase_admin defaults are handled by 007_supabase_admin_defaults_DRAFT.sql.

BEGIN;

DO $preflight$
BEGIN
  IF current_user <> 'postgres'
     AND NOT pg_has_role(current_user, 'postgres', 'MEMBER') THEN
    RAISE EXCEPTION 'Run this draft as postgres or a member of postgres; current role is %', current_user;
  END IF;

  IF to_regclass('auth.users') IS NULL OR to_regprocedure('auth.uid()') IS NULL THEN
    RAISE EXCEPTION 'Supabase Auth users and auth.uid() are required';
  END IF;

  IF to_regclass('storage.objects') IS NULL THEN
    RAISE EXCEPTION 'Expected storage.objects to exist';
  END IF;
END
$preflight$;

ALTER TABLE public.owners
  ADD COLUMN IF NOT EXISTS auth_user_id uuid
  REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE UNIQUE INDEX IF NOT EXISTS owners_auth_user_id_uidx
  ON public.owners(auth_user_id)
  WHERE auth_user_id IS NOT NULL;

CREATE SCHEMA IF NOT EXISTS app_private;
REVOKE ALL ON SCHEMA app_private FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE IF NOT EXISTS app_private.admin_users (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON TABLE app_private.admin_users FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION app_private.is_app_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM app_private.admin_users AS admin
    WHERE admin.user_id = auth.uid()
  )
$function$;

REVOKE ALL ON FUNCTION app_private.is_app_admin() FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA app_private TO authenticated;
GRANT EXECUTE ON FUNCTION app_private.is_app_admin() TO authenticated;

DROP POLICY IF EXISTS "Allow anon insert activity" ON public.activity_history;
DROP POLICY IF EXISTS "Allow anon select" ON public.activity_history;
DROP POLICY IF EXISTS "Allow anon select" ON public.bot_sessions;
DROP POLICY IF EXISTS "Allow anon select" ON public.businesses;
DROP POLICY IF EXISTS "Service role full access on businesses" ON public.businesses;
DROP POLICY IF EXISTS "Allow anon select" ON public.credit_scores;
DROP POLICY IF EXISTS "Allow anon select" ON public.expense_entries;
DROP POLICY IF EXISTS "Allow anon select" ON public.owners;
DROP POLICY IF EXISTS "Service role full access on owners" ON public.owners;
DROP POLICY IF EXISTS "Allow anon select" ON public.revenue_entries;
DROP POLICY IF EXISTS "Allow anon select" ON public.supplier_records;
DROP POLICY IF EXISTS "Allow anon select" ON public.trust_signals;

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public
  FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public
  FROM PUBLIC, anon, authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON FUNCTIONS FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE
  public.owners,
  public.businesses,
  public.activity_history,
  public.bot_sessions,
  public.credit_scores,
  public.expense_entries,
  public.revenue_entries,
  public.supplier_records,
  public.trust_signals
TO authenticated;

GRANT UPDATE (business_name, business_type, location)
  ON TABLE public.businesses TO authenticated;
GRANT INSERT ON TABLE public.revenue_entries, public.expense_entries
  TO authenticated;

CREATE POLICY owners_select_own_or_admin
  ON public.owners FOR SELECT TO authenticated
  USING (auth_user_id = (SELECT auth.uid()) OR app_private.is_app_admin());

CREATE POLICY businesses_select_own_or_admin
  ON public.businesses FOR SELECT TO authenticated
  USING (
    app_private.is_app_admin()
    OR EXISTS (
      SELECT 1
      FROM public.owners AS owner
      WHERE owner.id = businesses.owner_id
        AND owner.auth_user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY businesses_update_own
  ON public.businesses FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.owners AS owner
      WHERE owner.id = businesses.owner_id
        AND owner.auth_user_id = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.owners AS owner
      WHERE owner.id = businesses.owner_id
        AND owner.auth_user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY activity_history_select_own_or_admin
  ON public.activity_history FOR SELECT TO authenticated
  USING (
    app_private.is_app_admin()
    OR EXISTS (
      SELECT 1
      FROM public.businesses AS business
      JOIN public.owners AS owner ON owner.id = business.owner_id
      WHERE business.id = activity_history.business_id
        AND owner.auth_user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY bot_sessions_select_admin
  ON public.bot_sessions FOR SELECT TO authenticated
  USING (app_private.is_app_admin());

CREATE POLICY credit_scores_select_own_or_admin
  ON public.credit_scores FOR SELECT TO authenticated
  USING (
    app_private.is_app_admin()
    OR EXISTS (
      SELECT 1
      FROM public.businesses AS business
      JOIN public.owners AS owner ON owner.id = business.owner_id
      WHERE business.id = credit_scores.business_id
        AND owner.auth_user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY expense_entries_select_own_or_admin
  ON public.expense_entries FOR SELECT TO authenticated
  USING (
    app_private.is_app_admin()
    OR EXISTS (
      SELECT 1
      FROM public.businesses AS business
      JOIN public.owners AS owner ON owner.id = business.owner_id
      WHERE business.id = expense_entries.business_id
        AND owner.auth_user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY expense_entries_insert_own
  ON public.expense_entries FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.businesses AS business
      JOIN public.owners AS owner ON owner.id = business.owner_id
      WHERE business.id = expense_entries.business_id
        AND owner.auth_user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY revenue_entries_select_own_or_admin
  ON public.revenue_entries FOR SELECT TO authenticated
  USING (
    app_private.is_app_admin()
    OR EXISTS (
      SELECT 1
      FROM public.businesses AS business
      JOIN public.owners AS owner ON owner.id = business.owner_id
      WHERE business.id = revenue_entries.business_id
        AND owner.auth_user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY revenue_entries_insert_own
  ON public.revenue_entries FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.businesses AS business
      JOIN public.owners AS owner ON owner.id = business.owner_id
      WHERE business.id = revenue_entries.business_id
        AND owner.auth_user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY supplier_records_select_own_or_admin
  ON public.supplier_records FOR SELECT TO authenticated
  USING (
    app_private.is_app_admin()
    OR EXISTS (
      SELECT 1
      FROM public.businesses AS business
      JOIN public.owners AS owner ON owner.id = business.owner_id
      WHERE business.id = supplier_records.business_id
        AND owner.auth_user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY trust_signals_select_own_or_admin
  ON public.trust_signals FOR SELECT TO authenticated
  USING (
    app_private.is_app_admin()
    OR EXISTS (
      SELECT 1
      FROM public.businesses AS business
      JOIN public.owners AS owner ON owner.id = business.owner_id
      WHERE business.id = trust_signals.business_id
        AND owner.auth_user_id = (SELECT auth.uid())
    )
  );

-- Remove client access to the private verification bucket. Keep service_role
-- operations available; authenticated uploads need a separately reviewed path.
DROP POLICY IF EXISTS "Allow anon upload to verifications" ON storage.objects;
REVOKE TRUNCATE ON ALL TABLES IN SCHEMA storage FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE storage.objects FROM PUBLIC, anon, authenticated;

COMMIT;
