-- Bound sync-push outbox cleanup so webhook traffic never triggers an
-- unbounded delete. Schedule the same batch operation when pg_cron exists.

create index if not exists sync_push_events_created_at_id_idx
on public.sync_push_events (created_at, id);

create or replace function public.delete_old_sync_push_events_batch(
  retention interval default interval '7 days',
  batch_limit integer default 5000
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted_count integer;
  safe_batch_limit integer;
begin
  if retention is null or retention < interval '1 day' then
    raise exception 'retention must be at least one day';
  end if;

  safe_batch_limit := least(greatest(coalesce(batch_limit, 5000), 1), 10000);

  with stale_events as (
    select event.id
    from public.sync_push_events event
    where event.created_at < now() - retention
    order by event.created_at, event.id
    limit safe_batch_limit
    for update skip locked
  )
  delete from public.sync_push_events event
  using stale_events
  where event.id = stale_events.id;

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

create or replace function public.delete_old_sync_push_events(
  retention interval default interval '7 days'
)
returns integer
language sql
security definer
set search_path = ''
as $$
  select public.delete_old_sync_push_events_batch(retention, 5000);
$$;

revoke all on function public.delete_old_sync_push_events_batch(interval, integer) from public;
revoke all on function public.delete_old_sync_push_events_batch(interval, integer) from anon;
revoke all on function public.delete_old_sync_push_events_batch(interval, integer) from authenticated;
grant execute on function public.delete_old_sync_push_events_batch(interval, integer) to service_role;

revoke all on function public.delete_old_sync_push_events(interval) from public;
revoke all on function public.delete_old_sync_push_events(interval) from anon;
revoke all on function public.delete_old_sync_push_events(interval) from authenticated;
grant execute on function public.delete_old_sync_push_events(interval) to service_role;

do $schedule$
declare
  existing_job_id bigint;
begin
  if to_regprocedure('cron.schedule(text,text,text)') is null then
    raise notice 'pg_cron is unavailable; sync-push cleanup remains opportunistic';
    return;
  end if;

  for existing_job_id in
    execute 'select jobid from cron.job where jobname = $1'
    using 'todo-sync-push-outbox-cleanup'
  loop
    execute 'select cron.unschedule($1)' using existing_job_id;
  end loop;

  execute $cron$
    select cron.schedule(
      'todo-sync-push-outbox-cleanup',
      '17 3 * * *',
      'select public.delete_old_sync_push_events_batch(interval ''7 days'', 5000);'
    )
  $cron$;
end;
$schedule$;

-- Remove one bounded batch immediately. The scheduled job and successful
-- webhook invocations handle any remaining backlog without a long migration.
select public.delete_old_sync_push_events_batch(interval '7 days', 5000);

comment on function public.delete_old_sync_push_events_batch(interval, integer) is
  'Deletes one bounded, oldest-first batch of stale sync-push outbox events.';
