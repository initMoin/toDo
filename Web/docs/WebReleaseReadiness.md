# toDō Web 3.1 release readiness

**Status:** Internal development build. Not approved for public deployment.

This document is the current release gate for the Web product. It reconciles
the attached blockers register with the implementation in this repository.
The blockers register is a status and requirements source; it is not an
instruction to claim unfinished work as complete.

## Verification evidence

**Checked September 6, 2026**

- Passed: Web TypeScript compilation, lint, production build, rendered-route
  and browser-boundary tests (6/6), and whitespace validation.
- Added August 24, 2026: Playwright browser smoke coverage for the
  username-first provider reveal, direct route responses, legal-page boundary,
  and nested Settings URLs. The suite is local and non-mutating.
- Added August 27, 2026: the shared Web link boundary disables Vinext RSC
  prefetching, which prevents the deployed mixed-chunk `ee is not a function`
  runtime error from firing before navigation. The local browser suite now
  asserts that primary routes emit no console errors. The corrected build is
  deployed; the live browser console regression check remains part of the
  authenticated browser/device matrix.
- Added September 9, 2026: the Web primary-auth slice now includes verified-email
  code entry, email/password fallback, passkey sign-in, existing MFA
  challenges, and Account Security status-only reporting. Credential and factor
  enrollment/management remain native-app responsibilities.
- Added September 5, 2026: Web now blocks resolved account data behind the
  enrolled TOTP challenge, supports authenticator enrollment/removal in Account
  Security, and requires `aal2` for export, reset, deletion, provider linking,
  and credential changes according to the account security contract.
- Added September 5, 2026: native-app credential changes continue through the
  Supabase reauthentication code when the session is no longer recent; Web
  Account Security reports passkey status without management controls.
- Added September 5, 2026: the opt-in Playwright release layer can verify a
  disposable account's password-plus-TOTP sign-in, toDō+ entitlement, protected
  route access, and JSON export without storing credentials or mutating data.
- Operator-confirmed August 31, 2026: hosted Supabase Auth has been configured
  for the account-security work. Remaining Auth gates are platform behavior,
  passkey-origin verification, MFA challenge coverage, and production delivery;
  the Dashboard setup itself should not be repeated.
- Passed: Web Push and calendar-feed Edge Function type checks with Deno.
- Passed: sync webhook authorization tests (5/5), including fail-closed
  missing-secret behavior, rotation, legacy bearer compatibility, and invalid
  credentials.
- Passed August 23, 2026: local Supabase pgTAP/RLS suite (47/47). The four
  local Vault-configuration warnings are expected: the local environment does
  not contain the production sync-webhook secrets, and the trigger correctly
  fails closed without them.
- Confirmed in source: the Web client contains only browser-safe Supabase and
  VAPID public-key configuration; no service-role, VAPID private key, or
  webhook secret is referenced by browser code.
- Confirmed in source: the Android Digital Asset Links declaration is public
  and uses the exact Google Play App Signing identity for
  `dev.iamshift.toDo.android`. It includes both
  `delegate_permission/common.handle_all_urls` for Android App Links and
  `delegate_permission/common.get_login_creds` for Credential Manager/passkey
  credential sharing.
- Confirmed in source: the canonical Web Push/calendar migration and both
  related Edge Functions are present in the linked Supabase checkout.
- Verified August 24, 2026 from the authenticated Supabase CLI: the linked
  project has active `todo-web-push` and `todo-calendar-feed` functions, and
  the required VAPID and Web Push webhook secret names are configured. Secret
  values were not read or exposed.
- Verified August 24, 2026 over HTTPS: `https://do.yourtodo.today/` returned
  `200`, confirming that the intended custom hostname currently resolves to a
  live Web deployment.
- Verified September 6, 2026 over production HTTPS:
  `https://do.yourtodo.today/.well-known/assetlinks.json` returned `200` with
  `application/json`, no redirect, package `dev.iamshift.toDo.android`, the
  Google Play App Signing certificate fingerprint, and both Android App Links
  and Credential Manager relations. Android device-level App Links and passkey
  verification remain pending.

## Latest linked Supabase result

**Checked August 24, 2026 from the authenticated Supabase CLI**

The linked migration catalog is aligned through
`20260821130000_add_relation_tombstone_key.sql`. This shared sync-correctness
migration expands `sync_tombstones` to include `related_record_id`, preserving
distinct deleted `todo_tags` relations during sync. The local test suite passed
before application, and the operator confirmed the remote catalog afterward.

The following checks could not be completed from this environment:

- Authenticated Supabase data/RLS checks and valid Push/calendar delivery still
  require a disposable toDō+ account, a real browser permission grant, and a
  calendar client. These checks must not use production personal data.
- Production Push and calendar delivery have not yet been functionally tested
  from a real browser and calendar client.

## Implemented in the current Web codebase

- TypeScript/Vinext foundation, Cloudflare Worker configuration, responsive
  shell, semantic routes, browser Back/Forward handling, and explicit
  loading, empty, error, setup, unauthenticated, and entitlement states.
- Supabase browser boundary using only the project URL and publishable key.
- Username-first account resolution, verified-email code entry,
  email/password fallback, passkey entry points, Apple/Google backup OAuth,
  returning-session handling, provider account boundaries, migration handling,
  and mismatch protection.
- toDō+ access gating through `current_account_entitlements`.
- Authenticated ToDo retrieval and presentation.
- ToDo create/edit/complete/reopen/archive/trash/restore/permanent-delete
  flows, with notes, due dates/times, reminder intent, recurrence, Tags,
  NanoDos, and Collab assignment.
- Basic Collabs: load existing Collabs, create a Collab, and assign ToDos.
- Account/Profile, profile-image crop finalization, Settings subviews,
  onboarding, Stats, JSON export, personal-data reset, and account-deletion
  controls.
- Web Push subscription registration and notification preference controls.
- Private calendar-feed token creation and revocation controls.
- Shared Web preference storage for ordering, grouping, reverse order, default
  due time, tag visibility, completion handling, appearance, and notification
  choices.
- Refetch after lifecycle mutations and on browser focus, reconnect, page
  restore, visibility return, and Supabase access-token refresh.
- Explicit partial-save recovery when the parent ToDo saves but NanoDos or Tag
  relations fail.

## Explicit 3.1 Collab contract

The frozen Web 3.1 contract is intentionally reduced:

- included: existing Collab retrieval;
- included: Collab creation;
- included: assigning a ToDo to a Collab;
- deferred: invitations and invitation links;
- deferred: acceptance, decline, expiration, member lists, roles, removal,
  leaving, deletion, entitlement limits, and Collab-specific notifications.

The UI and public-facing Web documentation must not imply that the deferred
membership workflows are available.

## Release gates still open

### Production integrations

- Verify the deployed Web Push path with the configured production VAPID
  values, background delivery while the site is closed, multiple
  browsers/devices, denied
  permission, stale-subscription cleanup, notification deep links, and failure
  logging.
- Verify the private calendar-feed endpoint with valid, invalid, and revoked
  tokens, calendar-client refresh, due dates/times, time zones, deleted ToDos,
  recurring ToDos, and bearer-link security.

### Data integrity and session behavior

- Local behavior is defined for network loss during save, reconnect, stale
  tabs, remote deletion, and expired authentication: confirmed reads remain
  authoritative, active views refetch when the browser becomes active again,
  and a failed detail-graph save is surfaced as a partial-save error with an
  explicit reload action.
- Cross-platform simultaneous edits and conflict resolution remain last-write
  wins at the remote API boundary; offline-first persistence is not part of
  3.1.
- Validate authorized and unauthorized production-equivalent RLS operations
  for personal ToDos, Collabs, NanoDos, Tags, lifecycle changes, reset, and
  account deletion.

### Functional browser coverage

The opt-in authenticated Playwright layer now covers password-plus-TOTP session
setup, entitlement gating, protected route access, and export. Extend it with a
disposable account for OAuth, passkeys, ToDo CRUD/lifecycle, recurrence, Tags,
NanoDos, basic Collabs, reset/delete, Push registration, calendar-feed controls,
responsive layout, session expiry, failed mutations, and reconnect behavior.
The automated public and authenticated smoke layers do not replace the full
production matrix.

### Authentication configuration and assurance

- Operator-confirmed complete: the aligned hosted Supabase Auth settings cover
  email confirmation, manual identity linking, eight-character minimum
  passwords, secure password changes, six-digit/ten-minute email codes, and
  TOTP enrollment/verification. The live behavior still needs the disposable
  account/browser verification below.
- Configure production SMTP before email verification or recovery is opened to
  non-team addresses.
- Finalize and enable Passkeys only after the relying-party ID and Web, iOS,
  and Android origins are fixed. Changing the relying-party ID invalidates
  existing passkeys.
- Verify the Web MFA challenge and `aal2` enforcement with a disposable account
  in each supported browser before public release.
- Configure SMS only after the messaging provider, rate limits, costs, and
  recovery policy are approved.

### Legal and public-release readiness

- Finalize Privacy Policy and Terms of Use.
- Verify Web Push, calendar-feed, export, deletion, entitlement, and
  third-party-service disclosures.
- Remove the internal-review wording from the legal shell only after that
  review is complete.
- Obtain separate public-release approval before publishing the currently
  internal Worker beyond the development audience.

### Operator sequence for the remaining external checks

1. Completed: authenticate the CLI, validate the local pgTAP/RLS suite, apply
   `20260821130000_add_relation_tombstone_key.sql`, and verify the linked
   migration catalog is aligned.

2. Completed: deploy `todo-web-push` and `todo-calendar-feed`, and configure
   the production VAPID and Web Push webhook secrets. Never place those private
   values in `Web/.env.local` or Cloudflare browser-exposed variables.

3. Completed September 6, 2026: the Cloudflare Worker is bound to
   `do.yourtodo.today`; authenticated Wrangler deployment, the custom-domain
   trigger, HTTPS response, and Digital Asset Links endpoint were verified.

4. Execute the authenticated browser/device matrix for OAuth, toDō+ gating,
   RLS, Push, calendar feeds, deletion/export, responsive routes, session
   expiry, and reconnect behavior. Record the results before requesting
   deployment approval.

## Next phase order

1. Validate production-equivalent RLS and deployed Push/calendar paths.
2. Extend the Playwright suite with the authenticated matrix.
3. Finalize legal copy and perform a release review.
4. Request deployment approval and configure the Cloudflare custom domain.

Additional named themes and richer desktop multi-column presentation remain
post-3.1 enhancements and should not delay these gates.
