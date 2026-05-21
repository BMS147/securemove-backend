const express = require('express');
const cors = require('cors');
const pool = require('./db');
const jwt = require('jsonwebtoken');   // <-- you need this
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());
app.use((req, res, next) => {
  res.type('application/json');
  next();
});

// Test route
app.get('/', (req, res) => {
  res.json({ message: 'SecureMove backend is running' });
});

// Import routes
const authRouter = require('./routes/auth');
const paymentsRouter = require('./routes/payments');
app.use('/auth', authRouter);
app.use('/payments', paymentsRouter);

// JWT middleware
function authenticateToken(req, res, next) {
  const token = req.headers['authorization']?.split(' ')[1];
  if (!token) return res.status(401).send('Access denied');

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) return res.status(403).send('Invalid token');
    req.user = user;
    next();
  });
}

// Example protected route
app.get('/tickets', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM tickets WHERE user_id = $1', [req.user.userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).send('Server error');
  }
});
// DB test route
app.get('/dbtest', async (req, res) => {
  try {
    const result = await pool.query('SELECT NOW()'); // simple query to check DB
    res.json(result.rows);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Database connection error');
  }
});

app.use((req, res) => {
  res.status(404).json({ error: `Cannot ${req.method} ${req.path}` });
});

app.use((err, req, res, next) => {
  res.status(err.status || 500).json({ error: err.message || 'Internal server error' });
});

app.listen(3000, () => {
  console.log('Server started on port 3000');
});
