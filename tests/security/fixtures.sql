\set ON_ERROR_STOP on

INSERT INTO auth.users (id) VALUES
  ('00000000-0000-4000-8000-000000000001'),
  ('00000000-0000-4000-8000-000000000002'),
  ('00000000-0000-4000-8000-000000000003'),
  ('00000000-0000-4000-8000-000000000004');

INSERT INTO public.owners (id, phone, full_name, auth_user_id) VALUES
  ('10000000-0000-4000-8000-000000000001', '+10000000001', 'Synthetic Owner A', '00000000-0000-4000-8000-000000000001'),
  ('10000000-0000-4000-8000-000000000002', '+10000000002', 'Synthetic Owner B', '00000000-0000-4000-8000-000000000002');

INSERT INTO public.businesses (id, owner_id, business_name, business_type, location) VALUES
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'Synthetic Business A', 'retail', 'Test A'),
  ('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 'Synthetic Business B', 'retail', 'Test B');

INSERT INTO public.revenue_entries (business_id, amount, entry_date) VALUES
  ('20000000-0000-4000-8000-000000000001', 10, DATE '2026-01-01'),
  ('20000000-0000-4000-8000-000000000002', 20, DATE '2026-01-02');
INSERT INTO public.expense_entries (business_id, amount, expense_date) VALUES
  ('20000000-0000-4000-8000-000000000001', 3, DATE '2026-01-01'),
  ('20000000-0000-4000-8000-000000000002', 4, DATE '2026-01-02');
INSERT INTO public.activity_history (business_id, activity_type) VALUES
  ('20000000-0000-4000-8000-000000000001', 'synthetic_test');
INSERT INTO public.credit_scores (business_id, score) VALUES
  ('20000000-0000-4000-8000-000000000001', 600),
  ('20000000-0000-4000-8000-000000000002', 500);
INSERT INTO public.supplier_records (business_id, supplier_name) VALUES
  ('20000000-0000-4000-8000-000000000001', 'Synthetic Supplier A'),
  ('20000000-0000-4000-8000-000000000002', 'Synthetic Supplier B');
INSERT INTO public.trust_signals (business_id, signal_type) VALUES
  ('20000000-0000-4000-8000-000000000001', 'synthetic_test'),
  ('20000000-0000-4000-8000-000000000002', 'synthetic_test');
INSERT INTO public.activity_history (business_id, activity_type) VALUES
  ('20000000-0000-4000-8000-000000000002', 'synthetic_test');
INSERT INTO public.bot_sessions (phone, data) VALUES
  ('synthetic-session-a', '{"label":"synthetic"}'),
  ('synthetic-session-b', '{"label":"synthetic"}');

INSERT INTO app_private.admin_users (user_id)
VALUES ('00000000-0000-4000-8000-000000000003');
