
-- Mzanzi Tax Assist — dedicated schema, fully isolated from credo
CREATE SCHEMA IF NOT EXISTS mzanzi;

CREATE TABLE IF NOT EXISTS mzanzi.users (
    id SERIAL PRIMARY KEY,
    email VARCHAR UNIQUE NOT NULL,
    hashed_password VARCHAR NOT NULL,
    full_name VARCHAR NOT NULL,
    date_of_birth DATE NOT NULL,
    is_provisional_taxpayer BOOLEAN DEFAULT FALSE,
    is_disabled BOOLEAN DEFAULT FALSE,
    is_vat_registered BOOLEAN DEFAULT FALSE,
    vat_number VARCHAR,
    medical_aid_members INTEGER DEFAULT 1,
    medical_aid_dependants INTEGER DEFAULT 0,
    popia_consent BOOLEAN DEFAULT FALSE,
    popia_consent_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS mzanzi.transactions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES mzanzi.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    description VARCHAR NOT NULL,
    amount FLOAT NOT NULL,
    category VARCHAR DEFAULT 'Uncategorised',
    is_deductible BOOLEAN DEFAULT FALSE,
    tax_code VARCHAR,
    confidence FLOAT DEFAULT 0.0,
    user_confirmed BOOLEAN DEFAULT FALSE,
    vat_amount FLOAT DEFAULT 0.0,
    receipt_linked BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS mzanzi.capital_gains (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES mzanzi.users(id) ON DELETE CASCADE,
    asset_name VARCHAR NOT NULL,
    acquisition_date DATE NOT NULL,
    disposal_date DATE NOT NULL,
    proceeds FLOAT NOT NULL,
    base_cost FLOAT NOT NULL,
    gain_or_loss FLOAT NOT NULL,
    tax_year VARCHAR NOT NULL
);

CREATE TABLE IF NOT EXISTS mzanzi.tax_documents (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES mzanzi.users(id) ON DELETE CASCADE,
    doc_type VARCHAR NOT NULL,
    tax_year VARCHAR NOT NULL,
    filename VARCHAR NOT NULL,
    uploaded_at TIMESTAMP DEFAULT NOW(),
    verified BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS mzanzi.tax_returns (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES mzanzi.users(id) ON DELETE CASCADE,
    tax_year VARCHAR NOT NULL,
    total_income FLOAT DEFAULT 0.0,
    total_deductions FLOAT DEFAULT 0.0,
    taxable_income FLOAT DEFAULT 0.0,
    tax_liability FLOAT DEFAULT 0.0,
    rebates_applied FLOAT DEFAULT 0.0,
    medical_credits FLOAT DEFAULT 0.0,
    ra_deduction FLOAT DEFAULT 0.0,
    cgt_included FLOAT DEFAULT 0.0,
    final_tax_due FLOAT DEFAULT 0.0,
    audit_risk_score INTEGER DEFAULT 0,
    filed_at TIMESTAMP,
    sars_reference VARCHAR
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_mzanzi_transactions_user ON mzanzi.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_mzanzi_documents_user ON mzanzi.tax_documents(user_id);
CREATE INDEX IF NOT EXISTS idx_mzanzi_gains_user ON mzanzi.capital_gains(user_id);
CREATE INDEX IF NOT EXISTS idx_mzanzi_returns_user ON mzanzi.tax_returns(user_id);
