ALTER TABLE users
  ADD COLUMN IF NOT EXISTS company_id INTEGER REFERENCES companies(company_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_users_role_company
  ON users (role_id, company_id);
