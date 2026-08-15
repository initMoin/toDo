# toDō Data Structures and Algorithms Tracker

> Historical Apple-platform tracker. The maintained cross-platform source of truth is [`DataStructuresAndAlgorithmsAudit.md`](DataStructuresAndAlgorithmsAudit.md).

**Last reviewed:** 2026-08-08  
**Scope:** iOS, iPadOS, macOS, watchOS, WidgetKit, Live Activities, sync, commerce, notifications, onboarding, profiles, and collaboration  
**Status:** Living engineering document

## Purpose

This document records real data structures and algorithms already present in the toDō codebase. It is not a generic computer-science glossary. Each entry names the implementation area, explains the invariant it protects, records the expected complexity, and identifies whether the implementation is verified by source inspection or still needs runtime measurement.

Keep this file current whenever a change introduces or materially changes:

- A collection used for identity, lookup, ordering, grouping, deduplication, or reconciliation.
- A sort, filter, reduction, retry policy, queue, state machine, parser, scheduler, or join.
- A potentially unbounded operation or an operation that runs from a SwiftUI rendering path.
- A sync, collaboration, commerce, notification, or account-switching invariant.

When adding an entry, record the affected platform targets and both the asymptotic complexity and the practical bound. Complexity alone is not a performance claim until it has been profiled with representative data.

## Working Complexity Conventions

- `n` is the number of primary records being processed.
- `t` is the number of tags; `a` is the average number of tags on one toDō.
- `N` is the number of nanoDos; `r` is the number of relationships or repaired records.
- `k` is a platform or app-imposed bound, such as the number of scheduled notifications.
- Dictionary and set membership are described as average `O(1)`; worst-case hash behavior is not treated as a design guarantee.
- SwiftData index performance is store-dependent. The code declares indexes, but this document does not claim a query plan without Instruments or database evidence.

## Confirmed Implementations

### 1. Ordered tag deduplication

**Where:** `Features/ToDos/Models/ToDo.swift`, tag selection/canonicalization helpers.  
**Structures:** An ordered array plus sets of tag IDs and normalized names.  
**How:** Tags are visited in presentation order. The ID set prevents duplicate object identity and the normalized-name set prevents semantic duplicates while the array preserves the user's order.  
**Why:** A set alone would lose presentation order; an array alone would make uniqueness checks linear.  
**Complexity:** Average `O(n)` time and `O(k)` auxiliary space, with the UI limiting the number of tags.  
**Status:** Source-verified; regression tests cover the contract.

### 2. Canonical tag selection

**Where:** `Features/Tags/Models/Tag.swift`.  
**Structures:** `Dictionary(grouping:by:)` followed by a deterministic comparator.  
**How:** Tags are grouped by normalized name, then cloud-backed, recently updated, and creation-order rules choose one canonical record.  
**Why:** Duplicate cleanup becomes independent per name, and deterministic tie-breaking prevents different devices from choosing different winners.  
**Complexity:** `O(n + sum(g_i log g_i))` time and `O(n)` space for duplicate groups `g_i`.  
**Status:** Source-verified; should be measured only if tag counts become large.

### 3. Semantic duplicate keys

**Where:** `Core/Infrastructure/Supabase/SupabaseSyncService.swift`.  
**Structures:** Hashable composite key structs used in sets and dictionaries.  
**How:** Task content, notes, state, reminder intent, due information, recurrence, and collaboration scope are combined into semantic keys.  
**Why:** A cloud UUID identifies a row, but it cannot determine whether two independently created rows represent the same logical toDō.  
**Complexity:** Key construction is proportional to the included fields; average lookup is `O(1)`.  
**Risk:** Changing key fields changes duplicate behavior. Any change requires migration/regression tests.

### 4. Remote duplicate election and tombstoning

**Where:** `Core/Infrastructure/Supabase/SupabaseSyncService.swift`, remote duplicate repair.  
**Structures:** Dictionary groups plus deterministic sorted winner selection and tombstone arrays.  
**How:** Active remote records are grouped by semantic key, one winner is elected, and losing records receive tombstones before cleanup.  
**Why:** Deleting a duplicate without a durable tombstone lets a stale device upload it again.  
**Complexity:** Up to `O(n log n)` time and `O(n)` temporary space.  
**Status:** Source-verified; requires multi-device conflict testing for behavioral confidence.

### 5. In-memory hash joins for account migration

**Where:** `Core/Infrastructure/Supabase/SupabaseSyncService.swift`, migration and relationship-repair paths.  
**Structures:** Dictionaries keyed by cloud ID, semantic key, normalized tag name, and source identifier.  
**How:** Indexes are built once, then parent, child, and tag relationships are resolved by key instead of repeatedly scanning every collection.  
**Why:** This is the in-memory equivalent of relational hash joins and prevents nested linear searches during account migration.  
**Complexity:** Approximately `O(T + D + N)` average time and space before duplicate-group sorting.

### 6. Canonical tag graph rewiring

**Where:** `Core/Infrastructure/Supabase/SupabaseSyncService.swift`, duplicate-tag repair.  
**Structures:** Canonical-node selection and relationship traversal.  
**How:** References from toDōs and nanoDos are redirected to the canonical tag before the duplicate tag is deleted.  
**Why:** Tags are graph nodes with edges to other persisted records; deleting a node before rewiring loses relationships.  
**Complexity:** Grouping is average `O(t)`; repair is proportional to relationships attached to duplicate nodes.  
**Status:** Source-verified.

### 7. Reverse indexes for startup tag normalization

**Where:** `App/ToDoApp.swift`, startup migration.  
**Structures:** Tag-ID-to-toDō and tag-ID-to-nanoDo dictionaries.  
**How:** Relationship traversal occurs once, then invalid or duplicate tags update only records in the relevant index bucket.  
**Why:** A full scan for every tag would repeat the same relationship work.  
**Complexity:** Approximately `O(D * a + N + t + r)` time and `O(D * a + N)` temporary space.

### 8. Composite tombstone identity

**Where:** `Core/Sync/SyncTombstoneStore.swift`.  
**Structures:** Composite key `(userID, table, recordID)` with optional collaboration scope; dictionary storage and acknowledgement sets.  
**How:** Repeated deletion events collapse to one key and the newest timestamp wins. Acknowledged keys are removed through set membership.  
**Why:** Record IDs are not globally meaningful without account and table scope.  
**Complexity:** Average `O(1)` lookup/update; batch processing is average `O(n + a)`.  
**Status:** Source-verified; deletion mirroring tests exist.

### 9. ToDo filtering and multi-key sorting

**Where:** `Features/ToDos/Views/ToDosView.swift`.  
**Structures:** Ordered arrays, predicate pipelines, grouping dictionaries, and deterministic comparators.  
**How:** Lifecycle, selected list, search, and tag predicates reduce the working set before grouping/sorting by due date, tag, nanoDo count, and tie-breakers.  
**Why:** Filtering before expensive ordering reduces work and explicit tie-breakers keep the UI stable.  
**Complexity:** Filtering is `O(n + r)`; sorting is `O(n log n)`.  
**Risk:** This runs near presentation code; profile before adding more derived passes.

### 10. Tag usage index for cleanup

**Where:** `Features/Settings/Views/SettingsView.swift` and `Features/Tags/Views/TagManagementView.swift`.  
**Structures:** `Set<PersistentIdentifier>`.  
**How:** All referenced tag IDs are collected once, then unused tags are identified by membership.  
**Why:** The question is binary and does not need ordering or counts.  
**Complexity:** `O(D * a + N + t)` time and `O(u)` space for used tags.

### 11. Deterministic child ordering

**Where:** `Features/ToDos/Models/ToDo.swift`, `orderedNanoDos`.  
**Structures:** Sorted array from a SwiftData to-many relationship.  
**How:** Children sort by synchronized creation time and then cloud/persistent identity.  
**Why:** SwiftData relationships do not promise insertion order, especially after sync.  
**Complexity:** `O(n log n)` time and `O(n)` result storage.  
**Status:** Source-verified.

### 12. Notification recurrence estimation and correction

**Where:** `Services/Notifications/NotificationManager.swift`.  
**Algorithm:** Estimate the next recurrence index using elapsed time/calendar components, then correct using actual `Calendar` arithmetic.  
**Why:** Replaying every occurrence from the original anchor is unbounded with task age. Estimation jumps near the answer while correction handles DST and calendar irregularities.  
**Complexity:** `O(c)`, where `c` is the small correction distance rather than recurrence age.  
**Status:** Source-verified; calendar edge cases need device/time-zone tests.

### 13. Bounded recurrence materialization

**Where:** `Services/Notifications/NotificationManager.swift`.  
**Algorithm:** Generate future occurrences until the system request limit, finite recurrence count, or end date is reached.  
**Why:** A continuous recurrence is conceptually infinite, but the OS only needs a finite scheduled prefix.  
**Complexity:** `O(k)` time and retained space for the bounded result.

### 14. Bounded top-K notification selection

**Where:** `Services/Notifications/NotificationManager.swift`.  
**Structures:** Candidate array with date ordering and truncation at the platform scheduling cap.  
**How:** Candidates are ordered by fire date and only the earliest usable requests are retained.  
**Why:** Scheduling every theoretical candidate wastes memory and violates OS limits.  
**Complexity:** Current implementation is approximately `O(C log C)` when sorting all candidates; retained output is `O(k)`. A heap could reduce selection to `O(C log k)` if candidate volume becomes material.  
**Status:** Optimization candidate; do not replace without profiling because current platform bounds are small.

### 15. Frequency maps and mode statistics

**Where:** `Features/Stats/Views/StatsView.swift`.  
**Structures:** `[String: Int]` frequency dictionaries and grouped weekday values.  
**How:** Tag usage and overdue-day frequencies are counted, then the maximum identifies the mode.  
**Why:** Statistics need aggregate counts, not repeated ordered scans.  
**Complexity:** `O(n + e)` time and `O(u)` space for distinct categories.

### 16. StoreKit entitlement sets

**Where:** `Core/Commerce/ToDoProductCatalog.swift` and `Core/Commerce/ToDoPurchaseManager.swift`.  
**Structures:** Sets for product classifications and active capabilities.  
**How:** Union, subtraction, membership, and disjointness express restoration, missing products, and toDō+ access.  
**Why:** Entitlement evaluation is a membership/overlap problem and sets avoid inconsistent nested conditionals.  
**Complexity:** Average `O(1)` membership and linear set operations.

### 17. StoreKit product lookup and partial recovery

**Where:** `Core/Commerce/ToDoPurchaseManager.swift`.  
**Structures:** Product-ID dictionary and set subtraction.  
**How:** Products are indexed by stable IDs. Missing IDs from a partial StoreKit result are retried individually.  
**Why:** UI lookup is keyed by product ID and StoreKit can return partial catalogs.  
**Complexity:** Average `O(p)` catalog build and `O(1)` lookup, excluding network latency.

### 18. Account revision generation counter

**Where:** `Core/Commerce/ToDoPurchaseManager.swift`.  
**Structure:** Monotonic account revision integer.  
**How:** Account switching increments the revision; async results apply only if their captured revision still matches.  
**Why:** Cancellation cannot guarantee that an already-returning request will not publish stale state.  
**Complexity:** `O(1)` validation and constant space.

### 19. Debounced sync and bounded retry schedule

**Where:** `Core/Infrastructure/Supabase/SupabaseSyncService.swift`.  
**Structures:** Cancellable `Task` references for trailing-edge debounce and a fixed retry-delay array.  
**How:** A new remote event cancels the prior refresh task; realtime reconnects use bounded 2s/10s/30s delays.  
**Why:** Coalescing prevents event bursts from starting overlapping full refreshes; backoff avoids tight outage loops.  
**Complexity:** Task replacement is `O(1)`; eventual refresh cost is dataset-dependent; retry storage is constant.

### 20. Explicit sync state machine

**Where:** `Core/Sync/SyncCoordinator.swift` and `Core/Infrastructure/Supabase/SupabaseSyncService.swift`.  
**Structure:** Enumerated flush dispositions and guarded phases such as hydration, remote apply, local push, and queued refresh.  
**How:** `SupabaseLocalSyncFlushDisposition.resolve` chooses ignore, queue-until-hydrated, queue-after-remote-apply, or perform.  
**Why:** Explicit states prevent account leakage and feedback loops between SwiftData writes, remote application, and realtime events.  
**Complexity:** `O(1)` state transition decisions.  
**Status:** Source-verified; requires stress testing for rapid account switching.

### 21. watchOS hash joins

**Where:** `ToDo Watch App/WatchDirectSyncClient.swift`.  
**Structures:** Grouped nanoDos by parent ID, tag lookup by ID, and join links grouped by toDō ID.  
**How:** Normalized REST records are hydrated into complete watch models using keyed lookups.  
**Why:** A watch should not repeatedly scan every child/tag for every parent.  
**Complexity:** Average `O(D + N + L + T)` time and space.

### 22. Persistent watch action queue

**Where:** `ToDo Watch App/WatchActionQueueStore.swift`.  
**Structure:** Ordered JSON array plus acknowledgement set.  
**How:** Queue order is preserved across launches; duplicate IDs are rejected and acknowledged IDs are removed in a batch.  
**Why:** Ordered replay matters for user edits, while a set makes acknowledgement membership efficient.  
**Complexity:** Current enqueue duplicate detection is `O(q)`; batch removal is average `O(q + a)`.  
**Optimization candidate:** Add a persisted ID index only if queue sizes become large; current watch bounds make the simple array reasonable.

### 23. Per-activity task registries

**Where:** `Core/Services/LiveActivityService.swift`.  
**Structure:** Dictionaries map activity IDs to scheduled-end and token-observation tasks.  
**How:** Existing activity work is found, cancelled, replaced, and removed by stable activity ID.  
**Why:** Activity identity is the natural ownership key and avoids scanning unrelated tasks.  
**Complexity:** Average `O(1)` lookup/replacement/removal.

### 24. Ordered voice parsing pipeline

**Where:** `Core/Services/VoiceToDoIntentResolver.swift`.  
**Structures:** Ordered parsing rules, normalized unique arrays, and sets for deduplication.  
**How:** Due-date/property phrases are transformed in a deliberate order, then tags and nanoDos are deduplicated while spoken order is retained.  
**Why:** Parser stages are order-sensitive; an array preserves user intent and a set enforces uniqueness.  
**Complexity:** Approximately `O(pL)` for `p` fixed rule passes over input length `L`, subject to regex behavior.

### 25. SwiftUI onboarding anchor reduction

**Where:** `Features/ToDos/Views/ToDosViewComponents.swift`, spotlight preference key.  
**Structure:** Preference reduction into a dictionary keyed by semantic anchor ID.  
**How:** Distributed child controls emit geometry; the overlay receives one lookup table and targets the requested anchor.  
**Why:** This avoids coupling every child to onboarding state.  
**Complexity:** Average `O(a)` reduction time and `O(a)` space.

### 26. Persistent SwiftData secondary indexes

**Where:** `Features/ToDos/Models/ToDo.swift`, `Features/Tags/Models/Tag.swift`, and `Features/NanoDo/Models/NanoDo.swift`.  
**Structure:** SwiftData `#Index` declarations on ownership and collaboration scope.  
**Why:** Ownership and shared-scope predicates recur across sync and collaboration. Store-managed indexes are preferable to a custom cache.  
**Complexity:** Store-dependent; no asymptotic claim is made without query-plan evidence.

### 27. Profile image format normalization

**Where:** `Core/Profile/ToDoProfile.swift`.  
**Algorithm/data flow:** ImageIO decodes supported input formats, bounds the raster dimensions, and produces a normalized JPEG for the selected propagation scope.  
**Why:** Normalizing HEIF/PNG/JPEG input creates one predictable storage contract and prevents oversized uploads.  
**Complexity:** `O(p)` in decoded pixel count and bounded by the configured maximum dimension; memory is proportional to the raster being processed.

### 28. Capability reconciliation

**Where:** `Core/Commerce/ToDoPurchaseManager.swift` and account/profile state.  
**Structures:** Local StoreKit entitlement sets reconciled with server-backed account capabilities and an account revision guard.  
**Why:** Local purchase state and server account state are separate authorities; reconciliation must not leak an old user's benefit into a new account.  
**Complexity:** Linear in the number of entitlements and constant-time membership checks.

### 29. Collaboration authorization filtering

**Where:** `Core/Commerce/ToDoCollaborationService.swift` and Supabase-backed collaboration queries.  
**Structures:** Stable UUID sets and dictionaries of collab membership/profile records.  
**How:** User-visible collaborator data is filtered to shared scopes and role-specific actions.  
**Why:** Profile and shared-task access must be scoped by authorization, not by a client-side global list.  
**Complexity:** Average `O(1)` membership checks after one indexed fetch. Server RLS remains authoritative.

### 30. Activity graph bucketing

**Where:** `Features/Stats/Views/StatsView.swift` and shared activity graph components.  
**Structure:** Date buckets mapped to completion counts/intensity levels and rendered in stable row/column order.  
**Why:** A bounded grid is appropriate for a fixed time window and makes rendering predictable across iPhone, iPad, Mac, and Watch adaptations.  
**Complexity:** `O(n + c)` for `n` completion records and `c` graph cells; rendering storage is `O(c)`.

### 31. Fixed-label sync measurement

**Where:** `Core/Services/AppLog.swift` and `Core/Infrastructure/Supabase/SupabaseSyncService.swift`.  
**Structure:** A fixed operation label plus a start timestamp and a single terminal outcome.  
**How:** Local push and remote pull paths begin one measurement after their guard conditions, finish through `defer`, and record only success, cancellation, failure, and elapsed milliseconds. No user IDs, task text, account data, or tokens are included.  
**Why:** Sync performance and failure timing need evidence before moving work across actors or changing the state machine. Fixed labels keep the diagnostic stream bounded and searchable.  
**Complexity:** `O(1)` time and `O(1)` memory per measurement; it does not retain a history in process memory.

## Optimization Backlog

These are findings, not automatic rewrite instructions.

| Priority | Area | Finding | Recommended next step |
| --- | --- | --- | --- |
| High | `SupabaseSyncService` | A large `@MainActor` service owns networking orchestration, SwiftData reconciliation, realtime lifecycle, retries, and account switching. | Profile end-to-end sync with realistic datasets. Extract only measured hot paths into an actor/service boundary; preserve the existing state machine first. |
| Medium | `NotificationManager` | Top-K candidate selection currently sorts candidates before truncation. | Measure candidate counts. Replace with a bounded heap only if `C` materially exceeds the OS request limit. |
| Medium | `WatchActionQueueStore` | Duplicate detection scans the ordered array. | Keep the array until queue size evidence justifies a persisted index; avoid complexity on the watch without a measured need. |
| Medium | `ToDosView` and Stats | Derived filtering/grouping/sorting is close to SwiftUI rendering paths. | Use Instruments or signposts to measure body recomputation and move expensive derived work into observable services only when demonstrated. |
| Medium | Localization | The previously missing 138 customer-facing values are now translated across all supported languages; naturalness still needs native-speaker review. | Have language testers review and correct only the affected catalog values. |
| Medium | Typography | Mac and Watch system-font calls were mixed with role helpers. | Completed classification: icon/SF Symbol calls use explicit symbol helpers; release-history values use explicit monospaced helpers; customer-facing prose remains on shared roles. |
| Low | Logging | This pass removed raw Watch sync prints. Continue using `AppLog` and privacy-aware interpolation for new diagnostics. | Completed `Scripts/validate_raw_logging.rb`; keep it in release validation. |
| Low | Force unwraps | Remaining force unwraps are mostly trusted constants or guarded sorted collections. | Keep removing recoverable unwraps; review trusted constants separately rather than adding noisy optional plumbing. |
| Low | Swift versions | Main app targets and the previously stale Watch test/UI-test/widget configurations now use Swift 6; target compatibility is verified by generic builds. | Keep target settings aligned when new extensions or test targets are added. |

## Maintenance Checklist

Before merging a future data-heavy change:

1. Identify the identity key and whether it is local, cloud, account-scoped, or collaboration-scoped.
2. Choose `Set`, `Dictionary`, `Array`, queue, or sorted collection based on the operation the code actually performs.
3. Record average and practical worst-case complexity.
4. Bound recurrence, notification, retry, and remote-query work.
5. Preserve deterministic ordering wherever user-visible output is produced.
6. Check account switching, deletion tombstones, cancellation, and stale async results.
7. Add a focused behavior test before optimizing a hot path.
8. Profile before replacing a simple structure with a more complex one.

## Evidence Boundary

This document is a source-level audit. It does not claim measured latency, memory, energy, or query-plan performance. Those claims require representative data and runtime tools such as Instruments, signposts, SwiftData/SQL inspection, and multi-device sync testing.

## Audit Action Log

**2026-08-08**

- Replaced recoverable notification-title, location-label, and widget filter force unwraps with optional-value handling.
- Replaced four duplicate-repair `.first!` selections with guarded canonical selection. A missing winner now skips that repair group instead of crashing.
- Replaced raw Watch sync `print` calls with the privacy-aware `AppLog.sync` boundary.
- Added `AppLog.swift` to the Watch target source phase so the logging cleanup is actually available to watchOS.
- Refined `LocationReminderService` so an empty normalized location does not create a malformed `near ` suffix.
- Corrected the Watch test host/module contract and aligned Watch test/UI-test/widget targets with Swift 6/watchOS 27; the Watch test bundle now builds.
- Replaced WidgetKit's mutable static model-container cache with a lock-backed cache object; cache lookup remains `O(1)` and is now explicit about cross-invocation synchronization.
- Added translations for the 138 previously missing customer-facing catalog values across Arabic, Spanish, Hindi, Italian, Japanese, Malay, Thai, Urdu, and Simplified Chinese. The reusable `Scripts/fill_missing_localizations.rb` utility preserves existing values and fills only missing entries.
- Added fixed-label push/pull sync measurements to support runtime profiling without collecting user data.
- Added localized persistent-store recovery copy and `Scripts/validate_raw_logging.rb`; the release validator now rejects raw production console logging.
- Classified Mac/Watch system-font usage through explicit symbol and monospaced-code helpers; customer-facing prose remains on the approved typography roles.
- Added persistent-store recovery notices to the iOS and Mac roots; persistent-store failure now remains visible when the app falls back to a temporary offline store.
- Rebuilt iOS, macOS, and watchOS Debug targets successfully after these changes; final iOS and Watch test bundles also pass `build-for-testing`.

This log records implementation changes, not a claim that all platform UI or runtime behavior has been verified.
