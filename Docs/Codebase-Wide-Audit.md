# toDō Codebase-Wide Audit

**Review date:** 2026-08-08  
**Repository reviewed:** `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo`  
**Targets reviewed:** iOS/iPadOS app, macOS app, watchOS app, WidgetKit/Live Activity extension, unit/UI test targets, shared Supabase/commerce/profile/sync services  
**Review type:** Static architecture, typography/design contract, localization, safety, concurrency, data-flow, and build-readiness audit

## Scope and Working Rules

The repository is intentionally heavily modified and contains staged, unstaged, deleted, added, and untracked work. This audit did not reset, clean, reinitialize, or overwrite that work. The `/Users/shift/Development/Mobile/2026/Feb/ToDo/Open Source/` repository was not inspected or modified.

The purpose of this pass is to identify concrete issues and protect the existing product direction, not to rewrite the application into a different architecture.

## Architecture Summary

The codebase is a SwiftUI-first MV+Services application:

- SwiftUI views own presentation state and user interaction.
- SwiftData models own local persistence and relationships.
- Services own notifications, location, calendar, audio, Apple Intelligence, voice transcription, widgets, Live Activities, authentication, sync, commerce, profiles, and collaboration.
- `SupabaseSyncService` and `SyncCoordinator` coordinate remote state, realtime events, tombstones, retries, account isolation, and conflict behavior.
- Shared theme and typography contracts live in `Core/Theme/AppTheme.swift`; Mac and Watch provide platform-adapted role wrappers.
- Apple sign-in presentation uses a narrow UIKit bridge in `Core/Infrastructure/Supabase/SupabaseAuthStore.swift` because AuthenticationServices and Google sign-in require a view-controller presentation context. General UI remains SwiftUI.

This is a reasonable architecture for an entry-to-mid-level engineer: it has clear domain boundaries and meaningful services, but several large services and platform view files now need decomposition by measured responsibility rather than by arbitrary file size.

## Verified Strengths

### Design system foundation

- Brand/logo role: Cal Sans.
- View-title role: Cal Sans UI, semibold/bold.
- Display/section role: Bebas Neue.
- UI role: Jura with explicit weight helpers.
- Long-form role: Aleo italic.
- User-entry role: Aleo medium.
- Shared colors are named through `AppColor` and asset-backed color sets.
- The Mac and Watch layers already expose role helpers rather than requiring every view to know raw font names.
- All inspected app/extension Info.plist files list the same approved font resources: Cal Sans, Cal Sans UI, Bebas Neue, Jura, Aleo regular variable, and Aleo italic variable.

### Data and state boundaries

- Sync uses stable UUIDs, collaboration scope, tombstones, account revision guards, cancellation, and bounded retry/debounce state.
- StoreKit uses product classification, transaction observation, server-backed reconciliation, explicit restoration, and account-switch protection.
- Profile image handling normalizes supported formats and separates local, Apple-device, and all-device scope.
- Widget Swift 6 cache access is protected by one lock-backed cache object instead of mutable nonisolated static globals.
- Watch action replay is persisted and ordered.
- Notification recurrence generation is bounded rather than treating a recurring schedule as an infinite list.
- Detailed cross-platform data-structure findings are tracked in [`DataStructuresAndAlgorithmsAudit.md`](DataStructuresAndAlgorithmsAudit.md).

## Findings

### P0: Runtime verification is still required for release readiness

The application has now compiled successfully for the native iOS, macOS, and watchOS schemes in Debug, and the iOS test bundles also compile. Compilation does not prove runtime readiness: the remaining visual and behavioral claims require narrow iPhone, iPad portrait/landscape/split, small/Ultra Watch, and narrow/wide Mac runs. The prior environment has repeatedly shown Xcode beta/CoreSimulator failures, so runtime test results must distinguish infrastructure failure from source failure.

### P1: Localization requires human review after completion

The catalog previously had 138 missing values in every supported language. Those values are now translated in `Resources/Localizable.xcstrings`, with placeholder and source-key parity preserved. `Resources/InfoPlist.xcstrings` remains complete for all supported languages.

The remaining risk is linguistic review by native speakers, especially for Arabic, Hindi, Japanese, Thai, Urdu, and customer-facing collaboration/profile copy. The validator guards completeness and formatting; it cannot judge tone, regional terminology, or naturalness.

### P1: Visual parity still requires rendered review

The shared roles are present, and Mac/Watch platform files now classify their remaining system-font uses explicitly: SF Symbols/icon glyphs use platform system fonts, while release-history/code values use a documented monospaced helper. Customer-facing prose continues to use the approved shared roles. Static classification reduces drift; it does not replace rendered review of baselines, weight, Dynamic Type, and narrow layouts.

Source inspection confirms shared palette and role helpers, but it cannot validate baseline alignment, clipping, card width, carousel paging, whitespace, title-bar placement, sheet containment, or Reduce Motion behavior. These are known prior risk areas for this project and must be reviewed visually per platform.

### P2: Large files concentrate responsibilities

The largest risk areas are:

- `Core/Infrastructure/Supabase/SupabaseSyncService.swift` at roughly 2,851 lines.
- `ToDo Mac/ToDoMacViews.swift` at roughly 6,746 lines.
- `Features/Settings/Views/SettingsView.swift` at roughly 3,151 lines.
- `Features/Account/Views/AccountView.swift` at roughly 3,321 lines.
- `ToDo Watch App/WatchSupportViews.swift` at roughly 3,441 lines.

Large files are not automatically defects, but the Mac/Watch view files make design drift and accidental state coupling more likely. Refactor only at responsibility boundaries: shared sections, platform adapters, and services with tests. Do not split files only to reduce line count.

### P2: Main-actor sync orchestration needs profiling

`SupabaseSyncService` is main-actor isolated while coordinating networking, SwiftData reconciliation, realtime tasks, and UI state. This can be correct if blocking work is avoided, but static inspection cannot prove that large fetch/index/apply phases stay responsive. Low-overhead start/end measurements now record fixed operation labels, outcome, and duration without user data. Profile realistic datasets before moving code across actors. The existing guards and task cancellation should be preserved during any refactor.

### P2: Remaining fatal startup paths are intentional but user-hostile if reached

`App/ToDoApp.swift` and `ToDo Mac/ToDoMacApp.swift` now fall back to an in-memory store, persist a recovery flag, and show a localized, dismissible recovery notice. `preconditionFailure` remains only if even the in-memory recovery container cannot be created; that is a process-level invariant rather than a normal store error. The runtime recovery path still needs device testing with an intentionally unavailable store.

### P3: Target language-version drift was corrected in this pass

The Watch unit-test and UI-test targets, and the WidgetKit extension, had stale Swift 5/watchOS 26 settings while the app targets were already on Swift 6/watchOS 27. Those target settings now use Swift 6 and the project deployment target. The Watch unit-test host also now points at the actual `ToDo Watch.app` product and its test source imports the emitted `ToDo_Watch` module.

The Xcode 27 test-build phase still emits `Metadata extraction skipped, no AppIntents.framework dependency found` for test targets that do not contain App Intents. This is a toolchain warning, not an app-target compile error; it should not be suppressed until the target-level build setting is confirmed against the final Xcode 27 release.

### P3: Raw logging is now guarded by validation

Watch direct-sync paths used `print(...)` for server and merge errors. This pass changed those paths to `AppLog` with the sync category and added `Scripts/validate_raw_logging.rb` to prevent regressions. New production diagnostics should use privacy-aware `AppLog`; avoid tokens, signed JWS values, email addresses, or private profile fields in logs.

### P3: Recoverable force unwraps were found and corrected

This pass removed force unwraps from:

- `Services/Notifications/NotificationManager.swift`
- `Core/Services/LocationReminderService.swift`
- `ToDoWidget/ToDoWidgetEntry.swift`
- Four duplicate-repair selections in `Core/Infrastructure/Supabase/SupabaseSyncService.swift`

Remaining unwraps should be classified as trusted invariants, test-only assumptions, or recoverable paths. The next review should prioritize any new force unwrap rather than attempting a noisy whole-codebase rewrite.

## Platform Parity Matrix

| Area | iOS/iPadOS | macOS | watchOS | Static result |
| --- | --- | --- | --- | --- |
| Shared fonts registered | Yes | Yes | Yes | Verified in plist/source configuration |
| Shared role names | Yes | Adapted wrappers | Adapted wrappers | Present; icon/code system-font exceptions are explicit |
| Shared brand palette | AppColor/assets | ToDoMacPalette/assets | WatchAppColor | Present; runtime contrast still needs device checks |
| ToDo CRUD | Full | Full target path | Compact/standalone-adapted | Behavior needs real-device verification |
| NanoDos/tags/recurrence | Full | Full target path | Platform-adapted | Behavior needs real-device verification |
| Sync/tombstones | Full | Full target path | Direct/companion paths | Stress/account-switch testing required |
| Profiles | Full | Full target path | Shared/limited platform surface | Propagation previously tested; recheck after changes |
| Collaboration | Full | Full target path | Limited/brief interaction | RLS and invitation flows require backend evidence |
| Commerce | Full StoreKit flow | Universal purchase target | Shared/limited | Sandbox/App Store configuration remains external |
| Widgets/Live Activities | Widget/ActivityKit | Mac-specific path | Watch-specific path | OS availability and rendered testing required |
| Accessibility | Implemented adaptations | Mac adaptations | Watch adaptations | Reduce Motion/Differentiate Without Color need device QA |
| Localization | Shared catalog | Shared catalog | Shared catalog | Catalog complete; native-speaker review remains |

## Recommended Order From Here

1. Have native-speaking testers review the completed translations and record corrections in the catalog.
2. Run the platform visual QA matrix and capture findings by view, width, color scheme, Dynamic Type, Reduce Motion, and Differentiate Without Color.
3. Profile the new sync measurements with representative data before considering actor-boundary refactors.
4. Runtime-test the persistent-store recovery notice with an intentionally unavailable store.
5. Keep Swift 6 target settings aligned when new extensions or test targets are added.
6. Keep `DataStructuresAndAlgorithmsAudit.md` updated as each optimization is implemented or rejected with evidence.

## Verification Performed In This Pass

- Static source scan across shared, iOS/iPadOS, macOS, watchOS, WidgetKit, and test source directories.
- Font resource and Info.plist registration scan.
- SwiftUI/system-font usage scan.
- Force-unwrap, fatal/precondition, and raw-print scan.
- `ruby Scripts/validate_localization_sources.rb`: passed.
- `ruby Scripts/validate_string_placeholders.rb`: passed.
- `bash Scripts/validate_app_intent_metadata_terms.sh`: passed.
- `ruby Scripts/validate_localizations.rb`: passed; all supported languages are complete in both string catalogs.
- `ruby Scripts/validate_raw_logging.rb`: passed; no production raw console logging remains.
- `bash Scripts/validate_release_readiness.sh`: passed after localization completion.
- `xcodebuild -project Apple/toDo.xcodeproj -scheme ToDo -configuration Debug -destination 'generic/platform=iOS' ... build`: passed.
- `xcodebuild -project Apple/toDo.xcodeproj -scheme 'ToDo Mac' -configuration Debug -destination 'platform=macOS' ... build`: passed.
- `xcodebuild -project Apple/toDo.xcodeproj -scheme 'ToDo Watch App' -configuration Debug -destination 'generic/platform=watchOS' ... build`: passed.
- iOS `build-for-testing`: passed; Xcode emitted an App Intents metadata warning for the test-build phase because the test target does not link `AppIntents.framework`.
- Watch test `build-for-testing`: passed after correcting the test host to `ToDo Watch.app`, aligning the test module import, and moving the Watch test/UI-test/widget targets to Swift 6/watchOS 27. Xcode still emitted the non-fatal App Intents metadata warning described above.
- iOS, macOS, and watchOS static analysis: passed after the WidgetKit cache was moved behind an explicit lock-backed cache object.
- Final post-localization iOS, macOS, and watchOS Debug builds: passed; Xcode generated and compiled all localized resources.
- Final iOS and watchOS `build-for-testing`: passed.
- Git diff checks were not available because this local copy is not a Git worktree; file-level validation used the project validators and compiler instead.

## Explicit Non-Claims

This audit does not claim:

- That all views are visually identical across platforms.
- That translations are linguistically perfect; native-speaker review remains required.
- That sync is race-free under arbitrary load.
- That StoreKit, RLS, or App Store configuration is production-valid.
- That every simulator/device runtime path is healthy; generic builds do not exercise CoreSimulator or physical-device behavior.
