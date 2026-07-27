# securemove

A Flutter transport ticketing app.

## Backend Connection

The app sends auth requests from [`lib/auth_service.dart`](/c:/Users/Testu/SecureMove%20Flutter/securemove/lib/auth_service.dart) to:

- `POST /auth/register`
- `POST /auth/login`

By default it uses:

- Web: `http://localhost:3000`
- Android emulator: `http://10.0.2.2:3000`
- Other platforms: `http://localhost:3000`

Important: a real Android phone cannot reach your computer through `localhost` or `10.0.2.2`. Use your computer's LAN IP instead.

You can override that with a build-time variable:

```powershell
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

Examples:

```powershell
# Android emulator talking to a backend on your computer
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

# Physical phone on the same Wi-Fi as your computer
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:3000

# Flutter web
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

For a physical Android phone, also make sure:

- your backend server is actually running on port `3000`
- the backend is listening on your computer's network interface, not only on `127.0.0.1`
- your computer firewall allows inbound traffic to that port
- the phone and computer are on the same Wi-Fi network

This repo now enables Android cleartext traffic for local `http://` development. If your backend uses `https://`, that is preferred.

Your backend should return a JSON response with a `token` field for login, for example:

```json
{
  "token": "your-jwt-or-session-token"
}
```

## Mobile Money Payments

SecureMove now focuses on mobile money payments only. The Flutter app calls the backend mobile money endpoints for MTN MoMo, Airtel Money, mock mode, or the configured collection provider.

If your payments endpoint lives somewhere else, point the app at it with `PAYMENT_API_BASE_URL`:

```powershell
flutter run --dart-define=PAYMENT_API_BASE_URL=http://10.0.2.2:3000
```

For Flutter web:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000 --dart-define=PAYMENT_API_BASE_URL=http://localhost:3000
```

The Flutter app uses these backend endpoints:

- `GET /payments/mobile-money/config`
- `POST /payments/mobile-money/initiate`
- `GET /payments/:paymentId/status`

Example mobile money request body sent by the app:

```json
{
  "bookingId": 123,
  "provider": "airtel",
  "phoneNumber": "0970000000",
  "amount": 250
}
```

Notes:

- Use backend mock mode for local payment testing without real provider approval.
- Android, iOS, and web builds all use the same mobile money API flow.
- The conductor scanner is intended mainly for phone use; the passenger web app does not depend on scanner support.
