# Watch Direct Sync Fallback Plan

The first watchOS release uses the iPhone as the source of truth. The Watch app receives compact snapshots through WatchConnectivity and sends actions back to the iPhone for SwiftData mutation and normal sync.

Current foundation:

1. The paired iPhone includes account state in the Watch snapshot so the Watch can show whether it is using the iPhone account.
2. The Watch supports standalone Sign in with Apple and exchanges the Apple identity token with Supabase Auth through REST.
3. The Watch stores its standalone Supabase session in the watchOS keychain.
4. Google sign-in is intentionally not available on watchOS; a Google-backed ToDo account is usable on Watch only through the paired iPhone handoff.

When the Watch needs to work away from the iPhone, add a direct-sync fallback in these phases:

1. Persist a small watch-local queue of `WatchToDoAction` values whenever `WCSession` cannot reach the phone.
2. Add a watch-specific Supabase sync client that can pull active ToDos and push queued complete/reopen actions.
3. Resolve conflicts on iPhone using the existing `SyncCoordinator` path after the Watch reconnects, treating Watch writes as normal remote changes.
4. Keep Watch storage intentionally narrow: active and recently completed ToDos, action queue, last sync metadata, and receipt state only.

Until that fallback exists, the Watch should show the latest iPhone snapshot and queue actions for delivery through WatchConnectivity.
