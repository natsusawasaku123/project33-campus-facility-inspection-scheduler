# Week 14 setup and evidence guide

Project 33 · Campus Facility Inspection Scheduler · SA8 and IA5

This update adds secure integration and a responsive campus dashboard. Keep the Week 13 submission as the historical record. The Week 14 instructions below use a release Flutter build and a local HTTPS proxy. Open **https://localhost:8443**, including when using Microsoft Edge.

## Requirements

- PHP 8.2 or later, Composer and PDO SQLite.
- Flutter with Dart satisfying `^3.13.7`. Cloud validation used Flutter **3.47.9 / Dart 3.13.7**, PHP **8.4.23**, Laravel **12.71.0**, Sanctum **4.3.3** and Caddy **2.11.9**.
- [Caddy for Windows](https://caddyserver.com/download), available as `caddy` on PATH, and Microsoft Edge.
- Run only on your own workstation, using fictional facilities and demo accounts. This Caddy configuration binds to loopback and is not a public deployment configuration.

## Update your existing Project33 folder

Commit or otherwise preserve your own outstanding work before switching branches. From your existing project root:

```powershell
git status --short
git fetch origin
git switch --track origin/codex/week14-secure-integration
cd backend
composer install
cd ..
./scripts/Configure-Week14.ps1
```

If that local branch already exists, use `git switch codex/week14-secure-integration`. The configuration script updates only the non-secret HTTPS/logging settings. It preserves your existing application key, demo password and database. It does not reseed users or reset any data. If PowerShell blocks the script, review it and run its non-secret configuration changes manually; do not lower your machine-wide execution policy.

For a fresh clone, copy `backend/.env.example` to `backend/.env`, run `composer install`, create `backend/database/database.sqlite` if absent, and run `php artisan key:generate` **only for that new installation**. Choose your own local `FACILITY_DEMO_PASSWORD` of 12–64 characters, then run:

```powershell
cd backend
php artisan migrate
php artisan db:seed --class=FacilitySeeder
php artisan db:seed --class=DemoUserSeeder
cd ..
```

Do not paste a password into a tracked script or a screenshot. Re-running DemoUserSeeder changes the four demo account passwords to the configured value. Restrict your local `.env`, database, logs and Caddy private keys to your Windows user account.

## Build and start

Build once from `frontend` after each application change:

```powershell
cd frontend
flutter pub get
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn --dart-define=API_BASE_URL=https://localhost:8443/api
cd ..
```

Open separate terminals at the project root:

```powershell
# Terminal 1: API, accessible only through local loopback
cd backend
php artisan serve --host=127.0.0.1 --port=8000
```

```powershell
# Terminal 2: serve the built Flutter files
php -S 127.0.0.1:5000 -t frontend/build/web
```

```powershell
# Terminal 3: HTTPS entry point for both frontend and API
caddy run --config infra/Caddyfile
```

```powershell
# Terminal 4: needed when demonstrating the recurring inspection/alert workflow
cd backend
php artisan schedule:work
```

Caddy generates a local certificate authority and a localhost certificate. The configuration deliberately does not install a trusted root automatically. On Windows, inspect Caddy's local root certificate under `%APPDATA%\Caddy\pki\authorities\local\root.crt`, then explicitly trust **your own generated root** in your current user's Trusted Root Certification Authorities store:

```powershell
certutil.exe -user -addstore Root "$env:APPDATA\Caddy\pki\authorities\local\root.crt"
```

If Caddy uses a custom data directory, use that directory's `pki/authorities/local/root.crt` instead. Restart Edge after trusting the root. Open `https://localhost:8443/api/health`; expect `{"status":"ok"}` and no certificate warning. Open `https://localhost:8443` for the app. Never bypass a certificate warning or disable certificate validation to produce passing HTTPS evidence. Keep `root.key` private; it is not an uploadable evidence file. Remove the local root from your trust store when you retire this demonstration CA.

## Authentication and permissions

Use your own locally selected password with the four fictional demo emails: supervisor, inspector, maintenance and custodian at `example.test`. Supervisors can create plans and open Alerts & Compliance; inspectors can access only their own inspections and checklists; maintenance can see their delivered alerts. Custodian is seeded but has no dedicated inspection actions in this prototype.

Tokens last one hour. They stay only in app memory. Sign out revokes the current token on the server; switching account first signs out. A protected request returning 401 clears the local session and returns to the home screen. A failed sign-out request is reported and can be retried. Other active sessions remain valid until revoked or expired.

The `/user` and login user payloads contain only ID, name and role. A login response also contains its opaque token and expiration. Do not record or publish the token value.

## Checks and capture plan

Run the backend tests from `backend`:

```powershell
php artisan test
```

Capture the real result, actual software versions and the tested commit (`git rev-parse HEAD`). The suite covers successful authentication, password/token storage, invalid/altered/expired tokens, logout, wrong roles, changed inspection IDs, invalid inputs, HTTP rejection, proxy spoofing, nonlocal HTTPS enforcement, login throttling, safe logging/errors and explicit CORS origins. Framework request tests are not a substitute for an actual TLS connection.

Collect separate browser/API evidence for these cases. Keep expected and actual results together:

| Case | Expected result | Suggested filename |
| --- | --- | --- |
| HTTPS app and health endpoint | Valid trusted certificate; API 200 | `week14_https_browser.png` |
| Missing, invalid, altered or expired token | 401 JSON; protected data absent | `week14_token_rejected.png` |
| Maintenance requests supervisor summary | 403; no summary data | `week14_wrong_role_denied.png` |
| Inspector substitutes another inspector's record ID | 404; record unchanged | `week14_record_access_denied.png` |
| Invalid plan/checklist values | 422; no unintended data change | `week14_validation_rejected.png` |
| Current token reused after sign out | 401 | `week14_logout_revoked.png` |
| Direct HTTP API access | 400; no redirect forwards credentials | `week14_http_rejected.png` |
| Correlated security log entry | Route template, status, UUID and optional actor ID only | `week14_safe_security_log.txt` |
| Desktop and narrow browser layouts | Clear navigation, usable forms, no overlap | `week14_desktop.png`, `week14_mobile.png` |

For a true expired-token demonstration, use the automated test's controlled expiration fixture or a separate local test token. Do not change a live account's token expiry and call it an observed one-hour wait. Do not expose Authorization headers, `.env` values, login request bodies or private certificate keys in captures. Do not edit screenshots to make a test pass; label any necessary credential redactions accurately.

The five-attempt login limit is per minute; a successful sign-in also consumes an attempt. Wait for the displayed retry interval before continuing account switching. Use a fresh isolated test environment when repeating an independent test campaign.

## Troubleshooting

- **400 HTTPS is required:** apply the configuration script, clear cached Laravel configuration, keep the backend bound to loopback and access it through Caddy. Only the explicitly listed proxy IPs may assert HTTPS.
- **Certificate warning:** check that Edge trusts the root generated by your current Caddy data directory. Replacing the Caddy data directory generates a different root. Keep validation enabled.
- **502:** start the API and static Flutter servers on ports 8000 and 5000.
- **Changes do not appear:** rebuild Flutter, restart the static server if needed and reload the HTTPS page.
- **Separate frontend/API domains:** explicitly list exact HTTPS frontend origins in `CORS_ALLOWED_ORIGINS`; the supplied same-origin proxy needs no CORS allowlist entries. CORS is a browser policy and does not replace authentication or authorization.

The ordinary Week 13 HTTP launch commands are not the secure Week 14 entry point. An explicit debug-only Flutter loopback HTTP option exists for development, but release builds reject it. The API HTTPS requirement cannot be disabled outside local/testing environments.

## Submission boundaries

Submit the source commit/ZIP, Week 14 report, evidence index and genuine safe test/log outputs. Dependency directories, compiled builds, `.env`, databases, local CA keys and browser profiles are excluded from the source archive and can be regenerated using this guide. Confirm the full SA8/IA5 rubric and the instructor's required access before official submission; only the overview requirements were supplied for this update.
