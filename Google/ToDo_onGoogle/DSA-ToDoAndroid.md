# DSA — toDō Android

This document tracks meaningful algorithm and data-structure decisions in the
Android codebase. It is part of the development process, not an after-the-fact
performance report.

## Primary rule

Use algorithms and data structures deliberately wherever they improve
correctness, predictable scaling, or resource usage. Prefer the simplest
structure that matches the dominant operation:

- `Set` for membership and uniqueness.
- `Map` for keyed lookup, deduplication, aggregation, or indexing.
- Ordered maps or stable sorting when deterministic output matters.
- Short-lived indexes for a bounded operation unless a cache has a clear
  invalidation strategy.
- A durable database index when the same lookup is performed across sessions
  or across large persisted datasets.

Do not add complexity only to make a complexity claim. Every non-trivial DSA
choice should be justified by the operation it serves, tested against the
product semantics, and documented here.

## Required record for new decisions

For each meaningful algorithmic or structural decision, record:

1. Date and status.
2. File or feature where it was introduced.
3. Problem being solved.
4. Chosen algorithm or data structure.
5. Expected time and space complexity.
6. Alternative considered and why it was not selected.
7. Lifecycle and invalidation behavior, if state is cached or indexed.
8. A small product example.
9. Tests or measurements that protect the decision.

## Android engineering context

The Android client is intended for production and should remain behaviorally
aligned with the Apple clients. Algorithmic changes must therefore preserve:

- ToDo, NanoDo, and Tag identity and lifecycle semantics.
- Stable UUID-based Supabase and Firebase record identity.
- Supabase cross-platform sync behavior.
- Firebase same-platform cross-device behavior.
- Deterministic conflict, deduplication, ordering, and deletion behavior.
- Android lifecycle, offline, accessibility, and resource constraints.

Domain models stay provider-neutral. Sync structures may model provider state,
but Firebase and Supabase SDK objects belong in service adapters.

## Implemented decisions

### 0. Stable UI projections for row metadata and adaptive surfaces

**Status:** Implemented

**Files:** `app/src/main/java/dev/iamshift/todo/android/ui/ToDoApp.kt`,
`app/src/main/java/dev/iamshift/todo/android/ui/SettingsScreen.kt`

**Problem:** A ToDo row must present the same semantic metadata on every
platform, while the Android layout must remain usable from a compact phone to a
tablet. Recomputing each chip independently in arbitrary screen branches makes
ordering and empty-state behavior drift.

**Choice:** `ToDoMetadataRow` first builds one ordered list of present metadata
(`due`, NanoDo progress, time-sensitive reminder, recurrence), then renders that
list. Settings keeps one selected-route state and chooses a list-only or
list-plus-detail layout from the available width.

**Complexity:** Metadata projection is `O(m)` time and `O(m)` short-lived space,
where `m` is the bounded number of metadata roles (at most four), plus the
NanoDo completion count. Route selection is `O(1)` state transition; layout
selection is `O(1)` from the measured width.

**Why this structure:** A small ordered list is easier to audit against the
Apple row contract than repeated conditional layout branches. A width-based
breakpoint is stable across phone rotation, tablets, and resizable windows; it
does not depend on device names.

**Example:** A ToDo with a due date, two NanoDos, and a time-sensitive reminder
always renders `Due → NanoDos → Time-sensitive`, while a tablet can show the
Settings list and selected detail side by side without a second navigation
model.

**Protection:** `ToDoModelTest` protects the model-side NanoDo state; the debug
build and connected-device visual QA protect the projection and adaptive
composition contract.

### 0.1. Stats snapshot aggregation

**Status:** Implemented

**File:** `app/src/main/java/dev/iamshift/todo/android/ui/ToDoApp.kt`

**Problem:** Stats needs multiple related measures—active, completed, overdue,
due today, scheduled, recurring, and NanoDo completion—without persisting a
second mutable statistics cache that could become stale after sync.

**Choice:** Stats derives a short-lived snapshot from the current canonical
ToDo list and its NanoDo children. The derived values are rendered directly and
are recalculated when the source flow emits.

**Complexity:** `O(n + c)` expected time and `O(n + c)` transient space for `n`
ToDos and `c` NanoDos in the current emission. No durable cache invalidation is
needed.

**Why this structure:** Stats is a presentation projection, not a sync source
of truth. Persisting it would add invalidation risk when Supabase or Firebase
updates a record. The current screen-sized calculation is predictable and
keeps all metrics consistent with the same emission.

**Example:** When one active ToDo becomes done, the hero, Momentum cards, and
NanoDo completion row update from the same list emission instead of displaying
mixed generations of data.

**Protection:** `ToDoModelTest` and the debug unit-test suite cover the source
state transitions; connected-device Stats QA verifies the rendered projection.

### 1. Stable-ID ToDo canonicalization

**Status:** Implemented

**File:** `app/src/main/java/dev/iamshift/todo/android/core/model/ToDo.kt`

**Problem:** Local state, Supabase changes, Firebase changes, and future
replay/outbox work can temporarily provide more than one representation of the
same ToDo. We need one deterministic record per logical ID.

**Choice:** `ToDo.canonical` uses a `LinkedHashMap<UUID, ToDo>`. The UUID is the
key, the newest `updatedAt` wins, and the first-seen key order is retained.

**Complexity:** Expected `O(n)` time and `O(u)` additional space, where `n` is
the number of candidate records and `u` is the number of unique IDs.

**Why this structure:** A list would require a repeated scan for every
candidate, producing `O(n²)` behavior. A plain hash map would deduplicate but
would not explicitly preserve deterministic first-seen ordering.

**Example:** If local storage contains ToDo `A` at version 10 and Supabase
returns ToDo `A` at version 11, canonicalization keeps the version-11 record.
If the input is `[A, B, A-newer]`, the output order remains `[A-newer, B]`.

**Protection:** `ToDoModelTest` covers stable-ID deduplication behavior.

### 2. Deterministic Tag canonicalization

**Status:** Implemented

**File:** `app/src/main/java/dev/iamshift/todo/android/core/model/Tag.kt`

**Problem:** Tags are user-entered strings but sync records have stable IDs.
Duplicate names must be normalized and resolved deterministically without
allowing case or whitespace differences to create separate logical names.

**Choice:** `Tag.canonicalTags` groups by normalized name, selects the most
recently updated tag using deterministic tie-breakers, and sorts the final
canonical list by name.

**Complexity:** `O(n + Σ dᵢ log dᵢ + u log u)` time and `O(n)` temporary space,
where `dᵢ` is the size of each duplicate-name group and `u` is the number of
canonical names. The final sort provides stable user-facing order.

**Why this structure:** Grouping by normalized name makes the identity rule
explicit and ensures that the conflict winner is selected per logical name.
The final ordering is independent of remote arrival order.

**Example:** `" Work "` and `"work"` normalize to `"work"`. The record with
the newer `updatedAt` is retained, and the result is ordered alphabetically.

**Protection:** `ToDoModelTest` covers normalization and canonical selection.

### 3. Composite identity for `todo_tags` sync records

**Status:** Implemented

**File:** `app/src/main/java/dev/iamshift/todo/android/core/sync/SyncModels.kt`

**Problem:** The `todo_tags` relation has a composite identity rather than a
standalone record ID. Treating only the ToDo ID as the identity could merge or
delete the wrong relationship.

**Choice:** `SyncRecordKey` stores `table`, `recordId`, and an optional
`relatedRecordId`. The `todo_tags` table requires both the ToDo ID and tag ID.

**Complexity:** Expected `O(1)` identity construction and comparison as the
key is bounded by a fixed number of UUID fields.

**Why this structure:** A single UUID cannot uniquely identify a join-table
row. Modeling the composite key at the sync boundary keeps deletion,
deduplication, and outbox operations precise for both providers.

**Example:** `(todo_tags, todo-A, tag-work)` and `(todo_tags, todo-A,
tag-health)` are distinct mutations even though they share the same ToDo ID.

**Protection:** `SyncModelsTest` verifies that a relationship key requires the
related tag ID and preserves the composite identity.

### 4. Independent provider sync state

**Status:** Implemented

**File:** `app/src/main/java/dev/iamshift/todo/android/core/sync/SyncModels.kt`

**Problem:** Supabase is the cross-platform sync service and Firebase is the
same-platform cross-device service. A record can be current with one provider
while awaiting upload or download with the other.

**Choice:** `RecordSyncMetadata` stores independent `ProviderSyncState` values
for Supabase and Firebase, including cursors, versions, timestamps, and errors.

**Complexity:** `O(1)` provider-state lookup for the fixed provider set and
`O(1)` storage per record for the current state model.

**Why this structure:** One shared `lastSyncedAt` value would conflate two
different synchronization lifecycles and could incorrectly suppress work.

**Example:** Firebase may have uploaded a record successfully while Supabase
is offline. The Firebase state can advance without marking the Supabase state
as current.

**Protection:** `SyncModelsTest` verifies that provider states remain
independent.

### 5. Room indexes for durable local queries

**Status:** Implemented

**Files:** `app/src/main/java/dev/iamshift/todo/android/core/persistence/RoomEntities.kt`,
`app/src/main/java/dev/iamshift/todo/android/core/persistence/RoomDaos.kt`

**Problem:** The in-memory list was not durable and would eventually require
repeated full scans for lifecycle, due-date, ownership, and sync work.

**Choice:** Room persists ToDos, NanoDos, Tags, the composite `todo_tags`
relationship, and the sync outbox. Indexes cover owner scope, collaboration
scope, lifecycle state, due time, update time, tag names, relationship tag
IDs, outbox status/next-attempt time, and outbox deduplication keys.

**Complexity:** Indexed equality/range lookups are expected to be `O(log n)`
for the database index, compared with `O(n)` scans. The observable aggregate
currently combines three bounded Room flows and groups NanoDos and tag links
by parent in `O(n)` expected time per emission, using temporary maps.

**Why this structure:** Database indexes are durable and query-planner-visible;
a Kotlin cache would introduce invalidation and lifecycle risks. Short-lived
maps are used only to assemble the domain aggregate from the current Room
emission.

**Example:** Loading a ToDo after a completion action uses its primary-key
lookup, while lists can order by stored `sortPosition`, creation time, and ID.
NanoDos and tag links are grouped once per aggregate emission instead of
searching their full collections for every ToDo.

**Protection:** Room schema generation, `PersistenceMappingTest`, and the
debug compilation validate the schema and mapping contract.

### 6. Coalescing durable outbox mutations

**Status:** Implemented

**Files:** `app/src/main/java/dev/iamshift/todo/android/core/persistence/RoomEntities.kt`,
`app/src/main/java/dev/iamshift/todo/android/core/persistence/RoomDaos.kt`,
`app/src/main/java/dev/iamshift/todo/android/core/persistence/RoomToDoRepository.kt`

**Problem:** A user can edit the same record multiple times while a provider
is offline. Uploading every obsolete intermediate state wastes work and can
increase conflict pressure.

**Choice:** Each outbox row has a stable mutation ID and a separate
scope-plus-record `deduplicationKey`. Pending and failed mutations for the
same key are replaced by the newest mutation. In-flight mutations are retained
so an active upload cannot be hidden by a later local write.

**Complexity:** Expected `O(1)` lookup through the deduplication index and
`O(log n + k)` retrieval for the indexed pending queue, where `k` is the
bounded batch size.

**Why this structure:** A mutation UUID alone prevents accidental collisions
but cannot coalesce successive writes to the same logical record. The separate
deduplication key preserves idempotency while allowing mutation history to be
handled independently later.

**Example:** Five offline edits to ToDo `A` produce one pending upload for `A`
once the first four are still pending. If the first upload is already in
flight, it remains visible and the newest edit becomes the next pending state.

**Protection:** `PersistenceMappingTest` verifies stable key construction;
DAO behavior will receive device/instrumentation coverage when the sync worker
is introduced.

### 7. Stable installation identity

**Status:** Implemented

**File:** `app/src/main/java/dev/iamshift/todo/android/core/auth/DeviceIdentityStore.kt`

**Problem:** Sync mutations need a stable origin device identity for tracing,
idempotency, and future conflict diagnostics. Generating a new UUID whenever a
repository is created would make the same installation look like a new device
after process death.

**Choice:** A single UUID is created lazily and stored in application-scoped
`SharedPreferences`. It is independent of the authenticated account, so
sign-out does not change the installation identity.

**Complexity:** Expected `O(1)` lookup and `O(1)` storage. The synchronized
initialization path runs only when the value is first created or recovered.

**Example:** A user signs out, signs into another account, and later retries an
outbox mutation. The mutation still identifies the same Android installation,
while the authenticated user ID changes with the sync scope.

**Protection:** `ToDoStore` now uses the persisted identity when constructing
the Room repository; account scope behavior is covered by `AuthModelsTest`.

### 8. Shared serialized payload contract

**Status:** Implemented

**Files:** `app/src/main/java/dev/iamshift/todo/android/core/sync/payload/SyncPayloads.kt`,
`app/src/main/java/dev/iamshift/todo/android/core/sync/payload/SupabasePayloadMapper.kt`

**Problem:** Maintaining separate Supabase and Firebase model shapes would
invite field drift and break Apple/Android parity. The outbox also needs a
durable payload that can be decoded after process death.

**Choice:** Immutable Kotlin serialization DTOs represent the shared remote
contract, including the Apple/Supabase snake_case field names. Supabase and
Firebase mappers adapt that contract to their transport shape without exposing
SDK classes to the domain or persistence layers.

**Complexity:** Encoding and decoding are `O(f)` in the number of fields, with
`O(f)` temporary space. Firebase field-map conversion is also linear in the
serialized object size.

**Example:** `dueAt` in the Kotlin model is emitted as `due_at` in the shared
payload. Both providers can consume the same payload while the Apple app
continues using the same database column contract.

**Protection:** `SyncPayloadTest` verifies snake_case output, round-trip IDs,
recurrence fields, and user-scoped Firebase document paths.

### 9. Multi-provider outbox fan-out and retry backoff

**Status:** Implemented

**File:** `app/src/main/java/dev/iamshift/todo/android/core/sync/SyncEngine.kt`

**Problem:** One local mutation must reach both Supabase and Firebase, but a
provider may be temporarily unavailable. The app must not lose the mutation or
mark it complete after only one provider accepts it.

**Choice:** `SyncEngine` loads a bounded indexed batch, marks each mutation
in-flight, sends it to every configured provider adapter, and marks it complete
only when all adapters succeed. Failures use capped exponential backoff:
5 seconds, 10 seconds, 20 seconds, and so on up to one hour.

**Complexity:** `O(b * p)` provider calls per flush, where `b` is the batch size
and `p` is the number of configured providers. Pending selection remains
indexed and bounded by `b`.

**Why this structure:** Supabase and Firebase writes are expected to be
idempotent upserts. Retrying a provider that already succeeded is safer than
losing a mutation or prematurely completing the shared outbox row. Provider
state remains conceptually independent for future per-provider telemetry.

**Example:** If Supabase accepts a ToDo update but Firebase is offline, the
mutation becomes failed and retries later. Supabase may receive the same
upsert again, but the stable record ID and idempotent write contract prevent a
duplicate logical ToDo.

**Protection:** The engine is isolated behind `SyncProviderAdapter`; adapter
and device/instrumentation tests will be expanded when the background worker
and remote snapshot application are configured.

### 10. Cursor-ready remote pulls

**Status:** Transport implemented; durable cursor storage deferred

**File:** `app/src/main/java/dev/iamshift/todo/android/core/supabase/SupabaseSyncAdapter.kt`

**Problem:** Rehydrating every remote row after every local change wastes
network, decoding, and database work as an account accumulates more records.

**Choice:** The Supabase adapter accepts a provider cursor and applies a
strictly-greater-than filter to each timestamped table. It computes the next
cursor as the maximum returned `updated_at`/`deleted_at` value across the
snapshot, while relation rows are scoped through the returned ToDo IDs.

**Complexity:** Remote query work is bounded by the provider result size; local
cursor aggregation is `O(r)` time and `O(1)` additional space beyond the
returned rows, where `r` is the number of returned timestamp values.

**Why this structure:** A timestamp cursor is portable across Supabase and
the provider-neutral sync boundary, and the strict comparison prevents the
same row from being returned repeatedly on the next pull. Relation filtering
avoids an unscoped `todo_tags` query.

**Example:** After the first pull returns rows through `2026-08-08T20:00:00Z`,
the next pull requests only rows newer than that timestamp. A tag relation is
read only for ToDo IDs already visible in the scoped snapshot.

**Protection:** `SyncRemoteSnapshot` preserves the cursor and separate record
collections. The current application path intentionally performs full pulls
because a timestamp-only cursor is not yet durable or tie-safe across multiple
tables. Incremental pulls will be enabled after a durable cursor store uses a
composite `(timestamp, table, record ID)` position.

### 11. Full-snapshot relationship reconciliation

**Status:** Implemented

**File:** `app/src/main/java/dev/iamshift/todo/android/core/sync/RoomSyncSnapshotApplier.kt`

**Problem:** Upserting the `todo_tags` join rows is insufficient when another
device removes a tag relationship. The stale local link would survive every
pull and make Android diverge from Apple/Supabase.

**Choice:** Group fetched relationship rows by ToDo ID in a temporary map. For
full snapshots, replace each returned ToDo's complete relationship set in one
Room transaction. Incremental snapshots only add the relationships explicitly
returned by the provider until relation tombstones are available in the shared
schema.

**Complexity:** Grouping is expected `O(r)` time and `O(r)` space for `r`
relationship rows. Each returned ToDo then performs one indexed delete and one
bounded batch upsert.

**Why this structure:** A map avoids repeatedly scanning all relationship rows
for every ToDo. Full replacement makes the provider snapshot authoritative while
keeping incremental behavior conservative in the absence of composite relation
tombstones.

**Example:** If ToDo `A` had `[work, health]` locally and the full Supabase
snapshot contains only `[work]`, the Android transaction removes `health`.

**Protection:** The applier keeps snapshot application and relationship
replacement in the same Room write transaction; device/instrumentation fixture
coverage is the next test layer.

### 12. Serialized, cancellation-safe synchronization

**Status:** Implemented

**Files:** `ToDoApplication.kt`, `SyncEngine.kt`

**Problem:** Foreground refresh, realtime invalidation, and WorkManager may all
request a sync near the same time. Cancellation after an outbox row is marked
in-flight could otherwise leave that mutation permanently invisible to retries.

**Choice:** The application serializes complete pulls/applies/flushes with a
`Mutex`. `SyncEngine` restores an interrupted in-flight row as immediately
retryable inside `NonCancellable` cleanup before propagating cancellation.

**Complexity:** Concurrent callers are serialized at `O(1)` coordination cost;
the sync work itself remains `O(b * p)` for batch size `b` and provider count
`p`. Cleanup is one indexed outbox update per interrupted mutation.

**Example:** If the Activity stops during a Supabase upload, the row returns to
retryable failure rather than remaining `IN_FLIGHT` after the process resumes.

**Protection:** `SyncEngine` remains adapter-driven and the existing JVM test
suite compiles the cancellation path; worker/instrumentation coverage will
exercise process and network transitions.

### 13. Debounced realtime invalidation and unique background work

**Status:** Implemented

**Files:** `SupabaseRealtimeSyncService.kt`, `SyncWorkScheduler.kt`,
`SupabaseSyncWorker.kt`, `MainActivity.kt`

**Problem:** Sync must continue across Activity visibility changes and should
not decode/apply each Postgres Changes payload through a second conflict path.

**Choice:** Supabase Realtime emits a small invalidation signal for the shared
tables; Android debounces bursts and invokes the normal full snapshot pipeline.
WorkManager owns unique network-constrained immediate and 15-minute periodic
work. Signed-out/unresolved sessions complete as no-ops.

**Complexity:** Realtime buffering is `O(1)` per signal after debounce; a burst
causes one standard snapshot sync. WorkManager keeps one unique periodic job and
one replaceable immediate job rather than an unbounded queue.

**Why this structure:** One snapshot application path preserves conflict,
tombstone, relationship, and local-only-field rules. Unique work prevents
duplicate scheduler registrations after Activity recreation.

**Example:** Five edits arriving during one second produce one debounced pull;
if the socket is unavailable, the network-constrained worker remains the
fallback.

**Protection:** Realtime is scoped to the authenticated user where the schema
has `user_id`; `todo_tags` relies on authenticated RLS because it has no user
column. WorkManager uses network constraints and the application mutex.

### 14. WebSocket-capable Android transport engine

**Status:** Implemented

**Files:** `app/build.gradle.kts`, `core/supabase/SupabaseService.kt`

**Problem:** The initial Android build selected Ktor's Android engine. That
engine can perform ordinary HTTP requests but cannot establish WebSockets, so
Supabase Realtime repeatedly failed with `Engine doesn't support
WebSocketCapability`.

**Choice:** Use Ktor's OkHttp engine for the Supabase client. It supports both
the PostgREST HTTP path and the Realtime WebSocket path, keeping one client
configuration and one auth session.

**Complexity:** This is a transport capability choice rather than a data
algorithm; it adds `O(1)` engine selection overhead and avoids unbounded
reconnect attempts from an unsupported engine.

**Example:** After the change, Android connected to the Supabase Realtime
WebSocket and the full pull applied the previously missing remote ToDo.

**Protection:** The device smoke test confirmed a connected Realtime channel;
the build comment and this record prevent replacing OkHttp with a non-WebSocket
engine during dependency cleanup.

### 15. Width-based adaptive navigation and content constraints

**Status:** Implemented

**Files:** `app/src/main/java/dev/iamshift/todo/android/ui/AdaptiveLayout.kt`,
`app/src/main/java/dev/iamshift/todo/android/ui/ToDoApp.kt`

**Problem:** Phones and tablets need different navigation density, while the
same app state and destination semantics must survive rotation and resizable
windows. A tablet-width list should also remain readable instead of stretching
each row across the entire display.

**Choice:** Use one width-based breakpoint at 600dp. Compact windows use a
clean top-app-bar/system-Back flow without a persistent bottom toolbar;
tablet-width windows use a labeled navigation rail. The active content is
centered and capped at 960dp, leaving a stable surface for a future
master/detail layout.

**Complexity:** The layout decision is `O(1)` time and `O(1)` space. Content
measurement remains proportional to the rendered Compose tree and does not add
an application-level cache or duplicate state.

**Why this structure:** Available width is more reliable than device-model or
orientation checks: a landscape phone, tablet split window, and resizable
desktop-style window can all use the correct navigation automatically. A
single breakpoint also avoids a collection of subtly conflicting thresholds.

**Example:** A 599dp window keeps the phone top-app-bar/system-Back flow; a
600dp or 840dp window shows the rail and gives Home/ToDōs/Settings a centered
readable column. The selected destination remains the same during a resize
because navigation state is not recreated by the layout branch.

**Protection:** `AdaptiveLayoutTest` covers the boundary and representative
wide-window behavior. Real-device QA remains required in portrait, landscape,
split-screen, and larger accessibility text sizes.

### 16. Connectivity-gated Realtime lifecycle

**Status:** Implemented

**Files:** `app/src/main/java/dev/iamshift/todo/android/core/network/NetworkConnectivityMonitor.kt`,
`app/src/main/java/dev/iamshift/todo/android/core/supabase/SupabaseRealtimeSyncService.kt`

**Problem:** A WebSocket client that remains active while Android has no
validated network repeatedly attempts reconnects, wastes battery, and produces
misleading errors even though the durable sync worker is already the correct
offline path.

**Choice:** Convert Android's default network callback into a distinct Boolean
stream and use `flatMapLatest`: online creates one Realtime channel; offline
cancels that channel and emits no socket work. A later validated network event
creates a fresh channel.

**Complexity:** Connectivity state transitions are `O(1)` time and `O(1)`
space. At most one active channel exists for the foreground scope; channel
cleanup is bounded by the fixed table subscription set.

**Why this structure:** It makes OS connectivity the lifecycle boundary and
prevents a retry loop from competing with WorkManager. It also generalizes to
the future Watch, where an always-on socket would be especially wasteful.

**Example:** When Wi-Fi is disconnected, Android stops the channel instead of
logging a failed connection every seven seconds. When Wi-Fi becomes validated,
the service creates one new authenticated channel and the normal snapshot pull
remains the only apply path.

**Protection:** The build and device logs validate the connectivity callback
path; real-device network-loss and network-return tests remain required.

### 17. Off-main startup and local-state assembly

**Status:** Implemented

**Files:** `app/src/main/java/dev/iamshift/todo/android/ToDoRepository.kt`,
`app/src/main/java/dev/iamshift/todo/android/MainActivity.kt`,
`app/src/main/java/dev/iamshift/todo/android/ToDoApplication.kt`,
`app/src/main/java/dev/iamshift/todo/android/core/auth/SupabaseAuthSessionProvider.kt`

**Problem:** Room/SQLite initialization, aggregate mapping, Supabase session
startup, and WorkManager scheduling can compete with the first Compose frame.

**Choice:** Lazy database/repository/client construction is triggered from
background contexts; Room aggregate collection uses `Dispatchers.IO`; sync
and outbox actions run on `Dispatchers.IO`; auth initialization and periodic
work scheduling start away from the UI thread.

**Complexity:** The scheduling boundary is `O(1)` coordination. Aggregate
assembly retains its existing `O(n)` expected map-based work, but that work no
longer blocks the main thread.

**Why this structure:** UI state remains a single lifecycle-scoped flow and
does not duplicate a second cache. The phone and tablet therefore share the
same local source of truth while preserving responsive rendering.

**Example:** A cold launch can display the shell while Room opens and maps
ToDos on an IO dispatcher. A sync retry cannot block navigation or text input.

**Protection:** Full unit/build verification passes; Pixel cold-start logs show
Room and Supabase initialization on background threads. Device frame timing
still needs a foreground/unlocked run and macrobenchmark before release claims.

### 18. Stable-ID detail selection and saveable editor draft state

**Status:** Implemented

**Files:** `app/src/main/java/dev/iamshift/todo/android/ui/ToDoApp.kt`,
`app/src/main/java/dev/iamshift/todo/android/ui/ToDoDetailDialog.kt`

**Problem:** A detail surface must remain attached to the same logical toDō as
Room emits updates from local edits, Supabase sync, or a tablet resize. Holding
an entire mutable object in navigation state risks stale data and duplicate
copies of the local source of truth.

**Choice:** Navigation stores only the stable UUID string. The current object
is resolved from the collected Room-backed list, while editor fields use
Compose `rememberSaveable` state so an in-progress draft survives ordinary
configuration changes and resizable-window recomposition. Lazy rows use the
same UUID as their stable key.

**Complexity:** Selected-record resolution is `O(n)` over the currently
rendered local collection and `O(1)` additional navigation state. NanoDo
interaction updates the child list with a single `O(m)` map over the parent’s
children, where `m` is the bounded NanoDo count.

**Example:** A tablet rotation preserves the selected toDō ID and editor text;
when the persisted record changes, the dialog resolves the newest Room object
instead of displaying a second stale copy. Completing one NanoDo replaces only
that child and enqueues the parent aggregate through the existing outbox.

**Protection:** The detail/editor writes through `RoomToDoRepository.update`,
so title, notes, schedule, reminder intent, completion, and NanoDo changes
share the same durable transaction and sync path as list actions.

### 19. Account-scoped profile-image normalization and provider state sets

**Status:** Implemented

**Files:** `app/src/main/java/dev/iamshift/todo/android/ui/ProfileScreen.kt`,
`app/src/main/java/dev/iamshift/todo/android/core/auth/SupabaseAuthSessionProvider.kt`

**Problem:** Profile images can be very large, retain device-specific
orientation metadata, and arrive from account flows that must not accidentally
replace the canonical toDō account. Connected-provider rendering also needs
constant-time membership checks.

**Choice:** The Photo Picker image is decoded with orientation handling,
downscaled so its longest edge is at most 2048 pixels, then compressed as JPEG
with a bounded quality fallback until it is at or below 5 MB. The upload path
is derived from the resolved account UUID, while connected providers are held
in a `Set<String>` for direct membership checks. Provider linking refreshes the
same account UUID after the OAuth action.

**Complexity:** Image normalization is `O(p)` in decoded pixel count and uses
`O(p)` temporary bitmap/output space; the 2048-pixel bound limits that cost for
large source images. Provider membership is expected `O(1)` lookup and `O(k)`
space for the small provider set.

**Example:** A 12-megapixel portrait is decoded with its orientation applied,
resized before upload, and stored as
`<account UUID>/avatar.jpg`. Connecting Google while signed in with Apple
updates the provider set but must leave the account UUID unchanged.

**Protection:** The upload method checks the authenticated UUID against the
resolved account before writing and the Storage policies scope the object path
to `auth.uid()`. Unit/build verification passes; authenticated device testing
of Photo Picker and Storage RLS remains required.

### 20. Stable Settings routes and preference state flows

**Status:** Implemented

**Files:** `app/src/main/java/dev/iamshift/todo/android/ui/SettingsScreen.kt`,
`app/src/main/java/dev/iamshift/todo/android/core/settings/ToDoSettingsStore.kt`,
`app/src/main/java/dev/iamshift/todo/android/MainActivity.kt`

**Problem:** Settings has many related destinations and several choices that
must survive rotation, process recreation, and phone/tablet layout changes.
Duplicating booleans inside individual Composables would make the Settings
list and detail panel disagree.

**Choice:** Use one closed `SettingsRoute` enum for navigation and one
`selectedRoute` key in the screen. Store user choices behind a small
application-scoped preference service that exposes `StateFlow` values to both
the Settings UI and the root theme. The tablet branch reuses the same route
and service state instead of maintaining a second dashboard model.

**Complexity:** Route selection and preference reads/writes are `O(1)`. The
Settings list counts archived, trashed, and distinct tag-linked records in
`O(n)` over the already-collected local list; it does not introduce a second
database query or duplicate ToDo cache.

**Example:** Choosing Dark in the Appearance detail immediately updates the
root theme, and the same setting is still selected after restarting the app.
Selecting Archives on a phone or a tablet resolves the same Room-backed
records and does not create a second copy of the data.

**Protection:** The store has explicit defaults and a reset-choices operation;
remote account deletion and destructive data reset are deliberately not wired
to a UI action until their authenticated service contracts are implemented.

## Planned decisions

### 21. Account entitlement projection and capability gates

**Status:** Implemented

**Files:** `app/src/main/java/dev/iamshift/todo/android/core/auth/AuthModels.kt`,
`app/src/main/java/dev/iamshift/todo/android/core/auth/AccountSetupModels.kt`,
`app/src/main/java/dev/iamshift/todo/android/core/auth/SupabaseAuthSessionProvider.kt`

**Problem:** Membership state must follow the signed-in account across
platforms. A local purchase flag, provider name, or account role cannot safely
stand in for the server-authoritative entitlement state.

**Choice:** Decode the shared effective-entitlement view into a small list of
records, then project it into derived booleans and a membership label. The
projection recognizes `todo_plus`, `legacy_3_1`, and `founding_supporter`,
including active/grace/full and expired/revoked/read-only states. Account roles
are fetched separately and never silently converted into commerce access.

**Complexity:** Entitlement projection is `O(r)` over the small record set;
each derived capability scans the same bounded set. The account state stores
`O(r)` records and exposes constant-time capability reads after projection.

**Example:** A `legacy_3_1` record with `status = active`, `access_mode =
full`, and `source_kind = grandfathering` produces `toDō Pioneer`, full toDō+
access, and future-paid-feature inclusion. An expired record with a
`read_only` access mode produces limited access instead of falsely enabling
full features.

**Protection:** Android resolves these records after the profile identity is
known, so a provider login cannot change the canonical account UUID. Query
failures degrade to no entitlement rather than granting access.

### 22. Guided-tour state machine

**Status:** Implemented

**Files:** `app/src/main/java/dev/iamshift/todo/android/core/settings/GuidedTourStore.kt`,
`app/src/main/java/dev/iamshift/todo/android/ui/ToDoApp.kt`,
`app/src/main/java/dev/iamshift/todo/android/ui/SettingsScreen.kt`

**Problem:** The setup guide needs to survive recomposition and process
recreation while moving through the same conceptual steps as iOS/iPadOS.

**Choice:** Use a closed ordered enum for the tour steps and persist only the
active flag plus current step. Advancing is a monotonic transition to the next
enum value; restarting returns to `WELCOME`; completion clears persisted active
state. Settings starts/restarts the flow, while the root Android surface owns
the overlay so the guide can return the user to Home or Settings.

**Complexity:** Step transitions and persistence are `O(1)`. The ordered enum
provides deterministic progress and prevents invalid step names from creating
an unhandled branch.

**Example:** Starting the tour from Settings persists `WELCOME`, returns to
Home, and the “Create your first toDō” step opens the native creation dialog.
The sync, notifications, and archive/delete steps then return to Settings.

**Protection:** The tour is presentation state only; it does not mutate ToDo
records, account data, or sync preferences. Skipping clears the active state.

The following areas are expected to receive documented algorithmic decisions as
the implementation advances:

### Room persistence and local indexes

Evaluate database indexes for stable IDs, ownership scope, lifecycle state,
due dates, `updatedAt`, and sync status. The goal is to move repeated large
collection scans into indexed queries while retaining deterministic ordering.

### Durable sync outbox

Use a keyed mutation identity and an indexed pending-work query so retries are
idempotent and bounded. Document coalescing rules, deletion/tombstone behavior,
and conflict handling before implementing them.

### ToDo list filtering and search

Measure whether normalized search text, tag membership sets, or database-backed
full-text/search indexes are appropriate. Keep filtering semantics identical to
the Apple app and avoid indexing data whose invalidation cost exceeds its use.

### Recurrence calculation

Document the calendar/time-zone algorithm before implementation, especially
for DST changes, month boundaries, leap years, and finite recurrence counts.
Correctness is more important than a faster calculation here.

### Sync conflict resolution

Define the ordering and tie-breaking algorithm for local, Supabase, and
Firebase mutations. The rule must be deterministic across devices and must
preserve tombstones so deleted records cannot be resurrected accidentally.

## Change log

| Date | Change |
| --- | --- |
| 2026-08-08 | Created the Android DSA decision record and documented the initial model and sync structures. |
| 2026-08-08 | Added Room indexes, aggregate assembly maps, and durable outbox coalescing decisions. |
| 2026-08-08 | Added stable device identity, serialized provider payloads, provider mappers, multi-provider retry fan-out, and cursor-based Supabase pulls. |
| 2026-08-11 | Added full-snapshot relationship reconciliation, cancellation-safe serialized sync, Supabase Realtime invalidation, and unique WorkManager refresh. |
| 2026-08-11 | Switched the Supabase Android transport from Ktor Android to OkHttp after device logs exposed unsupported WebSockets; verified the missing remote ToDo arrived. |
| 2026-08-11 | Added width-based tablet navigation and 960dp content constraints, with breakpoint tests and Apple adaptive-layout parity notes. |
| 2026-08-11 | Upgraded Supabase Kotlin to 3.6.0, gated Realtime by validated connectivity, and moved startup/local-state work off the main thread. |
| 2026-08-11 | Packaged licensed brand fonts/logos, added stable-ID detail selection, and implemented the first persisted detail/editor slice. |
| 2026-08-11 | Replaced the standalone logo-plus-word header with a unified `toDō` lockup using the yellow `ō` mark, removed the compact bottom toolbar, and added controlled slide/fade destination transitions. |
| 2026-08-13 | Added the singular `toDō` all-items header, Apple-matched Momentum/filter treatments, profile Photo Picker normalization/upload, and account-preserving connected-provider state. |
| 2026-08-14 | Replaced the Android Settings shell with Apple-matched sections, adaptive phone/tablet detail navigation, persistent preference flows, and explicit capability/status boundaries. |
| 2026-08-14 | Added account-entitlement projection tests, separate account-role handling, native Material Settings controls, and a persisted guided-tour state machine. |
