# toDō Android Watch Plan

**Status:** Architecture planning; no Wear OS module has been added yet.

The Android Watch target will be a Wear OS client of the same toDō product,
not a thin remote control for the phone. It will share product semantics and
sync identity with Android phone/tablet while adapting interaction density,
power usage, authentication, and system integration to the watch.

## Product boundary

The Watch should provide the small, high-value loop that already exists in the
Apple Watch parity contract:

- Home or Up Next overview.
- Active toDō list with complete/reopen actions.
- View and create a toDō through a compact flow.
- View and edit the core title, notes, due date/time, reminder intent,
  recurrence, tags, and NanoDos as the screen permits.
- Account state, sync status, retry, and sign-out.
- Readable empty, offline, loading, and error states.

Detailed collaboration administration, commerce, location-map selection, and
large text editing belong on phone/tablet. The Watch must still preserve the
same underlying IDs and fields when those records are synced.

## Architecture

The target will remain MV+Services:

```text
Wear Compose UI
        |
Watch presentation store / actions
        |
Shared provider-neutral domain + sync contracts
        |
Room local source of truth + durable outbox
        |
Supabase cross-platform adapter
Firebase same-platform adapter (after token bridge and rules)
```

The current Android app keeps models and services inside the `app` module.
Before creating the Watch target, extract the provider-neutral model, payload,
conflict, and outbox contracts into a shared `:core` module. The phone,
tablet, and Watch should then compile against the same UUID identity,
lifecycle, tombstone, recurrence, tag, NanoDo, and sync behavior.

## Sync and power policy

The Watch should not maintain a permanent Realtime WebSocket merely because it
can. The intended policy is:

1. Pull and apply a scoped snapshot when the Watch surface becomes active.
2. Flush local outbox mutations immediately when network is available.
3. Keep WorkManager as the retry path for deferred work.
4. Use Realtime only while the Watch UI is active or when the platform power
   policy explicitly permits it.
5. Treat Firebase as the Android-device fan-out path after the trusted
   Supabase-to-Firebase custom-token bridge is implemented.

Phone-to-Watch Data Layer messages may accelerate a visible update, but they
must not become the source of truth. A Watch can be offline, the phone may be
off, and a mutation must survive process death on either device.

## Authentication direction

Authentication must support both companion and standalone operation:

- A paired phone may provision or refresh a Watch session through the Android
  Data Layer, without making the phone the permanent authority.
- Standalone sign-in should use the Wear browser/OAuth flow with the existing
  `todo://auth-callback` redirect once the Wear UX is tested.
- Google Sign-In is the first Watch provider candidate because it is already
  proven in the Android app.
- Apple Sign-In remains a required parity path, but its browser callback,
  account linking, and passkey behavior need a dedicated Wear-device test.
- Access/refresh tokens must be stored in a Watch-scoped secure store. Do not
  send a long-lived token through ordinary Data Layer messages.

## Staged implementation

### Stage 1 — shared-core extraction

- Move models, serialized payloads, sync contracts, conflict rules, and outbox
  identity to `:core`.
- Keep Android Room and Supabase adapters in Android source sets.
- Run phone/tablet tests unchanged against the extracted contracts.

### Stage 2 — Wear shell

- Add a separate Wear OS application module and Wear Compose dependencies.
- Build Home, ToDōs, detail, create, Settings, and sync-status surfaces with
  the same destination semantics as the phone.
- Use compact, scrollable sections and 44dp-equivalent reachable actions.

### Stage 3 — standalone sync/auth

- Add Watch Room storage and the same durable outbox rules.
- Add foreground pull/flush and network-aware Realtime only for active UI.
- Implement Google OAuth, then Apple OAuth, on real Wear hardware.

### Stage 4 — companion optimization

- Add Data Layer invalidation and action handoff.
- Verify duplicate delivery, phone-off behavior, offline edits, account
  switching, and conflict resolution.
- Add Watch-specific notifications and complication/tile surfaces only after
  the core sync contract is stable.

## Acceptance matrix

The Watch target is not ready when it merely builds. Verify:

- Phone, tablet, Watch, Web, and Apple clients converge on the same ToDō ID.
- A Watch-created ToDō survives phone-off and process-death scenarios.
- Realtime disconnects stop cleanly when the Watch loses validated internet.
- Reopening a completed ToDō preserves completion activity semantics.
- OAuth callback, account switching, sign-out, and token refresh do not leak
  the previous account's local or remote data.
- The UI remains responsive under a long title, notes, tags, NanoDos, and
  accessibility text sizes.

The first Watch code should begin only after the phone/tablet ToDō detail and
editor flow is complete enough to define which fields are core and which are
deliberately deferred from the Watch surface.
