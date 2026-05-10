# Supabase Push Notifications for ToDo Sync

This setup adds background sync nudges for ToDo Sync. Foreground sync still uses Supabase Realtime; this path is for devices that are not actively connected when another device changes ToDos.

## What Was Added

- `supabase/functions/todo-sync-push/index.ts`
  - Supabase Edge Function that sends silent APNs pushes.
  - Reads active iOS APNs tokens from `public.device_tokens`.
  - Sends `todoSync: "refresh"` so the app calls `SyncCoordinator.refreshFromRemote`.

- `supabase/migrations/20260508211000_add_todo_sync_push_events.sql`
  - Creates `public.sync_push_events` as a push outbox.
  - Adds triggers on `todos`, `tags`, `nanodos`, `todo_tags`, and `sync_tombstones`.
  - Each sync data change inserts one outbox row.

## Apple Credentials Needed

Do not commit the `.p8` file.

You need these values from Apple Developer:

- `APNS_SANDBOX_KEY_ID`: Key ID for the sandbox/development APNs `.p8` key.
- `APNS_SANDBOX_TEAM_ID`: Apple Developer Team ID for the sandbox/development key. Optional if it matches `APNS_TEAM_ID`.
- `APNS_SANDBOX_PRIVATE_KEY_BASE64`: base64-encoded contents of the sandbox/development `.p8` file.
- `APNS_PRODUCTION_KEY_ID`: Key ID for the production APNs `.p8` key.
- `APNS_PRODUCTION_TEAM_ID`: Apple Developer Team ID for the production key. Optional if it matches `APNS_TEAM_ID`.
- `APNS_PRODUCTION_PRIVATE_KEY_BASE64`: base64-encoded contents of the production `.p8` file.
- `APNS_TEAM_ID`: shared Apple Developer Team ID fallback.
- `APNS_BUNDLE_ID`: `dev.iamshift.ToDo-TaskManagement` unless the bundle ID changes.
- `SUPABASE_SERVICE_ROLE_KEY`: Supabase service role key. Supabase provides this automatically inside Edge Functions; do not worry if the CLI skips it from local env files.

## App-Side Requirements

Confirm these stay enabled before release:

- App ID capability: Push Notifications.
- App ID capability: Time Sensitive Notifications.
- App entitlement: `aps-environment`.
- App background mode: `remote-notification`.
- App background mode: `fetch` if foreground/manual refresh fallback remains enabled.
- Runtime notification authorization requested from the user.
- A signed-in ToDo Sync account, so the app can upsert the APNs token into `public.device_tokens`.

In the app, use `Settings > Sync Diagnostics` to confirm:

- Permission is `Allowed`, `Provisional`, or `Ephemeral`.
- APNs is `Push ready`.
- Token suffix is visible.
- Preferred and Active mode are both `ToDo Sync`.

Optional:

- `APNS_ENVIRONMENT`: `sandbox` or `production`. Device token rows already store environment, so this is only a fallback.
- `APNS_KEY_ID` and `APNS_PRIVATE_KEY_BASE64`: legacy single-key fallback. Prefer the sandbox/production-specific variables above for production apps.
- `TODO_SYNC_PUSH_DEBUG_LOGS`: `true` only while diagnosing APNs delivery. Leave unset for production.
- `SYNC_PUSH_EVENT_RETENTION_DAYS`: number of days to keep rows in `sync_push_events`; defaults to `7`.

## APNs Environments

Use matching APNs credentials for the token environment:

- Xcode/debug installs register sandbox APNs tokens. The Edge Function uses `APNS_SANDBOX_*` for those tokens.
- TestFlight/App Store installs register production APNs tokens. The Edge Function uses `APNS_PRODUCTION_*` for those tokens.
- `BadEnvironmentKeyInToken` means the APNs key does not match the endpoint/token environment.
- The app stores each token's environment in `public.device_tokens.environment`; the Edge Function uses that row value before falling back to `APNS_ENVIRONMENT`.
- Keeping both sandbox and production secrets configured lets debug and TestFlight/App Store devices coexist in the same Supabase project.

## Local Secret File

Create a local file that is never committed, for example `supabase/.env.todo-sync-push`:

```sh
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
APNS_TEAM_ID=your-apple-team-id
APNS_BUNDLE_ID=dev.iamshift.ToDo-TaskManagement
APNS_SANDBOX_KEY_ID=your-sandbox-key-id
APNS_SANDBOX_PRIVATE_KEY_BASE64=base64-encoded-sandbox-p8-file
APNS_PRODUCTION_KEY_ID=your-production-key-id
APNS_PRODUCTION_PRIVATE_KEY_BASE64=base64-encoded-production-p8-file
APNS_ENVIRONMENT=sandbox
SYNC_PUSH_EVENT_RETENTION_DAYS=7
```

To base64 encode the `.p8` file:

```sh
base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n'
```

## Deploy

```sh
supabase functions deploy todo-sync-push
supabase secrets set --env-file supabase/.env.todo-sync-push
```

## Apply SQL

Apply this migration in Supabase SQL Editor or via Supabase CLI:

```sh
supabase db push
```

If applying manually, paste the contents of:

```text
supabase/migrations/20260508211000_add_todo_sync_push_events.sql
```

## Database Webhook

In Supabase Dashboard:

1. Go to Database Webhooks.
2. Create a webhook.
3. Table: `sync_push_events`.
4. Event: `Insert` only.
5. Type: Supabase Edge Function.
6. Function: `todo-sync-push`.
7. Method: `POST`.
8. Headers: add auth header with service key.
9. Timeout: `1000` ms is acceptable to start.

## Test

1. Deploy the app to two physical devices.
2. Sign into the same ToDo Sync account on both.
3. Confirm notifications are authorized so APNs registration stores device tokens.
4. Open `Settings > Sync Diagnostics` on each device and confirm APNs shows `Push ready`.
5. Background Device 2.
6. Add or edit a ToDo on Device 1.
7. Device 2 should receive a silent push and refresh when iOS grants background execution.

Silent pushes are delivery hints, not guaranteed immediate execution. Foreground/open app sync remains Supabase Realtime.

## Verification Queries

Confirm each signed-in device has an active APNs token:

```sql
select
  user_id,
  platform,
  push_provider,
  app_bundle_id,
  environment,
  is_active,
  last_seen_at,
  created_at
from public.device_tokens
where push_provider = 'apns'
order by last_seen_at desc;
```

Confirm database mutations are creating push outbox rows and being processed:

```sql
select
  id,
  source_table,
  mutation_type,
  created_at,
  processed_at
from public.sync_push_events
order by created_at desc
limit 20;
```

Confirm Realtime is enabled for every ToDo Sync table:

```sql
select schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
  and schemaname = 'public'
  and tablename in ('todos', 'tags', 'nanodos', 'todo_tags', 'sync_tombstones')
order by tablename;
```

Expected rows:

```text
nanodos
sync_tombstones
tags
todo_tags
todos
```

## Environment Checklist

- Debug/Xcode-installed builds should write `sandbox` into `public.device_tokens.environment`.
- TestFlight/App Store builds should write `production`.
- Sandbox tokens require `APNS_SANDBOX_KEY_ID` and `APNS_SANDBOX_PRIVATE_KEY_BASE64`.
- Production tokens require `APNS_PRODUCTION_KEY_ID` and `APNS_PRODUCTION_PRIVATE_KEY_BASE64`.
- `APNS_BUNDLE_ID` must match the app bundle identifier exactly.
- `BadEnvironmentKeyInToken` means the function is using the wrong APNs key for that token's environment.
- `TODO_SYNC_PUSH_DEBUG_LOGS=true` belongs in Supabase Edge Function secrets only while diagnosing delivery.

## Logs

By default, the Edge Function logs failures only. To temporarily log accepted APNs sends and masked APNs metadata, set:

```sh
TODO_SYNC_PUSH_DEBUG_LOGS=true
```

Unset it again after validation so production logs stay quiet.

## Cleanup

The Edge Function deletes `sync_push_events` rows older than `SYNC_PUSH_EVENT_RETENTION_DAYS` after each webhook run. The SQL helper can also be run manually:

```sql
select public.delete_old_sync_push_events(interval '7 days');
```
