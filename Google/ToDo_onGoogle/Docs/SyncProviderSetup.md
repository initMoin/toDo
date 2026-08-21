# Android Sync Provider Setup

This document describes the configuration required before the Android app can
connect to Supabase and Firebase. Provider SDKs and credentials are kept
behind the sync interfaces already implemented in `core/sync`.

## Current architecture

Supabase Auth is the canonical account system, matching the Apple app's
`SupabaseAuthStore`. The Supabase user UUID is the shared `user_id` used by
the ToDo data contract.

Supabase is the cross-platform source of truth. Firebase is the Android
same-platform cross-device transport. Android must not create a second
unrelated Firebase account identity for the same person.

For direct Firestore access, the recommended identity bridge is:

```text
Supabase Auth session
        ↓ validate Supabase access token on trusted server
Firebase custom token with uid = Supabase user UUID
        ↓ signInWithCustomToken on Android
Firestore security rules use request.auth.uid
```

The Firebase Admin credential required to mint custom tokens must remain on a
trusted server or Supabase Edge Function. It must never be placed in the
Android app, `google-services.json`, `local.properties`, or source control.

## What I need from the project owner

### 1. Supabase project values — needed first

Provide these values through the local file described below, not by committing
them to the repository:

- Supabase Project URL, such as `https://your-project-ref.supabase.co`.
- Supabase publishable key. This is the client-safe key from the Supabase API
  settings. Do not provide the `service_role` key.
- Confirmation that the existing `Shared/Supabase/` migrations in the shared backend
  have been applied to the intended Supabase project.

#### Obtain the Supabase values

1. Open the Supabase Dashboard and select the toDō project.
2. Open `Project Settings` → `API`.
3. Copy `Project URL`.
4. Under `Project API keys`, copy the `Publishable` key. If the dashboard only
   exposes the older key names, use the `anon` key and tell me that it is the
   legacy key; never use `service_role` in the mobile app.
5. From the repository root, copy the Android template:

   ```text
   Google/ToDo_onGoogle/app/supabase.properties.example
   ```

   to:

   ```text
   Google/ToDo_onGoogle/app/supabase.properties
   ```

6. Replace the two placeholders:

   ```properties
   supabase.url=https://YOUR_PROJECT_REF.supabase.co
   supabase.publishableKey=YOUR_SUPABASE_PUBLISHABLE_KEY
   ```

7. Leave `app/supabase.properties` uncommitted. It is already ignored by the
   Android project.

### 2. Supabase Auth choices — needed before the Android sign-in UI

The Apple app currently supports Sign in with Apple and Google through
Supabase Auth. Confirm which Android sign-in methods should be enabled for the
first Android implementation:

- Email/password or magic link.
- Google sign-in.
- Sign in with Apple on Android.

For Google and Apple, the Supabase Dashboard provider settings and the Android
OAuth redirect/deep-link configuration must agree. I will add the Android
redirect URI and manifest intent filters after the chosen providers are
confirmed.

### 3. Firebase project configuration — needed after Supabase Auth is working

Provide or create the Firebase project that will host Android Firestore sync.
I need:

- Firebase project ID.
- An Android app registered with package ID
  `dev.iamshift.todo.android`.
- The downloaded `google-services.json` file.
- Confirmation that Cloud Firestore is enabled.
- A decision about where the Supabase-to-Firebase custom-token bridge will
  run: Supabase Edge Function or an existing trusted backend.

#### Obtain `google-services.json`

1. Open the Firebase Console and select the intended project.
2. Open `Project settings`.
3. In `Your apps`, choose `Add app` → Android.
4. Use this exact Android package name:

   ```text
   dev.iamshift.todo.android
   ```

5. Add the Android debug SHA-1 and SHA-256 fingerprints. On macOS, the
   default debug keystore fingerprints can be displayed with:

   ```bash
   keytool -list -v \\
     -alias androiddebugkey \\
     -keystore ~/.android/debug.keystore \\
     -storepass android \\
     -keypass android
   ```

6. Download `google-services.json`.
7. Place it at:

   ```text
   Google/ToDo_onGoogle/app/google-services.json
   ```

8. Do not commit that file unless the team explicitly chooses a protected
   configuration-management policy. The Android project ignores it by
   default.

#### Enable Firestore

1. In Firebase Console, open `Build` → `Firestore Database`.
2. Create the database in the intended region.
3. Do not leave broad test-mode rules in place for production.
4. Wait for the custom-token identity design before finalizing rules. The
   target rule shape is user-scoped access using the Supabase UUID:

   ```text
   request.auth.uid == userId in the document path
   ```

### 4. Firebase custom-token bridge — required before direct Firebase sync

This is a server-side requirement. The Android app cannot safely mint its own
Firebase custom tokens.

The bridge must:

1. Receive a request authenticated with the Supabase access token.
2. Validate that token with Supabase.
3. Read the authenticated Supabase user UUID.
4. Use Firebase Admin SDK credentials stored only on the trusted server.
5. Mint a Firebase custom token whose Firebase UID equals the Supabase UUID.
6. Return the short-lived custom token to the Android client.

The bridge endpoint, deployment target, and server-side secret configuration
are not needed for the Supabase implementation, but they are required before
Firebase Firestore synchronization can be enabled.

## Implementation order

### Supabase: implement now

The Android client now has the Supabase SDK, Auth session adapter, OAuth
deep-link handling, PostgREST adapter, and authenticated outbox flush path.
The remaining dashboard-side requirement before testing sign-in is to add this
exact redirect URL under Supabase Dashboard → Authentication → URL
Configuration → Additional Redirect URLs:

```text
todo://auth-callback
```

The Android client currently uses `supabase-kt` 3.6.0 and Ktor 3.3.1 to match
the project's Kotlin 2.2.x toolchain. It explicitly selects Ktor's OkHttp
engine because the Ktor Android engine does not support WebSockets, while
Supabase Realtime requires a WebSocket-capable engine. The Supabase client uses
the BOM with `auth-kt`, `postgrest-kt`, and `realtime-kt` modules.

The first Supabase sync phase now includes:

1. Pull/apply full remote snapshots into Room using timestamp conflict and
   tombstone rules.
2. Reconcile full `todo_tags` relationship sets and preserve Android-only local
   fields that are not part of the shared Supabase schema.
3. Use debounced Realtime invalidation while the Activity is visible and
   network-constrained WorkManager refresh while it is not.

The cursor transport is present but is not yet persisted. Full pulls are the
deliberate first production slice until a durable, tie-safe cursor is added.

### Firebase: implement immediately after the identity bridge

Firebase implementation begins after:

1. `google-services.json` is present.
2. Firestore is enabled.
3. The custom-token bridge can return a Firebase token for a Supabase user.
4. Firestore rules are written and tested for the shared UUID scope.

Then Android can add Firebase Auth custom-token sign-in, the Firestore adapter,
and provider-specific same-platform sync behavior.

## Security rules

- Never use Supabase `service_role` keys in Android.
- Never use Firebase Admin SDK credentials in Android.
- Never commit `app/supabase.properties`.
- Never commit Firebase service-account JSON credentials.
- Treat `google-services.json` as project configuration, not as a secret
  replacement for server credentials; keep it out of this repository unless
  the project adopts an explicit protected configuration policy.

## Decision record

The Android DSA and sync decision history is maintained in
[`../DSA-ToDoAndroid.md`](../DSA-ToDoAndroid.md). The Supabase UUID as the
shared Firebase UID is a security and data-integrity requirement, not merely a
convenience.
