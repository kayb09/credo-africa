
CREATE TABLE IF NOT EXISTS bot_sessions (
  phone TEXT PRIMARY KEY,
  step INTEGER DEFAULT 1,
  data JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS revenue_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL,
  entry_date DATE NOT NULL,
  source TEXT DEFAULT 'whatsapp',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS expense_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL,
  category TEXT,
  notes TEXT,
  expense_date DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS supplier_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
  receipt_image_path TEXT,
  supplier_name TEXT,
  purchase_date DATE,
  amount NUMERIC,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS trust_signals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
  signal_type TEXT NOT NULL,
  confidence NUMERIC DEFAULT 0.5,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS activity_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
  activity_type TEXT NOT NULL,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS on all new tables
ALTER TABLE bot_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE revenue_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE trust_signals ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_history ENABLE ROW LEVEL SECURITY;

-- Anon SELECT policies
CREATE POLICY "Allow anon select" ON bot_sessions FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon select" ON revenue_entries FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon select" ON expense_entries FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon select" ON supplier_records FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon select" ON trust_signals FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon select" ON activity_history FOR SELECT TO anon USING (true);

-- Grants
GRANT SELECT ON bot_sessions TO anon;
GRANT SELECT ON revenue_entries TO anon;
GRANT SELECT ON expense_entries TO anon;
GRANT SELECT ON supplier_records TO anon;
GRANT SELECT ON trust_signals TO anon;
GRANT SELECT ON activity_history TO anon;
