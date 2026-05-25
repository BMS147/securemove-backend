-- 007_fulfillment_tracking.sql
--
-- Adds fulfillment tracking columns to the bookings table so that a failed
-- ticket issuance (e.g. missing env var, DB error after payment is marked
-- successful) is visible to admins and can be retried, rather than being
-- silently swallowed by the webhook/polling error handler.
--
-- fulfillment_status values:
--   NULL       — payment not yet successful; fulfillment not attempted
--   'fulfilled' — ticket issued successfully
--   'failed'   — fulfillment was attempted but threw an error (see fulfillment_error)
--
-- fulfillment_error stores the error message string when status = 'failed'.

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS fulfillment_status TEXT,
  ADD COLUMN IF NOT EXISTS fulfillment_error  TEXT;

CREATE INDEX IF NOT EXISTS idx_bookings_fulfillment_status
  ON bookings (fulfillment_status)
  WHERE fulfillment_status IS NOT NULL;
