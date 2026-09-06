# Web browser testing

The Web package has two complementary test layers:

- `npm test` builds the Worker output and verifies every documented route and
  source boundary without requiring a browser session.
- `npm run test:browser` starts the local Web server and exercises the public
  browser contract with Playwright.

The public browser suite does not invent a signed-in user or mutate Supabase
data. It verifies the username-first sign-in transition, direct route
responses, legal-page boundaries, and nested Settings URLs.

An opt-in authenticated layer verifies password plus TOTP sign-in, the toDō+
entitlement boundary, protected routes, and account export. It runs only when
all four disposable-account values below are present. The values are read from
the process environment and must never be committed.

## Local run

From `Web/`:

```sh
npm run typecheck
npm run test
npx playwright install chromium
npm run test:browser
```

Set `PLAYWRIGHT_BASE_URL` when testing an already-running local or internal
deployment:

```sh
PLAYWRIGHT_BASE_URL=https://do.yourtodo.today npm run test:browser
```

## Authenticated run

Create a disposable account with an active toDō+ entitlement, a verified
email, a password, and an authenticator factor. Add an ignored `.env.e2e` file
inside `Web/`:

```dotenv
TODO_E2E_USERNAME=disposable-username
TODO_E2E_EMAIL=disposable@example.com
TODO_E2E_PASSWORD=disposable-password
TODO_E2E_TOTP_SECRET=BASE32-SETUP-KEY
```

Run only the authenticated layer with:

```sh
npm run test:browser:authenticated
```

Use the authenticator setup key, not a current six-digit code; the test derives
a fresh code in memory. Playwright traces, screenshots, and video are disabled
for the authenticated suite so credentials cannot be captured in its normal
artifacts. `.env.e2e` is covered by the repository's `.env*` ignore rule; keep
it local and remove it when the disposable account is retired.

OAuth, passkey registration, ToDo mutations, account deletion, Web Push,
calendar-client refresh, session expiry, reconnects, and production-equivalent
RLS authorization remain operator checks. Keep using disposable accounts and
never commit browser storage state or provider credentials.
