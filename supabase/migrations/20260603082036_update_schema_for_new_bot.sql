
-- Drop old tables and rebuild to match new bot schema
DROP TABLE IF EXISTS businesses CASCADE;
DROP TABLE IF EXISTS owners CASCADE;

CREATE TABLE owners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone TEXT UNIQUE NOT NULL,
  full_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE businesses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES owners(id) ON DELETE CASCADE,
  business_name TEXT,
  business_type TEXT,
  location TEXT,
  monthly_revenue NUMERIC,
  age_years INTEGER,
  employee_count INTEGER,
  has_bank_account BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE owners ENABLE ROW LEVEL SECURITY;
ALTER TABLE businesses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access on owners" ON owners FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Service role full access on businesses" ON businesses FOR ALL USING (true) WITH CHECK (true);

GRANT ALL ON owners TO service_role, anon;
GRANT ALL ON businesses TO service_role, anon;
