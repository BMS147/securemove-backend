const express = require('express');
const router = express.Router();
const pool = require('../db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const authenticateToken = require('../middleware/authenticateToken');
const {
  maybeRecordFraudAlert,
  recordAuditEvent,
} = require('../services/security_audit');
const { ROLE_BY_ID } = require('../middleware/checkRole');
const { sendOtpEmail } = require('../services/emailService');

const JWT_SECRET = process.env.JWT_SECRET || 'supersecretkey';

router.get('/me', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT user_id, name, email, role_id, company_id, email_verified, created_at FROM users WHERE user_id = $1',
      [req.user.user_id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    return res.json({ user: result.rows[0] });
  } catch (err) {
    console.error('Fetch current user error:', err.message);
    return res.status(500).json({ error: 'Server error' });
  }
});

// REGISTER
router.post('/register', async (req, res) => {
  const { name, email, password } = req.body;
  const normalizedEmail = typeof email === 'string' ? email.trim().toLowerCase() : null;

  if (!name || !normalizedEmail || !password) {
    await recordAuditEvent({
      eventType: 'register_failed',
      status: 'validation_error',
      severity: 'medium',
      email: normalizedEmail,
      req,
      details: { reason: 'Missing required registration fields' },
    });
    return res.status(400).json({
      error: 'Name, email, and password are required',
    });
  }

  if (!isValidEmail(normalizedEmail)) {
    await recordAuditEvent({
      eventType: 'register_failed',
      status: 'validation_error',
      severity: 'medium',
      email: normalizedEmail,
      req,
      details: { reason: 'Invalid email format' },
    });
    return res.status(400).json({ error: 'Enter a valid email address' });
  }

  if (!isStrongPassword(password)) {
    return res.status(400).json({
      error: 'Password must be at least 8 characters and include uppercase, lowercase, and a number',
    });
  }

  try {
    const existingUser = await pool.query('SELECT user_id FROM users WHERE email = $1', [normalizedEmail]);

    if (existingUser.rows.length > 0) {
      await recordAuditEvent({
        eventType: 'register_failed',
        status: 'duplicate_email',
        severity: 'medium',
        email: normalizedEmail,
        userId: existingUser.rows[0].user_id,
        req,
        details: { reason: 'Email already registered' },
      });
      return res.status(400).json({ error: 'User already exists' });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const result = await pool.query(
      `INSERT INTO users (name, email, password_hash, email_verified)
       VALUES ($1, $2, $3, FALSE)
       RETURNING user_id, name, email, role_id, company_id, email_verified`,
      [name.trim(), normalizedEmail, hashedPassword]
    );

    await createAndSendOtp({
      user: result.rows[0],
      purpose: 'email_verification',
      req,
    });

    await recordAuditEvent({
      eventType: 'register_success',
      status: 'success',
      severity: 'info',
      email: normalizedEmail,
      userId: result.rows[0].user_id,
      req,
      details: { roleId: result.rows[0].role_id },
    });

    res.status(201).json({
      message: 'Account created. Check your email for the verification code.',
      user: result.rows[0],
      requiresEmailVerification: true,
    });
  } catch (err) {
    console.error('Registration error:', err.message);
    await recordAuditEvent({
      eventType: 'register_failed',
      status: 'server_error',
      severity: 'high',
      email: normalizedEmail,
      req,
      details: { reason: err.message },
    });
    res.status(500).json({ error: 'Server error' });
  }
});

// LOGIN
router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  const normalizedEmail = typeof email === 'string' ? email.trim().toLowerCase() : null;

  if (!email || !password) {
    await recordAuditEvent({
      eventType: 'login_failed',
      status: 'validation_error',
      severity: 'medium',
      email: normalizedEmail,
      req,
      details: { reason: 'Missing email or password' },
    });
    return res.status(400).json({ error: 'Email and password are required' });
  }

  try {
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [normalizedEmail]);

    if (result.rows.length === 0) {
      await recordAuditEvent({
        eventType: 'login_failed',
        status: 'invalid_credentials',
        severity: 'medium',
        email: normalizedEmail,
        req,
        details: { reason: 'Unknown email address' },
      });
      await maybeRecordFraudAlert({ email: normalizedEmail, req });
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = result.rows[0];
    const isMatch = await bcrypt.compare(password, user.password_hash);

    if (!isMatch) {
      await recordAuditEvent({
        eventType: 'login_failed',
        status: 'invalid_credentials',
        severity: 'medium',
        email: normalizedEmail,
        userId: user.user_id,
        req,
        details: { reason: 'Incorrect password' },
      });
      await maybeRecordFraudAlert({ email: normalizedEmail, userId: user.user_id, req });
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    if (!user.email_verified) {
      await createAndSendOtp({
        user,
        purpose: 'email_verification',
        req,
      });
      await recordAuditEvent({
        eventType: 'login_failed',
        status: 'email_not_verified',
        severity: 'medium',
        email: normalizedEmail,
        userId: user.user_id,
        req,
        details: { reason: 'Email address not verified' },
      });
      return res.status(403).json({
        error: 'Verify your email address before logging in. We sent you a new code.',
        code: 'EMAIL_NOT_VERIFIED',
      });
    }

    const token = jwt.sign(
      {
        user_id: user.user_id,
        email: user.email,
        role_id: user.role_id,
        role: ROLE_BY_ID[user.role_id] || 'passenger',
        company_id: user.company_id,
        companyId: user.company_id,
        email_verified: user.email_verified,
      },
      JWT_SECRET,
      { expiresIn: '1h' }
    );

    await recordAuditEvent({
      eventType: 'login_success',
      status: 'success',
      severity: 'info',
      email: normalizedEmail,
      userId: user.user_id,
      req,
      details: { roleId: user.role_id },
    });

    res.json({ token });
  } catch (err) {
    console.error('Login error:', err.message);
    await recordAuditEvent({
      eventType: 'login_failed',
      status: 'server_error',
      severity: 'high',
      email: normalizedEmail,
      req,
      details: { reason: err.message },
    });
    res.status(500).json({ error: 'Server error' });
  }
});

router.post('/verify-email', async (req, res) => {
  const { email, code } = req.body ?? {};
  const normalizedEmail = typeof email === 'string' ? email.trim().toLowerCase() : null;

  if (!normalizedEmail || !code) {
    return res.status(400).json({ error: 'Email and verification code are required' });
  }

  try {
    const user = await getUserByEmail(normalizedEmail);
    if (!user) {
      return res.status(404).json({ error: 'Account not found' });
    }

    await consumeOtp({
      email: normalizedEmail,
      code: String(code),
      purpose: 'email_verification',
    });

    await pool.query(
      `UPDATE users
       SET email_verified = TRUE,
           email_verified_at = NOW()
       WHERE user_id = $1`,
      [user.user_id]
    );

    await recordAuditEvent({
      eventType: 'email_verification_success',
      status: 'success',
      severity: 'info',
      email: normalizedEmail,
      userId: user.user_id,
      req,
    });

    return res.json({ message: 'Email verified successfully' });
  } catch (err) {
    console.error('Email verification error:', err.message);
    await recordAuditEvent({
      eventType: 'email_verification_failed',
      status: 'failed',
      severity: 'medium',
      email: normalizedEmail,
      req,
      details: { reason: err.message },
    });
    return res.status(400).json({ error: err.message });
  }
});

router.post('/verification/resend', async (req, res) => {
  const { email } = req.body ?? {};
  const normalizedEmail = typeof email === 'string' ? email.trim().toLowerCase() : null;

  if (!normalizedEmail) {
    return res.status(400).json({ error: 'Email is required' });
  }

  try {
    const user = await getUserByEmail(normalizedEmail);
    if (user) {
      await createAndSendOtp({
        user,
        purpose: 'email_verification',
        req,
      });
    }

    return res.json({
      message: 'If this account needs verification, a new code has been sent.',
    });
  } catch (err) {
    console.error('Resend verification error:', err.message);
    return res.status(500).json({ error: 'Unable to send verification code' });
  }
});

router.post('/password/forgot', async (req, res) => {
  const { email } = req.body ?? {};
  const normalizedEmail = typeof email === 'string' ? email.trim().toLowerCase() : null;

  if (!normalizedEmail) {
    return res.status(400).json({ error: 'Email is required' });
  }

  try {
    const user = await getUserByEmail(normalizedEmail);
    if (user) {
      await createAndSendOtp({
        user,
        purpose: 'password_reset',
        req,
      });
    }

    return res.json({
      message: 'If the email exists, a password reset code has been sent.',
    });
  } catch (err) {
    console.error('Forgot password error:', err.message);
    return res.status(500).json({ error: 'Unable to start password reset' });
  }
});

router.post('/password/reset', async (req, res) => {
  const { email, code, password } = req.body ?? {};
  const normalizedEmail = typeof email === 'string' ? email.trim().toLowerCase() : null;

  if (!normalizedEmail || !code || !password) {
    return res.status(400).json({ error: 'Email, code, and new password are required' });
  }

  if (!isStrongPassword(password)) {
    return res.status(400).json({
      error: 'Password must be at least 8 characters and include uppercase, lowercase, and a number',
    });
  }

  try {
    const user = await getUserByEmail(normalizedEmail);
    if (!user) {
      return res.status(404).json({ error: 'Account not found' });
    }

    await consumeOtp({
      email: normalizedEmail,
      code: String(code),
      purpose: 'password_reset',
    });

    const passwordHash = await bcrypt.hash(password, 10);
    await pool.query(
      `UPDATE users
       SET password_hash = $1,
           email_verified = TRUE,
           email_verified_at = COALESCE(email_verified_at, NOW())
       WHERE user_id = $2`,
      [passwordHash, user.user_id]
    );

    await recordAuditEvent({
      eventType: 'password_reset_success',
      status: 'success',
      severity: 'medium',
      email: normalizedEmail,
      userId: user.user_id,
      req,
    });

    return res.json({ message: 'Password reset successfully' });
  } catch (err) {
    console.error('Password reset error:', err.message);
    await recordAuditEvent({
      eventType: 'password_reset_failed',
      status: 'failed',
      severity: 'medium',
      email: normalizedEmail,
      req,
      details: { reason: err.message },
    });
    return res.status(400).json({ error: err.message });
  }
});

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(email || ''));
}

function isStrongPassword(password) {
  const value = String(password || '');
  return value.length >= 8 &&
    /[A-Z]/.test(value) &&
    /[a-z]/.test(value) &&
    /[0-9]/.test(value);
}

function generateOtpCode() {
  return String(crypto.randomInt(0, 1000000)).padStart(6, '0');
}

function hashOtp(code) {
  return crypto
    .createHash('sha256')
    .update(`${process.env.OTP_SECRET || process.env.JWT_SECRET || 'securemove-otp'}:${code}`)
    .digest('hex');
}

async function getUserByEmail(email) {
  const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
  return result.rows[0] ?? null;
}

async function createAndSendOtp({ user, purpose, req }) {
  const code = generateOtpCode();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

  await pool.query(
    `UPDATE auth_otps
     SET consumed_at = NOW()
     WHERE email = $1
       AND purpose = $2
       AND consumed_at IS NULL`,
    [user.email, purpose]
  );

  await pool.query(
    `INSERT INTO auth_otps (user_id, email, purpose, code_hash, expires_at)
     VALUES ($1, $2, $3, $4, $5)`,
    [user.user_id, user.email, purpose, hashOtp(code), expiresAt.toISOString()]
  );

  const delivery = await sendOtpEmail({
    to: user.email,
    code,
    purpose,
    name: user.name,
  });

  await recordAuditEvent({
    eventType: purpose === 'password_reset' ? 'password_reset_code_sent' : 'email_verification_code_sent',
    status: delivery.delivered ? 'sent' : 'dev_logged',
    severity: 'info',
    email: user.email,
    userId: user.user_id,
    req,
    details: { devMode: delivery.devMode },
  });

  return delivery;
}

async function consumeOtp({ email, code, purpose }) {
  const result = await pool.query(
    `SELECT otp_id, code_hash, attempts, expires_at
     FROM auth_otps
     WHERE email = $1
       AND purpose = $2
       AND consumed_at IS NULL
     ORDER BY created_at DESC
     LIMIT 1`,
    [email, purpose]
  );

  const otp = result.rows[0];
  if (!otp) {
    throw new Error('Verification code not found. Request a new code.');
  }

  if (new Date(otp.expires_at).getTime() < Date.now()) {
    await pool.query('UPDATE auth_otps SET consumed_at = NOW() WHERE otp_id = $1', [otp.otp_id]);
    throw new Error('Verification code expired. Request a new code.');
  }

  if (otp.attempts >= 5) {
    await pool.query('UPDATE auth_otps SET consumed_at = NOW() WHERE otp_id = $1', [otp.otp_id]);
    throw new Error('Too many attempts. Request a new code.');
  }

  if (hashOtp(String(code).trim()) !== otp.code_hash) {
    await pool.query('UPDATE auth_otps SET attempts = attempts + 1 WHERE otp_id = $1', [otp.otp_id]);
    throw new Error('Invalid verification code.');
  }

  await pool.query('UPDATE auth_otps SET consumed_at = NOW() WHERE otp_id = $1', [otp.otp_id]);
}

module.exports = router;
