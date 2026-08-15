# toDō v3.1 Feature Parity

**Audit date:** 2026-08-01  
**Scope:** iOS, iPadOS, macOS, and watchOS targets in the current Xcode project

## Activity Tracker

The Stats surface now includes a GitHub-style completion activity graph on every platform.

- iPhone and iPad use a 12-week, seven-day grid with completion intensity.
- macOS uses the same 12-week data model in a wider Stats layout.
- watchOS uses an eight-week compact grid sized for the watch viewport.
- A cell represents the calendar day on which a toDō entered the Done state.
- Re-editing an already completed toDō does not create a new activity entry.
- Reopening a completed toDō clears its completion activity until it is completed again.
- Legacy completed records use their last known update timestamp until the database migration is applied.
- The app stores the completion transition in `completed_at`; the migration is source-controlled at `supabase/migrations/20260801090000_add_todo_completion_activity.sql` and still requires explicit production deployment.
- Differentiate Without Color adds a visible cell border so intensity is not communicated by color alone.
- Dynamic Type, accessibility labels, and compact platform-specific sizing are included.

The graph is intentionally an activity history, not a generic edit counter. Its source is the same `ToDo` model on all platforms, so the content should agree after sync even though the grids have different dimensions.

## Shared Product Surface

| Capability | iPhone | iPadOS | macOS | watchOS |
| --- | --- | --- | --- | --- |
| Home overview | Yes | Yes | Yes | Yes, compact |
| What matters now actions | Yes | Yes | Yes | Yes |
| Up Next overview | Yes | Yes | Yes | Yes, read-only |
| All toDōs list | Yes | Yes, split layout when appropriate | Yes, native window split layout | Yes, compact list |
| Create toDō | Yes | Yes | Yes | Yes |
| View existing toDō | Yes | Yes | Yes | Yes |
| Edit existing toDō | Yes | Yes | Yes | Yes |
| Mark done / reopen | Yes | Yes | Yes | Yes |
| Archive / trash / restore | Yes | Yes | Yes | Supported through the Watch workflow |
| NanoDos | Interactive, add/edit/delete | Interactive, add/edit/delete | Interactive, add/edit/delete | Interactive, add/edit/delete |
| Tags | Add, edit, filter, bulk actions | Add, edit, filter, bulk actions | Add, edit, filter, bulk actions | View and edit in a compact flow |
| Notes | Yes | Yes | Yes | Yes, compact editor |
| Due date and time | Yes | Yes | Yes | Yes, watch-sized picker |
| Day-only due date with configured default time | Yes | Yes | Yes | Yes |
| Reminder intent | Quiet, Due, Time-Sensitive | Quiet, Due, Time-Sensitive | Quiet, Due, Time-Sensitive | Quiet, Due, Time-Sensitive |
| Recurrence | Yes | Yes | Yes | Yes, compact editor |
| Location reminder | Yes | Yes | Yes | Supported with watch-sized capture flow; maps remain a phone/iPad/Mac presentation concern |
| Parent completion from NanoDos | Yes | Yes | Yes | Yes |
| Notification scheduling | Yes | Yes | Yes | Receives/schedules according to the Watch platform model |
| Custom notification sounds | Yes | Yes | Yes | Uses the companion notification experience |
| Search, filters, and utility actions | Yes | Yes | Yes | Compact, platform-appropriate subset |
| Sync account and refresh | Yes | Yes | Yes | Companion and standalone Watch sync paths |
| Profiles | Own profile and collaborator profile | Own profile and collaborator profile | Own profile and collaborator profile | Not exposed as a full profile-management surface |
| Collaboration | Personal app UI and shared-list workflows | Personal app UI and shared-list workflows | Personal app UI and shared-list workflows | Sync-compatible; detailed collaboration management remains on larger platforms |
| StoreKit membership and support purchases | Yes | Yes | Yes | Not a primary Watch purchase surface; use a larger platform for commerce management |
| Onboarding / Guided Tour | Yes | Yes | Yes | Watch-specific compact guidance |
| Localization | Yes | Yes | Yes | Watch-specific localized strings and formatting |
| Light/dark appearance | Yes | Yes | Yes | Uses the Watch environment with the app palette |
| Reduce Motion | Yes | Yes | Yes | Platform-aware subset |
| Differentiate Without Color | Yes | Yes | Yes | Supported where the compact layout can preserve the indicator |
| Dynamic Type | Yes | Yes | Yes | Watch-sized type adjustments |

## Platform Services

### iPhone and iPadOS

These targets are the reference implementation for the full operational UI.

- Widgets are provided through `ToDoWidgetExtension`.
- Live Activities are provided through the ActivityKit widget extension, including lock-screen, Dynamic Island, and Watch-specific surfaces where the system supports them.
- Remote notifications, local reminder scheduling, notification actions, and custom sound imports are supported.
- Apple Intelligence and speech-to-text entry are available in the in-app creation flow when the OS and device support them.
- StoreKit products, restoration, server entitlement linking, and account-scoped membership reconciliation are exposed from Settings.
- iPad uses the same content model with split-panel and larger-viewport presentation rather than a separate feature model.

### macOS

The native Mac target uses the same content and service layers but presents them in a native window and menu-bar workflow.

- The main app has a Dock visibility preference and a Menu Bar visibility preference. Changes that affect process activation require the documented restart flow.
- The Menu Bar popover is intentionally limited to the pending toDō list, completion actions, and opening the main app. Creation and editing open the main window instead of duplicating the editor inside the popover.
- The main window supports Home, ToDos, ToDo detail, Settings, Stats, account/profile, sync, membership, notifications, and data-management surfaces.
- macOS notifications use the same notification content builder and include the toDō text.
- macOS does not have the iOS/iPad widget extension presentation. The Mac menu-bar popover is the Mac-native quick-access equivalent.
- The Mac target should not be treated as Catalyst; it is the native SwiftUI Mac app target and uses the shared SwiftUI/service architecture.

### watchOS

Watch is a companion and standalone-capable client with deliberate interaction compression.

- Home, Up Next, ToDos, ToDo detail, create, edit, Stats, Settings, notifications, and direct sync paths are present.
- Up Next is read-only; completion controls belong in the ToDos workflow rather than the overview.
- Editors expose the same core properties as the larger platforms, but use watch-sized sections and controls.
- Standalone Watch sync uses the Watch Supabase client and the migration flow can detect whether the user has other signed-in devices.
- The Watch target does not duplicate the iPhone/iPad/Mac commerce or profile-management screens; those remain larger-platform tasks.
- Live Activity presentation is constrained by the system and Watch viewport. Its content uses the shared activity attributes and a Watch-specific layout rather than assuming the lock-screen layout will fit.

## Data and Service Parity

The following are shared rather than reimplemented per platform:

- `ToDo`, `NanoDo`, `Tag`, lifecycle transitions, recurrence validation, completion tracking, and activity-grid aggregation.
- Supabase sync payloads, including `completed_at`, tombstones, tags, NanoDos, and account-scoped ownership.
- Notification content construction, notification action routing, sound selection, and Live Activity refresh/end decisions.
- Account-scoped profile, commerce, entitlement, and collaboration service boundaries.
- App preferences for list sorting, default times, destructive action choice, reminder behavior, appearance, and accessibility policies.

The platform views are intentionally different renderers over those shared services. A difference in layout, control density, window behavior, or system integration is not a data or feature-parity failure by itself.

## Known Verification Boundaries

These items require device or App Store Connect verification rather than a simulator-only claim:

1. Live Activity lifecycle behavior on physical iPhone, iPad, and Apple Watch hardware.
2. Standalone Watch authentication and sync without a paired iPhone.
3. Notification authorization, custom sound playback, and notification tray behavior on each OS.
4. StoreKit sandbox products, introductory offers, promotional offers, restoration, revocation, grace periods, and server entitlement linking.
5. Apple Intelligence availability, language support, speech recognition quality, and user confirmation flow.
6. Menu-bar and Dock activation-policy changes on macOS after the required restart.
7. Dynamic Type, Reduce Motion, VoiceOver, Voice Control, and Differentiate Without Color on physical devices.

## Remaining Parity Risks

- The activity migration must be deployed before historical completion graphs are complete for existing users.
- Apple system surfaces can impose layout and update limits that the app cannot override, especially Live Activities and watchOS complications.
- Watch profile, commerce, and detailed collaboration management are intentionally deferred to larger screens; the underlying account and sync identity remains shared.
- The Mac menu-bar popover is intentionally not a second editor. It is a quick completion surface and entry point into the main Mac app.
