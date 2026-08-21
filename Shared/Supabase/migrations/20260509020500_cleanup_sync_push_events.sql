-- Keep the ToDo Sync push outbox from growing indefinitely.
-- The Edge Function also performs this cleanup opportunistically after each webhook run.

create or replace function public.delete_old_sync_push_events(retention interval default interval '7 days')
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count integer;
begin
  delete from public.sync_push_events
  where created_at < now() - retention;

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

-- One-time cleanup for old failed validation attempts and stale processed rows.
select public.delete_old_sync_push_events(interval '7 days');
