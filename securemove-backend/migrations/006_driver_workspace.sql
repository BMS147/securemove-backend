ALTER TABLE drivers
  ADD COLUMN IF NOT EXISTS nrc_number TEXT,
  ADD COLUMN IF NOT EXISTS license_expiry DATE,
  ADD COLUMN IF NOT EXISTS license_class TEXT NOT NULL DEFAULT 'Class C PSV',
  ADD COLUMN IF NOT EXISTS profile_photo_url TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'ACTIVE',
  ADD COLUMN IF NOT EXISTS total_distance_km NUMERIC(10, 1) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS driver_notifications (
  notification_id SERIAL PRIMARY KEY,
  driver_id INTEGER NOT NULL REFERENCES drivers(driver_id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  kind TEXT NOT NULL DEFAULT 'info',
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_driver_notifications_driver_created
  ON driver_notifications (driver_id, created_at DESC);
