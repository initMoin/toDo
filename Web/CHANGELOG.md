# toDō Web changelog

This changelog describes the Web product only. Native-platform release notes
belong to their respective Apple, Android, and other client histories.

## 3.1 Web

### Foundation and navigation

- Established the TypeScript/Vinext Web package and Cloudflare Worker boundary
  for `https://do.yourtodo.today`.
- Added responsive application shell, browser-native routes, direct URLs,
  browser Back/Forward behavior, loading/empty/error/setup states, and reduced
  motion handling.
- Added the shared toDō typography, color roles, spacing, icon, and profile
  image rules without introducing a component library's visual identity.

### Authentication and access

- Added Apple and Google Supabase OAuth.
- Added username-first account resolution, returning sessions, provider
  account boundaries, migration handling, and account-mismatch protection.
- Added toDō+ entitlement gating through the effective entitlement view.

### ToDos

- Added authenticated retrieval and presentation of ToDos, NanoDos, Tags, and
  accessible Collabs.
- Added ToDo creation and editing for titles, notes, due dates/times, reminder
  intent, recurrence, Tags, NanoDos, and Collab assignment.
- Added completion, reopening, archive, trash, restore, permanent deletion,
  and browser-native detail routes.
- Added search, filters, sorting, grouping, Stats, onboarding, Account/Profile,
  and Settings subviews.

### Account and data controls

- Added profile-image selection, square crop finalization, and consistent
  image presentation across Web account surfaces.
- Added JSON export, personal ToDo reset, and account-deletion controls.
- Added browser-stored appearance, behavior, tag, notification, and trash
  preferences.

### Web integrations

- Added Web Push service-worker registration, VAPID public-key handling,
  subscription persistence, permission controls, and notification-click
  routing.
- Added private calendar-feed token creation and revocation controls.

## Deliberate 3.1 boundaries

- Collabs are intentionally basic in Web 3.1: load existing Collabs, create a
  Collab, and assign ToDos to a Collab. Invitations, invitation links,
  acceptance/decline/expiration, member lists, roles, removal, leaving,
  deletion, entitlement limits, and Collab-specific notifications remain
  deferred.
- Web Push registration and calendar-feed controls exist, but production
  delivery, scheduling, browser/device coverage, and calendar-client
  compatibility remain verification work.
- The Web client does not claim offline-first editing, Realtime synchronization,
  or automatic conflict resolution. Active surfaces now have an explicit
  refetch policy for confirmed mutations, browser focus, reconnect, page
  restore, visibility return, and access-token refresh.
- Privacy Policy and Terms of Use remain internal review drafts until the legal
  copy and service disclosures are finalized.

## Not claimed by this Web changelog

This file does not claim native-only voice entry, custom audio delivery,
widgets, Live Activities, Apple Watch behavior, or Mac-specific behavior.
