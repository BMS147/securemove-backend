ALTER TABLE companies
  ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'pending';

ALTER TABLE buses
  ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'Coach';

ALTER TABLE trips
  ADD COLUMN IF NOT EXISTS conductor_id INTEGER REFERENCES drivers(driver_id) ON DELETE SET NULL;

UPDATE trips
SET conductor_id = driver_id
WHERE conductor_id IS NULL;

CREATE TABLE IF NOT EXISTS ticket_scan_events (
  scan_event_id SERIAL PRIMARY KEY,
  ticket_id INTEGER REFERENCES tickets(ticket_id) ON DELETE SET NULL,
  conductor_id INTEGER REFERENCES drivers(driver_id) ON DELETE SET NULL,
  result_status TEXT NOT NULL,
  details JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ticket_scan_events_ticket_created
  ON ticket_scan_events (ticket_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ticket_scan_events_conductor_created
  ON ticket_scan_events (conductor_id, created_at DESC);
