CREATE TABLE public.owners (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), phone text NOT NULL UNIQUE,
 full_name text, created_at timestamptz DEFAULT now()
);
CREATE TABLE public.businesses (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 owner_id uuid REFERENCES public.owners(id) ON DELETE CASCADE,
 business_name text, business_type text, location text, monthly_revenue numeric,
 age_years integer, employee_count integer, has_bank_account boolean DEFAULT false,
 created_at timestamptz DEFAULT now()
);
CREATE TABLE public.credit_scores (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 business_id uuid REFERENCES public.businesses(id) ON DELETE CASCADE,
 score integer NOT NULL, tier text, scored_at timestamptz DEFAULT now()
);
CREATE TABLE public.bot_sessions (
 phone text PRIMARY KEY, step integer DEFAULT 1, data jsonb DEFAULT '{}'::jsonb,
 created_at timestamptz DEFAULT now()
);
CREATE TABLE public.revenue_entries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 business_id uuid REFERENCES public.businesses(id) ON DELETE CASCADE,
 amount numeric NOT NULL, entry_date date NOT NULL, source text DEFAULT 'whatsapp',
 created_at timestamptz DEFAULT now()
);
CREATE TABLE public.expense_entries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 business_id uuid REFERENCES public.businesses(id) ON DELETE CASCADE,
 amount numeric NOT NULL, category text, notes text, expense_date date NOT NULL,
 created_at timestamptz DEFAULT now()
);
CREATE TABLE public.supplier_records (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 business_id uuid REFERENCES public.businesses(id) ON DELETE CASCADE,
 receipt_image_path text, supplier_name text, purchase_date date, amount numeric,
 created_at timestamptz DEFAULT now()
);
CREATE TABLE public.trust_signals (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 business_id uuid REFERENCES public.businesses(id) ON DELETE CASCADE,
 signal_type text NOT NULL, confidence numeric DEFAULT 0.5, created_at timestamptz DEFAULT now()
);
CREATE TABLE public.activity_history (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 business_id uuid REFERENCES public.businesses(id) ON DELETE CASCADE,
 activity_type text NOT NULL, metadata jsonb, created_at timestamptz DEFAULT now()
);
ALTER TABLE public.owners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.revenue_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supplier_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trust_signals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON SCHEMA public FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA public TO service_role;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC, anon, authenticated;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
 REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
 REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
 REVOKE ALL ON FUNCTIONS FROM PUBLIC, anon, authenticated;
