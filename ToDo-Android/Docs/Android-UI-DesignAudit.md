# Android UI Design Audit — toDō v3.1

**Date:** 2026-08-14
**Scope:** Android phone/tablet Home, Momentum, all-toDō, task rows, task detail/editor dialog, Settings, profile/connected accounts, and create dialog.

This audit applies the shared brand contract in `Docs/toDo-Brand-UI-UX-Principles.md`, using the Apple implementation as the behavioral and visual reference while retaining Material 3 conventions on Android.

## Findings and decisions

### Typography

- The Home question was using the Cal Sans UI view-title role. It now uses Jura Semibold, matching the brand matrix for strong UI headlines.
- Display typography was being used for filter labels and other ordinary controls. Filters now use Jura Medium; Bebas Neue remains reserved for section labels, button moments, and metric numbers.
- User-authored task titles continue to use Aleo Medium, while task notes use the Aleo italic role and system metadata uses Jura.
- Shared Android text roles now live in `ToDoTextStyles` instead of being recreated with per-screen guesses.

### Color and surfaces

- `onSurfaceVariant` was full-opacity primary text. It now maps to the documented secondary-text contrast in light and dark themes.
- Inactive filters now use semantic muted-surface tokens; selected filters use brand yellow with white text and no accidental default outline.
- Up Next filters now use an explicit circular shape so their selected and unselected states remain true pills across phone and tablet widths.
- The Time-sensitive Momentum badge uses the neutral action-primary role: black glyph on a light-gray badge in light mode, matching the Apple implementation.
- Cards explicitly use the elevated surface role so Material defaults cannot introduce a second surface hierarchy.
- Destructive task-row actions now use the error/destructive role.
- Action controls no longer inherit unrelated Material purple tonal surfaces. The
  tonal container role is mapped to the toDō muted surface, keeping native Android
  controls inside the product palette.
- Filled Android text fields replace unnecessary outlined fields. They use the
  elevated surface as their container and retain a brand-secondary focus line,
  so input focus remains discoverable without turning every editor surface into
  a bordered card.

### Shape and spacing

- Default Material shapes were creating overly pill-like primary controls and inconsistent card geometry. Shared tokens now define 18dp controls, 20dp cards, and 30dp hero panels.
- Screen padding, card padding, and major spacing now use shared 4-point-scale tokens.
- Home actions stack below 360dp of available content width, preserving usable touch targets and text at compact phone widths.
- Momentum badges now follow the Apple scale relationship: 28dp badge with a 14dp glyph, while retaining Android-native layout and touch behavior.

### Semantics and navigation

- Active task rows now show an open completion circle; completed rows show a checkmark. This restores the shared Active/Done state distinction.
- The all-items view uses the singular app wordmark `toDō`; only Home may use `toDō+` when an account entitlement exists. The view retains Android system Back behavior and a visible in-surface back action.
- Empty-state layout no longer requests an unbounded full-screen child inside a lazy-list item.
- Settings now follows the Apple information architecture—Account, toDō+, Sync, Look & Feel, Workflow, Guided Tour, Manage Your Data, and About—while using Android system Back and Material controls.
- Settings uses one route enum and one selected-route state. Phone widths transition between list/detail surfaces; tablet widths show the list and detail panel together.
- Home-to-destination transitions now use horizontal slide/fade only. Destination headers are owned by Profile, Stats, and Settings instead of being conditionally inserted by the parent Scaffold, and the animated container uses a snapped size transform to prevent vertical remeasurement movement.
- Destination headers use centered current-view titles with icon-only Back navigation. Their system-bar insets are disabled because the parent content already accounts for the status bar; this prevents the duplicate whitespace previously visible above Settings.
- Settings detail navigation now reverses the horizontal transition when the user
  returns to the list. A snapped size transform prevents vertical remeasurement
  from becoming a visible route-change animation.

### Profile and connected accounts

- The Home profile avatar now opens a dedicated Profile surface rather than routing to Settings.
- Profile displays the resolved account identity, email, username, avatar URL when available, and a stable placeholder when no avatar exists.
- Apple and Google appear as separate connected-account rows. Connecting a provider refreshes the resolved account state while preserving the signed-in toDō account identity.
- The current Android slice displays a remote `avatar_url` or a stable placeholder, and supports the first shared-image path: Android Photo Picker, EXIF-aware resize, JPEG size validation, account-scoped Supabase Storage upload, and profile refresh. Cropping UI and avatar-availability scope controls remain a follow-up against the Apple profile-image contract.
- Home and Profile now share the same avatar renderer, so both surfaces load the account's remote image and use the same initials/person fallback.

### Settings capability boundaries

- Appearance, workflow choices, delete matching, and tag-entry preference are persisted through the Android settings service and survive process restart.
- Notifications hand off to Android system notification settings, rather than reproducing iOS permission UI.
- Archives and Trash read the existing Room-backed ToDo state and support restoring records. Destructive account/data reset, Android onboarding, tag management, billing, and Firebase device-sync controls remain explicitly deferred until their services exist.
- The sync surface uses the same customer-facing language as iOS/iPadOS: `toDō Sync`, `Connected`, and `Local only`. Provider implementation names remain internal to the service layer and do not appear in Settings.
- Membership presentation now reads the signed-in account's effective entitlement state. Full access, pioneer recognition, founding recognition, grace period, limited access, and free states are distinct; account roles remain separate from commerce access.
- Settings rows use native Material list semantics, switches, radio buttons, and assist chips. Brand color is reserved for selected/recognized state rather than replacing Android's system control behavior.
- Guided Tour is a persisted Android-native state machine with a restart action, progress, creation-dialog handoff, and return path to Settings for sync, notifications, and archive/delete choices.

### Detail and editor surfaces

- Detail cards and NanoDo rows now share the same card radius, elevated surface, and spacing hierarchy as Home.
- User-authored detail titles and editor fields use Aleo rather than inheriting a generic Material headline role.
- Due/reminder controls and reminder-intent chips now use the shared control geometry and semantic selected state.
- Trash is explicitly destructive in both icon and label color; completion and
  date/time actions are native filled-tonal controls without an unrelated outline.
- ToDo rows now project due date, NanoDo progress, time-sensitive reminder, and
  recurrence metadata into compact chips in the same order as the Apple row.
  The only row outline is the intentional time-sensitive warning accent.

### Full visual pass — 2026-08-14

- Replaced the hand-drawn Momentum glyph set with the standard Material icon set
  (including chart, bolt, clock, warning, reminder, repeat, and completion roles)
  at the smaller Apple-relative scale.
- Added an Android-native Stats hero, focus grid, Momentum summary, and workload
  breakdown so Stats is not a reduced copy of the Home counters.
- Corrected intrinsic-width cards in Profile and Settings so phone surfaces fill
  the available content width and tablet panes remain readable.
- Kept the platform translation intentional: Material top app bars, navigation
  rails, switches, radio buttons, text fields, ripple/pressed behavior, and
  Android horizontal route transitions surround the shared toDō brand hierarchy.
- Phone visual QA was performed on the connected Android device for Home,
  Settings, Profile, toDō list, and Stats after installation of the debug APK.

## Verification

- `./gradlew testDebugUnitTest assembleDebug` — passed.
- The combined source compiles, the debug APK is generated successfully, and the final APK installed successfully on the connected device.
- `./gradlew testDebugUnitTest assembleDebug` passed after the full pass.
- Launch smoke testing and phone visual QA found no `AndroidRuntime` crash output.
- Tablet, dark-mode, TalkBack, and large-text QA remain required before release; the layout code is adaptive, but those environments still need dedicated device passes.

## Follow-up slices

Tags and collaboration affordances remain a follow-up row contract. Due date,
reminder intent, recurrence, and NanoDo metadata are now present as compact Jura
chips; titles remain dominant and rows grow rather than truncate user-authored
content.
