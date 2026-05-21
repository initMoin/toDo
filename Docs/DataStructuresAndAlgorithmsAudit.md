# Data Structures and Algorithms Audit

Date: 2026-05-14

This audit covers the iOS, iPadOS, and watchOS code paths in ToDo. The project now follows these rules for the reviewed areas:

- Use `Set` when the dominant operation is membership.
- Use `Dictionary` when the dominant operation is keyed lookup or repeated keyed counts.
- Keep full collection scans out of sort comparators.
- Avoid recomputing normalized values inside repeated UI render-path loops.
- Keep indexes short-lived unless a longer-lived cache has a clear invalidation strategy.

## Platform Scope

- iOS and iPadOS: `App`, `Features`, `Core`, and `Services`.
- watchOS: `ToDo Watch App` plus shared watch bridge services.
- Shared sync and notification infrastructure: `Core/Infrastructure`, `Core/Sync`, `Services/Watch`, and `Services/Notifications`.

## 1. Watch List Partitioning

File: `ToDo Watch App/ContentView.swift`

Category: Algorithmic improvement  
Impact level: High  
Platforms: watchOS

### What Changed

- Extracted the "Now" bucket predicate into `isNowItem(_:soon:)`.
- `laterItems` now applies the same predicate directly instead of recomputing `nowItems` and calling `contains` for each item.

### Complexity

- Before: `O(n * k + n log n)`, worst case `O(n^2 + n log n)`.
- After: `O(n + n log n)`, simplified to `O(n log n)`.

### Structure Selection Rationale

No persistent index was needed. A shared predicate was chosen because the list is partitioned by rule, not by stable key.

### Tradeoffs

- Additional memory/allocation cost: none.
- Persistence-layer impact: none; this is in-memory watch data.
- Lifecycle duration: per computed-property evaluation.
- Why acceptable: removes quadratic behavior without cache invalidation complexity.

### Why This Matters

watchOS devices are resource constrained. Avoiding repeated scans during SwiftUI updates helps scrolling, battery use, and thermal behavior.

## 2. Settings Unused-Tag Detection

File: `Features/Settings/Views/SettingsView.swift`

Category: Algorithmic improvement  
Impact level: High  
Platforms: iOS, iPadOS

### What Changed

- Added `scopedUsedTagIDs()` to build a `Set<PersistentIdentifier>` of tags referenced by scoped ToDos and NanoDos.
- `unusedTagCount` and `deleteUnusedTags()` now use constant-time set membership.

### Complexity

- Before: `O(t * (d * a + n))`.
- After: `O(d * a + n + t)`.

Where:
- `t` = tag count
- `d` = ToDo count
- `a` = average tags per ToDo
- `n` = NanoDo count

### Structure Selection Rationale

`Set` was chosen because the operation is membership-only: determine whether a tag ID is used anywhere. Ordering and duplicate counts are irrelevant.

### Tradeoffs

- Additional memory/allocation cost: one short-lived set proportional to used tag count.
- Persistence-layer impact: performs one up-front relationship traversal rather than repeated SwiftData relationship traversals.
- Lifecycle duration: one settings computation or delete action.
- Why acceptable: the set is temporary and avoids repeated scans during settings rendering and deletion.

### Why This Matters

Settings summaries can be recomputed by SwiftUI. A linear index prevents repeated relationship scans as data grows.

## 3. Tag Management Usage Counts

File: `Features/Tags/Views/TagManagementView.swift`

Category: Algorithmic improvement and render-path optimization  
Impact level: High  
Platforms: iOS, iPadOS

### What Changed

- Added `[PersistentIdentifier: Int]` usage counts for real tag records.
- Added `[String: Int]` normalized-name counts for default tag names.
- Linked-count sorting and tag-pill rendering now read from dictionaries.

### Complexity

- Linked sort before: approximately `O(t log t * (d * a + n))`.
- Linked sort after: `O(d * a + n + t log t)`.
- Tag pill rendering before: `O(t * (d * a + n))`.
- Tag pill rendering after: `O(d * a + n + t)`.
- Default tag counts before: `O(g * d * a)`.
- Default tag counts after: `O(d * a + g)`.

### Structure Selection Rationale

`Dictionary` was chosen because the UI repeatedly asks for counts by tag identity or normalized tag name. Arrays were rejected because they would require repeated scans for every sort comparison and row render.

### Tradeoffs

- Additional memory/allocation cost: short-lived dictionaries proportional to tag/default-tag count.
- Persistence-layer impact: relationship traversal is moved up front for each view pass, reducing repeated SwiftData relationship access.
- Lifecycle duration: one SwiftUI computation pass.
- Why acceptable: avoids comparator-amplified scans and keeps no stale long-lived cache.

### Why This Matters

Tag sorting and tag-pill counts are visible render-path work. Removing repeated scans improves responsiveness on iPhone and iPad when tag and ToDo counts increase.

## 4. ToDo Detail Tag Selection

File: `Features/ToDos/Views/ToDoView.swift`

Category: Render-path optimization  
Impact level: Medium  
Platforms: iOS, iPadOS

### What Changed

- Added `tagsByID` to index `tagList` by `PersistentIdentifier`.
- `selectedTags` and save-time selected tag resolution use dictionary lookup instead of repeatedly searching `tagList`.

### Complexity

- Before: `O(s * t)` for selected tag resolution.
- After: `O(t + s)`.

Where:
- `s` = selected tag count
- `t` = available tag count

### Structure Selection Rationale

`Dictionary` was chosen because selected tag IDs must be resolved back to tag records by identity while preserving the selected ID order.

### Tradeoffs

- Additional memory/allocation cost: one short-lived dictionary proportional to tag count.
- Persistence-layer impact: no additional fetches; indexes already-loaded query results.
- Lifecycle duration: one computed-property or save pass.
- Why acceptable: selected tags are bounded, but the dictionary keeps behavior consistent with the project-wide lookup rule and avoids scaling surprises.

### Why This Matters

The ToDo editor is a common iOS/iPadOS workflow. Lookup indexing keeps tag selection work predictable as tag count grows.

## 5. ToDo List Filtering and Bulk Actions

File: `Features/ToDos/Views/ToDosView.swift`

Category: Render-path optimization and algorithmic improvement  
Impact level: High  
Platforms: iOS, iPadOS

### What Changed

- Normalized the search term once per grouping pass.
- Removed selected-tag membership checks from the selected-tag sort comparator because prior filtering already guarantees that invariant.
- Added `selectedToDos()` to index scoped ToDos by `PersistentIdentifier` for bulk completion, deletion, tag application, and tag clearing.

### Complexity

- Search normalization before: repeated `O(d * s)` normalization work.
- Search normalization after: `O(s)` normalization plus the existing `O(d)` filter pass.
- Selected-tag sort before: `O(d log d * a)` membership checks inside the comparator.
- Selected-tag sort after: `O(d log d)`.
- Bulk actions before: `O(b * d)` selected-ID lookup.
- Bulk actions after: `O(d + b)`.

Where:
- `d` = scoped ToDo count
- `s` = search text length
- `a` = average tags per ToDo
- `b` = selected ToDo count

### Structure Selection Rationale

`Dictionary` was chosen for bulk actions because the workload is repeated ID-to-record lookup. The selected-tag comparator no longer needs a data structure because the earlier filter already proves membership.

### Tradeoffs

- Additional memory/allocation cost: one short-lived dictionary for bulk actions.
- Persistence-layer impact: indexes already-loaded SwiftData query results.
- Lifecycle duration: one bulk operation.
- Why acceptable: avoids repeated scans when users select many ToDos, while avoiding long-lived cache invalidation.

### Why This Matters

The ToDo list is the main iOS/iPadOS surface. SwiftUI can recompute list sections often, and bulk operations should scale with selected item count without repeatedly scanning the whole list.

## 6. Startup Tag Normalization

File: `App/ToDoApp.swift`

Category: Algorithmic improvement  
Impact level: Medium  
Platforms: iOS, iPadOS

### What Changed

- Built `toDosByTagID` and `nanoDosByTagID` dictionaries before stored tag normalization.
- Invalid and duplicate tags now update only records that reference the current tag.

### Complexity

- Before: duplicate/invalid tag cleanup could scan all ToDos and NanoDos for each tag, `O(t * (d * a + n))`.
- After: one indexing pass plus direct lookup, `O(d * a + n + t + r)`, where `r` is total affected records.

### Structure Selection Rationale

`Dictionary` was chosen because normalization repeatedly needs records grouped by tag ID. A persistent cache was rejected because this migration-style pass runs at startup and the index is immediately discarded.

### Tradeoffs

- Additional memory/allocation cost: temporary dictionaries proportional to tag relationships.
- Persistence-layer impact: front-loads relationship traversal once instead of repeatedly faulting relationships per tag.
- Lifecycle duration: one startup normalization pass.
- Why acceptable: startup migrations should be predictable and bounded as user data grows.

### Why This Matters

Startup normalization affects launch performance. Reducing repeated scans lowers the risk of launch-time stalls on larger datasets.

## 7. Supabase Remote Duplicate and Apply Passes

File: `Core/Infrastructure/Supabase/SupabaseSyncService.swift`

Category: Algorithmic improvement  
Impact level: Critical for sync growth  
Platforms: iOS, iPadOS

### What Changed

- Added `remoteToDoChildCounts(in:)` to precompute child counts by remote ToDo UUID.
- Duplicate canonical selection now reads child counts from `[UUID: Int]`.
- Remote apply now builds `activeToDoRecordsByID` before updating tag relationships and sync timestamps.

### Complexity

- Duplicate canonical selection before: `O(c log c * (r + l))` per duplicate group.
- Duplicate canonical selection after: `O(r + l)` once, then `O(c log c)` per duplicate group.
- Apply timestamp lookup before: `O(m * r)` for repeated record searches.
- Apply timestamp lookup after: `O(r + m)`.

Where:
- `c` = duplicate group size
- `r` = remote ToDo count
- `l` = remote ToDo-tag link count
- `m` = synced ToDo count being updated

### Structure Selection Rationale

`Dictionary` was chosen because sync reconciliation repeatedly queries by stable UUID. Arrays were rejected in comparator and apply paths because they amplify scan cost with remote dataset size.

### Tradeoffs

- Additional memory/allocation cost: short-lived dictionaries proportional to remote snapshot size.
- Persistence-layer impact: no extra database fetches; indexes in-memory remote snapshots.
- Lifecycle duration: one sync pass.
- Why acceptable: faster sync reduces conflict windows, battery cost, and background execution pressure.

### Why This Matters

Sync systems must scale with remote record count. Removing comparator-amplified scans prevents pathological reconciliation time as data grows.

## 8. Reviewed and Left Unchanged

These usages were reviewed and intentionally left as-is because they do not violate the audit rules:

- `Services/Notifications/NotificationManager.swift`: notification action lookup is a single identifier search per notification action. It is not inside a repeated loop or comparator.
- `Services/Watch/WatchConnectivityService.swift`: Watch action ToDo lookup is a single action lookup and does not justify a persistent index.
- `ToDo Watch App/WatchActionQueueStore.swift`: queue duplicate checks operate on a small persisted pending-action list. `remove(_:)` already receives a `Set<UUID>` and uses constant-time membership.
- `Core/Sync/SyncTombstoneStore.swift`: conflict resolution performs a single lookup during an explicit resolution action.
- Sorting by date/name in archive, settings, account, tag, and list views remains appropriate because sorting is the required operation and comparators do not perform unbounded nested scans.
- Small enum or fixed-size collection searches, such as `allCases.first(where:)`, remain appropriate because their bounds are tiny and stable.

## Validation

Validated with:

- Xcode live diagnostics for touched Swift files.
- Full Xcode project build.
- Static project-wide scan for remaining repeated membership, lookup, and sort-comparator patterns.

## Evidence Collected on 2026-05-14

### Build and Compiler Evidence

Device:
- Not a physical-device performance run.

Build:
- Xcode project build through `BuildProject`.
- Result: succeeded.
- Build log: `/var/folders/2s/mbs54f255pn1dnlg_7svvh8h0000gn/T/ActionArtifacts/DB9342C6-B402-4362-BB74-C8CD9CEBCA11/BuildProject/BuildProject-Log-20260514-121827.txt`

Diagnostics:
- `ToDo/App/ToDoApp.swift`: no issues found.
- `ToDo/Core/Infrastructure/Supabase/SupabaseSyncService.swift`: no issues found.
- `ToDo/Features/Settings/Views/SettingsView.swift`: no issues found.
- `ToDo/Features/Tags/Views/TagManagementView.swift`: no issues found.
- `ToDo/Features/ToDos/Views/ToDoView.swift`: no issues found.
- `ToDo/Features/ToDos/Views/ToDosView.swift`: no issues found.
- `ToDo/ToDo Watch App/ContentView.swift`: no issues found.
- `ToDo/ToDo Watch App/WatchSupabaseAuthClient.swift`: no issues found.

### Static Scan Evidence

Commands run:

```sh
grep -R -n "<<<<<<<\|=======\|>>>>>>>" App Core Features Services 'ToDo Watch App' Docs --include='*.swift' --include='*.md'
grep -R -n "contains(where:\|first(where:\|\.sorted" App Core Features Services 'ToDo Watch App' --include='*.swift'
grep -n "Validation\|Evidence\|Impact level\|Tradeoffs\|Structure Selection" Docs/DataStructuresAndAlgorithmsAudit.md
```

Observed:
- No merge-conflict markers were found.
- Remaining `sorted`, `first(where:)`, and `contains(where:)` hits were reviewed as one of:
  - required direct sorting;
  - single-action lookup;
  - tiny fixed-size collection lookup;
  - search/tag relationship predicates where a per-item scan is the actual query being performed;
  - already-indexed or already-bounded paths documented above.
- The audit document contains production-audit sections for impact level, structure selection, tradeoffs, and validation.

### Runtime Evidence

Measured using:
- No Instruments runtime profile was collected in this pass.

Observed:
- No before/after CPU percentages are claimed.
- Algorithmic evidence is source-level and complexity-based only.
- Runtime validation still requires Time Profiler runs against large seeded datasets.

Recommended next measurement:
- Time Profiler on `groupedVisibleToDos(in:)`, `TagManagementView.sortedTags`, startup tag normalization, and Supabase duplicate cleanup.
- Dataset targets: 500-5,000 ToDos, 2,000-20,000 NanoDos, 50-500 Tags, and 1,000-10,000 sync records.

### SwiftUI Render Evidence

Measured using:
- No SwiftUI Instruments or Animation Hitches session was collected in this pass.

Observed:
- Render-path changes compile and are statically aligned with the audit rules.
- No visual smoothness claim is made without a device/simulator trace.

Recommended next measurement:
- SwiftUI and Animation Hitches instruments while searching, changing tag sort modes, scrolling large lists, bulk-selecting ToDos, and refreshing the watch app.

### Allocation Evidence

Measured using:
- No Allocations instrument session was collected in this pass.

Observed:
- The introduced `Set` and `Dictionary` indexes are short-lived and scoped to one computed property, action, startup pass, or sync pass.
- No persistent caches or retained indexes were introduced.

Recommended next measurement:
- Allocations instrument during tag-management sorting, settings unused-tag count/delete, ToDo bulk actions, and Supabase sync apply.

### SwiftData and Persistence-Layer Evidence

Measured using:
- Source-level validation only.

Observed:
- Startup tag normalization now front-loads relationship traversal into `toDosByTagID` and `nanoDosByTagID`.
- Settings unused-tag detection front-loads relationship traversal into a `Set<PersistentIdentifier>`.
- Tag-management usage counts front-load relationship traversal into dictionaries.
- These changes reduce repeated relationship traversal by design, but fault-count reduction has not been measured with Instruments.

Recommended next measurement:
- Use Time Profiler and Allocations with a large persisted SwiftData store.
- Compare relationship faulting/allocation behavior before and after these indexing passes.

### Launch Evidence

Measured using:
- No cold-launch or warm-launch trace was collected in this pass.

Observed:
- Startup normalization complexity is now bounded by one relationship-indexing pass plus direct lookup updates.
- No launch-time improvement claim is made without launch profiling.

Recommended next measurement:
- Release build cold launch and warm launch with a large persisted dataset and startup normalization version forced to run.

### Sync Evidence

Measured using:
- No large remote sync benchmark was collected in this pass.

Observed:
- Duplicate canonical selection no longer scans child collections inside the comparator.
- Remote apply no longer searches active ToDo records for each synced ToDo timestamp update.
- No sync-duration improvement is claimed without a seeded remote snapshot measurement.

Recommended next measurement:
- Run sync with duplicate-heavy remote snapshots and record duplicate cleanup/apply durations before and after.

### watchOS Evidence

Measured using:
- No watchOS physical-device profiling was collected in this pass.

Observed:
- Watch list partitioning no longer recomputes and linearly searches `nowItems` while building `laterItems`.
- Watch direct-sync token refresh changes compile and build.
- No battery, thermal, or scrolling claim is made without a watchOS device trace.

Recommended next measurement:
- Profile the Watch app on physical Apple Watch using Time Profiler and scrolling/refresh scenarios.

Measurement still recommended before making stronger runtime claims:

- Instruments Time Profiler for large ToDo/tag datasets.
- Instruments Allocations to quantify temporary dictionary/set costs.
- SwiftUI template and Animation Hitches for list and tag-management render paths.
- Sync timing logs for large remote snapshots.

## Summary

Fixed:

- Repeated Watch list partition scans.
- Settings unused-tag repeated scans.
- Tag-management usage count scans in sort/render paths.
- ToDo editor selected-tag lookup scans.
- ToDo list search normalization, selected-tag sorting, and bulk-action lookup scans.
- Startup tag normalization repeated relationship scans.
- Supabase sync duplicate and apply-pass repeated remote snapshot scans.

Not changed:

- Single-action lookups where an index would add allocation without meaningful benefit.
- Required sorts whose comparators are already bounded and direct.
- Tiny fixed-size enum/option searches.

The project now follows the attached audit standard for the reviewed iOS, iPadOS, and watchOS paths: use keyed indexes for repeated lookup/count workloads, avoid nested scans in render and sync paths, and document both Big-O impact and production tradeoffs.
