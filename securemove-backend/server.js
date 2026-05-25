const express = require('express');
const cors = require('cors');
require('dotenv').config();

const authRoutes = require('./routes/auth');
const bookingRoutes = require('./routes/bookings');
const companyRoutes = require('./routes/companies');
const driverWorkspaceRoutes = require('./routes/driverRoutes');
const driverRoutes = require('./routes/drivers');
const paymentRoutes = require('./routes/payments');
const routeRoutes = require('./routes/routes');
const securityRoutes = require('./routes/security');
const ticketRoutes = require('./routes/tickets');
const superAdminRoutes = require('./routes/superAdminRoutes');
const roleCompanyRoutes = require('./routes/companyRoutes');
const conductorRoutes = require('./routes/conductorRoutes');
const lencoWebhookRoute = require('./routes/lencoWebhook');

const app = express();
let server = null;
try {
  const http = require('http');
  const { Server } = require('socket.io');
  server = http.createServer(app);
  app.locals.io = new Server(server, {
    cors: { origin: '*' },
  });
} catch (error) {
  console.warn('Socket.io unavailable; fraud alerts will be stored but not broadcast.', error.message);
}

app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use('/uploads', express.static('uploads'));

// Webhook must receive raw body for HMAC-SHA512 signature verification.
// Mount BEFORE express.json() so the body is not pre-parsed.
app.use('/webhooks/lenco', express.raw({ type: 'application/json' }), lencoWebhookRoute);

app.use(express.json());
app.use((req, res, next) => {
  res.type('application/json');
  next();
});

app.get('/', (req, res) => {
  res.json({ message: 'SecureMove backend is running' });
});

app.use('/auth', authRoutes);
app.use('/bookings', bookingRoutes);
app.use('/companies', companyRoutes);
app.use('/driver', driverWorkspaceRoutes);
app.use('/drivers', driverRoutes);
app.use('/payments', paymentRoutes);
app.use('/routes', routeRoutes);
app.use('/security', securityRoutes);
app.use('/tickets', ticketRoutes);
app.use('/admin', superAdminRoutes);
app.use('/company', roleCompanyRoutes);
app.use('/conductor', conductorRoutes);

// Render/public clients sometimes call the API with an /api prefix.
// Keep the original routes working while also supporting /api/*.
app.use('/api/auth', authRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/companies', companyRoutes);
app.use('/api/driver', driverWorkspaceRoutes);
app.use('/api/drivers', driverRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/routes', routeRoutes);
app.use('/api/security', securityRoutes);
app.use('/api/tickets', ticketRoutes);
app.use('/api/admin', superAdminRoutes);
app.use('/api/company', roleCompanyRoutes);
app.use('/api/conductor', conductorRoutes);

app.use((req, res) => {
  res.status(404).json({ error: `Cannot ${req.method} ${req.path}` });
});

app.use((err, req, res, next) => {
  console.error('Unhandled request error:', err);
  res.status(err.status || 500).json({ error: err.message || 'Internal server error' });
});

const PORT = process.env.PORT || 3000;

const listener = server ?? app;
listener.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
