# toDō Account Architecture, Onboarding, Migration, and Founder Authority

**Status:** Approved product direction; implementation not yet started  
**Last updated:** August 11, 2026  
**Applies to:** iPhone, iPad, Mac, Apple Watch, Android, Web, Supabase, and future account-management tooling

## Executive summary

toDō will use a simple username-first account experience backed by Supabase Auth:

```text
Username identifies the toDō account
              ↓
Apple or Google proves account ownership
              ↓
Supabase auth.users.id owns the data
```

The username is the account's required, human-facing identity and the connective tissue users see across platforms. Apple and Google remain the actual authentication providers. The immutable Supabase user UUID remains the internal owner of profile data, toDōs, Collabs, purchases, entitlements, connected identities, and future MFA factors.

The immediate work has two product surfaces:

1. A revised username-first account-creation and returning-sign-in experience.
2. A one-time account-setup migration for existing users.

The change must also designate the founder's existing, correct legacy account as the one authoritative founder account. Founder authority is a server-owned role attached to the account UUID. It is not inferred from a username, email address, Apple account, Google account, or client-side flag.

Passwords, MFA, SMS authentication, automated account merging, and the Founding Supporter code-management interface are intentionally deferred. Their future relationship to the account is documented here so the immediate implementation does not block them or accidentally implement them prematurely.

## Instructions for the implementation agent

Treat the decisions in this document as the product contract. Before changing code, inspect the current schema, auth flows, tests, and worktree state in every project being modified. Implement the work in phases and keep the first deliverable within the explicit immediate scope.

Workspace considerations:

- The workspace root is not itself a Git repository.
- `Apple/`, `Google/`, and `Web/` are platform boundaries inside the same repository. Shared backend infrastructure lives under `Shared/Supabase/`.
- Shared Supabase migrations and functions are under the repository-level `Shared/Supabase/` directory.
- Workspace-level product documentation is under `Docs/`.
- Do not modify archived/copy directories such as `ToDo copy/` or `ToDo copy 2/`, generated `Build/` content, Derived Data, or repomix output.
- Preserve existing user changes and avoid broad auth/schema rewrites when a focused extension of the current contracts is sufficient.
- Use replayable, forward-only Supabase migrations. Do not edit historical production migrations to simulate a new change.
- Add or update automated tests with each phase. Do not rely only on successful provider UI interaction as proof that account IDs and entitlements remained stable.
- Do not implement any item listed under **Out of scope for the immediate implementation** unless separately requested.

## Context and reason for the change

The current application signs users in directly with Apple or Google. The resulting Supabase `auth.users.id` becomes the owner of all account-scoped data. The current product and Web documentation treat Apple and Google as separate accounts.

At the time of this decision, the affected app version is being run as a local Xcode build and is not live in the App Store. App Store Connect offer codes are therefore unavailable for this build and are not part of the account solution. Username onboarding, Supabase identity linking, founder-role storage, and any future custom Founding Supporter grant system are application/backend features that can be developed and tested independently of an App Store release.

This creates a rare but confusing failure mode: an existing user can select an Apple or Google identity different from the one previously used and receive a valid session for a new, empty Supabase account. The user then appears to have lost profile history, synced data, Legacy 3.1 access, or Founding Supporter recognition even though the original account still exists under its original UUID.

Under normal use, this should be exceptionally uncommon. The primary user-created cause is authenticating with a different Apple or Google account. The design should therefore make the account/provider relationship obvious without introducing a second authentication system or a generalized account-merging platform.

The username-first design balances those concerns:

- The user begins with the toDō identity they recognize.
- Apple or Google still handles secure authentication.
- The app verifies that the provider returned the account the user expected.
- A wrong provider identity can be explained before the app begins syncing or presents an apparently empty account.
- Existing storage, RLS, commerce, and synchronization contracts continue using the same Supabase UUID.

## Final product decisions

The following decisions are authoritative for the initial implementation:

1. Every active toDō account has a unique username.
2. A username is the public account handle and first step of the sign-in experience; it is not a secret and does not prove ownership by itself.
3. Every account has at least one connected authentication provider: Apple or Google.
4. Connecting both providers is optional and should be offered after account creation and in Account Settings.
5. A provider can be connected to an existing account only while that account is authenticated.
6. Using a different Apple or Google account intentionally represents a different toDō account unless the identity was explicitly connected beforehand.
7. `auth.users.id` remains the canonical internal account identifier.
8. The username is never used as a database foreign key and never replaces `auth.users.id` in RLS.
9. A user may optionally provide a verified contact email for toDō updates. That address is not an authentication or automatic account-linking credential in the initial implementation.
10. Existing users receive a one-time account-setup migration after signing in normally.
11. Existing data, purchases, and entitlements stay attached to the current account UUID; ordinary migration does not move or re-key data.
12. The founder's correct existing legacy account receives the server-owned `founder` role.
13. Founder authority and the `founding_supporter` entitlement are distinct concepts.
14. Password login, MFA/SMS, automated duplicate-account merging, and Founding Supporter code management are future phases.

## Terminology

### Account

The canonical Supabase user represented by `auth.users.id`. This UUID owns all account-scoped application state.

### Username

The required public `@username`, stored in `public.profiles.username`. It is the human-facing account name, collaboration identity, and first field in the account-creation and returning-sign-in experience.

### Identity or provider

An Apple or Google identity maintained by Supabase Auth. Multiple provider identities may be linked to one Supabase user.

### Contact email

An optional, user-selected, verified address for product communication. It is separate from provider emails, including Apple's private relay addresses.

### Founder role

Server-authoritative operational authority belonging exclusively to the founder account unless the founder explicitly delegates a capability.

### Founding Supporter entitlement

A recognition/access entitlement that the founder may grant to selected accounts. It does not confer founder or administrator authority.

## Canonical account model

```text
Supabase auth.users.id (immutable canonical account UUID)
├── public.profiles
│   ├── username
│   ├── display name and personal profile fields
│   └── account setup version
├── Supabase Auth identities
│   ├── Apple
│   └── Google
├── optional account contact preferences
│   ├── verified contact email
│   └── product-update consent
├── optional server-owned account role
│   └── user / admin / founder
├── future MFA factors
├── toDōs, NanoDōs, tags, devices, and Collabs
├── Apple purchase links
└── account entitlements
    ├── todo_plus
    ├── legacy_3_1
    └── founding_supporter
```

No new application-level account UUID should be introduced. The current schema already uses `public.profiles.id` as a one-to-one foreign key to `auth.users.id`, and account-scoped tables and RLS policies consistently compare their owner to `auth.uid()`.

## Current implementation contracts

Codex should preserve and build on these existing contracts:

- `Shared/Supabase/schemas/01_profiles.sql` defines `public.profiles.id` as the primary key referencing `auth.users(id)`.
- `Shared/Supabase/migrations/20260806120000_add_collab_usernames.sql` already provides case-insensitive, trimmed username uniqueness.
- `ToDo/Core/Profile/ToDoProfile.swift` currently normalizes usernames to lowercase and validates a 3–30 character client contract.
- `ToDo/Core/Infrastructure/Supabase/SupabaseAuthStore.swift` currently calls `signInWithIdToken` for native Apple and Google authentication.
- The installed Supabase Swift SDK includes `linkIdentityWithIdToken`, `userIdentities`, and `unlinkIdentity` support.
- `Shared/Supabase/config.toml` currently has `enable_manual_linking = false` and MFA enrollment/verification disabled.
- `Shared/Supabase/migrations/20260715090000_add_apple_iap_entitlements.sql` already stores `todo_plus`, `legacy_3_1`, and `founding_supporter` entitlements against `public.profiles.id`.
- The current Web and Android clients perform provider-first sign-in and do not yet resolve or validate the expected username before allowing the authenticated account into the application.
- `Docs/WebProductionSetup.md`, `Docs/WebLocalDevelopment.md`, and the Web sign-in card currently state that Apple and Google remain separate accounts. Those statements become obsolete when identity linking ships and must be updated in the same change.

## Username contract

### User-facing behavior

The username is displayed consistently as `@username` and is used throughout profile and Collab interfaces. The raw stored value should not include `@`.

### Validation

The initial contract should remain compact and predictable:

- 3–30 characters.
- Stored lowercase.
- ASCII letters `a-z`, numbers `0-9`, periods, and underscores.
- No leading or trailing period.
- No whitespace.
- Case-insensitive uniqueness.
- Reserved product/system names must be rejected.

The database must enforce the same format as the clients. The current Swift check uses Unicode `isLetter` and `isNumber`; because the username is becoming an account locator, Codex should intentionally decide whether to narrow it to ASCII as specified above and update tests and UI copy together.

### Mutability

Username changes are not required for the first implementation beyond the current profile editor. The architecture must nevertheless preserve these rules:

- Changing a username never changes the account UUID or ownership of data.
- A future security-sensitive username-change flow should require recent authentication.
- Previous usernames should not be automatically reassigned to another account. A username-history or reserved-name mechanism may be added when rename policy is implemented.

### Database nullability during migration

`profiles.username` may remain nullable while an account is provisional or an existing user has not completed the updated setup. An account is considered fully set up only when it has a valid username and the current setup version.

Do not immediately add a global `NOT NULL` constraint that would break profile creation triggers or legacy accounts. A version-aware check may be added after the migration path is operational.

## Account setup version

Add a small version field to `public.profiles`, for example:

```text
account_setup_version smallint not null default 1
```

The username-first account model is version `2`.

The version exists to:

- Show the migration once across devices.
- Distinguish an old profile with a username from an account that has acknowledged and completed the new provider relationship.
- Gate sync/account presentation while a newly authenticated account is unresolved.
- Support future account-setup changes without relying only on local preferences.

The client should not mark version `2` until the account has a valid username and at least one authenticated provider identity.

## New account creation

### User experience

```text
Welcome to toDō
    ↓
Create Account
    ↓
Choose @username
    ↓
Continue with Apple or Continue with Google
    ↓
Confirm account
    ↓
Optional: connect the other provider
    ↓
Optional: add an email for toDō updates
    ↓
Enter the application
```

### Required behavior

1. The user chooses **Create Account**, distinct from **Sign In**.
2. The client validates and checks availability of the proposed username.
3. The username remains pending in client state while the provider flow runs. A temporary username-reservation service is not required.
4. Apple or Google authenticates the user and Supabase returns a session.
5. The client loads the returned profile before starting account sync.
6. If the returned profile is provisional and has no username, atomically claim the pending username for that account and set `account_setup_version = 2`.
7. If another account claimed the username during provider authentication, return to the username step with a friendly conflict message.
8. If the provider already belongs to an existing account with a username, do not overwrite that username or create a second profile. Explain that the provider already signs into the existing `@username` and let the user continue to that account or sign out.
9. After activation, offer—but do not require—the other provider and the contact-email step.

The existing unique username index is the final concurrency authority. A small server function/RPC may be used to atomically validate, claim, and version the profile, but a long-lived reservation table is unnecessary.

## Returning-user sign-in

### User experience

On a new or unrecognized device:

```text
Sign In
    ↓
Enter @username
    ↓
Continue with Apple or Continue with Google
    ↓
Verify returned account matches @username
    ↓
Enter the application
```

On a recognized device, the client may remember and prefill the last successful username:

```text
Continue as @shift with Apple
```

This local convenience is not an authentication factor and must be cleared or replaced on sign-out/account switch.

### Resolution rules

After provider authentication, load the profile for the returned `auth.users.id` and compare its normalized username with the expected username:

| Returned account state | Result |
| --- | --- |
| Username matches | Complete sign-in and begin sync. |
| Different username | Explain which toDō account this authenticated provider belongs to; allow continuing as that account or signing out. Do not pretend it is the requested account. |
| No username / provisional profile | Explain that this provider is not connected to a completed toDō account. Offer **Create Account** or **Try Another Sign-in Method**. |
| Provider identity is connected to another account | Do not reassign it automatically. The user must authenticate the intended account first and connect the provider from Account Settings. |

Provider authentication may cause Supabase to provision an auth user even when a user chose **Sign In**. Such an account must remain provisional and must not begin sync, receive migration entitlements, or be presented as a completed account until the user explicitly chooses to create it and claims a username.

### Sync gating

This is a critical implementation detail. The current iOS flow applies the returned session, bootstraps a profile, syncs device tokens, and applies sync mode immediately after provider authentication. The updated auth coordinator must introduce an account-resolution state before remote synchronization and commerce reconciliation.

Suggested conceptual states:

```text
signedOut
authenticating(intent, expectedUsername)
resolvingAccount(session, expectedUsername)
needsNewAccountUsername
needsExistingAccountMigration
authenticatedResolved(accountID, username)
accountMismatch
```

Only `authenticatedResolved` may start normal account sync. This prevents a wrong provider selection from immediately making the app look like the user's data disappeared.

## Connecting another provider

The account/profile area should contain a **Sign-in Methods** section showing Apple and Google independently as **Connected** or **Connect**.

Connecting a provider must:

1. Begin from an authenticated, resolved account.
2. Obtain a fresh native Apple or Google ID token.
3. Call the platform SDK's identity-linking method, not ordinary sign-in.
4. Confirm that the session's canonical `auth.users.id` did not change.
5. Refresh and display the connected identity list.
6. Preserve all data and entitlements.

For Swift, use the installed SDK's `linkIdentityWithIdToken(credentials:)` for native ID-token linking. Manual linking must be enabled locally and in the hosted Supabase project. Supabase currently documents manual linking as beta, so Codex must add integration tests and graceful error handling.

If an identity already belongs to another Supabase user, show a clear conflict. Do not implement automatic reassignment or merge as part of this feature.

Provider unlinking is not required in the initial phase. If implemented later, never allow removal of the last usable sign-in method.

## Existing-user migration

### Trigger

After a normal provider sign-in, if `account_setup_version < 2`, show a full-screen or blocking **Complete Your toDō Account** flow before ordinary sync/account presentation.

### Existing user without a username

The screen should:

1. Explain that toDō accounts now use a username across platforms.
2. Reassure the user that existing toDōs, Collabs, purchases, and access remain unchanged.
3. Require a username.
4. Show the currently authenticated provider as connected.
5. Offer the other provider as optional.
6. Offer the contact-email step as optional when that feature is available.
7. Set `account_setup_version = 2` after the required step succeeds.

Suggested copy:

> Your toDō account now uses a username across iPhone, Android, Mac, Watch, and Web. Choose how people recognize you. Your existing toDōs and account access will stay exactly where they are.

### Existing user with a username

Do not force the user to choose another username. Show a confirmation such as:

> Your toDō account is now **@shift**. Apple is connected to this account.

Then offer the optional second provider and contact email before marking setup version `2`.

### Data behavior

The ordinary migration does not change account IDs or move data. It must not grant, revoke, or recompute `legacy_3_1`, `founding_supporter`, or `todo_plus` status.

Existing duplicate accounts are an exceptional support case and are outside this migration. If a user authenticates a different provider account and receives a provisional/empty account, the UI should first direct them to sign out and use the provider connected to their expected username.

## Optional contact email

The selected contact email is for communication, not account identity.

Recommended data separation:

```text
account_contact_preferences
├── account_id uuid primary key references public.profiles(id)
├── contact_email text nullable
├── contact_email_normalized text nullable
├── contact_email_verified_at timestamptz nullable
├── product_updates_opt_in boolean not null default false
├── created_at timestamptz
└── updated_at timestamptz
```

Requirements:

- Keep contact information out of collaborator profile projections.
- Do not use the contact email to automatically link Apple or Google.
- Do not assume the Supabase user's primary/provider email is the desired contact email.
- Treat Apple private-relay addresses as provider metadata unless the user explicitly selects that address.
- Do not send optional product updates until the address is verified and the user opts in.
- Clients may request an address change, but only trusted server logic may mark it verified.
- If no verification/sending backend exists when username migration ships, hide or feature-gate this optional step instead of storing an unverified address as if it were active.

Account recovery through this address is not part of the initial feature.

## Founder account

### Decision

The founder should have one specifically designated founder account. The recommended account is the existing, correct legacy account that already owns the founder's real profile, data, Legacy 3.1 status, and Founding Supporter status. Do not create another everyday Supabase account solely to represent founder authority unless the founder later chooses a separate operations-only identity.

The founder account should have:

- The founder's selected username.
- Both intended Apple and Google identities connected to the same UUID where practical.
- Existing Legacy 3.1 and Founding Supporter entitlements.
- A server-owned `founder` role.
- Future access to founder-only account and code-management controls.
- MFA before privileged production controls become available.

### Role storage

Use a minimal, service-controlled role table rather than a client-editable profile field:

```text
account_roles
├── account_id uuid primary key references public.profiles(id)
├── role text check (role in ('user', 'admin', 'founder'))
├── granted_by uuid nullable
├── granted_at timestamptz
└── updated_at timestamptz
```

Security requirements:

- Ordinary clients may read only their effective role if the UI needs it.
- No client may create, promote, or modify roles.
- Role writes occur only through a migration or trusted service operation.
- Founder authority is attached to the immutable account UUID, never to a username, email, provider claim, display name, or bundle-local preference.
- Changing the founder's username or provider email must not affect authority.
- No Supabase service-role key may appear in iOS, Mac, Watch, Android, or Web clients.
- Founder-only server operations must verify the caller's Supabase session and role.

### Founder versus Founding Supporter

These must remain separate:

- `founder` is an operational role belonging to the owner of toDō.
- `founding_supporter` is an account entitlement/recognition status that the founder may grant to selected users.

A Founding Supporter is not an administrator. An administrator is not automatically a Founding Supporter. Only the founder may issue Founding Supporter grants unless the founder explicitly delegates that exact capability.

Whether the founder role is publicly displayed as a badge or title is a separate product decision. Public presentation must not be the source of authorization.

## Future Founding Supporter code system

The code-management UI and backend are deferred, but future implementation must honor these decisions:

- Only the founder account decides who receives a Founding Supporter code.
- Only the founder may create, revoke, reassign, or deliberately make a code transferable unless the founder explicitly delegates that permission.
- Codes should be account-bound by default. The founder may select the recipient by username; the server resolves and stores the immutable account UUID.
- The founder may deliberately issue a bearer/transferable code when that behavior is desired.
- A code is random, unguessable, single-use, stored as a cryptographic hash, and redeemed transactionally.
- Redemption grants the agreed entitlement bundle: `legacy_3_1` plus `founding_supporter`.
- The existing entitlement model already permits `source_kind = 'support'`; a future code UUID can be recorded in `source_id`.
- A code grants entitlements only. It does not merge accounts, transfer toDōs, connect providers, or grant administrator/founder authority.
- Issuance, redemption, revocation, and reassignment must be audited.

This is a custom toDō backend capability and does not depend on App Store Connect offer-code configuration.

## Deferred password and MFA direction

### Passwords

Username/password authentication is not part of the immediate username-first provider flow. Apple or Google remains the proof of ownership.

If password login is added later:

- The username may remain the user-facing account locator.
- Supabase password auth natively verifies an email or phone plus password, so username/password would require a secure server-side resolution flow or a different auth design.
- A password must attach to the same canonical Supabase user rather than create another account.
- Password reset and account recovery must be designed before password enrollment becomes mandatory.

### MFA and SMS

MFA is deferred until its recovery and support behavior is designed. When added:

- Factors attach to the canonical account UUID, not the username string.
- TOTP should be evaluated before SMS because it does not depend on cellular delivery.
- SMS may be added later if user need justifies provider cost and phone-number lifecycle handling.
- The founder account should be the first account required to use MFA once privileged tools exist.
- Privileged server operations should enforce an MFA-verified Supabase session, not merely hide controls in the UI.

The current local Supabase configuration has TOTP and phone MFA disabled; the immediate account migration must not enable or require either factor.

## Exceptional duplicate-account recovery

Automated account merging is not part of this project. The expected user guidance is to use the provider identity connected to the intended username.

If manual recovery is ever required:

1. Identify the intended surviving account UUID.
2. Verify control of the relevant identities or make an explicit founder-authorized support decision.
3. Inventory data, Collabs, purchase links, and entitlements on both UUIDs.
4. Define conflict rules before moving anything.
5. Link the desired provider to the surviving account only after it is no longer attached to the duplicate.
6. Delete or archive the duplicate only after verification.
7. Audit the operation.

Never merge accounts merely because someone knows or enters the same username.

## Implementation plan

### Phase 1: Shared schema and account state

1. Add `profiles.account_setup_version` with a safe legacy default.
2. Add database username-format enforcement consistent with the finalized client contract.
3. Add or update profile DTOs on each client.
4. Introduce a shared conceptual account-resolution state so sync starts only after username/provider resolution.
5. Add contract tests for setup-version and username normalization behavior.

### Phase 2: New-account and returning-sign-in UX

1. Separate **Create Account** from **Sign In**.
2. Add username-first create-account flow.
3. Add username-first returning-sign-in flow.
4. Resolve the returned profile before starting sync.
5. Handle match, mismatch, provisional, and existing-account outcomes explicitly.
6. Remember the last successful username locally as a convenience only.

### Phase 3: Existing-user migration

1. Present **Complete Your toDō Account** when setup version is below `2`.
2. Require a username only when one is missing.
3. Confirm an existing username without forcing a rename.
4. Show the currently connected identity or identities.
5. Mark setup version `2` after required completion.
6. Verify that entitlements and synced data are unchanged.

### Phase 4: Provider connection

1. Enable manual identity linking locally and in the hosted project.
2. Add connected-provider state to account/profile UI.
3. Implement native Apple and Google identity linking from an authenticated account.
4. Verify the canonical UUID remains unchanged after linking.
5. Handle `identity_already_exists`, manual-linking-disabled, cancellation, and provider failures with user-facing guidance.

### Phase 5: Founder designation

1. Add the service-owned account-role table.
2. Assign `founder` to the approved existing legacy account UUID through a controlled migration or service operation.
3. Add server-side role checks and tests before exposing any privileged control.
4. Do not build the Founding Supporter code-management interface in this phase unless separately requested.

### Phase 6: Optional contact email

1. Add contact-preference storage and RLS.
2. Add verification and consent handling.
3. Add the optional onboarding/account-settings UI.
4. Keep the feature hidden until verification and sending infrastructure are operational.

## Likely code and documentation touchpoints

### Shared Supabase

- `Shared/Supabase/schemas/01_profiles.sql`
- A new replayable migration under `Shared/Supabase/migrations/`
- `Shared/Supabase/config.toml`
- Hosted Supabase Auth manual-linking configuration
- Existing profile bootstrap trigger/function contracts
- RLS and contract tests

### iPhone and iPad

- `ToDo/Core/Infrastructure/Supabase/SupabaseAuthStore.swift`
- `ToDo/Core/Profile/ToDoProfile.swift`
- `ToDo/Features/Account/Views/AccountView.swift`
- Current Apple and Google sign-in entry views
- Sync coordinator gating after authentication
- Profile and commerce contract tests

### Mac

- `ToDo/ToDo Mac/ToDoMacAuthStore.swift`
- `ToDo/ToDo Mac/ToDoMacProfileViews.swift`
- Mac sign-in and account presentation

### Apple Watch

- Standalone Watch auth must respect setup/mismatch state.
- The initial implementation may direct an incomplete account to finish setup on iPhone, Mac, Android, or Web instead of reproducing the full username-creation flow on Watch.
- Watch sync must not begin against an unresolved account.

### Android

- `Google/ToDo_onGoogle/app/src/main/java/dev/iamshift/todo/android/core/auth/SupabaseAuthSessionProvider.kt`
- `Google/ToDo_onGoogle/app/src/main/java/dev/iamshift/todo/android/ui/ToDoApp.kt`
- Provider callback/deep-link account resolution
- Username/profile loading and migration UI

### Web

- `Web/features/auth/AuthProvider.tsx`
- `Web/features/auth/SignInCard.tsx`
- Auth callback and account-resolution state
- Username-first create/sign-in UI
- `Docs/WebProductionSetup.md`
- `Docs/WebLocalDevelopment.md`
- `Web/docs/WebFoundationDecisions.md`, if it repeats the separate-account policy

## Security requirements

- Preserve `auth.users.id` and `auth.uid()` as the authorization basis.
- Do not authorize access based on a username supplied by the client.
- Validate profile ownership after provider authentication before starting sync.
- Do not expose Supabase service-role credentials in any client.
- Do not automatically link providers by an unverified contact email.
- Do not overwrite an existing profile username during Create Account.
- Do not silently move entitlements between account UUIDs.
- Founder role writes must be service-only.
- Log security-relevant provider-linking and founder-authority operations without logging raw provider tokens.
- Keep provider ID tokens and nonces in memory only for the duration required by the auth/link operation.
- Preserve generic, helpful error behavior without exposing private account information to unauthenticated callers.

## Acceptance criteria

### New account

- A user can choose an available username and create an account with Apple.
- A user can choose an available username and create an account with Google.
- A username collision returns to username selection without losing the authenticated account context.
- A provider already connected to an existing account does not overwrite that account's username.
- Sync does not start until the account has been resolved and activated.

### Returning sign-in

- Entering the correct username and connected provider signs into the expected UUID.
- Selecting a provider connected to another username produces a clear mismatch result.
- A provisional provider account is not presented as the requested existing account.
- The last successful username may be remembered locally and is cleared or replaced on account switch.

### Existing-user migration

- A user without a username is required to claim one once.
- A user with a username sees confirmation and is not forced to rename it.
- Setup completion persists across devices through `account_setup_version`.
- Migration does not change account UUID, tasks, Collabs, purchases, or entitlements.

### Provider linking

- Connecting Apple or Google while authenticated preserves the canonical UUID.
- Both identities subsequently sign into the same profile and data.
- An identity already attached elsewhere is not reassigned automatically.
- Provider-link failures and cancellations do not sign the user into another account.

### Founder authority

- The approved legacy account has role `founder`.
- Changing its username does not remove founder authority.
- A normal user or administrator cannot grant themselves founder authority.
- Founder and Founding Supporter remain distinct in code, schema, and UI.
- No client can write account roles directly.

### Regression coverage

- Existing RLS continues isolating personal account data.
- Current Legacy 3.1 and Founding Supporter entitlement reads remain unchanged.
- Account deletion still removes the correct canonical account data.
- iOS, Mac, Watch, Android, and Web do not begin sync for an unresolved account.
- Existing profile, Collab, purchase, and sync tests continue passing.

## Out of scope for the immediate implementation

- Username/password sign-in.
- Password reset or recovery email.
- Mandatory TOTP or SMS MFA.
- Automated duplicate-account merging.
- Moving data between two existing account UUIDs.
- Provider unlinking, unless separately approved.
- Founding Supporter code issuance/redemption UI.
- General-purpose customer-support administration console.
- Public founder badge or title presentation.

These exclusions are deliberate. Codex should not expand the first implementation to include them without a separate product decision.

## External technical references

- [Supabase Auth overview](https://supabase.com/docs/guides/auth)
- [Supabase identity linking](https://supabase.com/docs/guides/auth/auth-identity-linking)
- [Supabase password-based authentication](https://supabase.com/docs/guides/auth/passwords)
- [Supabase MFA](https://supabase.com/docs/guides/auth/auth-mfa)
- [Supabase custom access token hooks](https://supabase.com/docs/guides/auth/auth-hooks/custom-access-token-hook)

## Definition of done

This account-architecture change is complete when a new user can create a username-first account with Apple or Google, a returning user can identify the intended username before provider authentication, an existing user can complete the one-time setup without losing data or access, a second provider can be explicitly connected to the same UUID, unresolved accounts cannot begin sync, and the approved legacy account is securely designated as the founder account.
