begin;

select plan(19);

select has_column(
  'public',
  'profiles',
  'username',
  'profiles retain the public username locator'
);

select has_column(
  'public',
  'profiles',
  'account_setup_version',
  'profiles track account-setup migration state'
);

select has_index(
  'public',
  'profiles',
  'profiles_username_lower_unique_idx',
  'profile usernames have a database-level case-insensitive uniqueness guard'
);

select has_table(
  'public',
  'reserved_usernames',
  'reserved usernames are server-owned'
);

select has_table(
  'public',
  'account_roles',
  'account roles are stored separately from commerce entitlements'
);

select isnt_empty(
  $$
    select 1
    from pg_class
    where oid = 'public.reserved_usernames'::regclass
      and relrowsecurity
  $$,
  'reserved usernames use row-level security'
);

select isnt_empty(
  $$
    select 1
    from pg_class
    where oid = 'public.account_roles'::regclass
      and relrowsecurity
  $$,
  'account roles use row-level security'
);

select has_function(
  'public',
  'is_username_available',
  array['text'],
  'username availability is exposed through a bounded function'
);

select has_function(
  'public',
  'claim_account_username',
  array['text'],
  'username claims use a server-side account setup function'
);

select has_function(
  'public',
  'current_account_role',
  array[]::text[],
  'the current account role is exposed through a guarded function'
);

select has_function(
  'public',
  'assign_founder_role',
  array['uuid'],
  'founder assignment has a dedicated server-side hook'
);

select function_privs_are(
  'public',
  'is_username_available',
  array['text'],
  'anon',
  array['EXECUTE'],
  'anonymous users may check a candidate username without reading profiles'
);

select function_privs_are(
  'public',
  'claim_account_username',
  array['text'],
  'authenticated',
  array['EXECUTE'],
  'authenticated users may claim only through the guarded setup function'
);

select function_privs_are(
  'public',
  'assign_founder_role',
  array['uuid'],
  'authenticated',
  array[]::text[],
  'normal clients cannot assign founder authority'
);

select results_eq(
  $$
    select privilege_type::text
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'account_roles'
      and grantee = 'authenticated'
    order by privilege_type
  $$,
  $$ values ('SELECT'::text) $$,
  'authenticated clients can read only their own role through RLS'
);

select results_eq(
  $$
    select privilege_type::text
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'reserved_usernames'
      and grantee in ('anon', 'authenticated')
  $$,
  $$ select null::text where false $$,
  'reserved username rows are never directly readable by clients'
);

select matches(
  pg_get_functiondef('public.claim_account_username(text)'::regprocedure),
  'set_config\(''todo\.account_setup_claim'', ''on''',
  'username claims use a scoped server-side identity-change marker'
);

select matches(
  pg_get_functiondef('public.assign_founder_role(uuid)'::regprocedure),
  'service_role',
  'founder assignment checks the trusted service role'
);

select isnt_empty(
  $$
    select 1
    from pg_trigger
    where tgrelid = 'public.profiles'::regclass
      and tgname = 'protect_profile_account_identity'
  $$,
  'direct username and setup-version edits are guarded by a profile trigger'
);

select * from finish();
rollback;
