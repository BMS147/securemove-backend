const pool = require('../db');

function getClientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.trim().length > 0) {
    return forwarded.split(',')[0].trim();
  }

  return req.ip || null;
}

function getUserAgent(req) {
  return req.headers['user-agent'] || null;
}

async function recordAuditEvent({
  eventType,
  status,
  severity = 'info',
  email = null,
  userId = null,
  req = null,
  details = null,
}) {
  const metadata = details == null ? null : JSON.stringify(details);

  await pool.query(
    `INSERT INTO audit_logs (
      event_type,
      status,
      severity,
      email,
      user_id,
      ip_address,
      user_agent,
      details
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)`,
    [
      eventType,
      status,
      severity,
      email,
      userId,
      req ? getClientIp(req) : null,
      req ? getUserAgent(req) : null,
      metadata,
    ]
  );
}

async function maybeRecordFraudAlert({ email, userId = null, req = null }) {
  if (!email) {
    return;
  }

  const latestSuccessResult = await pool.query(
    `SELECT created_at
     FROM audit_logs
     WHERE email = $1 AND event_type = 'login_success'
     ORDER BY created_at DESC
     LIMIT 1`,
    [email]
  );

  const lastSuccessAt = latestSuccessResult.rows[0]?.created_at ?? null;

  const failedCountResult = await pool.query(
    `SELECT COUNT(*)::int AS failed_count
     FROM audit_logs
     WHERE email = $1
       AND event_type = 'login_failed'
       AND ($2::timestamptz IS NULL OR created_at > $2)`,
    [email, lastSuccessAt]
  );

  const failedCount = failedCountResult.rows[0]?.failed_count ?? 0;

  if (failedCount !== 3) {
    return;
  }

  await recordAuditEvent({
    eventType: 'fraud_alert',
    status: 'triggered',
    severity: 'high',
    email,
    userId,
    req,
    details: {
      reason: 'Three consecutive failed login attempts',
      failedCount,
    },
  });
}

async function listAuditLogsForViewer({ viewer, limit = 25, scope = 'self' }) {
  const normalizedLimit = Math.max(1, Math.min(Number(limit) || 25, 100));
  const canViewAll = viewer?.role_id === 3 && scope === 'all';

  if (canViewAll) {
    const result = await pool.query(
      `SELECT audit_log_id, event_type, status, severity, email, user_id,
              ip_address, user_agent, details, created_at
       FROM audit_logs
       ORDER BY created_at DESC
       LIMIT $1`,
      [normalizedLimit]
    );

    return result.rows;
  }

  const result = await pool.query(
    `SELECT audit_log_id, event_type, status, severity, email, user_id,
            ip_address, user_agent, details, created_at
     FROM audit_logs
     WHERE user_id = $1 OR email = $2
     ORDER BY created_at DESC
     LIMIT $3`,
    [viewer.user_id, viewer.email, normalizedLimit]
  );

  return result.rows;
}

module.exports = {
  listAuditLogsForViewer,
  maybeRecordFraudAlert,
  recordAuditEvent,
};
