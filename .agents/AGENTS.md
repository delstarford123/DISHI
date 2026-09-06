# SwapEat Project Rules

## Terminal Commands

- When running `vercel`, `vercel --prod`, or any Vercel CLI deployment command, always use the `unsandboxed` permission action. The Vercel CLI writes to Windows NUL which is blocked in the sandboxed terminal environment.
- When running `flutter pub get`, `flutter run`, `flutter build`, or `flutter analyze`, use the standard `command` permission (these work fine in the sandbox).
- When running `python` scripts in the `swapeat_backend/` directory, use the standard `command` permission.

## Project Architecture

- Backend: Python Flask on Vercel at `https://swapeatbackend.vercel.app`
- Backend source: `c:\Users\Delstaford\swapeat\swapeat_backend\`
- Frontend: Flutter app at `c:\Users\Delstaford\swapeat\`
- Database: Firebase Firestore
- Payments: Safaricom M-PESA Daraja API (production environment)

## Backend Rules

- Never import heavy packages (`reportlab`, `pycryptodome`) at module/top level — always use lazy imports inside functions so a missing package does not crash the entire Vercel function.
- Never import `flask_mail` at module level — always import inside the function body.
- All external HTTP calls (to Daraja M-PESA API) must have a `timeout=15` parameter.
- The M-PESA STK callback credits wallets using `user_id` stored in `mpesa_transactions` Firestore collection — NOT via BillRefNumber.

## Flutter Rules

- Theme: `MPesaTheme` from `lib/core/theme/mpesa_theme.dart`
- All HTTP calls must have a 30-second `.timeout(const Duration(seconds: 30))`.
- Always catch `TimeoutException` separately from general exceptions.
- Parse JSON error responses from backend and show the `error` field — never show raw `response.body` to users.
