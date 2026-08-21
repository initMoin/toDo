-- 1) Add new column if it doesn't exist
alter table public.profiles
add column if not exists preferred_time_zone text;

-- 2) Copy data from old column → new column
update public.profiles
set preferred_time_zone = timezone
where preferred_time_zone is null;

-- 3) Set default (optional but recommended)
alter table public.profiles
alter column preferred_time_zone set default 'UTC';

-- 4) Drop old column if it exists
alter table public.profiles
drop column if exists timezone;