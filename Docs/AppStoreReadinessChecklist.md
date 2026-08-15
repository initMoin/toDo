# App Store Readiness Checklist

This checklist tracks release-facing items that cannot be fully validated by code review alone.

## Current Validation Status

- Xcode Missing Localizability analyzer: enabled through `CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED = YES`.
- Localization completeness: passing through `Scripts/validate_localizations.rb`.
- Localization placeholder parity: passing through `Scripts/validate_string_placeholders.rb`.
- App Intent restricted metadata terms: passing through `Scripts/validate_app_intent_metadata_terms.sh`.
- iOS Debug simulator build: passing.
- iOS Release simulator build: passing.
- watchOS Release simulator build: passing.
- Static analysis: passing.

Run the local pre-upload validation bundle before every TestFlight upload:

```sh
cd /Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo
Scripts/validate_release_readiness.sh
```

Note: recent command-line builds emitted Xcode/CoreDevice messages about a passcode-protected physical device service. Those messages came from Xcode's device service discovery, not from ToDo build diagnostics. They did not produce compiler warnings or analyzer findings.

## Permissions Copy

- Calendar: `NSCalendarsWriteOnlyAccessUsageDescription`
  - Current copy: "ToDo adds due ToDos to your calendar when you choose to mirror them there."
  - Status: Good. It states the feature is user-triggered and write-only.
- Location When In Use: `NSLocationWhenInUseUsageDescription`
  - Current copy: "ToDo uses your location to set up arrival and leaving reminders you choose."
  - Status: Good. It is specific and user-initiated.
- Location Always: `NSLocationAlwaysAndWhenInUseUsageDescription`
  - Current copy: "ToDo uses location only when you choose arrival or leaving reminders for specific ToDos."
  - Status: Good. It explains background use without overclaiming.

## Entitlements

- iOS/iPadOS app:
  - Push Notifications: enabled through `aps-environment`.
  - Sign in with Apple: enabled.
  - CloudKit: enabled for `iCloud.dev.iamshift.toDo`.
  - Time-Sensitive Notifications: enabled.
  - App Group: enabled for `group.dev.iamshift.toDo`.
- Widget extension:
  - App Group: enabled for `group.dev.iamshift.toDo`.
- Watch app:
  - Push Notifications: enabled through `aps-environment`.
  - Sign in with Apple: enabled.

## Provisioning

- Confirm the Apple Developer App ID for `dev.iamshift.toDo` includes:
  - App Groups
  - CloudKit
  - Push Notifications
  - Sign in with Apple
  - Time-Sensitive Notifications
- Confirm the Watch App ID includes:
  - Push Notifications
  - Sign in with Apple
- Regenerate provisioning profiles after changing any capability.

## Privacy Labels

Expected App Store privacy disclosures based on current functionality:

- Contact Info:
  - Email address if the user signs in with Apple or Google through ToDo Sync.
- Identifiers:
  - User ID for Supabase-backed sync.
  - Device ID / push token for notifications.
- Location:
  - Precise location if the user enables location reminders or location-based timezone.
- User Content:
  - ToDos, notes, tags, nanoDos, reminder configuration, and sync metadata.
- Diagnostics:
  - Only disclose if production analytics/crash reporting is added later.

## Crash And Memory Validation

- Run an iPhone physical-device idle test for at least 15 minutes with:
  - ToDo Sync signed in.
  - Watch not installed.
  - Watch installed and paired.
  - Widget on Home Screen.
  - One active Live Activity.
- Run an iPad physical-device layout pass with:
  - No ToDo selected.
  - ToDo detail selected.
  - Editing detail panel.
  - Done drawer open and closed.
- Run Instruments Allocations for:
  - Launch to idle.
  - Add/edit/delete ToDo.
  - Settings open/close.
  - Widget completion action.
  - Watch refresh.

## Known Validation Dependencies

- APNs production key and sandbox key must match the token environment.
- Supabase Edge Function secrets must be configured separately for sandbox and production APNs.
- Calendar mirroring requires a real device authorization test.
- Location reminders require a real device geofence test; simulator testing is insufficient.
- Linguistic quality requires human review through TestFlight because the current non-English translations are implementation-complete but machine-assisted.
