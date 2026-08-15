# Step 08: Platform Services and Cross-Device QA

## Objective

Run the final service matrix for notifications, custom sounds, widgets, Live
Activities, sync, offline conflicts, account switching, Watch companion/standalone
behavior, and macOS menu-bar behavior.

## Test Both Build Paths

Run critical scenarios using:

1. A development build installed from Xcode.
2. The actual TestFlight release candidate.

This distinction matters because push environments, StoreKit, signing, entitlements,
and extensions can differ.

## Notifications

Create synthetic toDōs for each case:

- Quiet reminder.
- Due reminder.
- Time-Sensitive reminder.
- Recurring reminder.
- NanoDo reminder.
- Custom reminder sound.
- Location arrival reminder.
- Location departure reminder.

For each case:

1. Confirm notification permission and Time-Sensitive authorization state.
2. Schedule the event far enough ahead for background delivery.
3. Test with the app foregrounded, backgrounded, and terminated.
4. Verify exactly one notification appears unless the recurrence explicitly requires
   more.
5. Verify toDō or NanoDo text, correct due time, sound, and action buttons.
6. Test notification actions and deep linking.
7. Verify completing, editing, deleting, or disabling the reminder cancels obsolete
   pending requests.

Duplicate simultaneous notifications are a release blocker.

## Custom Sound

1. Import each supported format: MP3, M4A, CAF, WAV, AIFF, and AIF.
2. Confirm the app enforces 30 seconds or shorter and smaller than 5 MB.
3. Verify import selects and immediately tests the sound.
4. Schedule a real notification and test the first firing after import.
5. Relaunch and test again.
6. Confirm the UI displays `Custom` rather than the raw filename.
7. Replace and remove the custom sound; verify future notifications update.

## Widgets

Test every supported iPhone/iPad widget family and configuration:

1. Add widget.
2. Create, update, complete, delete, archive, and restore a displayed toDō.
3. Change filters and verify timeline refresh.
4. Restart the device.
5. Confirm stale or deleted data disappears.
6. Tap supported links and verify the intended app destination.

Current project support should be tested according to actual target availability;
do not claim a separate Watch or Mac widget target if the system surface is provided
through ActivityKit instead.

## Live Activities

Test on:

- iPhone Lock Screen and Dynamic Island when supported.
- iPad system Live Activity surface.
- Apple Watch Smart Stack/system presentation.
- macOS Menu Bar/system presentation on supported OS versions.

For each:

1. Create a future Time-Sensitive toDō.
2. Verify the Live Activity starts without requiring the receiving app to open when
   remote start is supported.
3. Edit title, due date/time, and reminder state from another device.
4. Verify update delivery and display.
5. Complete, archive, delete, and disable Time-Sensitive; verify termination.
6. Restart devices and ensure stale activities do not resurrect.
7. Verify compact layouts do not overlap system clock or controls.
8. Verify tapping opens the specific toDō where the platform permits deep linking.

## Cross-Device Sync Matrix

Use iPhone, iPad, Mac, and Watch where available. For each source device, verify on
every destination:

- Create a personal toDō.
- Update title, notes, tags, NanoDos, due date/time, reminder, recurrence, location,
  destination, and completion behavior.
- Complete and undo completion.
- Archive and restore.
- Delete and verify tombstone propagation.
- Create/update/delete a Collab toDō.
- Edit profile display name.
- Accept/cancel/remove a Collab User.

Wait for explicit sync completion rather than relying on arbitrary sleeps. Record
the mutation UUID and UTC timestamp.

## Offline and Conflict QA

1. Put Device A and Device B offline after a common sync.
2. Edit the same toDō differently on both devices.
3. Reconnect A, wait for sync, then reconnect B.
4. Verify the documented deterministic resolution behavior.
5. Repeat with delete-versus-edit and completion-versus-edit.
6. Confirm tombstones prevent deleted data from reappearing.
7. Confirm tags do not duplicate after reconciliation.
8. Confirm NanoDo order remains deterministic.

## Account Switching

On every platform:

1. Sign in as Account A and wait for sync.
2. Sign out.
3. Confirm Account A's toDōs, profile, Collabs, and entitlement disappear from active
   UI before Account B data loads.
4. Sign in as Account B.
5. Verify no Account A records appear in Home, ToDos, widgets, menu bar, Watch, or
   notifications.

## Watch Companion and Standalone

### Companion

- Verify Watch receives data and mutations through the supported companion path.
- Create/edit/complete/delete and confirm phone, tablet, and Mac receive changes.
- Verify full ToDoView properties according to Watch UX constraints.
- Verify Home, ToDos, Stats, Settings, filters, tags, NanoDo indicators, and Done list.

### Standalone

- Use a physical standalone-capable Watch if available.
- Sign in directly and create a toDō without iPhone mediation.
- Verify direct Supabase sync, migration/merge, duplicate review, notifications, and
  account state.
- If no physical standalone Watch exists, mark this scenario **Externally Blocked**.
  A paired simulator does not prove standalone behavior.

## macOS Menu Bar

1. Toggle Dock and Menu Bar presence and follow the restart confirmation.
2. Verify all active toDōs appear in the scrollable popover.
3. Complete a toDō and verify the polished completion animation and sync.
4. Tap See All toDōs repeatedly. Exactly one main window must exist and move to the
   foreground.
5. Confirm no create/edit controls are embedded in the popover; those actions open
   the appropriate main-app view.

## Pass Criteria

- [ ] Notifications deliver once with correct content and sound.
- [ ] Widgets remain current after every mutation and restart.
- [ ] Live Activities start, update, deep-link, and end correctly on supported surfaces.
- [ ] Every CRUD field syncs across iPhone, iPad, Mac, and Watch.
- [ ] Offline conflicts are deterministic and deleted data does not resurrect.
- [ ] Account switching leaks no data or entitlements.
- [ ] Watch companion passes; standalone passes or is explicitly blocked with reason.
- [ ] macOS menu-bar behavior is complete and does not duplicate windows.

