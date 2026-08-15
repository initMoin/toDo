# Step 03: Profile, RLS, and Collab Authorization

## Objective

Prove that profile identity and Collab data are useful to authorized Users while
remaining private from unrelated or anonymous callers. Prove that invitation
limits and Collab toDō authorization are enforced by the server, including under
concurrency.

## Test Identities

Use four synthetic Supabase accounts:

- **Owner A** creates the Collab.
- **User B** joins the Collab.
- **User C** joins as the second accepted outgoing User.
- **Stranger D** remains unrelated.

Set unique display names that do not resemble real users. Record only UUIDs in the
release evidence.

## Build the Authorization Fixture

1. Sign in as Owner A.
2. Edit My Profile and save a recognizable display name.
3. Create one Collab named `Release Authorization QA`.
4. Invite User B and accept the invitation while signed in as User B.
5. Invite User C and accept the invitation while signed in as User C.
6. Do not invite Stranger D.
7. As Owner A, create one Collab toDō containing:
   - a due date and time;
   - one tag;
   - two NanoDos;
   - notes;
   - a reminder;
   - a recurrence rule if supported in the tested path.

## Profile Projection Test

As Owner A or User B, call:

```sql
select *
from public.collab_user_profiles_for_collab(
  '<COLLAB_UUID>'::uuid,
  100,
  0
);
```

The function must return only:

- `user_id`
- `display_name`
- `avatar_url`
- `role`
- `collab_id`
- `collab_name`

It must not return email, auth provider, entitlement, time zone, purchases,
personal toDōs, or Collabs unrelated to the requested ID.

## Emulating Authenticated SQL Safely

When testing in SQL Editor, execute authorization checks in a transaction and set
the JWT claims locally. Replace the UUID with the synthetic test account ID:

```sql
begin;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', '<USER_UUID>',
    'role', 'authenticated'
  )::text,
  true
);

select *
from public.collab_user_profiles_for_collab('<COLLAB_UUID>'::uuid, 100, 0);
rollback;
```

Run this once for Owner A, User B, and User C. Each must succeed. Run it for
Stranger D; it must fail with an authorization error and return no profile rows.

For an anonymous test:

```sql
begin;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select *
from public.collab_user_profiles_for_collab('<COLLAB_UUID>'::uuid, 100, 0);
rollback;
```

Expected: denied.

## Direct Profile Enumeration Test

Under each authenticated test account, query `public.profiles` through the same
API path used by the app. Confirm the account can read and update its own row but
cannot enumerate unrelated profiles. Do not use the service-role key for this
test; it bypasses RLS and proves nothing about client security.

## Own-Profile Behavior

1. Sign in as Owner A on iPhone.
2. Open Account > My Profile.
3. Verify avatar or initials, display name, owner-only email, sign-in method, and
   membership.
4. Change the display name to a valid value and save.
5. Relaunch and verify the saved value.
6. Try blank, whitespace-only, and over-60-character names. They must be rejected
   without corrupting the current profile.
7. Sign out and sign in as User B. Owner A's name, email, avatar, and membership
   must disappear before User B's profile is shown.
8. Simulate an avatar-load failure. Initials must remain legible and stable.

## Collab User Profile Behavior

1. Open the User list for the test Collab.
2. Open User B's profile as Owner A.
3. Verify only avatar/initials, display name, Owner/User role, Collab context, and
   authorized actions appear.
4. Confirm email, provider, membership purchase history, time zone, personal
   toDōs, and unrelated Collabs are absent.
5. Verify Stranger D cannot open or query this profile.
6. Verify removal actions appear only to an authorized Owner and execute with a
   confirmation.

## Collab toDō Authorization Matrix

| Action | Owner A | User B/C | Stranger D |
| --- | --- | --- | --- |
| Read Collab toDō | Allow | Allow | Deny |
| Create in joined Collab | Allow | Allow | Deny |
| Update accessible Collab toDō | Allow | Allow | Deny |
| Delete own created toDō | Allow | Allow | Deny |
| Delete another User's toDō | Owner may allow per policy | Deny unless creator | Deny |
| Read attached NanoDos/tags | Allow | Allow | Deny |
| Read Collab tombstones | Allow | Allow | Deny |
| Rename another User's tag definition | Deny unless owner of tag | Deny | Deny |

Test each allowed and denied path through the normal client/API role, not through
the service role.

## Free Invitation Limit

The free policy is two accepted outgoing Users across owned Collabs. Pending,
declined, canceled, and expired invitations do not consume a slot.

1. Ensure Owner A has no paid entitlement.
2. Accept User B: first slot consumed.
3. Accept User C: second slot consumed.
4. Attempt to invite or accept a third outgoing User.
5. Confirm the client disables or explains the unavailable action.
6. Bypass the client and attempt the server action directly. It must still fail.
7. Remove User B or cancel an accepted relationship through the supported flow.
8. Confirm one slot becomes available.

### Concurrent acceptance

Create three pending invitations, then attempt acceptance from three devices or
parallel API clients as closely together as possible. Exactly two may become
accepted. The third must remain non-accepted with a recoverable limit response.
No duplicate membership row may be created.

### toDō+ entitlement

Repeat with a verified toDō+ account. Invitation and Collab creation limits must
be removed while RLS privacy remains unchanged.

## Pass Criteria

- [ ] Own-profile editing and account switching are correct.
- [ ] Collab User projection exposes only the six intended fields.
- [ ] Unrelated authenticated and anonymous access is denied.
- [ ] Email and private entitlement data never appear in Collab User results.
- [ ] Collab toDō, NanoDo, tag, and tombstone access follows the matrix.
- [ ] Free invitation enforcement survives direct and concurrent requests.
- [ ] toDō+ removes only the intended limits.
- [ ] No test leaves one account's profile or records visible after sign-out.
