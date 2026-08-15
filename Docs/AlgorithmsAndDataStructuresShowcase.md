# Algorithms, Data Structures, and Architecture in toDō

toDō primarily uses practical, production-oriented algorithms: hashing, grouping, deterministic conflict resolution, bounded selection, calendar arithmetic, and asynchronous coordination. Where intent is not documented directly, the rationale below is inferred from the surrounding behavior and invariants.

**Last revalidated against the codebase:** 2026-07-16

## Algorithms and Data Structures

### 1. Ordered Deduplication with `Array` and `Set`

**Where:** [`Features/ToDos/Models/ToDo.swift`](../Features/ToDos/Models/ToDo.swift#L431)

**How it works:** Two sets track tag IDs and normalized names, while an array preserves the user's original tag order. This prevents duplicates by both identity and semantic name without losing deterministic presentation order.

**Why these structures are appropriate:** A `Set` provides average constant-time membership checks, but it does not preserve the user-facing order required by the UI. The array and sets therefore serve separate responsibilities: order and uniqueness.

**Complexity:** Average `O(n)` time and `O(k)` auxiliary space, with `k` capped at five tags.

### 2. Canonicalization through Hash Grouping and Priority Comparison

**Where:** [`Features/Tags/Models/Tag.swift`](../Features/Tags/Models/Tag.swift#L79)

**How it works:** `Dictionary(grouping:by:)` partitions tags by normalized name. A multi-criteria comparator prefers cloud-backed, recently updated, and then older-created records. This produces a deterministic canonical tag from inconsistent local data.

**Why it is appropriate:** Grouping converts a global duplicate-search problem into independent duplicate groups. Deterministic tie-breaking ensures that different reconciliation passes make the same choice from equivalent input.

**Complexity:** `O(n + Σ gᵢ log gᵢ)` time and `O(n)` space, where `gᵢ` is the size of each duplicate group.

### 3. Composite Hash Keys for Semantic Duplicate Detection

**Where:** [`Core/Infrastructure/Supabase/SupabaseSyncService.swift`](../Core/Infrastructure/Supabase/SupabaseSyncService.swift#L484)

**How it works:** `Hashable` structures combine task text, notes, state, deadline, reminder intent, recurrence configuration, and, for semantic matching, collaboration scope. These keys allow complete toDō records to participate in set and dictionary operations as semantic identities.

**Why it is appropriate:** A cloud UUID identifies a particular stored record, but it cannot determine whether two independently created records represent the same logical toDō. The semantic key provides that second form of identity.

**Complexity:** Average `O(1)` dictionary or set lookup after key construction. Constructing the key is proportional to the fields included in it.

### 4. Remote Duplicate Cleanup Using Group, Elect, and Tombstone

**Where:** [`Core/Infrastructure/Supabase/SupabaseSyncService.swift`](../Core/Infrastructure/Supabase/SupabaseSyncService.swift#L1200)

**How it works:** Active records are grouped by semantic key, one canonical record is elected with a deterministic comparator, and losing records receive tombstones before deletion.

**Why it is appropriate:** Deleting a duplicate without recording the deletion could allow another device with stale data to upload it again. Tombstoning gives deletion durable meaning across distributed replicas.

**Complexity:** Up to `O(n log n)` time and `O(n)` auxiliary space across the grouped records.

### 5. In-Memory Hash Join for Account Migration

**Where:** [`Core/Infrastructure/Supabase/SupabaseSyncService.swift`](../Core/Infrastructure/Supabase/SupabaseSyncService.swift#L1289)

**How it works:** Dictionaries index tags by normalized name, toDōs by cloud ID and semantic key, and cloned objects by source identifier. These lookup tables reconstruct tag-toDō-nanoDo relationships without repeatedly scanning every collection.

**Why it is appropriate:** This is the in-memory equivalent of a relational hash join. Building indexes once changes repeated parent, child, and tag resolution from nested searches into keyed lookups.

**Complexity:** Near `O(T + D + N)` average time and space for tags, toDōs, and nanoDos, excluding duplicate-group sorting.

### 6. Graph Repair through Canonical-Node Rewiring

**Where:** [`Core/Infrastructure/Supabase/SupabaseSyncService.swift`](../Core/Infrastructure/Supabase/SupabaseSyncService.swift#L1478)

**How it works:** Duplicate tags are grouped, a canonical node is selected, and all toDō and nanoDo relationships are redirected before duplicate nodes are deleted.

**Why it is appropriate:** Tags are not isolated values; they are nodes referenced by other persisted objects. Rewiring those edges before deleting a duplicate preserves referential integrity and prevents relationship loss.

**Complexity:** Grouping is average `O(t)`. Relationship repair is proportional to the number of relationships attached to duplicate nodes.

### 7. Composite-Key Tombstone Map

**Where:** [`Core/Sync/SyncTombstoneStore.swift`](../Core/Sync/SyncTombstoneStore.swift#L36)

**How it works:** A tombstone is keyed by `(userID, table, recordID)` and also carries optional collaboration scope for remote deletion policy. A dictionary collapses duplicate deletion events and retains the newest timestamp, while a set removes successfully synchronized keys efficiently.

**Why it is appropriate:** A record ID alone is insufficient because IDs exist in table and account scopes. The composite key expresses the full identity required by the synchronization protocol.

**Complexity:** Average `O(n)` processing instead of repeated `O(n²)` searches.

### 8. Estimate-and-Correct Recurrence Indexing

**Where:** [`Services/Notifications/NotificationManager.swift`](../Services/Notifications/NotificationManager.swift#L872)

**How it works:** The next recurrence index is estimated using elapsed seconds or calendar components, then corrected backward or forward using actual calendar arithmetic.

**Why it is appropriate:** Replaying every recurrence from its original anchor would scale with the age and frequency of the recurring toDō. Estimation jumps near the answer, while correction preserves accuracy for months, years, daylight-saving transitions, and other calendar irregularities.

**Complexity:** `O(c)`, where `c` is a small correction distance rather than the complete recurrence history.

### 9. Bounded Recurrence Generation

**Where:** [`Services/Notifications/NotificationManager.swift`](../Services/Notifications/NotificationManager.swift#L766)

**How it works:** Future occurrences are generated iteratively but stop at the notification limit, finite recurrence count, or configured end date.

**Why it is appropriate:** Continuous recurrence describes a conceptually unbounded sequence. The scheduler must materialize only the finite prefix that the operating system can use.

**Complexity:** `O(k)` time and space for at most `k` generated occurrences.

### 10. Bounded Top-K Notification Selection

**Where:** [`Services/Notifications/NotificationManager.swift`](../Services/Notifications/NotificationManager.swift#L808)

**How it works:** Candidate reminders are accumulated, periodically sorted by fire date, and truncated to the platform scheduling limit.

**Why it is appropriate:** Only the earliest `K` notifications are useful when the system imposes a finite request limit. Periodic pruning prevents memory from growing with every possible candidate.

**Complexity:** Approximately `O(C log K)` time and `O(K)` retained space, where `C` is the candidate count and `K` is the scheduling cap.

### 11. Filtering, Grouping, and Multi-Key Sorting Pipeline

**Where:** [`Features/ToDos/Views/ToDosView.swift`](../Features/ToDos/Views/ToDosView.swift#L1977)

**How it works:** toDōs pass through state, system-list, search, and tag predicates before being sorted or grouped by due month, tag, or nanoDo count. Comparators include deterministic tie-breakers such as overdue status and creation date.

**Why it is appropriate:** Filtering before grouping and sorting reduces the working set. Explicit tie-breakers keep ordering predictable when primary values are equal, which is important for stable user interfaces.

**Complexity:** Filtering is `O(n + r)`, where `r` is the number of inspected relationships. Sorting is `O(n log n)`.

### 12. Frequency Map and Mode Calculation for Statistics

**Where:** [`Features/Stats/Views/StatsView.swift`](../Features/Stats/Views/StatsView.swift#L413)

**How it works:** A `[String: Int]` dictionary counts tag usage, while weekday grouping and `max` identify the most common overdue day. These are histogram and mode-finding algorithms.

**Why it is appropriate:** The statistics screen needs aggregate frequencies rather than ordered raw records. A dictionary stores one counter per distinct category and supports average constant-time counter updates.

**Complexity:** `O(n + e)` time, where `e` is the number of tag relationships, and `O(u)` space for `u` unique tags.

### 13. Set Algebra for StoreKit Entitlements

**Where:** [`Core/Commerce/ToDoProductCatalog.swift`](../Core/Commerce/ToDoProductCatalog.swift#L32) and [`Core/Commerce/ToDoPurchaseManager.swift`](../Core/Commerce/ToDoPurchaseManager.swift#L233)

**How it works:** Product categories are represented as sets. `union`, `subtracting`, `contains`, and `isDisjoint` express restorable purchases, missing products, and active toDō+ access.

**Why it is appropriate:** Entitlement evaluation is fundamentally a membership and overlap problem. Set operations express the domain directly and reduce the risk of inconsistent conditional chains.

**Complexity:** Membership is average `O(1)`. Intersection-style checks are proportional to the smaller participating set in normal use.

### 14. Product Lookup Table with Partial-Result Recovery

**Where:** [`Core/Commerce/ToDoPurchaseManager.swift`](../Core/Commerce/ToDoPurchaseManager.swift#L302)

**How it works:** StoreKit products are indexed by product ID in a dictionary. Missing IDs are found through set subtraction and retried individually because StoreKit can return a partial catalog without throwing.

**Why it is appropriate:** The UI requests products by stable identifier, making a keyed lookup table more suitable than repeated array searches. Individual retries isolate partial catalog failures.

**Complexity:** Average `O(p)` catalog construction and `O(1)` product lookup, excluding StoreKit network latency.

### 15. Generation Counter for Stale Asynchronous-Result Suppression

**Where:** [`Core/Commerce/ToDoPurchaseManager.swift`](../Core/Commerce/ToDoPurchaseManager.swift#L287)

**How it works:** `accountRevision` increments whenever the active account changes. Asynchronous responses apply only when their captured revision still matches the current revision.

**Why it is appropriate:** Cancellation alone does not guarantee that every in-flight operation stops before returning. A generation token prevents a slow request for an old account from overwriting the new account's state.

**Complexity:** `O(1)` validation per asynchronous result and constant additional space.

### 16. Capped Retry Schedule and Trailing-Edge Debounce

**Where:** [`Core/Infrastructure/Supabase/SupabaseSyncService.swift`](../Core/Infrastructure/Supabase/SupabaseSyncService.swift#L833)

**How it works:** Realtime reconnection uses a bounded `2s`, `10s`, and `30s` retry schedule. Remote events use task cancellation to debounce multiple changes into one refresh.

**Why it is appropriate:** Backoff avoids tight reconnection loops during an outage. Debouncing coalesces a burst of related database events so one logical remote update does not trigger several overlapping full refreshes.

**Complexity:** Retry scheduling is constant-space and capped. Each event performs `O(1)` task replacement, while the eventual refresh cost depends on the synchronized dataset.

### 17. Hash Joins for watchOS Data Hydration

**Where:** [`ToDo Watch App/WatchDirectSyncClient.swift`](../ToDo%20Watch%20App/WatchDirectSyncClient.swift#L25)

**How it works:** NanoDos are grouped by parent ID, tags are indexed by tag ID, and join-table rows are grouped by toDō ID. The resulting indexes assemble complete watch models from normalized remote records.

**Why it is appropriate:** This mirrors relational database joins in memory and avoids scanning every child or tag for every parent. It is particularly useful on a resource-constrained watchOS device.

**Complexity:** Average `O(D + N + L + T)` time and space for toDōs, nanoDos, links, and tags.

### 18. Persistent Array-Backed Action Queue

**Where:** [`ToDo Watch App/WatchActionQueueStore.swift`](../ToDo%20Watch%20App/WatchActionQueueStore.swift#L3)

**How it works:** Pending watch actions are stored as an ordered JSON array. Duplicate IDs are rejected before append, and acknowledged IDs are removed using a set.

**Why it is appropriate:** The array preserves replay order and is simple to serialize atomically. The acknowledgement set makes batch-removal membership checks average `O(1)` per queued action.

**Complexity:** Enqueue duplicate detection is `O(q)` in the current implementation. Batch removal is average `O(q + a)` for `q` queued actions and `a` acknowledged IDs.

### 19. Per-Identifier Asynchronous Task Registries

**Where:** [`Core/Services/LiveActivityService.swift`](../Core/Services/LiveActivityService.swift#L9)

**How it works:** Dictionaries map activity IDs to scheduled-end and token-observation tasks. Existing work can be found, cancelled, and replaced without affecting unrelated activities.

**Why it is appropriate:** Activity identity is the natural key for task ownership. A dictionary avoids scanning an array of tasks and makes lifecycle cleanup explicit.

**Complexity:** Average `O(1)` lookup, replacement, and removal per activity.

### 20. Ordered Rule Reduction and Normalized Uniqueness in Voice Parsing

**Where:** [`Core/Services/VoiceToDoIntentResolver.swift`](../Core/Services/VoiceToDoIntentResolver.swift#L102) and [`normalizedUniqueStrings`](../Core/Services/VoiceToDoIntentResolver.swift#L262)

**How it works:** Regex patterns form an ordered transformation pipeline that removes due-date phrases before whitespace normalization. A set then deduplicates tags and nanoDo titles while an array preserves spoken order.

**Why it is appropriate:** Parsing stages are order-sensitive because earlier transformations simplify later input. The array-and-set combination retains the user's phrasing order while enforcing normalized uniqueness.

**Complexity:** Approximately `O(pL)` for `p` fixed pattern passes over input length `L`, subject to regular-expression engine behavior.

### 21. Dictionary Reduction across the SwiftUI View Tree

**Where:** [`Features/ToDos/Views/ToDosViewComponents.swift`](../Features/ToDos/Views/ToDosViewComponents.swift#L932)

**How it works:** A `PreferenceKey` reduces child anchor dictionaries into one spotlight lookup table. New anchors replace older anchors for the same semantic ID.

**Why it is appropriate:** The onboarding overlay needs geometry emitted by controls distributed throughout the view tree. A preference reduction communicates that information upward without tightly coupling child views to the overlay implementation.

**Complexity:** Average `O(a)` reduction time and `O(a)` space for `a` emitted anchors.

### 22. Deterministic Ordering over Unordered SwiftData Relationships

**Where:** [`Features/ToDos/Models/ToDo.swift`](../Features/ToDos/Models/ToDo.swift#L259)

**How it works:** `orderedNanoDos` sorts a SwiftData to-many relationship by synchronized creation time and then uses cloud or persistent identity as a final tie-breaker.

**Why it is appropriate:** SwiftData does not guarantee insertion order for to-many relationships. A total ordering prevents the same children from appearing in a different order across fetches or devices when timestamps are equal.

**Complexity:** `O(n log n)` time and `O(n)` result storage for `n` nanoDos.

### 23. Persistent Secondary Indexes for Ownership and Collaboration Scope

**Where:** [`Features/ToDos/Models/ToDo.swift`](../Features/ToDos/Models/ToDo.swift#L151), [`Features/Tags/Models/Tag.swift`](../Features/Tags/Models/Tag.swift#L11), and [`Features/NanoDo/Models/NanoDo.swift`](../Features/NanoDo/Models/NanoDo.swift#L11)

**How it works:** SwiftData `#Index` declarations index ownership fields on all primary models and collaboration scope on toDō records.

**Why it is appropriate:** Ownership and collaboration are recurring data-partition keys. Declaring persistent indexes allows the backing store to optimize scoped predicates without maintaining a custom in-memory cache. The concrete index implementation and query plan remain framework-controlled.

**Complexity:** Store-dependent. Indexed lookup is expected to avoid a full table scan, but no specific asymptotic guarantee should be claimed without inspecting the generated store and query plan.

### 24. Reverse Relationship Indexes for Startup Migration

**Where:** [`App/ToDoApp.swift`](../App/ToDoApp.swift#L326)

**How it works:** Startup tag normalization builds dictionaries from tag ID to referencing toDōs and nanoDos before repairing empty or duplicate tags.

**Why it is appropriate:** The migration repeatedly needs the records that point to a particular tag. A reverse index performs the relationship traversal once and then updates only affected records instead of rescanning the entire object graph for every tag.

**Complexity:** Approximately `O(D·A + N + T + R)` time and `O(D·A + N)` auxiliary space, where `A` is average tags per toDō and `R` is the number of repaired relationships.

### 25. Membership Index for Unused-Tag Detection

**Where:** [`Features/Settings/Views/SettingsView.swift`](../Features/Settings/Views/SettingsView.swift#L1664)

**How it works:** A `Set<PersistentIdentifier>` collects every tag referenced by scoped toDōs and nanoDos. Counting or deleting unused tags then becomes a linear pass with average constant-time membership tests.

**Why it is appropriate:** The question is binary: whether each tag is referenced anywhere. Ordering and occurrence counts are irrelevant, making a set the minimal fitting structure.

**Complexity:** `O(D·A + N + T)` time and `O(U)` space for `U` used tags, instead of repeatedly scanning relationships once per tag.

### 26. Short-Lived Frequency Indexes for SwiftUI Render Paths

**Where:** [`Features/Tags/Views/TagManagementView.swift`](../Features/Tags/Views/TagManagementView.swift#L283) and [`usageCountsByTagID`](../Features/Tags/Views/TagManagementView.swift#L520)

**How it works:** Tag relationships are grouped into dictionaries keyed by persistent ID or normalized name. Sort comparators and rendered rows then read precomputed counts rather than traversing all relationships repeatedly.

**Why it is appropriate:** A sort comparator executes many times. Moving relationship scans outside the comparator prevents the cost of a scan from being multiplied by `O(T log T)` comparisons. The indexes are short-lived so they do not introduce cache invalidation problems.

**Complexity:** Approximately `O(D·A + N + T log T)` time for linked-count sorting, rather than `O(T log T · (D·A + N))` when counts are recomputed inside comparisons.

### 27. Identity Lookup Tables for Editor and Bulk Operations

**Where:** [`Features/ToDos/Views/ToDoView.swift`](../Features/ToDos/Views/ToDoView.swift#L1857) and [`Features/ToDos/Views/ToDosView.swift`](../Features/ToDos/Views/ToDosView.swift#L2384)

**How it works:** The editor indexes tags by `PersistentIdentifier` while retaining selected IDs in an ordered array and a membership set. Bulk list actions similarly index scoped toDōs by ID before resolving selected records.

**Why it is appropriate:** IDs are the stable bridge between UI selection state and SwiftData objects. Dictionaries provide lookup, sets provide membership, and arrays preserve user selection order.

**Complexity:** Editor resolution is `O(T + S)` and bulk resolution is `O(D + B)`, replacing repeated `O(S·T)` or `O(B·D)` scans.

### 28. Precomputed Child Counts and Record Maps in Sync Reconciliation

**Where:** [`Core/Infrastructure/Supabase/SupabaseSyncService.swift`](../Core/Infrastructure/Supabase/SupabaseSyncService.swift#L1659) and [`remote apply`](../Core/Infrastructure/Supabase/SupabaseSyncService.swift#L1931)

**How it works:** One pass counts child nanoDos and tag links by parent UUID. Another pass indexes active remote toDō records by UUID before relationship reconciliation and timestamp updates.

**Why it is appropriate:** Canonical-selection comparators and apply loops execute repeatedly. Precomputation prevents each comparison or synchronized record from rescanning complete remote child and record collections.

**Complexity:** Child-count construction is `O(N + L)` and lookup is average `O(1)`. Active-record indexing changes repeated timestamp resolution from `O(M·R)` to `O(R + M)`.

### 29. Lazy, Bounded App Intent Query Pipeline

**Where:** [`Core/AppIntents/ToDoIntentRepository.swift`](../Core/AppIntents/ToDoIntentRepository.swift#L35)

**How it works:** SwiftData performs the initial active-state predicate and multi-key sort. A lazy sequence then applies account and collaboration visibility, optional normalized text filtering, a result limit, and projection into sendable snapshots.

**Why it is appropriate:** App Intents need a small result set rather than a second fully materialized transformed collection. `lazy` with `prefix(limit)` stops downstream filtering and mapping after enough visible matches have been found. Collaboration IDs are represented as a set for average constant-time scope membership.

**Complexity:** The in-memory stage inspects at most the fetched prefix required to produce `L` visible matches; worst case remains `O(F)`, where `F` is the fetched active record count, with `O(L)` output space.

### 30. Keyed Collaboration Caches and In-Flight Request Suppression

**Where:** [`Core/Commerce/ToDoCollaborationService.swift`](../Core/Commerce/ToDoCollaborationService.swift#L400)

**How it works:** Profiles and errors are dictionaries keyed by collaboration ID, while a set tracks collaborations with profile requests already in flight. An account revision counter rejects responses produced for a previous signed-in account.

**Why it is appropriate:** Collaboration ID is the natural cache and task-ownership key. The loading set prevents duplicate concurrent requests, and the generation counter prevents stale cross-account state from becoming visible.

**Complexity:** Average `O(1)` cache, loading-state, and error lookup per collaboration, plus `O(p)` storage for cached profiles.

## Complexity Notes

Swift `Dictionary` and `Set` operations above are average-case `O(1)`. Pathological hash-collision behavior can degrade toward `O(n)`. Complexity descriptions intentionally exclude external latency from StoreKit, Supabase, CloudKit, and operating-system services unless stated otherwise.

The examples describe implemented production techniques, not benchmark claims. Real-world performance also depends on SwiftData relationship faulting, allocation behavior, collection sizes, device class, and framework implementation details.

## Verification and Tests

Relevant model, sync, commerce, profile, collaboration, watch, and App Intent contracts have direct coverage in:

- [`ToDoTests/ToDoModelTests.swift`](../ToDoTests/ToDoModelTests.swift#L76)
- [`ToDoTests/SyncTombstoneStoreTests.swift`](../ToDoTests/SyncTombstoneStoreTests.swift#L5)
- [`ToDoTests/CommerceContractTests.swift`](../ToDoTests/CommerceContractTests.swift)
- [`ToDoTests/SyncConflictStoreTests.swift`](../ToDoTests/SyncConflictStoreTests.swift)
- [`ToDoTests/WatchBridgeCodecTests.swift`](../ToDoTests/WatchBridgeCodecTests.swift)
- [`ToDoTests/ToDoIntentRepositoryTests.swift`](../ToDoTests/ToDoIntentRepositoryTests.swift)
- [`ToDoTests/ProfileContractTests.swift`](../ToDoTests/ProfileContractTests.swift)

These tests establish behavioral contracts, but they are not performance benchmarks. Runtime performance claims still require Instruments measurements against representative large datasets.

## Suggested Social Post Topics

- **Why arrays and sets are used together:** preserving user-visible order while enforcing uniqueness.
- **Recurring reminders without replaying history:** estimate-and-correct calendar arithmetic.
- **Using hash joins in a Swift synchronization engine:** reconstructing relationships in linear average time.
- **Why distributed deletion requires tombstones:** preventing stale replicas from resurrecting deleted data.
- **Preventing stale asynchronous responses with generation counters:** protecting state during account changes.
- **Designing for watchOS constraints:** bounded collections, grouped remote records, and persistent offline actions.
- **Set algebra as business logic:** expressing StoreKit product and entitlement rules through membership operations.
- **Deterministic conflict resolution:** selecting canonical records with explicit, repeatable tie-breakers.
- **Database indexes versus temporary in-memory indexes:** choosing the right lifetime and invalidation strategy.
- **Why sort comparators should not scan relationships:** preventing hidden multiplicative work in SwiftUI render paths.
- **Designing App Intents for bounded work:** combining store predicates, lazy sequences, and result limits.
- **Collaboration state without cross-account races:** keyed caches, in-flight sets, and generation counters.

## Application Architecture

The most accurate description of toDō's architecture is:

> **A feature-first, layered SwiftUI architecture with SwiftData persistence, observable application services, coordinator-based orchestration, and protocol-oriented backend adapters.**

It is **not strict MVVM**. Although several `ObservableObject` and `@Observable` types perform view-model or store-like responsibilities, many SwiftUI views query SwiftData directly through `@Query`, receive `ModelContext` through the environment, and perform persistence operations themselves. The project does not consistently place each screen's presentation and mutation logic behind a dedicated view model.

The updated code strengthens application boundaries through `ToDoIntentRepository`, `ToDoEditorDraft`, backend-client protocols, collaboration services, and explicit sync adapters. Those additions improve separation and testability, but they do not change the overall classification because direct SwiftData access remains common in feature views.

It is also **not strict Clean Architecture**. The code has meaningful layers and abstractions, but framework types, shared singleton services, and persistence concerns cross boundaries that a strict Clean Architecture implementation would isolate behind domain-level use cases and dependency inversion.

### Architectural Layers

1. **Composition root:** `App/ToDoApp.swift` creates the SwiftData container, configures services, registers App Intents dependencies, and injects observable services into the SwiftUI environment.
2. **Presentation layer:** `Features/*/Views` and platform-specific views implement the SwiftUI interface and consume environment state, queries, and services.
3. **Domain and persistence models:** `ToDo`, `Tag`, `NanoDo`, and `SyncConflict` are SwiftData `@Model` types containing persisted state and selected domain invariants.
4. **Application and workflow layer:** repositories, editor drafts, purchase, authentication, collaboration, notifications, location, Live Activities, watch connectivity, and presentation services coordinate persistence mutations, framework APIs, and app workflows.
5. **Coordinator layer:** `NavigationCoordinator`, `ToDoPresentationService`, and `SyncCoordinator` centralize routing, modal presentation, synchronization state, and backend selection.
6. **Infrastructure layer:** Supabase, CloudKit, StoreKit, WatchConnectivity, ActivityKit, and notification implementations integrate external systems.
7. **Protocol-oriented boundaries:** abstractions such as `ToDoSyncBackend`, `ToDoEntitlementBackendClient`, and `ToDoCollaborationBackendClient` separate orchestration from selected infrastructure implementations.
8. **Extensions and secondary targets:** watchOS, widgets, App Intents, and macOS have target-specific composition and presentation code while sharing domain concepts and services where practical.

### Patterns Used within the Architecture

- **Repository pattern:** `ToDoIntentRepository` provides a persistence-facing boundary for App Intents.
- **Draft or transaction model:** `ToDoEditorDraft` stages editor state and applies a validated persistence mutation as one workflow.
- **Strategy pattern:** `SyncCoordinator` selects a `ToDoSyncBackend` implementation for local, CloudKit, or Supabase synchronization modes.
- **Coordinator pattern:** navigation, presentation, and synchronization workflows are managed outside individual leaf views.
- **Observer pattern:** SwiftUI observes `ObservableObject`, `@Observable`, `@Published`, and SwiftData query changes.
- **Adapter pattern:** backend types adapt Supabase and CloudKit services to the shared synchronization protocol.
- **Dependency injection:** the app injects SwiftData and observable services through SwiftUI's environment, while several protocol-backed services accept dependencies through initializers.
- **Singleton service pattern:** shared cross-cutting services provide process-wide ownership for notifications, synchronization, purchases, location, presentation, and Live Activities.

For public technical descriptions, use **feature-first layered SwiftUI architecture** as the primary label. A precise short version is:

> toDō uses a feature-first, layered SwiftUI architecture built around SwiftData, observable services, coordinators, and protocol-oriented infrastructure adapters.
