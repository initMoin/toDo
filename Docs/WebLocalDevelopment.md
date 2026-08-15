# toDō Web local development

This is the shortest path to testing the current Web foundation locally.

## 1. Install and start the Web package

From the repository:

```bash
cd "/Users/shift/Development/Mobile/2026/Feb/ToDo/Web"
npm install
npm run dev
```

Open [http://localhost:3000/](http://localhost:3000/).

## 2. Add browser-safe Supabase configuration

Create `Web/.env.local` locally:

```text
VITE_SUPABASE_URL=https://<project-ref>.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

Only the Supabase URL and publishable/anon key belong in browser configuration.
Never use `service_role` here.

Restart `npm run dev` after changing the file. If the values are absent, the
setup card is the correct result and no fake ToDos are shown.

## 3. Configure OAuth for local testing

In Supabase Auth URL Configuration, allow:

```text
http://localhost:3000/
```

Enable Apple and Google in Supabase Auth. Each provider must use the callback
URL shown by Supabase, normally:

```text
https://<project-ref>.supabase.co/auth/v1/callback
```

The Web client starts the OAuth flow with the current origin as the final
redirect. A username is collected before provider sign-in. Apple and Google are
separate authentication proofs until a resolved account explicitly connects the
second provider; matching usernames or emails never link accounts.

## 4. Test the toDō+ gate and read path

Sign in with an account that has an active or grace `todo_plus`/`legacy_3_1`
record visible through `current_account_entitlements`. The first slice then
reads only the RLS-protected `todos`, `nanodos`, `tags`, `todo_tags`, and
Collabs surfaces.

Expected states to verify:

- Supabase not configured: explicit setup state
- signed out: Apple/Google sign-in card
- signed in without toDō+: entitlement gate
- signed in with toDō+: active ToDo list
- no active ToDos: empty state
- request failure: error state with retry
- selecting a ToDo: browser-native `/todos/:id` detail route

Task creation, editing, completion, deletion, realtime conflict handling, and
Web Push are intentionally after this foundation slice. They should not be
treated as successful until their sync and RLS behavior is tested.
