begin;

select plan(14);

select has_function(
  'public',
  'invoke_todo_sync_push_webhook',
  array[]::text[],
  'Vault-backed sync-push webhook trigger function exists'
);

select has_function(
  'public',
  'delete_old_sync_push_events_batch',
  array['interval', 'integer'],
  'bounded sync-push cleanup function exists'
);

select isnt_empty(
  $$
    select 1
    from pg_proc
    where oid = 'public.invoke_todo_sync_push_webhook()'::regprocedure
      and prosecdef
  $$,
  'webhook trigger function uses security-definer isolation'
);

select matches(
  (
    select action_statement
    from information_schema.triggers
    where event_object_schema = 'public'
      and event_object_table = 'sync_push_events'
      and trigger_name = 'todo_sync_push_webhook'
    limit 1
  ),
  'invoke_todo_sync_push_webhook',
  'sync-push trigger calls the Vault-backed function'
);

select unlike(
  pg_get_functiondef('public.invoke_todo_sync_push_webhook()'::regprocedure),
  '%https://%.supabase.co/functions/v1/todo-sync-push%',
  'webhook function does not embed a project endpoint'
);

select matches(
  pg_get_functiondef('public.invoke_todo_sync_push_webhook()'::regprocedure),
  'vault\.decrypted_secrets',
  'webhook function loads its runtime configuration from Vault'
);

select function_privs_are(
  'public',
  'delete_old_sync_push_events_batch',
  array['interval', 'integer'],
  'authenticated',
  array[]::text[],
  'authenticated clients cannot invoke outbox cleanup'
);

select function_privs_are(
  'public',
  'delete_old_sync_push_events_batch',
  array['interval', 'integer'],
  'service_role',
  array['EXECUTE'],
  'service role may invoke bounded outbox cleanup'
);

select is(
  (
    select count(*)
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'sync_push_events'
      and indexname = 'sync_push_events_created_at_id_idx'
  ),
  1::bigint,
  'outbox cleanup has an oldest-first supporting index'
);

insert into auth.users (id, email)
values ('44444444-4444-4444-4444-444444444444', 'sync-push-test@example.invalid');

insert into public.sync_push_events (
  user_id,
  source_table,
  record_id,
  mutation_type,
  created_at
)
values
  ('44444444-4444-4444-4444-444444444444', 'todos', gen_random_uuid(), 'UPDATE', now() - interval '10 days'),
  ('44444444-4444-4444-4444-444444444444', 'todos', gen_random_uuid(), 'UPDATE', now() - interval '9 days'),
  ('44444444-4444-4444-4444-444444444444', 'todos', gen_random_uuid(), 'UPDATE', now() - interval '8 days'),
  ('44444444-4444-4444-4444-444444444444', 'todos', gen_random_uuid(), 'UPDATE', now());

select is(
  public.delete_old_sync_push_events_batch(interval '7 days', 2),
  2,
  'cleanup deletes no more than the requested batch size'
);

select is(
  (
    select count(*)
    from public.sync_push_events
    where user_id = '44444444-4444-4444-4444-444444444444'
      and created_at < now() - interval '7 days'
  ),
  1::bigint,
  'one stale event remains after a two-row batch'
);

select is(
  public.delete_old_sync_push_events_batch(interval '7 days', 5000),
  1,
  'a later cleanup removes the remaining stale event'
);

select is(
  (
    select count(*)
    from public.sync_push_events
    where user_id = '44444444-4444-4444-4444-444444444444'
  ),
  1::bigint,
  'cleanup preserves current outbox events'
);

select throws_ok(
  $$ select public.delete_old_sync_push_events_batch(interval '1 hour', 100) $$,
  'P0001',
  'retention must be at least one day',
  'cleanup rejects unsafe retention windows'
);

select * from finish();
rollback;
