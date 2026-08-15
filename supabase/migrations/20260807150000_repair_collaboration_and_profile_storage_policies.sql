-- Repair the policies used by shared toDos and profile avatars.
-- This migration is intentionally idempotent so it can repair an environment
-- that has the tables but missed one or more policies during deployment.

create or replace function public.can_access_collab_todo(
  target_todo_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.todos todo
    where todo.id = target_todo_id
      and (
        todo.user_id = target_user_id
        or (
          todo.collab_id is not null
          and public.is_collab_user(todo.collab_id, target_user_id)
        )
      )
  );
$$;

create or replace function public.can_delete_collab_todo(
  target_todo_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.todos todo
    where todo.id = target_todo_id
      and (
        todo.user_id = target_user_id
        or (
          todo.collab_id is not null
          and public.is_collab_owner(todo.collab_id, target_user_id)
        )
      )
  );
$$;

create or replace function public.can_access_collab_tag(
  target_tag_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.tags tag
    where tag.id = target_tag_id
      and tag.user_id = target_user_id
  )
  or exists (
    select 1
    from public.todo_tags relation
    where relation.tag_id = target_tag_id
      and public.can_access_collab_todo(relation.todo_id, target_user_id)
  );
$$;

alter table public.todos enable row level security;
alter table public.tags enable row level security;
alter table public.todo_tags enable row level security;
alter table public.nanodos enable row level security;

grant select, insert, update, delete on table
  public.todos,
  public.tags,
  public.todo_tags,
  public.nanodos
to authenticated;

drop policy if exists "Users can view own todos" on public.todos;
drop policy if exists "Users can insert own todos" on public.todos;
drop policy if exists "Users can update own todos" on public.todos;
drop policy if exists "Users can delete own todos" on public.todos;
drop policy if exists todos_select_accessible on public.todos;
drop policy if exists todos_insert_accessible on public.todos;
drop policy if exists todos_update_accessible on public.todos;
drop policy if exists todos_delete_creator_or_collab_owner on public.todos;

create policy todos_select_accessible
on public.todos for select to authenticated
using (public.can_access_collab_todo(id, (select auth.uid())));

create policy todos_insert_accessible
on public.todos for insert to authenticated
with check (
  user_id = (select auth.uid())
  and (
    collab_id is null
    or public.is_collab_user(collab_id, (select auth.uid()))
  )
);

create policy todos_update_accessible
on public.todos for update to authenticated
using (public.can_access_collab_todo(id, (select auth.uid())))
with check (
  public.can_access_collab_todo(id, (select auth.uid()))
  and (
    collab_id is null
    or public.is_collab_user(collab_id, (select auth.uid()))
  )
);

create policy todos_delete_creator_or_collab_owner
on public.todos for delete to authenticated
using (public.can_delete_collab_todo(id, (select auth.uid())));

drop policy if exists tags_select_own on public.tags;
drop policy if exists tags_select_accessible on public.tags;
drop policy if exists tags_insert_own on public.tags;
drop policy if exists tags_update_own on public.tags;
drop policy if exists tags_delete_own on public.tags;

create policy tags_select_accessible
on public.tags for select to authenticated
using (public.can_access_collab_tag(id, (select auth.uid())));

create policy tags_insert_own
on public.tags for insert to authenticated
with check (user_id = (select auth.uid()));

create policy tags_update_own
on public.tags for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy tags_delete_own
on public.tags for delete to authenticated
using (user_id = (select auth.uid()));

drop policy if exists todo_tags_select_own on public.todo_tags;
drop policy if exists todo_tags_select_accessible on public.todo_tags;
drop policy if exists todo_tags_insert_own on public.todo_tags;
drop policy if exists todo_tags_insert_accessible on public.todo_tags;
drop policy if exists todo_tags_delete_own on public.todo_tags;
drop policy if exists todo_tags_delete_accessible on public.todo_tags;

create policy todo_tags_select_accessible
on public.todo_tags for select to authenticated
using (public.can_access_collab_todo(todo_id, (select auth.uid())));

create policy todo_tags_insert_accessible
on public.todo_tags for insert to authenticated
with check (
  public.can_access_collab_todo(todo_id, (select auth.uid()))
  and public.can_access_collab_tag(tag_id, (select auth.uid()))
);

create policy todo_tags_delete_accessible
on public.todo_tags for delete to authenticated
using (public.can_access_collab_todo(todo_id, (select auth.uid())));

drop policy if exists nanodos_select_own on public.nanodos;
drop policy if exists nanodos_select_accessible on public.nanodos;
drop policy if exists nanodos_insert_own on public.nanodos;
drop policy if exists nanodos_insert_accessible on public.nanodos;
drop policy if exists nanodos_update_own on public.nanodos;
drop policy if exists nanodos_update_accessible on public.nanodos;
drop policy if exists nanodos_delete_own on public.nanodos;
drop policy if exists nanodos_delete_accessible on public.nanodos;

create policy nanodos_select_accessible
on public.nanodos for select to authenticated
using (public.can_access_collab_todo(todo_id, (select auth.uid())));

create policy nanodos_insert_accessible
on public.nanodos for insert to authenticated
with check (
  user_id = (select auth.uid())
  and public.can_access_collab_todo(todo_id, (select auth.uid()))
);

create policy nanodos_update_accessible
on public.nanodos for update to authenticated
using (public.can_access_collab_todo(todo_id, (select auth.uid())))
with check (public.can_access_collab_todo(todo_id, (select auth.uid())));

create policy nanodos_delete_accessible
on public.nanodos for delete to authenticated
using (public.can_access_collab_todo(todo_id, (select auth.uid())));

-- Supabase Storage upserts can perform a read/update check before writing.
-- Keep the object path scoped to the authenticated user's UUID.
insert into storage.buckets (id, name, public)
values ('profile-images', 'profile-images', true)
on conflict (id) do update set public = excluded.public;

grant select, insert, update, delete on table storage.objects to authenticated;

drop policy if exists profile_images_select_own on storage.objects;
drop policy if exists profile_images_insert_own on storage.objects;
drop policy if exists profile_images_update_own on storage.objects;
drop policy if exists profile_images_delete_own on storage.objects;

create policy profile_images_select_own
on storage.objects
for select to authenticated
using (
  bucket_id = 'profile-images'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy profile_images_insert_own
on storage.objects
for insert to authenticated
with check (
  bucket_id = 'profile-images'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy profile_images_update_own
on storage.objects
for update to authenticated
using (
  bucket_id = 'profile-images'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
)
with check (
  bucket_id = 'profile-images'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy profile_images_delete_own
on storage.objects
for delete to authenticated
using (
  bucket_id = 'profile-images'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);
