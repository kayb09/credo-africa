
CREATE TABLE IF NOT EXISTS owners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone TEXT UNIQUE NOT NULL,
  name TEXT,
  email TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE owners ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access on owners"
  ON owners
  FOR ALL
  USING (true)
  WITH CHECK (true);

GRANT ALL ON owners TO service_role;
GRANT SELECT, INSERT, UPDATE ON owners TO anon;
