# SecureMove

SecureMove is a secure mobile ticketing application developed as a final-year Bachelor of Computer Science project at Mulungushi University.

The application was designed to improve cybersecurity in Zambia's transport sector by providing a secure platform for purchasing, managing and validating digital bus tickets while reducing ticket fraud and protecting passenger information.

---

## Features

- Secure user registration and login
- Password hashing using bcrypt
- JSON Web Token (JWT) authentication
- Role-Based Access Control (RBAC)
- Secure RESTful API
- Bus search and ticket booking
- QR-code ticket generation and validation
- Stripe payment integration (Test Mode)
- PostgreSQL database hosted on Supabase
- Transaction auditing
- Secure backend architecture

---

## Technology Stack

### Frontend

- Flutter
- Dart

### Backend

- Node.js
- Express.js

### Database

- PostgreSQL
- Supabase

### Security

- JWT Authentication
- bcrypt Password Hashing
- Role-Based Access Control
- Environment Variables
- Secure REST APIs

### Payment

- Stripe Payment Sheet (Test Mode)

---

## Project Structure

```
securemove-backend/
│
├── routes/
├── middleware/
├── services/
├── controllers/
├── models/
├── utils/
├── database/
├── app.js
└── server.js
```

---

## Installation

### Clone the repository

```bash
git clone https://github.com/BMS147/securemove-backend.git
```

### Install dependencies

```bash
npm install
```

### Create a .env file

Example:

```env
DATABASE_URL=your_database_url
JWT_SECRET=your_secret_key
STRIPE_SECRET_KEY=your_stripe_secret
```

### Start the server

```bash
npm start
```

---

## API

Authentication

```
POST /auth/register
POST /auth/login
```

Payments

```
POST /payments/create-intent
```

---

## Security Considerations

SecureMove follows secure software development practices by:

- Never storing passwords in plain text
- Hashing passwords using bcrypt
- Using JWT for authentication
- Protecting sensitive configuration using environment variables
- Separating frontend and backend services
- Restricting access using role-based authorization

---

## Future Improvements

- Email Notifications
- Push Notifications
- Ticket Expiry Automation
- Fraud Detection Enhancements

---

## Author

**Blessed Mwangala Simonda**

Bachelor of Science in Computer Science

Mulungushi University

GitHub

https://github.com/BMS147



# SecureMove Backend

This backend is ready to deploy on Render with:

- one free Node web service
- one free Render Postgres database
- automatic database initialization during deploy

## Local Development

The app is still in development and the Airtel Money app is not approved yet, so run mobile money in local mock mode. This lets the Flutter app exercise the same backend payment endpoints without calling Airtel.

```powershell
npm install
Copy-Item .env.example .env
npm run db:init
npm start
```

In `.env`, keep:

```env
MOBILE_MONEY_MODE=mock
```

Do not add Airtel credentials yet. With mock mode enabled:

- `POST /payments/mobile-money/initiate` accepts `provider: "airtel"` or `provider: "mtn"`
- the backend creates a local pending payment
- `GET /payments/:paymentId/status` changes it to `successful` after a few seconds
- no Airtel API approval, client id, or client secret is needed

Example local Flutter run:

```powershell
flutter run --dart-define=API_BASE_URL=http://localhost:3000 --dart-define=PAYMENT_API_BASE_URL=http://localhost:3000 --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_your_key
```

For Android emulator, use `http://10.0.2.2:3000` instead of `http://localhost:3000`.

## Render deploy

1. Push this backend folder to a GitHub repository.
2. In Render, choose `New -> Blueprint`.
3. Select your repository.
4. Render will read [render.yaml](./render.yaml) and create:
   - `securemove-backend`
   - `securemove-db`
5. When prompted, paste your Stripe test secret key for `STRIPE_SECRET_KEY`.
6. Finish the deploy and wait for the health check on `/` to pass.

Render uses `preDeployCommand: npm run db:init`, which creates the required tables automatically.

## Required environment variables

- `DATABASE_URL`
- `JWT_SECRET`
- `STRIPE_SECRET_KEY`
- `MOBILE_MONEY_MODE=mock` for development

`DATABASE_URL` is wired automatically from Render Postgres in `render.yaml`.

## Airtel Approval Later

After Airtel approves the developer app, switch from mock mode to Airtel live/UAT calls:

```env
MOBILE_MONEY_MODE=live
AIRTEL_CLIENT_ID=your_airtel_client_id
AIRTEL_CLIENT_SECRET=your_airtel_client_secret
AIRTEL_ENVIRONMENT_MODE=staging
AIRTEL_COUNTRY=ZM
AIRTEL_CURRENCY=ZMW
```

Use `AIRTEL_ENVIRONMENT_MODE=production` only after Airtel enables production access. You can also set `AIRTEL_BASE_URL` directly if Airtel gives you a different Open API URL.

## Flutter app connection

After deploy, point Flutter to your hosted backend URL:

```powershell
flutter run --dart-define=API_BASE_URL=https://YOUR-RENDER-URL.onrender.com --dart-define=PAYMENT_API_BASE_URL=https://YOUR-RENDER-URL.onrender.com --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_your_key
```

## Notes

- Free Render web services spin down after inactivity.
- Free Render Postgres expires after 30 days unless upgraded.
