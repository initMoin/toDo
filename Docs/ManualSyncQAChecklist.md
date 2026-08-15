# Manual Sync QA Checklist

Use this checklist before any release that changes storage, sync, auth, notifications, or ToDo mutation behavior.

## Devices

- Device A: iPhone or iPad, signed into the same Apple ID/ToDo account used for testing.
- Device B: second Apple device, signed into the same Apple ID/ToDo account used for testing.
- Supabase Dashboard: SQL Editor and Edge Function logs available.
- Xcode console open for both devices when testing app-side behavior.

## This Device Only

1. Install a fresh build.
2. Select `This Device Only`.
3. Create a ToDo with:
   - task text
   - notes
   - due date
   - recurrence
   - tag
   - NanoDo
4. Relaunch the app.
5. Expected app result:
   - ToDo remains visible on the same device.
   - No account sign-in is required.
   - Sync status does not imply remote sync.
6. Expected backend result:
   - No new Supabase `todos`, `tags`, or `nanodos` rows are required for this local-only ToDo.

## Sync With iCloud

1. On Device A, select `Sync with iCloud`.
2. Confirm the relaunch notice.
3. Relaunch ToDo.
4. Create or edit a ToDo on Device A.
5. Open ToDo on Device B using `Sync with iCloud`.
6. Expected app result:
   - Device B receives the iCloud-backed ToDo.
   - Local-only and ToDo Sync scoped data should not be silently mixed unless the migration prompt was accepted.
   - Sync mode shows `Active` after relaunch.

## ToDo Sync

1. On Device A and Device B, select `ToDo Sync`.
2. Sign in with the same Apple or Google account.
3. Confirm Account/Identity displays the provider and email/name when available.
4. Open `Settings > Sync Diagnostics` on both devices.
5. Confirm both devices show:
   - Preferred: `ToDo Sync`
   - Active: `ToDo Sync`
   - State: `Active`, `Waiting to Sync`, or `Syncing`
   - APNs: `Push ready`
6. Create a ToDo on Device A.
7. Keep Device B open in the foreground.
8. Expected foreground result:
   - Device B receives the ToDo through Supabase Realtime.
   - Sync status should show meaningful states such as `Waiting to Sync`, `Checking Account`, `Applying Updates`, or `Sync Complete`.
9. Background Device B.
10. Edit the ToDo on Device A.
11. Reopen Device B.
12. Expected background result:
   - Device B should refresh from APNs silent push when iOS grants background execution, or refresh on reopen.
   - Supabase Edge Function logs should show accepted APNs sends for active device tokens.

## Mode Switching

Run each transition once with `Move Current ToDos`, then once with `Start Fresh`:

- `This Device Only` to `ToDo Sync`
- `ToDo Sync` to `This Device Only`
- `This Device Only` to `Sync with iCloud`
- `Sync with iCloud` to `This Device Only`
- `Sync with iCloud` to `ToDo Sync`
- `ToDo Sync` to `Sync with iCloud`

Expected behavior:

- The first confirmation explains what changes.
- The second confirmation asks whether to move current ToDos or start fresh when migration is relevant.
- iCloud transitions show a relaunch notice.
- The selection view remains visible and shows visual confirmation.
- No transition should duplicate existing ToDos.
- No transition should delete local data unless the user selected a destructive path or delete mirroring preference applies.

## Conflict Review

1. Put Device B offline.
2. Edit the same synced ToDo on Device A and Device B.
3. Bring Device B online.
4. Expected app result:
   - The ToDo is marked as `Sync Needs Review`.
   - Settings shows the conflict review entry.
   - Choosing `Keep This Device` requires confirmation and uploads the local version.
   - Choosing `Use Synced` requires confirmation and replaces local fields with the synced version.

## Supabase Verification SQL

Active APNs tokens:

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

Recent push outbox rows:

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

Recent ToDos:

```sql
select
  id,
  user_id,
  task,
  is_done,
  lifecycle_state,
  created_at,
  updated_at
from public.todos
order by updated_at desc nulls last, created_at desc
limit 20;
```

Realtime publication:

```sql
select schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
  and schemaname = 'public'
  and tablename in ('todos', 'tags', 'nanodos', 'todo_tags', 'sync_tombstones')
order by tablename;
```

## Console Signals

Expected:

- `ToDo Sync: Sync started`
- `ToDo Sync: Sync phase`
- `ToDo Sync: Sync completed`
- `APNs token registered` in `Settings > Sync Diagnostics`

Needs investigation:

- `Supabase sync bootstrap failed`
- `Supabase local push failed`
- `Supabase remote refresh failed`
- `Maximum retry attempts reached`
- `PostgrestError`
- duplicated ToDos after mode switching
