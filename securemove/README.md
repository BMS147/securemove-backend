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

## Stripe Test Payments

The card checkout flow now uses Stripe Payment Sheet in test mode on Android and iOS.

Add your Stripe publishable test key when you run the app:

```powershell
flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_your_key
```

If your payments endpoint lives somewhere else, you can point the app at it too:

```powershell
flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_your_key --dart-define=PAYMENT_API_BASE_URL=http://10.0.2.2:3000
```

By default, the app now targets the local payments backend on port `3001`:

- Web: `http://localhost:3001`
- Android emulator: `http://10.0.2.2:3001`
- Other platforms: `http://localhost:3001`

The Flutter app expects a backend endpoint at `POST /payments/create-intent` that returns a Stripe PaymentIntent client secret:

```json
{
  "clientSecret": "pi_..._secret_..."
}
```

Example request body sent by the app:

```json
{
  "amount": 2500,
  "currency": "zmw",
  "description": "SecureMove ticket for City Rider at 08:30"
}
```

Use Stripe test cards while developing. The built-in help text uses:

- Card number: `4242 4242 4242 4242`
- Expiry: any future date
- CVC: any 3 digits
- ZIP/postal code: any value

Notes:

- Test mode does not create real charges.
- Stripe mobile checkout needs a backend because your secret key must never live in the app.
- Android has been prepared for Stripe in this repo. For iOS, run the app once from macOS to generate/install CocoaPods support before building there.
