-- Support standalone Apple Watch sync through the same Supabase auth + REST path
-- used by iPhone, iPad, and Mac. This migration is intentionally additive and
-- idempotent so it can be applied safely to production.

-- 1) Make sure every authenticated user has a profile row. Standalone Watch
-- Sign in with Apple can be the first client to create the auth user, so the
-- profile trigger must be present before Watch inserts rows that reference the
-- user through todos/tags/nanodos.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    display_name,
    given_name,
    family_name
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', new.email),
    new.raw_user_meta_data->>'given_name',
    new.raw_user_meta_data->>'family_name'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

insert into public.profiles (id, display_name)
select users.id, coalesce(users.raw_user_meta_data->>'full_name', users.raw_user_meta_data->>'name', users.email)
from auth.users
left join public.profiles on profiles.id = users.id
where profiles.id is null;

-- 2) Direct Watch REST writes to todo_tags need the same ownership guarantees as
-- companion-device sync. Keep links scoped through both the toDo and the tag.
alter table public.todo_tags enable row level security;

drop policy if exists "todo_tags_select_own" on public.todo_tags;
create policy "todo_tags_select_own"
on public.todo_tags
for select
to authenticated
using (
  exists (
    select 1
    from public.todos t
    where t.id = todo_tags.todo_id
      and t.user_id = (select auth.uid())
  )
);

drop policy if exists "todo_tags_insert_own" on public.todo_tags;
create policy "todo_tags_insert_own"
on public.todo_tags
for insert
to authenticated
with check (
  exists (
    select 1
    from public.todos t
    where t.id = todo_tags.todo_id
      and t.user_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.tags g
    where g.id = todo_tags.tag_id
      and g.user_id = (select auth.uid())
  )
);

drop policy if exists "todo_tags_delete_own" on public.todo_tags;
create policy "todo_tags_delete_own"
on public.todo_tags
for delete
to authenticated
using (
  exists (
    select 1
    from public.todos t
    where t.id = todo_tags.todo_id
      and t.user_id = (select auth.uid())
  )
);

-- 3) Keep indexes explicit for standalone Watch fetches.
create index if not exists todo_tags_todo_id_idx on public.todo_tags(todo_id);
create index if not exists todo_tags_tag_id_idx on public.todo_tags(tag_id);
create index if not exists tags_user_lower_name_idx on public.tags(user_id, lower(name));
