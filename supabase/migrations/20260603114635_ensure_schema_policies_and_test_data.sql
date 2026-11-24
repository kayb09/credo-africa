
-- Ensure credit_scores table has correct structure
CREATE TABLE IF NOT EXISTS credit_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
  score INTEGER NOT NULL,
  tier TEXT,
  scored_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE credit_scores ENABLE ROW LEVEL SECURITY;

-- Drop existing anon select policies if any, then recreate cleanly
DROP POLICY IF EXISTS "Allow anon select" ON owners;
DROP POLICY IF EXISTS "Allow anon select" ON businesses;
DROP POLICY IF EXISTS "Allow anon select" ON credit_scores;

-- Anon SELECT policies
CREATE POLICY "Allow anon select" ON owners
  FOR SELECT TO anon USING (true);

CREATE POLICY "Allow anon select" ON businesses
  FOR SELECT TO anon USING (true);

CREATE POLICY "Allow anon select" ON credit_scores
  FOR SELECT TO anon USING (true);

-- Grants
GRANT SELECT ON owners TO anon;
GRANT SELECT ON businesses TO anon;
GRANT SELECT ON credit_scores TO anon;
