
CREATE TABLE IF NOT EXISTS businesses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES owners(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT,
  description TEXT,
  location TEXT,
  phone TEXT,
  email TEXT,
  website TEXT,
  verified BOOLEAN DEFAULT FALSE,
  trust_score INTEGER DEFAULT 0,
  registration_number TEXT,
  onboarding_step TEXT DEFAULT 'init',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE businesses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access on businesses"
  ON businesses
  FOR ALL
  USING (true)
  WITH CHECK (true);

GRANT ALL ON businesses TO service_role;
GRANT SELECT, INSERT, UPDATE ON businesses TO anon;
