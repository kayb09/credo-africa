-- DRAFT ONLY. This is a fail-closed rollback, not a restoration of the insecure
-- pre-audit state. It deliberately does not recreate anonymous policies/grants.
-- It also preserves owner identity links and administrator membership data.

BEGIN;

DROP POLICY IF EXISTS owners_select_own_or_admin ON public.owners;
DROP POLICY IF EXISTS businesses_select_own_or_admin ON public.businesses;
DROP POLICY IF EXISTS businesses_update_own ON public.businesses;
DROP POLICY IF EXISTS activity_history_select_own_or_admin ON public.activity_history;
DROP POLICY IF EXISTS bot_sessions_select_admin ON public.bot_sessions;
DROP POLICY IF EXISTS credit_scores_select_own_or_admin ON public.credit_scores;
DROP POLICY IF EXISTS expense_entries_select_own_or_admin ON public.expense_entries;
DROP POLICY IF EXISTS expense_entries_insert_own ON public.expense_entries;
DROP POLICY IF EXISTS revenue_entries_select_own_or_admin ON public.revenue_entries;
DROP POLICY IF EXISTS revenue_entries_insert_own ON public.revenue_entries;
DROP POLICY IF EXISTS supplier_records_select_own_or_admin ON public.supplier_records;
DROP POLICY IF EXISTS trust_signals_select_own_or_admin ON public.trust_signals;

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC, anon, authenticated;
REVOKE TRUNCATE ON ALL TABLES IN SCHEMA storage FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE storage.objects FROM PUBLIC, anon, authenticated;
DROP POLICY IF EXISTS "Allow anon upload to verifications" ON storage.objects;

REVOKE ALL ON FUNCTION app_private.is_app_admin() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SCHEMA app_private FROM authenticated;

COMMIT;
