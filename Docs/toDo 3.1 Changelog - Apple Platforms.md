# toDō 3.1 — Apple Platforms

toDō 3.1 expands the personal productivity system across iPhone, iPadOS, Apple Watch, and Mac. The release strengthens the task lifecycle, account ownership, synchronization, collaboration, membership, reminders, intelligent assistance, accessibility, and platform-specific presentation.

## Across Apple Platforms

### Task workflow

- Home now centers the experience around **What matters now?**
- Create, view, edit, complete, reopen, archive, trash, restore, and permanently delete toDōs.
- NanoDos, Tags, due dates, recurrence, notes, reminders, location-related workflows, and snooze are integrated throughout the supported task surfaces.
- Archives and Trash provide separate recovery-oriented locations instead of treating completion as deletion.
- Stats now includes Momentum, workload signals, completion history, and activity-graph data.

### Accounts, profiles, and privacy

- Username-first account setup and returning-user resolution.
- Apple and Google provider linking to one canonical Supabase account when explicitly initiated from an authenticated, resolved account.
- Account-scoped ownership remains tied to the immutable account UUID; usernames are locators, not authorization.
- Owner profiles include display name, username, email visibility for the owner, membership state, and profile-image support.
- Collaborator profiles expose only the minimum identity and role context required for a shared Collab.
- Account deletion calls the server-owned deletion flow and clears local account state only after confirmation.

### Sync and data safety

- Local, iCloud, and toDō Sync storage modes remain distinct.
- Sync migration, conflict handling, deletion mirroring, tombstones, Realtime refresh, account switching, and offline/reconnect paths were strengthened.
- Personal records are isolated by account namespace; signing out does not silently reassign one account's records to another account or to an unsigned session.
- toDō Sync is the account-backed cross-device path. Web access is not part of this Apple-platform release.

### toDō+

- Monthly and yearly toDō+ subscriptions.
- Lifetime toDō+ purchase.
- StoreKit 2 purchasing and explicit restoration.
- Account-linked server entitlements with expiration, grace-period, revocation, and account-switch protection.
- Pioneer and Founding Supporter recognition, including early-adopter/grandfathered account handling where the server designates it.
- Appreciation consumables remain repeatable support purchases and do not unlock capabilities.

### Collabs

- Create and delete owned Collabs.
- Invite, accept, decline, cancel, leave, remove members, and open invitation links.
- Profile-aware collaborator presentation with role-limited actions.
- Invitation push invalidation and refresh paths.
- Shared-task authorization remains server-controlled; free-account invitation limits are enforced by the backend policy.

### Reminders and notifications

- Standard due reminders, Time Sensitive reminders, snooze, notification actions, deep links, and synchronized notification state.
- Custom reminder sounds from MP3, M4A, CAF, WAV, AIFF, and AIF, converted to a notification-ready local copy.
- Notification payloads preserve enough identity to resolve synchronized records and recover from stale local records.
- Calendar integration mirrors due toDōs **one way from toDō to Calendar**. It does not synchronize Calendar events back into toDō.

### Apple Intelligence and voice

- Natural-language voice entry can produce a structured toDō with title, notes, due date/time, reminder intent, recurrence, Tags, NanoDos, and location information where supported.
- A short clarification and confirmation flow prevents inferred details from being saved silently.
- Apple Intelligence can summarize current task pressure and recommend a next focus when available and enabled.
- These features are implemented on supported iPhone, iPadOS, and macOS configurations. They are intentionally not claimed as watchOS features.

### App Intents, widgets, and Live Activities

- iPhone, iPadOS, and macOS expose App Intent task workflows for create, find/read, update, complete, reopen, archive, trash, restore, and permanent delete.
- Widgets received localization, sync-aware identity, formatting, and deep-link improvements.
- Live Activity support is integrated with the targets that include the Live Activity/widget infrastructure. Final availability remains target- and OS-version-specific; it is not a universal Watch feature.

### Onboarding, accessibility, and localization

- Guided onboarding covers creation, editing, storage choice, notifications, Settings, and replay.
- Reduce Motion, Differentiate Without Color Alone, Dynamic Type, VoiceOver labels, Voice Control names, and adaptive layouts were expanded.
- Localization coverage and locale-aware dates/counts were expanded across the app, widgets, Watch surfaces, commerce, accounts, Collabs, sync, and onboarding.

## iPhone

- Complete 3.1 task, account, profile, Collab, membership, sync, notification, widget, Live Activity, App Intent, Apple Intelligence, onboarding, accessibility, and Stats experience.
- iPhone remains the reference implementation for the compact task workflow and the source of shared product hierarchy.

## iPadOS

- The iPhone feature set is adapted for regular-width presentation, split layouts, pointer/keyboard use, sheets, popovers, and Stage Manager.
- Stats, Settings, Profiles, Collabs, Archives, Trash, Membership, and ToDo editing use iPad-specific spacing and side-panel presentation where it improves clarity.

## watchOS

- Standalone Watch authentication and direct toDō Sync support.
- Direct Watch management of ToDos, NanoDos, Tags, notes, due dates, recurrence, completion/reopen, Archives, and Trash.
- Offline actions can queue and retry when connectivity returns.
- Apple Intelligence and App Intent CRUD are intentionally not part of the Watch experience.
- Standalone location-reminder editing remains dependent on paired-phone assistance because the direct Watch backend representation does not expose the required location fields.

## macOS

- Native SwiftUI Mac application with Home, ToDos, ToDo create/view/edit, Settings, Stats, Account, Profiles, Collabs, Membership, Archives, Trash, Tags, NanoDos, notifications, App Intents, Apple Intelligence, toDō Sync, menu-bar integration, Dock preferences, and native window behavior.
- The Mac surface uses macOS presentation patterns while preserving the iPhone/iPad product hierarchy, typography roles, colors, and task capabilities.
- Mac Apple Sign In still requires hosted Supabase/provider configuration verification before it can be considered released.
- Persistent-store recovery is implemented, but its user-visible behavior remains a release-validation item.

## What This Changelog Does Not Claim

- It does not claim that hosted App Store Connect, Supabase, Apple Sign In, StoreKit sandbox, Server Notifications, or migration verification is complete.
- It does not claim App Intent CRUD or Apple Intelligence on watchOS.
- It does not claim bidirectional Calendar sync.
- It does not claim Web access as part of this Apple-platform release.
- It does not treat source code presence as proof of real-device or production readiness.
