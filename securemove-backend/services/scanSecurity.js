const crypto = require('crypto');

const replayCache = new Map();
const rateCache = new Map();

const REPLAY_WINDOW_MS = 10 * 1000;
const RATE_WINDOW_MS = 60 * 1000;
const RATE_LIMIT = 10;

function hashQr(rawQr) {
  return crypto.createHash('sha256').update(String(rawQr || '')).digest('hex');
}

function cleanExpired(now = Date.now()) {
  for (const [key, value] of replayCache.entries()) {
    if (value.expiresAt <= now) replayCache.delete(key);
  }
  for (const [key, value] of rateCache.entries()) {
    if (value.resetAt <= now) rateCache.delete(key);
  }
}

function checkRateLimit(conductorId) {
  cleanExpired();
  const key = String(conductorId || 'anonymous');
  const now = Date.now();
  const bucket = rateCache.get(key) ?? {
    count: 0,
    resetAt: now + RATE_WINDOW_MS,
  };

  if (bucket.count >= RATE_LIMIT) {
    const retryAfter = Math.ceil((bucket.resetAt - now) / 1000);
    return {
      limited: true,
      retryAfter: retryAfter > 0 ? retryAfter : 60,
    };
  }

  bucket.count += 1;
  rateCache.set(key, bucket);
  return { limited: false };
}

function checkReplay(ticketId, qrHash) {
  cleanExpired();
  const key = `scan:${ticketId || qrHash}:recent`;
  if (replayCache.has(key)) {
    return true;
  }

  replayCache.set(key, {
    expiresAt: Date.now() + REPLAY_WINDOW_MS,
  });
  return false;
}

async function triggerFraudAlert(pool, {
  conductorId,
  ticketId,
  tripId,
  rawQrHash,
  ipAddress,
  reason,
  req,
}) {
  await pool.query(
    `INSERT INTO fraud_alerts (conductor_id, ticket_id, trip_id, raw_qr_hash, ip_address, details)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [
      conductorId ?? null,
      ticketId ?? null,
      tripId ?? null,
      rawQrHash,
      ipAddress ?? null,
      { reason, userAgent: req?.headers?.['user-agent'] },
    ]
  );

  req?.app?.locals?.io?.to('super_admin_room')?.emit('fraud_alert', {
    message: 'Fraudulent ticket scan detected',
    conductorId,
    ticketId: ticketId ?? null,
    tripId: tripId ?? null,
    timestamp: new Date().toISOString(),
  });

  const recent = await pool.query(
    `SELECT COUNT(*)::int AS count
     FROM ticket_scan_events
     WHERE conductor_id = $1
       AND fraud_alert = TRUE
       AND created_at >= NOW() - INTERVAL '1 hour'`,
    [conductorId]
  );

  if ((recent.rows[0]?.count ?? 0) >= 3) {
    await pool.query(
      `UPDATE users
       SET flagged = TRUE,
           flag_reason = 'Multiple fake or replayed ticket scans'
       WHERE LOWER(email) IN (
         SELECT LOWER(email)
         FROM conductors
         WHERE conductor_id = $1
       )`,
      [conductorId]
    );
  }
}

module.exports = {
  checkRateLimit,
  checkReplay,
  hashQr,
  triggerFraudAlert,
};
