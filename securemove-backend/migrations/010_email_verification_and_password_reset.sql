ALTER TABLE users
  ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMPTZ;

UPDATE users
SET email_verified = TRUE,
    email_verified_at = COALESCE(email_verified_at, NOW())
WHERE email IN (
  'admin@securemove.dev',
  'chanda@powertools.dev',
  'mary@likili.dev',
  'james@mazhandu.dev',
  'susan@shalom.dev',
  'victor@ubz.dev',
  'benson.phiri@securemove.dev',
  'ruth.mwila@securemove.dev',
  'peter.banda@securemove.dev',
  'grace.tembo@securemove.dev',
  'daniel.zulu@securemove.dev',
  'officer.banda@securemove.dev',
  'officer.mwansa@securemove.dev',
  'officer.chirwa@securemove.dev',
  'officer.tembo@securemove.dev',
  'officer.zulu@securemove.dev',
  'temwa@test.dev',
  'chisomo@test.dev',
  'mutale@test.dev',
  'lombe@test.dev'
);

CREATE TABLE IF NOT EXISTS auth_otps (
  otp_id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(user_id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  purpose TEXT NOT NULL,
  code_hash TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  consumed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auth_otps_email_purpose_created
  ON auth_otps (email, purpose, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_auth_otps_active
  ON auth_otps (email, purpose, expires_at)
  WHERE consumed_at IS NULL;
