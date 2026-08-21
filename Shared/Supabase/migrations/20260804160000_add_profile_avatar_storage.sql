-- Profile avatars are intentionally limited to one small, public image per user.
-- The URL is exposed only as part of the minimum collaborator profile projection.
insert into storage.buckets (id, name, public)
values ('profile-images', 'profile-images', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists profile_images_insert_own on storage.objects;
create policy profile_images_insert_own
on storage.objects
for insert to authenticated
with check (
  bucket_id = 'profile-images'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

drop policy if exists profile_images_update_own on storage.objects;
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

drop policy if exists profile_images_delete_own on storage.objects;
create policy profile_images_delete_own
on storage.objects
for delete to authenticated
using (
  bucket_id = 'profile-images'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);
