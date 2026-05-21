# Evidence & Validation Instructions for Performance Audit Updates

These instructions define how future optimization passes should be validated and documented with measurable evidence.

The goal is to evolve the audit from:
- "well-reasoned optimization documentation"

into:
- "evidence-backed performance engineering documentation"

The focus is not merely proving theoretical complexity improvements, but validating:
- real runtime behavior
- SwiftUI responsiveness
- launch impact
- sync scalability
- allocation behavior
- persistence-layer impact
- platform-specific performance characteristics

---

# 1. General Validation Principles

## Rule 1 — Measure Before and After

Never document:
- runtime improvement
- hitch reduction
- responsiveness gains
- launch improvements

without:
- baseline measurement
- post-change measurement

Every optimization should eventually include:

```md
### Validation
```

with:
- before evidence
- after evidence
- test conditions
- dataset size
- platform/device used

---

## Rule 2 — Use Realistic Dataset Sizes

Avoid testing with:
- tiny datasets
- empty stores
- unrealistic simulator-only states

Testing should simulate realistic growth.

Recommended baseline sizes:

| Data Type | Suggested Large Test Dataset |
|---|---|
| ToDos | 500–5,000 |
| NanoDos | 2,000–20,000 |
| Tags | 50–500 |
| Remote Sync Records | 1,000–10,000 |

The purpose is to expose:
- comparator amplification
- repeated relationship traversal
- render-path bottlenecks
- launch-time scaling problems

---

## Rule 3 — Test Release Builds

Do NOT rely exclusively on:
- Debug builds
- SwiftUI previews

Validation should primarily use:
- Release configuration
- physical devices

Especially for:
- watchOS
- scrolling performance
- sync performance
- launch behavior

Debug builds distort:
- timing
- allocations
- rendering behavior

---

# 2. Validation Metadata Template

Each validated optimization section should eventually include:

```md
### Validation

Device:
- iPhone model:
- watchOS device:
- iOS/watchOS version:

Build:
- Release / Debug

Dataset:
- ToDo count:
- NanoDo count:
- Tag count:
- Sync record count:

Measured Using:
- Time Profiler
- Allocations
- SwiftUI
- Animation Hitches

Observed:
- Before:
- After:
- Notes:
```

---

# 3. Runtime Performance Evidence

## Goal

Validate:
- reduced CPU time
- reduced repeated scans
- reduced comparator overhead
- improved grouping/filtering performance

---

## What To Measure

### A. Function Hotspots

Track:
- expensive grouping functions
- sorting passes
- tag counting
- sync reconciliation
- startup normalization

---

## Evidence To Record

```md
### Runtime Evidence

Before:
- groupedVisibleToDos consumed ~38% CPU during repeated filter/sort updates.

After:
- groupedVisibleToDos reduced to ~9% CPU after lookup indexing and comparator cleanup.

Conditions:
- 2,500 ToDos
- 300 Tags
- search filtering enabled
```

---

## Important

Avoid fake precision.

Do NOT write:
```md
Improved by exactly 73.492%
```

unless actually measured.

Engineering documentation should be:
- conservative
- believable
- reproducible

---

# 4. SwiftUI Render-Path Evidence

## Goal

Validate:
- smoother scrolling
- fewer render spikes
- fewer recomposition stalls
- reduced hitching

---

## What To Test

### Recommended Scenarios

#### Tag Management
- scrolling large tag lists
- changing sort modes
- opening tag-management screen repeatedly

#### ToDo Lists
- searching rapidly
- collapsing/expanding sections
- bulk selection
- switching filters

#### Watch App
- scrolling "Now" and "Later"
- repeated view refreshes
- complication-triggered refresh behavior

---

## Evidence To Record

```md
### SwiftUI Render Evidence

Before:
- noticeable hitching during repeated tag sorting on large datasets.

After:
- scrolling and sort-mode switching remained visually stable under the same dataset.

Conditions:
- iPhone 15 Pro
- ~2,000 ToDos
- ~200 Tags
```

---

# 5. Allocation & Memory Evidence

## Goal

Validate:
- temporary dictionary/set costs
- allocation spikes
- memory stability
- cache behavior

---

## What To Measure

### Measure:
- allocation spikes during grouping/sorting
- temporary memory growth
- persistent cache retention
- repeated allocation churn

---

## Evidence To Record

```md
### Allocation Evidence

Before:
- repeated relationship traversal caused sustained allocation churn during tag rendering.

After:
- allocation spikes shifted to one short-lived dictionary creation per render pass.

Observed:
- no persistent memory growth
- no retained stale indexes
```

---

# 6. SwiftData / Persistence-Layer Evidence

## Goal

Validate:
- reduced relationship traversal
- reduced faulting
- reduced repeated fetch behavior

This is especially important for:
- SwiftData
- CoreData-backed relationships
- sync reconciliation paths

---

## What To Observe

### Signs of Improvement

- fewer repeated relationship accesses
- fewer lazy faults
- reduced repeated fetch traversal
- more stable startup normalization

---

## Evidence To Record

```md
### Persistence-Layer Evidence

Before:
- tag cleanup repeatedly traversed SwiftData relationships for every tag validation pass.

After:
- relationships traversed once up front and indexed in-memory.

Observed:
- fewer repeated relationship evaluations during startup normalization.
```

---

# 7. Launch Performance Evidence

## Goal

Validate:
- reduced launch stalls
- bounded startup normalization
- reduced startup traversal costs

---

## What To Test

### Test Cases

- cold launch
- warm launch
- large persisted dataset
- post-sync launch
- migration/startup normalization scenarios

---

## Evidence To Record

```md
### Launch Evidence

Before:
- startup normalization scaled poorly with large tag datasets due to repeated traversal.

After:
- startup normalization performs one indexing pass followed by direct lookup updates.

Observed:
- launch remained responsive under large persisted datasets.
```

---

# 8. Sync-System Evidence

## Goal

Validate:
- reconciliation scalability
- reduced duplicate-resolution cost
- stable remote apply performance

---

## What To Test

### Test Cases

- large remote snapshots
- duplicate-heavy datasets
- repeated sync passes
- background sync execution

---

## Evidence To Record

```md
### Sync Evidence

Before:
- duplicate reconciliation repeatedly scanned remote child collections during comparator evaluation.

After:
- child counts precomputed once before reconciliation sorting.

Observed:
- sync duration remained stable as remote dataset size increased.
```

---

# 9. watchOS-Specific Validation

## Goal

Validate:
- reduced thermal pressure
- stable scrolling
- reduced repeated computation
- battery-conscious render behavior

watchOS optimization should prioritize:
- predictability
- low repeated work
- minimal recomputation

---

## What To Observe

### Indicators

- smoother scrolling
- fewer refresh pauses
- stable UI updates
- fewer visible render stalls

---

## Evidence To Record

```md
### watchOS Evidence

Before:
- repeated partition scans occurred during computed-property reevaluation.

After:
- list partitioning uses a shared predicate without repeated membership scans.

Observed:
- smoother scrolling and reduced refresh jitter during repeated updates.
```

---

# 10. Long-Term Validation Standard

Eventually, every major optimization should answer:

```md
What changed?
Why was it changed?
How was it validated?
What evidence supports the claim?
What tradeoffs were introduced?
```

The purpose of evidence is NOT:
- proving cleverness
- exaggerating improvements
- marketing the optimization

The purpose IS:
- engineering accountability
- reproducibility
- measurable runtime understanding
- platform-aware optimization discipline

That is what separates:
- theoretical optimization knowledge

from:
- professional performance engineering practice.