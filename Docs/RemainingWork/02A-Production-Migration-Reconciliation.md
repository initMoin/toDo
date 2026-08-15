# Production Migration Reconciliation

## Scope

This audit compares the authoritative migration files in:

`/Users/shift/Development/Mobile/2026/Feb/ToDo/supabase/migrations`

against a read-only schema dump and catalog queries from the linked production
project. Migration-history repair must only follow verification of the real database
state. It does not execute SQL and must not be used to conceal a missing object.

Audit date: 2026-07-17.

## Completion Update

Production migration history was reconciled successfully on 2026-07-17:

- all 24 historical local and remote versions now match;
- `supabase db push --linked --dry-run` reported the database current immediately
  after reconciliation;
- `20260715193000` was executed and its table, account index, and two RLS policies
  were verified before its history entry was repaired. It remains historical audit
  schema, not the active Legacy eligibility source;
- no historical migration file was reordered, edited, or rerun as part of the repair.

The later Legacy policy is separate from this historical reconciliation. Legacy is
granted by the service-role function in migration `20260804143000`, using the
release cutoff and the server-owned Auth account record. It does not use an Apple
AppTransaction or the historical acquisition-link table.

The remaining webhook hardening and replayable-baseline work is tracked in
`02B-Supabase-Hardening-and-Replayable-Baseline.md`.

## Findings

- `20260322190000` is already recorded in remote migration history. Do not repair or
  rerun it.
- Every later migration through `20260715090000` has its required surviving schema
  contract in production. Historical compatibility migrations have been superseded
  by later definitions, but their final invariants are satisfied.
- `20260715193000_add_apple_app_transaction_grandfathering.sql` is historical audit
  schema only. If its table exists, it must not be treated as the source of Legacy
  eligibility; if it does not exist, do not add it solely for the new Legacy policy.
- `20260804143000_reconcile_legacy_access_by_account_cutoff.sql` is the active Legacy
  policy migration. Apply it once, then run its service-role function after the public
  3.1 release cutoff is known.
- The three `20260716...` Collab/profile/shared-toDō migrations are present in
  production and are recorded as applied.
- Realtime contains `todos`, `tags`, `nanodos`, and `sync_tombstones`.
- The `auth.users` profile-creation trigger exists.
- All Auth users have profile rows; no legacy device rows are missing their copied
  APNs device-token row; task columns satisfy the non-null/default contract; and no
  legacy completion rows violate the lifecycle-state migration.

## Per-Migration Disposition

| Version | Migration | Production evidence | Action |
| --- | --- | --- | --- |
| `20260322190000` | NanoDo tag ID | Column, foreign key, and index exist; already tracked remotely | Do nothing |
| `20260322214752` | Initial schema | Baseline tables, keys, RLS, and owner policies exist; later policies supersede part of the baseline | Mark applied; do not rerun |
| `20260322231402` | Expanded core schema | Expanded columns/tables, triggers, functions, RLS, indexes, and profile rows exist | Mark applied; do not rerun |
| `20260322235500` | Recurrence fields | Recurrence columns, constraints, and index exist | Mark applied; do not rerun |
| `20260322235602` | Time-zone rename | `preferred_time_zone` exists with the UTC default; legacy profile `timezone` is absent | Mark applied; do not rerun |
| `20260323022447` | NanoDo tag relation | Duplicate final contract of `20260322190000`; contract exists | Mark applied; do not rerun |
| `20260323031000` | Legacy app-contract alignment | Canonical task fields and migrated completion/device invariants are satisfied | Mark applied; do not rerun |
| `20260508203000` | Realtime publication | All four required tables are publication members | Mark applied; do not rerun |
| `20260508211000` | Sync push events | Table, policy, index, function, cleanup function, and five triggers exist | Mark applied; do not rerun |
| `20260508213500` | ToDo task correction | Superseded by later hardening; final ToDo task contract is satisfied | Mark applied; do not rerun |
| `20260508215500` | Task hardening | ToDo and NanoDo task columns are non-null with empty-string defaults | Mark applied; do not rerun |
| `20260508221000` | Legacy title unlock | Legacy ToDo title is nullable with an empty-string default and has no null rows | Mark applied; do not rerun |
| `20260509020500` | Push-event cleanup | Cleanup function exists; old rows can accumulate again after the one-time cleanup | Mark applied; do not rerun |
| `20260509024500` | Push-event record IDs | Current trigger function uses `sync_tombstones.record_id` | Mark applied; do not rerun |
| `20260524172000` | Live Activity tokens | Table, indexes, update trigger, RLS, policies, and grants exist | Mark applied; do not rerun |
| `20260524211211` | APNs provider-token cache | Table, expiry index, cleanup function, and service-only RLS exist | Mark applied; do not rerun |
| `20260524212500` | Push installation IDs | Both installation columns and indexes exist | Mark applied; do not rerun |
| `20260620043000` | NanoDo parent completion | Boolean column exists with non-null false default | Mark applied; do not rerun |
| `20260708072000` | Standalone Watch sync | Auth trigger, profile backfill, tag policies, and Watch query indexes exist | Mark applied; do not rerun |
| `20260715090000` | Apple IAP entitlements | IAP tables, indexes, RLS, policies, and effective-entitlements view exist | Mark applied; do not rerun |
| `20260715193000` | Historical Apple acquisition audit | Not used by current entitlement policy | Do not use for Legacy eligibility |
| `20260804143000` | Legacy account-cutoff reconciliation | Service-role function grants Legacy and Founding Supporter idempotently | Apply migration; run function after 3.1 release |
| `20260716120000` | Collabs | Tables, indexes, triggers, RPCs, grants, and RLS policies exist | Mark applied; do not rerun |
| `20260716180000` | Collaborator profile access | Display-name constraint and privacy-limited RPC exist | Mark applied; do not rerun |
| `20260716190000` | Shared toDō records | Columns, indexes, helper functions, triggers, and accessible-record policies exist | Mark applied; do not rerun |

## Historical Acquisition Audit (Optional)

The following section is retained only for operators who deliberately maintain the
old acquisition audit table. It is not required for the current Legacy policy and
must not be substituted for the cutoff reconciliation migration.

In Supabase Dashboard, confirm the production project ref is
`kddeevmuyevhgoyvrdlc`. Open SQL Editor, create a new query, paste the **entire exact
contents** of:

`/Users/shift/Development/Mobile/2026/Feb/ToDo/supabase/migrations/20260715193000_add_apple_app_transaction_grandfathering.sql`

Run it once. Do not paste a migration-history repair command into SQL Editor.

Verify the migration with this read-only query:

```sql
select to_regclass('public.apple_app_transaction_links') as table_name;

select indexname, indexdef
from pg_indexes
where schemaname = 'public'
  and indexname = 'apple_app_transaction_account_idx';

select tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename = 'apple_app_transaction_links'
order by policyname;
```

Expected:

- `table_name` is `apple_app_transaction_links`.
- One `apple_app_transaction_account_idx` row is returned.
- Both `apple_app_transaction_links_select_own` and
  `apple_app_transaction_links_service_write` are returned.

## Migration-History Repair

The historical repair command below is retained as an audit record. Do not rerun it
if the remote migration list already contains these versions. The new
`20260804143000` migration is repaired/applied separately after its SQL is deployed.

Run the following from:

`/Users/shift/Development/Mobile/2026/Feb/ToDo`

```sh
supabase migration repair --linked --status applied \
  20260322214752 \
  20260322231402 \
  20260322235500 \
  20260322235602 \
  20260323022447 \
  20260323031000 \
  20260508203000 \
  20260508211000 \
  20260508213500 \
  20260508215500 \
  20260508221000 \
  20260509020500 \
  20260509024500 \
  20260524172000 \
  20260524211211 \
  20260524212500 \
  20260620043000 \
  20260708072000 \
  20260715090000 \
  20260716120000 \
  20260716180000 \
  20260716190000
```

Then run:

```sh
supabase migration list
supabase db push --linked --dry-run
```

Expected:

- Every local version has the same remote version.
- The dry run reports that the linked project is up to date.

Do not run a non-dry-run `db push` during this reconciliation.

## Reproducibility Defect

The legacy local chain is not clean-replayable from an empty database:

1. `20260322190000` references `nanodos` and `tags` before the later migration that
   creates them.
2. `20260508203000` and `20260508211000` reference `sync_tombstones` before
   `20260716190000` creates it.

Migration-history repair aligns production tracking but does not fix this local replay
defect. Do not edit already-applied files and do not run `supabase db reset --linked`.
After production history is aligned, create and validate a sanitized current-schema
baseline against a disposable local or staging database, preserve required data
migrations manually, and only then perform a reviewed history cutover. That work is a
separate controlled operation.

## Security Repair Required

The production schema dump includes a webhook authorization secret as a literal in a
database trigger definition. Treat that secret as exposed to anyone who can obtain a
schema dump. Do not commit the dump. Rotate the secret and replace the literal-header
trigger with a design that retrieves the secret from approved server-side secret
storage. Review and deploy that repair separately; do not mix it into migration-history
metadata repair.
