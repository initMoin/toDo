# toDō Web authentication contract

**Status:** Implemented Web account and TOTP foundation; production verification pending
**Last updated:** September 5, 2026

## Account model

The immutable Supabase `auth.users.id` remains the canonical account owner.
The public username identifies the toDō account but does not authenticate it.
All passwords, passkeys, provider identities, MFA factors, ToDos, Collabs,
entitlements, and profile data remain attached to that UUID.

```text
Username → verified private email → passkey/password → optional MFA
                                      ↘ Apple/Google backup identities
```

The Web client must never merge or link accounts because a username, email
address, display name, or provider payload appears to match.

## Progressive UX

### Create account

1. Enter a username.
2. Enter a private email address.
3. Send a short-lived verification code.
4. Enter the code in a dedicated setup view or sheet.
5. Claim the username for the authenticated account.
6. Offer **Create a passkey** as the recommended next step.
7. Offer **Create a password** as an optional fallback.
8. Offer TOTP and optional SMS backup in Security settings.
9. Offer Apple and Google under backup sign-in methods.

Only the current step should be visible. Do not present every provider and MFA
choice on the first screen.

### Returning sign-in

1. Enter username.
2. Present **Use passkey** when supported.
3. Present **Use password** as the fallback.
4. Offer **Use email code** only as recovery or when the user requests it.
5. Keep Apple and Google under **Other sign-in methods**.
6. If MFA is enrolled, require its challenge before opening account data.

### Account Security view

Show status rows for:

- Verified email
- Passkeys
- Password
- Authenticator app
- Text messages
- Apple
- Google

Each row opens a focused setup, verification, or management flow. Never expose
passwords, passkey private keys, TOTP secrets, or SMS credentials.

## Security rules

- Passwords use Supabase email/password authentication; username is not passed
  directly to `signInWithPassword`.
- Passkeys use WebAuthn and are managed by the browser/OS authenticator. The
  current Supabase passkey API is experimental, so the Web implementation must
  pin and test the supported client version before enabling production use.
- Apple and Google use Supabase OAuth as optional backup identities. Linking
  begins from an authenticated account and must preserve its UUID.
- Email codes verify email ownership and support recovery. They are never
  stored in local persistence or used as a substitute for TOTP MFA.
- TOTP is the preferred MFA factor. SMS is optional fallback with rate limits,
  abuse monitoring, cost controls, and explicit recovery language.
- Require a recent `aal2` session for provider linking, credential changes,
  data export, account deletion, and MFA-management changes.
- Before allowing mandatory MFA, require a second recovery factor. The current
  Supabase MFA flow does not provide recovery codes.

## Account-state boundaries

An account cannot enter normal sync or display synced data until:

1. the Supabase session is valid;
2. the profile has a valid username;
3. the email setup requirement is complete; and
4. any enrolled MFA challenge has reached the required assurance level.

An unresolved, provisional, mismatched, or recovery-only session must remain in
an explicit setup/recovery state.

## Browser persistence rules

- Session persistence is delegated to Supabase's browser client.
- Short-lived setup state may use memory or `sessionStorage` only.
- Do not store passwords, OTPs, TOTP seeds, phone verification data, recovery
  tokens, or passkey material in `localStorage`, IndexedDB, cookies created by
  application code, URLs, analytics events, or logs.
- Clear pending setup state on success, cancellation, sign-out, timeout, and
  account switch.

## Required test coverage

- Email code success, expiry, resend cooldown, invalid code, and rate limiting.
- Username collision without account reassignment.
- Password creation, sign-in, reset, and session expiration.
- Passkey enrollment, sign-in, cancellation, unsupported browser, and renamed
  or removed credential.
- TOTP enrollment, challenge, failed code, second-factor recovery, and
  unenrollment safeguards.
- SMS enrollment, challenge, rate limiting, fallback, and revoked phone.
- Apple/Google linking preserves the canonical UUID and rejects identities
  already attached to another account.
- Browser reload, multiple tabs, sign-out, account switching, and stale OAuth
  callbacks do not leak or cross account state.

## Current Web implementation

The Web client now resolves Supabase MFA state before loading profile or synced
data. If a verified TOTP factor is enrolled and the current session is `aal1`,
the application remains in a blocking authenticator challenge until Supabase
returns an `aal2` session.

Account Security supports TOTP enrollment, QR/setup-key presentation,
verification, and removal. It also lists registered passkeys and supports
adding, renaming, and removing them. Password updates continue through the
Supabase secure-change verification code when the session is no longer recent.

Password changes, passkey changes, and provider linking require `aal2` when an
MFA factor exists. Export, account-data reset, and account deletion require an
enrolled and currently verified factor. The account-deletion Edge Function
also checks recent `aal2` independently; the browser check is not treated as a
server authorization boundary.

SMS remains unavailable until its provider, cost limits, abuse controls, and
recovery behavior are approved.
