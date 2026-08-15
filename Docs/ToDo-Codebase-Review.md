# ToDo App — Execution Spec
**Revised May 2026**

Each item is a discrete, self-contained task. Every task has a file location, a definition of done, and either working code or a precise instruction. Items that require profiling or investigation before code can be written are in the **Deferred** section at the end with a defined first step.

---

## Table of Contents

1. [Architecture Identification](#1-architecture-identification)
2. [Confirmed Fixes — Ready to Execute](#2-confirmed-fixes--ready-to-execute)
3. [Data Structures & Algorithms — Annotated Reference](#3-data-structures--algorithms--annotated-reference)
4. [Deferred — Needs Investigation First](#4-deferred--needs-investigation-first)

---

## 1. Architecture Identification

**Pattern: Feature-Sliced MV with a Strategy-pattern sync layer.**

This is not MVVM. There are no ViewModel types. Views own their `@State`, `@Query`, and `@AppStorage` directly. Business logic (filtering, sorting, persistence) lives on the View struct as private methods. SwiftUI's reactive rendering loop performs the ViewModel observation role that `@Published`/`ObservableObject` would fill in classical MVVM.

The folder structure is a vertical-slice ("feature-sliced") organization: each `Features/` subfolder owns both model and UI for that feature. Cross-feature infrastructure lives in `Core/` and `Services/`.

**Sync layer: Strategy pattern.**

`ToDoSyncBackend` is a protocol. `SyncCoordinator` holds `activeBackend: (any ToDoSyncBackend)?` and delegates all sync through it. Three concrete strategies exist: `LocalDeviceSyncBackend` (no-op), `CloudKitSyncBackend` (stub — iCloud sync is handled by SwiftData's own CloudKit configuration, not this class), and `SupabaseSyncBackend` (fully implemented). Adding a fourth backend requires only a new conformance.

**`SyncCoordinator`: implicit state machine over `SyncActivityState`.**

```
idle → activating → syncing → synced
                             ↘ failed
```

Transitions are driven by explicit method calls (`beginSyncActivation`, `beginSyncOperation`, `completeSyncOperation`, `failSyncOperation`). There is no guard enforcement on invalid transitions — this is intentional given the current scale but worth watching as the sync engine grows.

**Key singletons to map before any refactoring:**

`SyncCoordinator`, `SupabaseAuthStore`, `NotificationManager`, `HapticFeedbackService`, `LocationReminderService`, `WidgetSnapshotService`, `WatchConnectivityService`, `NavigationCoordinator`. All are `static let shared`. Dependency injection is not used, which limits unit testability. The contract-based tests work around this by operating at the data model level.

**`NavigationCoordinator`** is the most modern piece — it uses `@Observable` (not `ObservableObject`) and is accessed via `@State private var navigationCoordinator = NavigationCoordinator.shared`, enabling property-level observation granularity.

---

## 2. Confirmed Fixes — Ready to Execute

---

### Task 1 — Push `FetchDescriptor` filters into SwiftData

**Priority: High**
**Files:** `Core/Infrastructure/Supabase/SupabaseSyncService.swift`, `Core/Sync/MigrationService.swift`, `Core/Sync/SyncTombstoneStore.swift`, `Core/Sync/SyncDeletionMirroring.swift`

**Problem:** Every fetch in the sync and migration paths loads the entire table from SQLite into memory, then filters in Swift. This is a full table scan on the heap on every sync cycle.

```swift
// CURRENT — full table scan + Swift filter
let tags = try context.fetch(FetchDescriptor<Tag>())
    .filter { $0.ownerUserID == ownerUserID }
```

**Fix — three steps:**

**Step 1.** Add `@Attribute(.index)` to `ownerUserID` on each model. This creates a B-tree index in SQLite so the predicate hits an index instead of scanning all rows.

```swift
// Features/ToDos/Models/ToDo.swift
@Attribute(.index) var ownerUserID: UUID? = nil

// Features/Tags/Models/Tag.swift
@Attribute(.index) var ownerUserID: UUID? = nil

// Features/NanoDo/Models/NanoDo.swift
@Attribute(.index) var ownerUserID: UUID? = nil
```

**Step 2.** Replace every unfiltered fetch with a predicated descriptor. Apply this change everywhere the pattern appears — do not leave any unfiltered fetches in the files listed above.

```swift
// REPLACEMENT — SQL-level filter
let ownerID = ownerUserID  // local capture required by #Predicate macro
let predicate = #Predicate<Tag> { tag in tag.ownerUserID == ownerID }
let tags = try context.fetch(FetchDescriptor<Tag>(predicate: predicate))
```

**Step 3.** Apply the same pattern to `SyncConflict` in `SyncConflictStore.unresolvedConflicts`, combining both filters and pushing the sort into the descriptor:

```swift
static func unresolvedConflicts(in context: ModelContext, userID: UUID?) -> [SyncConflict] {
    let ownerID = userID
    let predicate = #Predicate<SyncConflict> { c in
        c.resolvedAt == nil && c.userID == ownerID
    }
    let descriptor = FetchDescriptor<SyncConflict>(
        predicate: predicate,
        sortBy: [SortDescriptor(\SyncConflict.createdAt, order: .reverse)]
    )
    return (try? context.fetch(descriptor)) ?? []
}
```

**Definition of done:** No call to `context.fetch(FetchDescriptor<Tag/ToDo/NanoDo/SyncConflict>())` with no predicate exists in any of the four listed files. The `@Attribute(.index)` annotations are present on all three model types.

**Reference:** https://developer.apple.com/documentation/swiftdata/filtering-and-sorting-persistent-data

---

### Task 2 — Scope `todo_tags` fetch to the authenticated user

**Priority: High**
**File:** `Core/Infrastructure/Supabase/SupabaseSyncService.swift` → `fetchRawRemoteSnapshot(for:)`

**Problem:** The `todo_tags` join table fetch has no `user_id` filter. Every sync downloads every user's tag associations from the database.

```swift
// CURRENT — unscoped, fetches all rows from all users
async let toDoTags: [SupabaseToDoTagRecord] = supabase
    .from("todo_tags")
    .select()
    .execute()
    .value
```

**Fix — choose one option:**

**Option A (recommended — no schema change required):** Use PostgREST resource embedding to return `todo_tags` as a nested field inside the `todos` fetch. Scoping is automatic because `todos` is already filtered by `user_id`.

1. Update `fetchRawRemoteSnapshot` to embed `todo_tags` in the `todos` query:

```swift
async let toDos: [SupabaseToDoRecord] = supabase
    .from("todos")
    .select("*, todo_tags(tag_id)")
    .eq("user_id", value: userID)
    .execute()
    .value
```

2. Add an embedded field to `SupabaseToDoRecord`:

```swift
private struct SupabaseToDoRecord: Codable {
    // ... existing fields ...
    let todoTags: [SupabaseEmbeddedTagRef]?

    private struct SupabaseEmbeddedTagRef: Codable {
        let tagID: UUID
        enum CodingKeys: String, CodingKey { case tagID = "tag_id" }
    }

    enum CodingKeys: String, CodingKey {
        // ... existing keys ...
        case todoTags = "todo_tags"
    }
}
```

3. Remove the standalone `toDoTags` async let fetch entirely.

4. After fetching, extract the flat pair array for `SupabaseRemoteSnapshot`:

```swift
let toDoTagPairs = toDos.flatMap { record in
    (record.todoTags ?? []).map { ref in
        SupabaseToDoTagRecord(todoID: record.id, tagID: ref.tagID, createdAt: nil)
    }
}
return SupabaseRemoteSnapshot(tags: tags, toDos: toDos, nanoDos: nanoDos,
                              toDoTags: toDoTagPairs, tombstones: tombstones)
```

**Option B (if PostgREST embedding is blocked):** Add `user_id` to the `todo_tags` table in Supabase. Run: `ALTER TABLE todo_tags ADD COLUMN user_id UUID NOT NULL REFERENCES auth.users(id);`, backfill via join, add RLS policy and index, add the field to `SupabaseToDoTagRecord`, and add `.eq("user_id", value: userID)` to the existing fetch.

**Definition of done:** No unscoped `from("todo_tags").select()` call exists in the file. The `SupabaseRemoteSnapshot` for any given user contains only that user's tag associations.

**Reference:** https://supabase.com/docs/guides/database/joins-and-nesting

---

### Task 3 — Fix `isDone` / `lifecycleState` redundancy

**Priority: Medium**
**File:** `Features/ToDos/Models/ToDo.swift`

**Problem:** `isDone: Bool` and `lifecycleState` are both persisted in SwiftData. Any code path that sets `isDone` directly (bypassing the `lifecycleState` setter) leaves the two fields inconsistent. Both are uploaded to Supabase independently, so a diverged record sends contradictory data to the remote.

**Fix — two options:**

**Option A (cleanest — requires a SwiftData schema migration):**

1. Remove `var isDone: Bool = false` as a stored property.
2. Replace with a non-stored computed property:

```swift
var isDone: Bool {
    lifecycleState == .done
}
```

3. Add a `VersionedSchema` and `SchemaMigrationPlan` to drop the `isDone` column. Follow the pattern at https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches

**Option B (no migration — guards against future divergence):**

Add a `didSet` assertion that fires in debug builds if the two fields go out of sync. This makes the invariant visible without touching the schema:

```swift
var isDone: Bool = false {
    didSet {
        #if DEBUG
        assert(
            isDone == (lifecycleState == .done),
            "isDone (\(isDone)) diverged from lifecycleState (\(lifecycleState)). Use the lifecycleState setter, not isDone directly."
        )
        #endif
    }
}
```

**Decision:** Pick Option A unless you need to ship without a migration. Option B is a bandage, not a fix. The column never should have been stored independently.

**Definition of done (Option A):** `isDone` is not a stored `@Attribute` column in the SwiftData schema. The computed property returns `lifecycleState == .done`. The migration plan compiles and passes `SyncMigrationPlanTests`.

**Definition of done (Option B):** The `didSet` assertion is present and fires in debug builds when the invariant is violated by any test path.

---

### Task 4 — Replace GCD calls with Swift Concurrency

**Priority: Low**
**Files:** `Features/ToDos/Views/ToDosView.swift`, `Services/NavigationCoordinator.swift`

**Problem:** Several sites use `DispatchQueue.main.async` and `DispatchQueue.main.asyncAfter` in a codebase that otherwise uses structured concurrency. This bypasses actor isolation checks and can cause priority inversions.

**Fix:** Replace each site mechanically.

```swift
// BEFORE
DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
    openSettingsPanel()
}

// AFTER
Task { @MainActor in
    try? await Task.sleep(for: .seconds(0.55))
    openSettingsPanel()
}

// BEFORE
DispatchQueue.main.async {
    isSearchFieldFocused = true
}

// AFTER
Task { @MainActor in
    isSearchFieldFocused = true
}
```

Search for `DispatchQueue` across the entire project to catch any sites not listed here.

**Definition of done:** Zero occurrences of `DispatchQueue` in `Features/`, `Services/`, `Core/`, and `App/`. All replacements use `Task { @MainActor in }`.

**Reference:** https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/

---

### Task 5 — Deduplicate tag sorting logic

**Priority: Low**
**Files:** `Features/Tags/Models/TagSortOption.swift`, `Features/ToDos/Views/ToDosView.swift`, `Features/Tags/Views/TagManagementView.swift`

**Problem:** Identical sort comparator logic is copy-pasted in both `ToDosView.tagList` and `TagManagementView.sortedTags`. They will silently diverge when one is updated.

**Fix:**

1. Add a `comparator(ascending:)` method to `TagSortOption`:

```swift
// Features/Tags/Models/TagSortOption.swift

func comparator(ascending: Bool) -> (Tag, Tag) -> Bool {
    switch self {
    case .name:
        return { lhs, rhs in
            let compare = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if compare == .orderedSame { return lhs.createdAt > rhs.createdAt }
            return ascending ? compare == .orderedAscending : compare == .orderedDescending
        }
    case .created:
        return { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return ascending ? lhs.createdAt < rhs.createdAt : lhs.createdAt > rhs.createdAt
        }
    case .linked:
        return { lhs, rhs in
            if lhs.linkedTaskCount == rhs.linkedTaskCount {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return ascending ? lhs.linkedTaskCount < rhs.linkedTaskCount
                             : lhs.linkedTaskCount > rhs.linkedTaskCount
        }
    }
}
```

2. Replace the `switch sortOption { ... }` blocks in both views:

```swift
return scopedTags.sorted(by: sortOption.comparator(ascending: isSortAscending))
```

Note: `TagManagementView`'s `.linked` case currently calls a live `usageCountsByTagID()` helper for counts rather than `Tag.linkedTaskCount`. Decide which source is authoritative and unify before replacing. If `usageCountsByTagID()` is more accurate, pass an optional counts dictionary parameter into `comparator`.

**Definition of done:** The sort comparator logic exists in exactly one place (`TagSortOption`). The two views call it with no inline sort logic of their own.

---

### Task 6 — Remove or document `deleteMissingRemoteRecords`

**Priority: Low**
**File:** `Core/Infrastructure/Supabase/SupabaseSyncService.swift`

**Problem:** `deleteMissingRemoteRecords(localSnapshot:remoteSnapshot:)` is fully implemented but never called. Its presence implies a pending intention that makes the sync logic harder to follow.

**Fix:** Open the method and make one of two decisions.

**If the method has no planned use:** Delete it. The helper methods it uses (`upsertTombstones`, `deleteRemoteRecord`) are shared with other paths and must not be removed.

**If there is a planned use case:** Add a documentation comment that explains exactly what condition would make it safe to call:

```swift
/// Tombstones and deletes any remote record that is not present in the local snapshot.
/// 
/// ⚠️ NEVER call this in a multi-device context unless this device is confirmed
/// to be the authoritative source. A second device that has not yet synced will
/// cause all its unsynced records to be deleted from the remote.
///
/// Intended for: a future "reset remote to match this device" user action.
private func deleteMissingRemoteRecords(...) async throws { ... }
```

**Definition of done:** The method is either deleted or has a doc comment explaining its preconditions. No ambiguity about whether it is active code.

---

### Task 7 — Fix `SyncConflict` resolution to update `lastSyncedUpdatedAt`

**Priority: Low**
**File:** `Core/Sync/SyncTombstoneStore.swift` → `SyncConflictStore.applySyncedVersion(from:to:)`

**Problem:** After resolving a conflict by choosing the remote version, `lastSyncedUpdatedAt` is not reliably updated. On the next sync cycle, `hasTwoSidedToDoConflict` may re-detect the same record as a conflict.

**Fix:** One line, added immediately after `applySyncedVersion` returns:

```swift
case .useSyncedVersion:
    applySyncedVersion(from: conflict, to: toDo)
    toDo.lastSyncedUpdatedAt = toDo.updatedAt  // anchor post-resolution so conflict is not re-detected
    conflict.resolvedAt = .now
```

**Definition of done:** A unit test in `SyncConflictStoreTests` verifies that after applying `.useSyncedVersion`, `toDo.lastSyncedUpdatedAt == toDo.updatedAt`.

---

### Task 8 — Extract duplicated tag pair logic into shared helpers

**Priority: Low**
**File:** `Core/Infrastructure/Supabase/SupabaseSyncService.swift`

**Problem:** `insertMissingToDoTagPairs` and `reconcileToDoTags` contain verbatim copy-pasted pair-building and upsert code.

**Fix:** Extract two private helpers:

```swift
private func buildLocalTagPairs(
    from snapshot: LocalSnapshot
) -> Set<SupabaseToDoTagUpsertPayload> {
    Set(snapshot.toDos.flatMap { toDo in
        guard let toDoID = toDo.cloudID else { return [SupabaseToDoTagUpsertPayload]() }
        return toDo.effectiveTags.compactMap { tag in
            guard let tagID = tag.cloudID else { return nil }
            return SupabaseToDoTagUpsertPayload(todoID: toDoID, tagID: tagID)
        }
    })
}

private func upsertMissingTagPairs(
    localPairs: Set<SupabaseToDoTagUpsertPayload>,
    remotePairs: Set<SupabaseToDoTagUpsertPayload>
) async throws {
    let toInsert = Array(localPairs.subtracting(remotePairs))
    guard !toInsert.isEmpty else { return }
    try await supabase
        .from("todo_tags")
        .upsert(toInsert, onConflict: "todo_id,tag_id")
        .execute()
}
```

Then simplify both callers:

```swift
private func insertMissingToDoTagPairs(...) async throws {
    let local = buildLocalTagPairs(from: localSnapshot)
    let remote = Set(remoteSnapshot.toDoTags.map {
        SupabaseToDoTagUpsertPayload(todoID: $0.todoID, tagID: $0.tagID)
    })
    try await upsertMissingTagPairs(localPairs: local, remotePairs: remote)
}

private func reconcileToDoTags(...) async throws {
    let local = buildLocalTagPairs(from: localSnapshot)
    let remote = Set(remoteSnapshot.toDoTags.map {
        SupabaseToDoTagUpsertPayload(todoID: $0.todoID, tagID: $0.tagID)
    })
    try await upsertMissingTagPairs(localPairs: local, remotePairs: remote)

    for pair in remote.subtracting(local) {
        try await supabase.from("todo_tags").delete()
            .eq("todo_id", value: pair.todoID)
            .eq("tag_id", value: pair.tagID)
            .execute()
    }
}
```

**Definition of done:** The pair-building and upsert logic exists in exactly one place. Both callers are ≤ 10 lines each.

---

### Task 9 — Migrate `SyncCoordinator` from `ObservableObject` to `@Observable`

**Priority: Medium**
**File:** `Core/Sync/SyncCoordinator.swift`, `Features/ToDos/Views/ToDosView.swift`

**Problem:** `SyncCoordinator` is an `ObservableObject` with many `@Published` properties. In SwiftUI, any `@Published` change on an `ObservableObject` triggers a full re-evaluation of every view that holds `@ObservedObject var syncCoordinator`. This means `syncActivityState` updating during a background sync forces `ToDosView`'s entire body — including the sort pipeline — to re-execute.

With `@Observable`, SwiftUI tracks only the specific properties actually read during a given body execution. A `syncActivityState` change will only re-render views that read `syncActivityState`, not every view that holds a reference to `SyncCoordinator`.

**Fix:**

1. Replace `final class SyncCoordinator: ObservableObject` with `@Observable final class SyncCoordinator`.
2. Remove all `@Published` annotations from properties (they become plain `var`).
3. In `ToDosView`, change:

```swift
// BEFORE
@ObservedObject private var syncCoordinator = SyncCoordinator.shared

// AFTER
private var syncCoordinator: SyncCoordinator { SyncCoordinator.shared }
// OR simply reference SyncCoordinator.shared directly in body where needed
```

4. Remove the `import Combine` from `SyncCoordinator.swift` if it is no longer used after removing `@Published`.
5. Audit every view that previously held `@ObservedObject var syncCoordinator` and update the access pattern.

**Definition of done:** `SyncCoordinator` has zero `@Published` properties and zero `ObservableObject` conformance. The app compiles. `ToDosView` body no longer re-evaluates when `syncFeedback` changes while the view is not displaying a feedback banner.

**Minimum deployment target requirement:** `@Observable` requires iOS 17. Confirm this is met before executing.

**Reference:** https://github.com/apple/swift-evolution/blob/main/proposals/0395-observability.md

---

### Task 10 — Add `recurrenceConfig` unit tests

**Priority: Medium**
**File:** `ToDoTests/ToDoModelTests.swift`

**Problem:** `isRecurring` has at least six early-exit conditions and `clearRecurrence` touches six fields. Neither has test coverage. The feedback from review confirms recurrence edge cases should be tested before any refactoring of `ToDo`.

**Add these specific test cases:**

```swift
// ToDoTests/ToDoModelTests.swift

func testIsRecurringReturnsFalseWithNoDueDate() {
    let toDo = ToDo(task: "test", recurrenceUnit: .days, recurrenceInterval: 1, recurrenceMode: .continuous)
    XCTAssertFalse(toDo.isRecurring, "isRecurring must be false when dueDate is nil")
}

func testIsRecurringReturnsFalseWithZeroInterval() {
    let toDo = ToDo(task: "test", dueDate: .now, recurrenceUnit: .days,
                    recurrenceInterval: 0, recurrenceMode: .continuous)
    XCTAssertFalse(toDo.isRecurring, "isRecurring must be false when interval is 0")
}

func testIsRecurringReturnsFalseForFiniteModeWithNoCount() {
    let toDo = ToDo(task: "test", dueDate: .now, recurrenceUnit: .days,
                    recurrenceInterval: 1, recurrenceMode: .finite, recurrenceCount: 0)
    XCTAssertFalse(toDo.isRecurring, "isRecurring must be false for finite mode with count < 1")
}

func testIsRecurringReturnsTrueForValidContinuous() {
    let toDo = ToDo(task: "test", dueDate: .now, recurrenceUnit: .days,
                    recurrenceInterval: 2, recurrenceMode: .continuous)
    XCTAssertTrue(toDo.isRecurring)
}

func testIsRecurringReturnsTrueForValidFinite() {
    let toDo = ToDo(task: "test", dueDate: .now, recurrenceUnit: .weeks,
                    recurrenceInterval: 1, recurrenceMode: .finite, recurrenceCount: 3)
    XCTAssertTrue(toDo.isRecurring)
}

func testClearRecurrenceClearsAllSixFields() {
    let toDo = ToDo(task: "test", dueDate: .now, recurrenceUnit: .days,
                    recurrenceInterval: 1, recurrenceMode: .finite,
                    recurrenceCount: 2, recurrenceAnchorDate: .now, recurrenceEndDate: .now)
    toDo.clearRecurrence()
    XCTAssertNil(toDo.recurrenceUnit)
    XCTAssertNil(toDo.recurrenceInterval)
    XCTAssertNil(toDo.recurrenceMode)
    XCTAssertNil(toDo.recurrenceCount)
    XCTAssertNil(toDo.recurrenceAnchorDate)
    XCTAssertNil(toDo.recurrenceEndDate)
    XCTAssertFalse(toDo.isRecurring)
}

func testLifecycleStateAndIsDoneAreConsistent() {
    let toDo = ToDo(task: "test")
    toDo.lifecycleState = .done
    XCTAssertTrue(toDo.isDone)
    toDo.lifecycleState = .active
    XCTAssertFalse(toDo.isDone)
    toDo.lifecycleState = .archived
    XCTAssertFalse(toDo.isDone)
}
```

**Definition of done:** All seven tests above are present in `ToDoModelTests.swift` and pass.

---

### Task 11 — Replace `Dictionary(uniqueKeysWithValues:)` crash risk with safe initializer

**Priority: Low**
**File:** `Core/Infrastructure/Supabase/SupabaseSyncService.swift` → `upsertLocalSnapshot`

**Problem:** `Dictionary(uniqueKeysWithValues:)` crashes with a fatal error if the source array contains duplicate keys. The remote snapshot is assumed to have no duplicate IDs, but this assumption is not guaranteed if a Supabase bug or race condition produces them. The `cleanupDuplicateRemoteToDos` step attempts to prevent this, but a race between two syncing devices could still produce a duplicate in the snapshot between the cleanup and the upsert.

```swift
// CURRENT — crashes on duplicate IDs
let remoteTagsByID = Dictionary(uniqueKeysWithValues: remoteSnapshot.tags.map { ($0.id, $0) })
let remoteToDosByID = Dictionary(uniqueKeysWithValues: remoteSnapshot.toDos.map { ($0.id, $0) })
let remoteNanoDosByID = Dictionary(uniqueKeysWithValues: remoteSnapshot.nanoDos.map { ($0.id, $0) })
```

**Fix:** Replace all three with the safe initializer that takes last-write on collision:

```swift
let remoteTagsByID = Dictionary(
    remoteSnapshot.tags.map { ($0.id, $0) },
    uniquingKeysWith: { _, last in last }
)
let remoteToDosByID = Dictionary(
    remoteSnapshot.toDos.map { ($0.id, $0) },
    uniquingKeysWith: { _, last in last }
)
let remoteNanoDosByID = Dictionary(
    remoteSnapshot.nanoDos.map { ($0.id, $0) },
    uniquingKeysWith: { _, last in last }
)
```

Apply the same replacement to every other `Dictionary(uniqueKeysWithValues:)` call in the file that takes remote snapshot data as input.

**Definition of done:** Zero calls to `Dictionary(uniqueKeysWithValues:)` on remote snapshot arrays in `SupabaseSyncService.swift`.

---

### Task 12 — Fix `Timer.scheduledTimer` in `StatsInsightCard`

**Priority: Medium**
**File:** `Features/Stats/Views/StatsView.swift` → `StatsInsightCard.randomizeOrbState()`

**Problem:** A `Timer.scheduledTimer` is created on `.onAppear` and fires every 5.2 seconds on the main run loop. It is never invalidated. Every time `StatsInsightCard` appears — including during sheet presentation — a new timer is added. If the stats sheet is opened and dismissed multiple times in a session, multiple orphaned timers accumulate, each dispatching a `Task { @MainActor in }` block every 5.2 seconds for the rest of the app's lifecycle.

```swift
// CURRENT — leaks a Timer on every .onAppear
Timer.scheduledTimer(withTimeInterval: 5.2, repeats: true) { _ in
    Task { @MainActor in
        withAnimation(.easeInOut(duration: 5.2)) {
            // randomize orb state
        }
    }
}
```

**Fix:** Replace the `Timer` with a Swift Concurrency task that loops with sleep, and cancel it on disappear:

```swift
// In StatsInsightCard:
@State private var orbAnimationTask: Task<Void, Never>?

// Replace randomizeOrbState() timer block with:
private func startOrbAnimation() {
    orbAnimationTask?.cancel()
    orbAnimationTask = Task { @MainActor in
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 5.2)) {
                orbOneSize = CGFloat.random(in: 132...178)
                orbTwoSize = CGFloat.random(in: 82...118)
                orbOneOpacity = Double.random(in: 0.08...0.18)
                orbTwoOpacity = Double.random(in: 0.06...0.16)
                orbOneOffset = CGSize(
                    width: CGFloat.random(in: 26...64),
                    height: CGFloat.random(in: -76 ... -36)
                )
                orbTwoOffset = CGSize(
                    width: CGFloat.random(in: -240 ... -188),
                    height: CGFloat.random(in: 132 ... 188)
                )
            }
        }
    }
}

// Replace .onAppear call to randomizeOrbState() with:
.onAppear { startOrbAnimation() }
.onDisappear { orbAnimationTask?.cancel(); orbAnimationTask = nil }
```

**Definition of done:** No `Timer.scheduledTimer` call exists in `StatsView.swift`. Opening and dismissing the stats sheet 10 times in an Instruments Time Profiler session shows no accumulating periodic callbacks from this view.

---

## 3. Data Structures & Algorithms — Annotated Reference

This section documents every meaningful data structure and algorithm in the codebase with quoted source, type annotation, and complexity. Use this as a reference before touching any of these areas.

---

### Ordered Set (insertion-order deduplication) — `ToDo.effectiveTags`

```swift
// Features/ToDos/Models/ToDo.swift
// TYPE: Manual ordered set — Set<PersistentIdentifier> for O(1) membership,
// [Tag] for insertion-order preservation. Swift stdlib has no OrderedSet
// in core; this is the standard hand-rolled equivalent.

var effectiveTags: [Tag] {
    var seen = Set<PersistentIdentifier>()  // hash set: O(1) insert+lookup
    var resolved: [Tag] = []               // array: preserves insertion order

    for item in tags {
        guard seen.insert(item.id).inserted else { continue }
        resolved.append(item)
        if resolved.count == Self.maxTagSelection { return resolved }  // early exit at cap=5
    }

    if let legacyTag = primaryTag, seen.insert(legacyTag.id).inserted {
        resolved.append(legacyTag)
    }

    return Array(resolved.prefix(Self.maxTagSelection))
}
// Complexity: O(n), n ≤ 5. Effectively O(1).
```

**Improvement available:** Replace with `OrderedSet` from `apple/swift-collections` to express the same intent with a single data structure instead of two coordinated variables. Reference: https://github.com/apple/swift-collections/blob/main/Documentation/OrderedSet.md

---

### Set Union — `Tag.linkedTaskCount`

```swift
// Features/Tags/Models/Tag.swift
// TYPE: Set union over two relationship arrays.
// toDos and primaryToDos overlap during migration; Set union gives the
// correct unique count without double-counting.

var linkedTaskCount: Int {
    var ids = Set(toDos.map(\.id))      // O(n)
    ids.formUnion(primaryToDos.map(\.id))  // O(m)
    return ids.count
}
// Complexity: O(n + m) where n and m are the sizes of the two arrays.
```

---

### Hash Set (tombstone ID lookup) — `SupabaseRemoteSnapshot.tombstonedIDs`

```swift
// Core/Infrastructure/Supabase/SupabaseSyncService.swift
// TYPE: Set<UUID> built from a filtered array.
// Constructed once per sync operation; used for O(1) membership checks
// throughout apply(remoteSnapshot:). Without this, each check is O(t).

func tombstonedIDs(for table: SyncRecordTable) -> Set<UUID> {
    Set(tombstones.filter { $0.recordTable == table.rawValue }.map(\.recordID))
}
// Build: O(t). Each .contains: O(1) average.
```

---

### Hash Map (cloud ID lookup) — `firstLocalRecordByCloudID`

```swift
// Core/Infrastructure/Supabase/SupabaseSyncService.swift
// TYPE: [UUID: Record] lookup table.
// Built once before apply(remoteSnapshot:); replaces O(n) linear scan with
// O(1) lookup per remote record. Critical for keeping apply() at O(n) total
// rather than O(n²).

private func firstLocalRecordByCloudID<Record: PersistentModel>(
    _ records: [Record]
) -> [UUID: Record] where Record: AnyObject {
    var recordsByCloudID: [UUID: Record] = [:]
    for record in records {
        // ... extract cloudID by type switch ...
        guard let cloudID, recordsByCloudID[cloudID] == nil else { continue }
        recordsByCloudID[cloudID] = record
    }
    return recordsByCloudID
}
// Build: O(n). Each lookup: O(1) average.
```

---

### Composite Hash Key — `ToDoSemanticDuplicateKey`

```swift
// Core/Infrastructure/Supabase/SupabaseSyncService.swift
// TYPE: Composite Hashable struct used as dictionary key.
// Swift synthesizes Hashable from all stored properties.
// Timestamps are pre-converted to Int64 milliseconds to eliminate
// sub-millisecond floating-point noise before hashing.

private struct ToDoSemanticDuplicateKey: Hashable {
    let task: String
    let notes: String
    let isDone: Bool
    let lifecycleState: String
    let reminderIntent: String
    // no createdAt — "semantic" key matches same logical task across devices
    let dueAt: Int64?
    let recurrenceUnit: String?
    let recurrenceInterval: Int?
    let recurrenceMode: String?
    let recurrenceCount: Int?
    let recurrenceAnchorAt: Int64?
    let recurrenceEndAt: Int64?
}

private func timestampKey(_ date: Date?) -> Int64? {
    guard let date else { return nil }
    return Int64((date.timeIntervalSince1970 * 1_000).rounded())
    // Rounds to ms precision. Two dates < 0.5ms apart hash identically.
}
```

---

### Hash-Bucketed Grouping — duplicate detection

```swift
// Core/Infrastructure/Supabase/SupabaseSyncService.swift
// ALGORITHM: Dictionary(grouping:by:) for duplicate detection.
// Groups all records by semantic key; buckets with count > 1 are duplicates.

let grouped = Dictionary(grouping: toDos, by: semanticDuplicateKey(for:))
// O(n) average to build.

for duplicates in grouped.values where duplicates.count > 1 {
    let canonical = duplicates.sorted(by: shouldPreferAsCanonical(_:over:)).first!
    // O(d log d) to sort each duplicate group, d usually = 2.
    // ...
}
```

---

### Multi-Criteria Total Order Comparator — canonical record selection

```swift
// Core/Infrastructure/Supabase/SupabaseSyncService.swift
// ALGORITHM: Strict weak ordering over {ToDo} for duplicate resolution.
// Four criteria in priority order; final UUID comparison guarantees
// the order is total (deterministic across all devices independently).

private func shouldPreferAsCanonical(_ lhs: ToDo, over rhs: ToDo) -> Bool {
    if lhs.cloudID != nil, rhs.cloudID == nil { return true }   // 1. synced wins
    if lhs.cloudID == nil, rhs.cloudID != nil { return false }
    if lhs.lastSyncedUpdatedAt != nil, rhs.lastSyncedUpdatedAt == nil { return true }  // 2. confirmed wins
    if lhs.lastSyncedUpdatedAt == nil, rhs.lastSyncedUpdatedAt != nil { return false }
    if lhs.nanoDos.count != rhs.nanoDos.count { return lhs.nanoDos.count > rhs.nanoDos.count }  // 3. richer wins
    return (lhs.cloudID?.uuidString ?? lhs.id.hashValue.description)  // 4. UUID tiebreak
         < (rhs.cloudID?.uuidString ?? rhs.id.hashValue.description)
}
```

---

### Three-Condition Conflict Predicate — two-sided conflict detection

```swift
// Core/Infrastructure/Supabase/SupabaseSyncService.swift
// ALGORITHM: Boolean predicate requiring all three conditions simultaneously.
// The 1ms epsilon guard prevents false positives from JSON round-trip
// floating-point imprecision on timestamps.

private func hasTwoSidedToDoConflict(localToDo: ToDo, remoteTimestamp: Date) -> Bool {
    let baseTimestamp = localToDo.lastSyncedUpdatedAt ?? localToDo.createdAt
    let localChangedSinceBase = localToDo.updatedAt != nil
        && localToDo.syncUpdatedAt > baseTimestamp
    let remoteChangedSinceBase = remoteTimestamp > baseTimestamp
    let timestampsDiffer = abs(localToDo.syncUpdatedAt.timeIntervalSince(remoteTimestamp)) > 0.001
    return localChangedSinceBase && remoteChangedSinceBase && timestampsDiffer
}
```

---

### Set Difference — tag pair reconciliation

```swift
// Core/Infrastructure/Supabase/SupabaseSyncService.swift
// ALGORITHM: Symmetric set difference for bidirectional sync.
// local.subtracting(remote) → insert to remote
// remote.subtracting(local) → delete from remote
// Set subtraction: O(|smaller set|) average.

let pairsToInsert = Array(localPairs.subtracting(remotePairs))
for pair in remotePairs.subtracting(localPairs) { /* delete */ }
```

---

### Multi-Pass Lookup-Table Apply — `apply(remoteSnapshot:)`

```swift
// Core/Infrastructure/Supabase/SupabaseSyncService.swift
// ALGORITHM: Three-pass O(n) apply using pre-built hash maps.
// Lookup tables built once before each pass eliminate O(n²) naive matching.
// Task.yield() between passes keeps the Main Actor cooperative.

// Pre-build O(1)-lookup tables:
let localTagsByCloudID    = firstLocalRecordByCloudID(localSnapshot.tags)    // [UUID: Tag]
let localToDosByCloudID   = firstLocalRecordByCloudID(localSnapshot.toDos)   // [UUID: ToDo]
let localNanoDosByCloudID = firstLocalRecordByCloudID(localSnapshot.nanoDos) // [UUID: NanoDo]
let tombstonedTagIDs      = remoteSnapshot.tombstonedIDs(for: .tags)         // Set<UUID>
let tombstonedToDoIDs     = remoteSnapshot.tombstonedIDs(for: .toDos)        // Set<UUID>

// Pass 1 — Tags: O(n), builds syncedTagsByCloudID
// Pass 2 — ToDos: O(n), conflict detection inline, builds syncedToDosByCloudID
// Pass 2b — Tag relationships: O(n) using Dictionary(grouping:by:)
// Pass 3 — NanoDos: O(n), resolves parent via syncedToDosByCloudID
// Total: O(n), not O(n²)
```

---

### Stepped Backoff Array — realtime retry

```swift
// Core/Infrastructure/Supabase/SupabaseSyncService.swift
// TYPE: Fixed-size [UInt64] used as lookup table for retry delay values.
// Not true exponential backoff; steps are 2s, 10s, 30s.
// No jitter — simultaneous disconnects retry in lockstep.

let retryDelays: [UInt64] = [2_000_000_000, 10_000_000_000, 30_000_000_000]
let delayNanoseconds = retryDelays[min(attempt - 1, retryDelays.count - 1)]
```

**Improvement available:** Replace with a computed exponential backoff + jitter function. Reference: https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/

---

### Multi-Pass Collection Scan — `ToDoStatsSnapshot.init`

```swift
// Features/Stats/Views/StatsView.swift
// ALGORITHM: ~30 sequential filter/reduce/map passes over the same [ToDo] array.
// Each .filter, .count, .reduce, and .min creates a new pass.
// Passes are not memoized; the snapshot is recomputed every time StatsView
// body evaluates.

let active = toDos.filter(\.isActive)               // pass 1
let completed = toDos.filter { $0.lifecycleState == .done }  // pass 2
let scheduled = active.filter { $0.dueDate != nil } // pass 3
// ... ~27 more passes ...
overdueToDos = active.filter(\.isLate).count         // another pass over active
dueTodayToDos = active.filter { ... }.count          // another pass over active
// etc.
```

This is noted here for reference. The actual performance characteristics depend on n (number of todos) and how often the body re-evaluates. Do not optimize until profiled — see Task 13 in Deferred.

---

## 4. Deferred — Needs Investigation First

These items are confirmed real issues but require measurement, profiling, or design decisions before any code can be written. Each entry has a defined first step.

---

### Deferred A — `ToDo` model decomposition

**Background:** `ToDo` holds recurrence (6 fields), location reminder (5 fields), sync metadata (3 fields), and relationships (3) in addition to core task data. This makes the model large but not wrong — every field is used.

**Why deferred:** Extracting recurrence into a `Codable` blob attribute or a separate `@Model` requires a schema migration and changes how `SupabaseSyncService`, `SyncConflict`, and `WatchBridgeModels` assemble records. The blast radius is large enough that it should not be done speculatively.

**First step:** Before writing any code, list every location in the codebase that directly reads or writes any of the six recurrence fields (`recurrenceUnitRaw`, `recurrenceIntervalValue`, `recurrenceModeRaw`, `recurrenceCountValue`, `recurrenceAnchorDate`, `recurrenceEndDate`) using a project-wide search. This map is the prerequisite for any refactor.

---

### Deferred B — `StatsView` performance profiling

**Background:** `ToDoStatsSnapshot.init` runs approximately 30 sequential filter/reduce/map passes over the full `[ToDo]` array, all on the Main Actor, recomputed every time `StatsView`'s body evaluates. For users with large todo histories this could be slow.

**Why deferred:** "Could be slow" is not the same as "is slow." Premature optimization here would add complexity (caching, background calculation, `async` init) for a view that many users may never open.

**First step:** Profile `StatsView` with Instruments Time Profiler using a container seeded with 1,000 todos (a realistic power-user upper bound). If `ToDoStatsSnapshot.init` appears in the top 20% of CPU usage during sheet presentation, the refactor is justified. If not, close this item.

**If profiling shows a problem:** The fix is to move `ToDoStatsSnapshot` construction onto a background `Task` and show a loading state while it computes, similar to how `@Query` lazily loads from SwiftData. The snapshot is a value type, so it is safe to compute off the main actor and assign back.

---

### Deferred C — Singleton dependency injection

**Background:** All major services (`SyncCoordinator`, `NotificationManager`, `LocationReminderService`, etc.) are `static let shared` singletons accessed directly. This makes unit testing difficult for any code path that calls through to them.

**Why deferred:** Refactoring all singletons to be injected requires touching every call site in the app and rewriting the test architecture. This is a large structural change that should be done deliberately, not as part of another fix.

**First step:** Before any refactoring, produce a dependency map: for each singleton, list which files import or reference `.shared` directly. This map identifies the actual scope of the refactor and reveals which singletons are used in the most places (highest value targets for injection).

---

### Deferred D — `SyncCoordinator` scope management

**Background:** `SyncCoordinator` is responsible for sync mode transitions, backend lifecycle, error feedback, phase reporting, migration coordination, and Watch snapshot refresh. This is a broad set of responsibilities.

**Why deferred:** The current scope is intentional for a single-developer project — consolidating sync concerns in one place reduces indirection. Splitting it prematurely creates coordination overhead without a clear benefit.

**First step:** When `SyncCoordinator` exceeds ~400 lines or a second developer needs to work on the sync layer, revisit. At that point, `SyncFeedbackManager` (feedback and error display) and `SyncMigrationCoordinator` (migration staging and execution) are the natural extraction points with clear, non-overlapping responsibilities.

---

*End of spec.*
