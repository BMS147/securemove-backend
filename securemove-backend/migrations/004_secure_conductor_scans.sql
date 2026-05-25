ALTER TABLE ticket_scan_events
  ADD COLUMN IF NOT EXISTS trip_id INTEGER REFERENCES trips(trip_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS ip_address TEXT,
  ADD COLUMN IF NOT EXISTS device_info TEXT,
  ADD COLUMN IF NOT EXISTS qr_hash TEXT,
  ADD COLUMN IF NOT EXISTS fraud_alert BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_ticket_scan_events_trip_result
  ON ticket_scan_events (trip_id, result_status);

CREATE INDEX IF NOT EXISTS idx_ticket_scan_events_fraud_alert
  ON ticket_scan_events (fraud_alert);

CREATE TABLE IF NOT EXISTS fraud_alerts (
  fraud_alert_id SERIAL PRIMARY KEY,
  conductor_id INTEGER REFERENCES drivers(driver_id) ON DELETE SET NULL,
  ticket_id INTEGER REFERENCES tickets(ticket_id) ON DELETE SET NULL,
  trip_id INTEGER REFERENCES trips(trip_id) ON DELETE SET NULL,
  raw_qr_hash TEXT NOT NULL,
  ip_address TEXT,
  status TEXT NOT NULL DEFAULT 'OPEN',
  details JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fraud_alerts_status_created
  ON fraud_alerts (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_fraud_alerts_conductor_created
  ON fraud_alerts (conductor_id, created_at DESC);

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS flagged BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS flag_reason TEXT;
