CREATE TABLE IF NOT EXISTS conductors (
  conductor_id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT UNIQUE,
  phone_number TEXT,
  badge_number TEXT NOT NULL UNIQUE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_conductors_company_active
  ON conductors (company_id, is_active);

-- Preserve existing role_id=5 logins that were temporarily linked through
-- drivers. This keeps old test data alive, then future seeds use separate
-- conductor emails and badge numbers.
INSERT INTO conductors (
  conductor_id,
  company_id,
  full_name,
  email,
  phone_number,
  badge_number,
  is_active,
  created_at
)
SELECT d.driver_id,
       d.company_id,
       u.name,
       u.email,
       d.phone_number,
       COALESCE(NULLIF(d.license_number, ''), 'COND-' || d.driver_id::text),
       d.is_active,
       NOW()
FROM users u
INNER JOIN drivers d ON LOWER(d.email) = LOWER(u.email)
WHERE u.role_id = 5
ON CONFLICT (conductor_id) DO UPDATE
SET company_id = EXCLUDED.company_id,
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    phone_number = EXCLUDED.phone_number,
    badge_number = EXCLUDED.badge_number,
    is_active = EXCLUDED.is_active;

INSERT INTO conductors (
  conductor_id,
  company_id,
  full_name,
  email,
  phone_number,
  badge_number,
  is_active,
  created_at
)
SELECT d.driver_id,
       d.company_id,
       d.full_name,
       d.email,
       d.phone_number,
       'LEGACY-CON-' || d.driver_id::text,
       d.is_active,
       NOW()
FROM drivers d
WHERE EXISTS (
  SELECT 1 FROM trips tr WHERE tr.conductor_id = d.driver_id
)
ON CONFLICT (conductor_id) DO NOTHING;

SELECT setval(
  pg_get_serial_sequence('conductors', 'conductor_id'),
  GREATEST((SELECT COALESCE(MAX(conductor_id), 1) FROM conductors), 1),
  TRUE
);

DO $$
DECLARE
  constraint_record RECORD;
BEGIN
  FOR constraint_record IN
    SELECT con.conname, con.conrelid::regclass AS table_name
    FROM pg_constraint con
    INNER JOIN pg_attribute att
      ON att.attrelid = con.conrelid
     AND att.attnum = ANY (con.conkey)
    WHERE con.contype = 'f'
      AND att.attname = 'conductor_id'
      AND con.confrelid = 'drivers'::regclass
  LOOP
    EXECUTE format(
      'ALTER TABLE %s DROP CONSTRAINT %I',
      constraint_record.table_name,
      constraint_record.conname
    );
  END LOOP;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'trips_conductor_id_fkey'
  ) THEN
    ALTER TABLE trips
      ADD CONSTRAINT trips_conductor_id_fkey
      FOREIGN KEY (conductor_id)
      REFERENCES conductors(conductor_id)
      ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'ticket_scan_events_conductor_id_fkey'
  ) THEN
    ALTER TABLE ticket_scan_events
      ADD CONSTRAINT ticket_scan_events_conductor_id_fkey
      FOREIGN KEY (conductor_id)
      REFERENCES conductors(conductor_id)
      ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fraud_alerts_conductor_id_fkey'
  ) THEN
    ALTER TABLE fraud_alerts
      ADD CONSTRAINT fraud_alerts_conductor_id_fkey
      FOREIGN KEY (conductor_id)
      REFERENCES conductors(conductor_id)
      ON DELETE SET NULL;
  END IF;
END $$;
