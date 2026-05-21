const express = require('express');
const router = express.Router();
const pool = require('../db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const authenticateToken = require('../middleware/authenticateToken');
const {
  maybeRecordFraudAlert,
  recordAuditEvent,
} = require('../services/security_audit');
const { ROLE_BY_ID } = require('../middleware/checkRole');

const JWT_SECRET = process.env.JWT_SECRET || 'supersecretkey';

router.get('/me', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT user_id, name, email, role_id, company_id, created_at FROM users WHERE user_id = $1',
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

  if (!name || !email || !password) {
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
      `INSERT INTO users (name, email, password_hash)
       VALUES ($1, $2, $3)
       RETURNING user_id, name, email, role_id, company_id`,
      [name.trim(), normalizedEmail, hashedPassword]
    );

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
      message: 'User registered successfully',
      user: result.rows[0],
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

    const token = jwt.sign(
      {
        user_id: user.user_id,
        email: user.email,
        role_id: user.role_id,
        role: ROLE_BY_ID[user.role_id] || 'passenger',
        company_id: user.company_id,
        companyId: user.company_id,
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

module.exports = router;
