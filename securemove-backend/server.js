const express = require('express');
const cors = require('cors');
require('dotenv').config();

const authRoutes = require('./routes/auth');
const bookingRoutes = require('./routes/bookings');
const companyRoutes = require('./routes/companies');
const driverRoutes = require('./routes/drivers');
const paymentRoutes = require('./routes/payments');
const routeRoutes = require('./routes/routes');
const securityRoutes = require('./routes/security');
const ticketRoutes = require('./routes/tickets');
const superAdminRoutes = require('./routes/superAdminRoutes');
const roleCompanyRoutes = require('./routes/companyRoutes');
const conductorRoutes = require('./routes/conductorRoutes');

const app = express();

app.use(cors());
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
app.use('/drivers', driverRoutes);
app.use('/payments', paymentRoutes);
app.use('/routes', routeRoutes);
app.use('/security', securityRoutes);
app.use('/tickets', ticketRoutes);
app.use('/admin', superAdminRoutes);
app.use('/company', roleCompanyRoutes);
app.use('/conductor', conductorRoutes);

app.use((req, res) => {
  res.status(404).json({ error: `Cannot ${req.method} ${req.path}` });
});

app.use((err, req, res, next) => {
  console.error('Unhandled request error:', err);
  res.status(err.status || 500).json({ error: err.message || 'Internal server error' });
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
