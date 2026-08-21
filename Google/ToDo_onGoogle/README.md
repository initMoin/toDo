# toDō Android

The Android client for toDō, beginning with the v3.1 product surface.

This is the native Kotlin/Jetpack Compose client in the toDō product
monorepo. The Apple clients remain at the repository root. Android shares the
product contract and Supabase backend with the Apple clients while keeping
platform UI and service implementations native.

## Current baseline

- Android Studio: Quail 3 (2026.1.3)
- Android Gradle Plugin: 9.3.1 with Gradle 9.5.0
- Minimum / compile / target SDK: Android 16 (API 36)
- Built-in Kotlin 2.2.10 + Jetpack Compose compiler plugin
- Room 3.0.1 + bundled SQLite 2.7.0
- Supabase Auth, PostgREST, and Realtime services behind provider-neutral
  authentication scope, sync payloads, and outbox contracts
- Supabase Kotlin client 3.6.0 with the Realtime consecutive-connect fix
- Application ID: `dev.iamshift.todo.android`
- Version: `3.1.0` (`versionCode` 1)
- Room-backed local source of truth with a durable sync outbox and the v3.1
  core model vocabulary
- Width-based adaptive UI: compact top-app-bar/system-Back navigation below
  600dp, labeled navigation rail at tablet width, and a 960dp readable content
  constraint

The first screen is intentionally small: Home, All toDōs, create, complete,
and Settings. It establishes the Android project, theme, domain boundary,
Room-backed local state, durable mutation tracking, authenticated Supabase
sync, and testable state flow before adding notifications, widgets, and
Android-specific system integrations.

The generated Gradle wrapper is checked in, so the project can be opened or
built with `./gradlew` without relying on a globally installed Gradle command.

## Open and run

1. Open this folder in Android Studio.
2. Let Android Studio use the Gradle wrapper and the bundled JDK.
3. Select an Android 16 emulator or connected device.
4. Run the `app` configuration.

If Android Studio asks to install a missing component, use the SDK Manager to
install Android SDK Platform 36 and Build Tools 36.0.0.

## Product parity direction

The Apple v3.1 ledger is in `../Docs/v3.1-FeatureList.md`, and the platform
parity contract is in `../Docs/FeatureParity-v3.1.md`. Android
will follow the same data and sync semantics while adapting navigation,
permissions, notifications, widgets, voice input, billing, and accessibility
to Android conventions.

Tablet support is a first-class layout requirement. The current shell uses the
available width rather than a device-model check: windows below 600dp use the
compact top-app-bar/system-Back flow, while windows at or above 600dp use a
navigation rail and centered content. Future tablet work should preserve this
adaptive boundary and add master/detail panes only when both panes remain
readable.

Branding, typography, color, spacing, accessibility, and responsive design
decisions are governed by the shared
[`toDo-Brand-UI-UX-Principles.md`](../Docs/toDo-Brand-UI-UX-Principles.md).
The Android mapping and asset decisions are tracked in
[`Docs/Android-Branding-Implementation.md`](Docs/Android-Branding-Implementation.md).

Android Watch planning is documented in
[`Docs/Android-Watch-Plan.md`](Docs/Android-Watch-Plan.md). The Watch will use
the same provider-neutral core and durable sync semantics, with a
power-conscious active-surface Realtime policy and standalone-capable auth.

## Primary engineering rules

This codebase is being built toward production from the beginning. Each
feature should meet industry-standard Android expectations for correctness,
testability, accessibility, lifecycle safety, security, performance, and
maintainability.

Android should remain as close as practical to the Apple app in product
behavior, data semantics, and sync behavior. Platform-specific UI and system
integrations may be native to Android, but differences should be intentional,
documented, and covered by the parity contract.

The architecture remains MV+Services. Android lifecycle types may be used as
implementation details where they provide lifecycle safety, but they are not
permission to introduce an MVVM architecture boundary by default.

Algorithms and data structures are part of the implementation process. When a
map, set, index, ordering strategy, cache, deduplication algorithm, or other
algorithmic choice improves correctness or scaling, use it when justified and
record the decision, complexity, tradeoffs, and an example in
[`DSA-ToDoAndroid.md`](DSA-ToDoAndroid.md). Avoid speculative optimization, but
do not accept repeated scans or comparator work when a clear bounded structure
solves the problem.

Supabase remains the cross-platform sync contract and Firebase remains the
same-platform cross-device sync service. Domain models must stay provider
neutral; provider SDK types belong in service adapters.

The current sync layer includes the account/device identity contracts, shared
serialized payloads, Supabase transport adapter, full remote snapshot
application, an authenticated outbox flush path, debounced Realtime
invalidation, and WorkManager refresh. Firebase remains staged behind the
shared provider boundary and will be added after its custom-token identity
bridge and Firestore rules are available.
