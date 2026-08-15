# Step 02: Production Database Migrations

## Objective

Deploy the three pending Collab, profile, and shared-toDō migrations to the correct Supabase
production project, verify their schema and policy effects, and preserve a clear
forward-recovery path.

## Mandatory Approval Boundary

Do not run `supabase db push` until the product owner explicitly approves the
production deployment. The linked production project currently has migration-history
drift: `supabase migration list` reports older local migrations that are not recorded
remotely. A blind push could therefore execute unrelated historical migrations.
Inspection, login, project verification, and migration listing may be completed first.

## Migrations

Apply these authoritative files in timestamp order:

1. `/Users/shift/Development/Mobile/2026/Feb/ToDo/supabase/migrations/20260716120000_add_collabs.sql`
2. `/Users/shift/Development/Mobile/2026/Feb/ToDo/supabase/migrations/20260716180000_add_collab_user_profile_access.sql`
3. `/Users/shift/Development/Mobile/2026/Feb/ToDo/supabase/migrations/20260716190000_add_collab_todos.sql`

The physical schema uses the same vocabulary as the product: `collabs`,
`collab_users`, `collab_invitations`, and the roles `owner` and `user`.

## Pre-Deployment Review

1. Open all three migration files and confirm they are unchanged from the reviewed
   candidate.
2. Confirm production backups and point-in-time recovery are enabled according to
   the project plan.
3. Open Supabase Dashboard and verify the selected project is **ToDo _prod** with
   project ref `kddeevmuyevhgoyvrdlc`.
4. Review the migration history for out-of-band production changes.
5. Confirm no unrelated migration is unexpectedly pending.

## CLI Procedure

Run commands from the outer checkout that contains the authoritative `supabase`
directory:

```sh
cd /Users/shift/Development/Mobile/2026/Feb/ToDo
supabase login
supabase projects list
supabase link --project-ref kddeevmuyevhgoyvrdlc
supabase migration list
```

### Stop on migration-history drift

The current production history is not aligned with the authoritative local migration
directory. If `supabase migration list` shows any older locally-only migration, stop.
Do not run `supabase db push`, including `--dry-run`, and do not use `migration repair`
merely to make the columns appear aligned.

After explicit approval, use one of these reviewed paths:

1. Reconcile migration history against the actual production schema, review every
   pending migration, and only then use the CLI; or
2. Apply only the three SQL files above, in timestamp order, through Supabase SQL
   Editor, verify every object below, and record the out-of-band deployment before
   any later CLI migration operation.

No production write is authorized by this document.

## Database Verification

Run the following in Supabase SQL Editor after deployment.

### Confirm new columns

```sql
select table_schema, table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and (
    (table_name = 'todos' and column_name = 'collab_id')
    or (table_name = 'sync_tombstones' and column_name = 'collab_id')
  )
order by table_name, column_name;
```

Expected: one `collab_id` row for each table, both typed as `uuid`.

### Confirm RPC and helper functions

```sql
select n.nspname as schema_name,
       p.proname as function_name,
       pg_get_function_identity_arguments(p.oid) as arguments
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'collab_user_profiles_for_collab',
    'is_collab_user',
    'is_collab_owner',
    'can_access_collab_todo',
    'can_delete_collab_todo',
    'can_access_collab_tag'
  )
order by p.proname;
```

Expected: all six functions exist.

### Confirm indexes

```sql
select schemaname, tablename, indexname, indexdef
from pg_indexes
where schemaname = 'public'
  and indexname in (
    'todos_collab_id_idx',
    'sync_tombstones_collab_id_deleted_at_idx'
  )
order by indexname;
```

Expected: both partial indexes exist.

### Confirm relevant RLS policies

```sql
select schemaname, tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('profiles', 'todos', 'tags', 'todo_tags', 'nanodos', 'sync_tombstones')
order by tablename, policyname;
```

Review every returned policy. Confirm anonymous access is not introduced and
authenticated policies use the intended helper functions.

### Check display names before validating the constraint

```sql
select id, display_name
from public.profiles
where display_name is not null
  and char_length(btrim(display_name)) not between 1 and 60;
```

Expected: zero rows. If invalid rows exist, do not silently delete or truncate
them. Decide on a reversible data-cleanup migration, then validate the constraint
in a later migration.

## Recovery Rules

- Do not edit an already-applied migration.
- Do not use migration repair merely to make history appear green.
- Do not drop production tables to retry the migration.
- If a migration partially succeeds or verification fails, capture the exact
  database state and write a new, forward-only corrective migration.
- If security is weaker than expected, treat the release as blocked until a
  corrective migration is reviewed, deployed, and retested.

## Pass Criteria

- [ ] Deployment received explicit approval.
- [ ] Project ref was verified before deployment.
- [ ] Migration-history drift was resolved or an approved SQL Editor deployment was recorded.
- [ ] Only the three reviewed migrations were applied.
- [ ] Required columns, functions, indexes, triggers, and policies exist.
- [ ] No anonymous profile or Collab data access was introduced.
- [ ] Invalid display-name state is zero or has an approved remediation.
- [ ] Step 03 authorization tests are ready to run.
