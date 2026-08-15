# Supabase Hardening and Replayable Baseline

## Current Status

Migration-history reconciliation is complete. All 24 historical local versions through
`20260716190000` match production, and the linked dry run was current before this
hardening work began.

Two new forward migrations are implemented locally but are **not deployed**:

1. `20260717133245_harden_sync_webhook_secret.sql`
2. `20260717140500_bound_sync_push_outbox_cleanup.sql`

The linked dry run recognizes exactly these two pending files.

## Why These Changes Exist

The production database webhook currently exposes a literal authentication secret in
its trigger definition. A schema dump therefore reproduces the credential. The
replacement trigger reads its endpoint and secret from Supabase Vault at runtime and
passes the secret to an Edge Function that fails closed when authentication is not
configured.

The push outbox also had an unbounded cleanup path. The replacement deletes an
oldest-first bounded batch, uses a supporting index, and schedules a daily batch when
`pg_cron` is available. Successful webhook runs retain an opportunistic 1,000-row
cleanup call.

## Zero-Downtime Production Rollout

Do not place secret values in source, migration SQL, terminal history, screenshots, or
this document.

### 1. Prepare a New Secret

Generate a cryptographically random value and keep it in a password manager for the
duration of the rotation. The old secret remains valid during the overlap.

### 2. Add the Rotation Secret to the Edge Function

In the production project's Edge Function secrets, retain the existing
`TODO_SYNC_PUSH_WEBHOOK_SECRET` and add the new value as:

`TODO_SYNC_PUSH_WEBHOOK_SECRET_ROTATION`

This permits both credentials only during the controlled rotation window.

### 3. Deploy the Updated Edge Function

Deploy `todo-sync-push` from the authoritative backend directory. Its function config
uses `verify_jwt = false` because the database trigger authenticates with the dedicated
rotating webhook secret. The function itself now returns:

- `503` when no webhook secret is configured
- `401` when a request has no valid secret
- normal processing only when the primary or rotation secret matches

### 4. Store Runtime Configuration in Vault

Create or update these production Vault secrets:

| Vault name | Value |
| --- | --- |
| `todo_sync_push_webhook_url` | Production `todo-sync-push` Edge Function URL |
| `todo_sync_push_webhook_secret` | New rotation secret |

Do not save the old secret in Vault. Vault should immediately use the new credential,
while the Edge Function temporarily accepts both.

### 5. Obtain Explicit Deployment Approval

Implementation approval does not automatically authorize production mutation. Before
running a non-dry-run database push or deploying the Edge Function, confirm the exact
production project, two pending migrations, deployment order, backup/rollback plan,
and test window with the project owner.

### 6. Apply the Forward Migrations

Run a final linked dry run. If it still lists only the two expected `20260717...`
migrations, apply them once. Do not edit or replace any previously applied migration.

### 7. Verify Delivery

Create or update one non-critical test toDō. Verify:

- the mutation succeeds even if push delivery is unavailable;
- one `sync_push_events` row is processed;
- the Edge Function accepts the Vault-backed secret;
- APNs delivery has the expected result;
- `net._http_response` contains no authentication failure for the request;
- no trigger definition contains the project URL or literal secret;
- the daily `todo-sync-push-outbox-cleanup` cron job exists when `pg_cron` is enabled.

### 8. Complete Rotation

Promote the new value to `TODO_SYNC_PUSH_WEBHOOK_SECRET`, remove
`TODO_SYNC_PUSH_WEBHOOK_SECRET_ROTATION`, redeploy, and verify another mutation. The
old secret is then invalid everywhere.

## Rollback Boundary

If the new Edge Function rejects the Vault credential, restore the previous Edge
Function deployment while keeping the database migrations in place, then correct the
function secret configuration. Do not reintroduce a literal trigger secret. The new
trigger deliberately catches webhook enqueue failures so a push outage does not roll
back user data.

## Replayable Baseline Strategy

The historical migration chain cannot initialize an empty database because early
migrations reference tables created later. Already-applied migrations must remain
immutable, so this is not repaired by reordering or editing history.

A baseline cutover is a separate operation:

1. Deploy and verify webhook hardening first.
2. Run `supabase/scripts/generate_sanitized_baseline.sh` to create a schema-only review
   artifact outside the repository.
3. Confirm the tool rejects any dump containing the legacy webhook helper, fixed
   production endpoint, or a known local secret/key value.
4. Review the dump for managed Supabase objects that should not be owned by app
   migrations.
5. Add a small companion migration for contracts not captured by a `public`-schema
   dump, including the `auth.users` profile trigger and required Realtime publication
   membership.
6. Preserve required historical data transformations as explicit idempotent backfill
   migrations. A schema dump alone is not enough.
7. Initialize a disposable Supabase project from the candidate baseline.
8. Run all database contract and RLS tests, including
   `sync_push_hardening.test.sql`.
9. Exercise sign-in, sync, profile access, Collab access, Watch sync, IAP linking,
   notifications, and Live Activities against the disposable project.
10. Compare disposable and production schema contracts.
11. Only after review, archive the legacy chain and perform a controlled migration
    history cutover. Never run `db reset --linked` against production.

No baseline cutover is approved or performed by the current hardening work.

## Verification Completed Locally

- Edge Function TypeScript type-check: passed
- Webhook authentication unit tests: 5 passed, 0 failed
- Secret scan outside ignored environment and dependency directories: no literal
  production webhook credential or fixed endpoint found in new source
- Linked migration dry run: exactly two pending forward migrations recognized
- Production deployment: not performed
- Database pgTAP execution: pending a disposable database with the complete schema
