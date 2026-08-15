-- Keep the ToDo Sync webhook credential out of trigger definitions and schema dumps.
-- Production must provide these named Vault values before this trigger can dispatch:
--   todo_sync_push_webhook_url
--   todo_sync_push_webhook_secret

create or replace function public.invoke_todo_sync_push_webhook()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  webhook_url text;
  webhook_secret text;
  webhook_payload jsonb;
begin
  select nullif(btrim(secret.decrypted_secret), '')
    into webhook_url
    from vault.decrypted_secrets secret
    where secret.name = 'todo_sync_push_webhook_url'
    order by secret.updated_at desc
    limit 1;

  select nullif(btrim(secret.decrypted_secret), '')
    into webhook_secret
    from vault.decrypted_secrets secret
    where secret.name = 'todo_sync_push_webhook_secret'
    order by secret.updated_at desc
    limit 1;

  if webhook_url is null or webhook_secret is null then
    raise warning 'Skipped todo-sync-push webhook: required Vault configuration is missing';
    return new;
  end if;

  webhook_payload := jsonb_build_object(
    'type', tg_op,
    'table', tg_table_name,
    'schema', tg_table_schema,
    'record', to_jsonb(new),
    'old_record', null
  );

  perform net.http_post(
    url := webhook_url,
    body := webhook_payload,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-ToDo-Webhook-Secret', webhook_secret
    ),
    timeout_milliseconds := 5000
  );

  return new;
exception
  when others then
    -- Push delivery is auxiliary. A networking/configuration failure must never
    -- roll back the user's underlying toDo mutation.
    raise warning 'Failed to enqueue todo-sync-push webhook request: %', sqlerrm;
    return new;
end;
$$;

revoke all on function public.invoke_todo_sync_push_webhook() from public;
revoke all on function public.invoke_todo_sync_push_webhook() from anon;
revoke all on function public.invoke_todo_sync_push_webhook() from authenticated;

drop trigger if exists todo_sync_push_webhook on public.sync_push_events;
create trigger todo_sync_push_webhook
after insert on public.sync_push_events
for each row execute function public.invoke_todo_sync_push_webhook();

comment on function public.invoke_todo_sync_push_webhook() is
  'Dispatches authenticated sync-push webhook payloads using encrypted Vault configuration.';
