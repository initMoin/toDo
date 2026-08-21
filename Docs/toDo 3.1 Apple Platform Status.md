# toDō 3.1 Apple Platform Status

**Status date:** August 19, 2026  
**Scope:** iPhone, iPadOS, macOS, and watchOS  
**Purpose:** Release-readiness status after reconciling the 3.1 scope freeze with the current Apple-platform source.

## How To Read This

The attached scope-freeze document is treated as a release-board input, not as an instruction to add new product scope. This status document records what the current source supports and separates:

- **Implemented:** present in the current code and target configuration.
- **Implemented; verify:** present in source, but still requires device, hosted-service, or App Store validation.
- **Blocked by configuration:** code exists, but an external provider or hosted setting must be corrected.
- **Platform limitation:** intentionally unavailable or delegated to another Apple device.
- **Deferred:** outside the frozen Apple-platform 3.1 scope.

Source presence is not treated as proof of release readiness.

## Verification Snapshot

**Checked:** August 19, 2026

Passed source-level gates:

- `validate_localization_sources.rb`
- `validate_string_placeholders.rb`
- `validate_raw_logging.rb`
- `validate_app_intent_metadata_terms.sh`
- `xcodebuild -list`

Open automation gates:

- `validate_localizations.rb` reports 99 missing translated values in each supported non-English `Localizable.xcstrings` locale. These values are newly added customer-facing copy and remain pending deliberate native-speaker translation review. They must not be filled with guessed translations.
- `validate_release_readiness.sh` remains red because localization completeness is a required gate.
- Release compilation for iPhone, macOS, and watchOS was not conclusively verified in this pass. The package graph resolves, but the network-enabled build attempt was rejected by the execution environment's usage limit before compilation began. This is not a compiler result.

## Shared Product Surface

| Area | Current status | Notes |
| --- | --- | --- |
| Core task lifecycle | Implemented; verify | Active, Done, Archived, Trashed, restore, and permanent deletion paths exist. |
| NanoDos | Implemented; verify | Create, edit, completion, parent-completion policy, sync, and Watch support exist. |
| Tags | Implemented; verify | Local, sync, Watch, App Intent, and collaboration paths exist. |
| Recurrence | Implemented; verify | Supported in the editor, sync contract, Calendar mirroring, App Intents, and Watch direct sync. |
| Notifications | Implemented; verify | Due, Time Sensitive, custom sounds, actions, routing, and synchronized notification state exist. |
| Custom reminder sounds | Implemented; verify | MP3, M4A, CAF, WAV, AIFF, and AIF import paths exist with local notification-ready conversion. |
| Account architecture | Implemented; verify | Username-first resolution, provider linking, immutable `auth.users.id`, account switching isolation, and sync gating exist. |
| Profiles | Implemented; verify | Owner profile and limited collaborator profile paths exist, including avatar normalization and revision invalidation. |
| Collabs | Implemented; verify | Creation, invitation, accept/decline, cancel, member removal, leave, owned-Collab deletion, invitation links, email/share flows, and push invalidation exist. |
| Account deletion | Implemented; verify | The client calls the `delete-account` Edge Function and clears local account state after server confirmation. |
| toDō+ commerce | Implemented; verify | StoreKit 2 catalog, purchase, restore, account-linked entitlements, Pioneer/Founding Supporter recognition, grace/revocation state, and transaction linking exist. |
| App Intents | Implemented on iPhone, iPadOS, and macOS; verify | CRUD and Apple Intelligence creation actions are in the main and Mac targets. Watch does not claim App Intent CRUD. |
| Apple Intelligence | Implemented on supported iPhone, iPadOS, and macOS configurations; verify | Structured voice parsing, clarification, summaries, and focus recommendations exist. It is intentionally not implemented on watchOS. |
| Voice entry | Implemented on supported Apple platforms; verify | Speech transcription feeds structured parsing and confirmation before save. |
| Widgets | Implemented; verify | Widget formatting, localization, sync-aware identity, and deep-link routing exist in the widget target. |
| Live Activities | Implemented for targets that include the Live Activity/widget infrastructure; verify | Do not describe this as a universal watchOS feature. Confirm the final target matrix before release claims. |
| Calendar | Implemented; verify | toDō due dates are mirrored **one way from toDō to Calendar**. There is no Calendar-to-toDō bidirectional sync. |
| Activity graph | Implemented; verify | Completion activity is stored with transition timestamps and rendered as bounded platform-specific grids. |
| Localization and accessibility | Implemented; verify | Catalog validation, Dynamic Type, Reduce Motion, Differentiate Without Color, VoiceOver labels, and platform adaptations exist. Runtime and native-speaker review remain required. |

## iPhone

### Implemented

- Full Home, ToDos, ToDo create/view/edit, Stats, Settings, Account, Profiles, Collabs, Archives, Trash, Tags, NanoDos, Notifications, Membership, About, and onboarding surfaces.
- App Intent CRUD and Apple Intelligence creation flow.
- Widgets, notification deep links, Live Activity integration, Calendar mirroring, custom sounds, account deletion, and toDō Sync.
- Account switching and unsigned/signed-in namespace isolation.

### Release verification still required

- Functional UI coverage for onboarding, task lifecycle, Archives/Trash, recurrence, notifications/deep links, widgets, Live Activities, App Intents, local/iCloud/toDō Sync migration, account switching, commerce, Pioneer migration, Collabs, and offline reconnect.
- Runtime accessibility, localization, RTL, poor-network, stale/corrupt local data, memory pressure, and repeated foreground/background checks.

## iPadOS

### Implemented

- Shared iPhone feature set with adaptive presentation for regular-width layouts.
- iPad-specific Settings side-panel behavior, Stats paging, split-layout presentation, pointer/keyboard-aware interactions, and platform-specific spacing.

### Release verification still required

- 11-inch and 13-inch portrait/landscape.
- Split View and Stage Manager width changes.
- Hardware keyboard, pointer, focus, sheets/popovers, selection persistence, rotation while sheets are open, multitasking suspension/resume, and memory pressure.
- The same shared commerce, migration, account, Collab, notification, App Intent, and accessibility checks required on iPhone.

## macOS

### Implemented

- Native SwiftUI Mac target with its own lifecycle and presentation layer.
- Home, ToDos, ToDo create/view/edit, Settings, Stats, Account, Profiles, Collabs, Membership, Archives, Trash, Tags, NanoDos, sync, App Intents, Apple Intelligence, notifications, Dock preference, menu-bar extra, and window activation behavior.
- Persistent SwiftData storage with an explicit in-memory recovery path when the persistent container cannot be opened.

### Blocked by hosted configuration

- **Apple Sign In:** Mac code handles `Unsupported provider: missing OAuth secret`, but the hosted Supabase/provider configuration must be corrected and verified before claiming Mac Apple authentication is released.

### Release verification still required

- Google and Apple sign-in, account setup, sync, migrations, task lifecycle, Collabs, StoreKit, notifications, App Intents, Apple Intelligence availability states, menu-bar-only use, Dock visibility, window restoration, deep links, keyboard commands, focus, sleep/wake, offline recovery, localization, VoiceOver, Reduce Motion, and increased contrast.
- Persistent-store failure must be tested so the temporary recovery store is visible and not mistaken for durable storage.

## watchOS

### Implemented

- Standalone Watch authentication/session support.
- Direct Watch-to-Supabase fetch and mutation paths for ToDos, NanoDos, Tags, notes, due dates, recurrence, completion/reopen, Archives, and Trash.
- Durable action queue, reconnect handling, account-aware presentation, Stats, and companion-phone fallback paths.

### Platform limitations

- Apple Intelligence and App Intent CRUD are not implemented on Watch.
- Direct standalone Watch location-reminder mutation is intentionally a no-op because the current backend ToDo representation does not expose the required location fields. Location reminders require paired-phone assistance, or the standalone UI must state that the capability is unavailable.

### Release blockers and verification

- Standalone end-to-end validation on Wi-Fi, cellular, offline, iPhone nearby/unavailable, expired auth, reconnect, simultaneous edits, reinstall/restart, small/Ultra displays, Digital Crown, accessibility, and low-power conditions.
- Durable queue ordering, retry, duplicate prevention, stale-record handling, token refresh, process termination, and recovery.
- Explicitly document the location-reminder limitation in the final product copy.

## Shared P0 Release Board

- [ ] Mac Apple Sign In hosted configuration verified.
- [ ] App Store Connect product IDs, subscription group, one-week introductory offer, lifetime product, consumables, and offer-code paths verified.
- [ ] Purchase restore, transaction linking, App Store Server Notifications, grace, revocation, account switching, and Pioneer migration verified.
- [ ] 3.0 to 3.1 and 3.0.1 to 3.1 migration verified.
- [ ] Local to iCloud, local to toDō Sync, and iCloud to toDō Sync migration verified.
- [ ] Sync conflict, deletion/tombstone, offline/reconnect, and account-switch isolation verified.
- [ ] Collab invitation, acceptance, expiry, cancellation, deletion, revoked membership, duplicate invite, offline invite, and account-switch edge states verified.
- [ ] Notification and widget deep-link routing verified for stale/deleted records.
- [ ] Standalone Watch sync and queue durability verified.
- [ ] Persistent Mac-store recovery behavior verified.
- [ ] Accessibility, localization, RTL, poor-network, and performance passes completed on all four Apple platforms.
- [ ] Functional release test matrix completed and recorded.
- [ ] Resolve the 99 missing non-English catalog values through deliberate translation and native-speaker review; do not use the stale bulk-fill table without reconciling it to the current catalog.
- [ ] Re-run Release builds for iPhone, macOS, and watchOS after package/network access is available.

## Scope-Freeze Rule

A change belongs in 3.1 only if it:

1. fixes a defect;
2. completes functionality already represented by the frozen 3.1 design;
3. closes an integration gap;
4. addresses migration or data integrity;
5. improves accessibility, localization, security, reliability, or performance; or
6. is necessary for App Review or platform compliance.

Web access, password authentication, automated account merging, provider unlinking, a public founder badge, and a general administrative console remain outside this Apple-platform 3.1 scope.
