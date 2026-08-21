begin;

select plan(14);

select has_function(
  'public',
  'collab_user_profiles_for_collab',
  array['uuid', 'integer', 'integer'],
  'Collab-scoped User profile RPC exists'
);

select function_privs_are(
  'public',
  'collab_user_profiles_for_collab',
  array['uuid', 'integer', 'integer'],
  'anon',
  array[]::text[],
  'anonymous users cannot execute Collab User profile RPC'
);

select function_privs_are(
  'public',
  'collab_user_profiles_for_collab',
  array['uuid', 'integer', 'integer'],
  'authenticated',
  array['EXECUTE'],
  'authenticated users can execute the guarded RPC'
);

select results_eq(
  $$
    select column_name::text
    from information_schema.routine_columns
    where specific_schema = 'public'
      and routine_name = 'collab_user_profiles_for_collab'
    order by ordinal_position
  $$,
  $$ values
    ('user_id'),
    ('display_name'),
    ('avatar_url'),
    ('role'),
    ('collab_id'),
    ('collab_name')
  $$,
  'RPC exposes only the approved Collab User projection'
);

select isnt_empty(
  $$
    select 1
    from pg_proc
    where oid = 'public.collab_user_profiles_for_collab(uuid,integer,integer)'::regprocedure
      and prosecdef
  $$,
  'RPC is security definer to avoid recursive profile/member RLS'
);

select matches(
  pg_get_functiondef('public.collab_user_profiles_for_collab(uuid,integer,integer)'::regprocedure),
  'viewer\\.user_id = current_account_id',
  'RPC requires the caller to be a User of the requested Collab'
);

select matches(
  pg_get_functiondef('public.collab_user_profiles_for_collab(uuid,integer,integer)'::regprocedure),
  'limit least\(greatest\(result_limit, 1\), 100\)',
  'RPC bounds every Collab User profile page to at most 100 rows'
);

select has_check(
  'public',
  'profiles',
  'profiles_display_name_length_check',
  'profile display names are constrained by the database'
);

insert into auth.users (id, email)
values
  ('11111111-1111-1111-1111-111111111111', 'profile-owner@example.invalid'),
  ('22222222-2222-2222-2222-222222222222', 'profile-member@example.invalid'),
  ('33333333-3333-3333-3333-333333333333', 'profile-unrelated@example.invalid');

insert into public.profiles (id, display_name, preferred_time_zone)
values
  ('11111111-1111-1111-1111-111111111111', 'Collab Owner', 'UTC'),
  ('22222222-2222-2222-2222-222222222222', 'Collab User', 'America/New_York'),
  ('33333333-3333-3333-3333-333333333333', 'Unrelated User', 'Asia/Tokyo');

insert into public.collabs (id, owner_user_id, name)
values (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '11111111-1111-1111-1111-111111111111',
  'Private Collab'
);

insert into public.collab_users (collab_id, user_id, role, invited_by_user_id)
values (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '22222222-2222-2222-2222-222222222222',
  'user',
  '11111111-1111-1111-1111-111111111111'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '22222222-2222-2222-2222-222222222222',
  true
);

select is(
  (
    select count(*)
    from public.collab_user_profiles_for_collab(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      100,
      0
    )
  ),
  2::bigint,
  'a User can read the minimum identities for their shared Collab'
);

select is(
  (
    select count(*)
    from public.profiles
    where id = '11111111-1111-1111-1111-111111111111'
  ),
  0::bigint,
  'direct profile RLS does not expose another Collab User profile'
);

select set_config(
  'request.jwt.claim.sub',
  '33333333-3333-3333-3333-333333333333',
  true
);

select throws_ok(
  $$
    select *
    from public.collab_user_profiles_for_collab(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      100,
      0
    )
  $$,
  '42501',
  'Collab access required',
  'an unrelated authenticated user cannot read Collab profiles'
);

select results_eq(
  $$
    update public.profiles
    set display_name = 'Unauthorized Change'
    where id = '11111111-1111-1111-1111-111111111111'
    returning id
  $$,
  $$ select null::uuid where false $$,
  'a user cannot update another account profile'
);

select results_eq(
  $$
    update public.profiles
    set display_name = 'Updated User'
    where id = '33333333-3333-3333-3333-333333333333'
    returning display_name
  $$,
  $$ values ('Updated User'::text) $$,
  'a user can update their own profile'
);

set local role anon;

select is(
  (select count(*) from public.profiles),
  0::bigint,
  'anonymous users cannot read profiles'
);

reset role;

select * from finish();
rollback;
