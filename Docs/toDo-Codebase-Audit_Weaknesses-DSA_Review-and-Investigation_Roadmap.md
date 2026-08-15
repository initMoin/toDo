# toDō Codebase Audit: Weaknesses, DSA Review, and Investigation Roadmap

## Purpose

This document summarizes architectural weaknesses, Data Structures & Algorithms observations, and recommended investigation areas identified during an initial review of the toDō codebase.

The goal is not to perform major rewrites. The goal is to improve maintainability, scalability, performance, and long-term reliability while preserving the current architecture and product direction.

---

# Architectural Weaknesses

## 1. ToDo Model Becoming a God Object

### Current Observation

The `ToDo` model currently owns responsibility for:

- Core task data
- Notes
- Due dates
- Reminder configuration
- Recurrence configuration
- Location reminder data
- Sync metadata
- Calendar integration metadata
- Lifecycle state
- Additional behavioral information

While each responsibility individually makes sense, collectively they are creating a model that is gradually accumulating unrelated concerns.

### Risks

- Increased maintenance burden
- More difficult testing
- Higher likelihood of merge conflicts
- Increased cognitive load when modifying functionality
- Greater risk of unintended side effects

### Investigation Tasks

Review the `ToDo` model and identify responsibilities that are conceptually independent.

Evaluate whether the following should eventually become dedicated value types or embedded models:

- RecurrenceRule
- LocationReminder
- SyncMetadata
- CalendarMetadata

Do not perform extraction immediately.

First document:
- Current responsibilities
- Responsibility ownership
- Dependencies

Produce a recommendation report before implementing structural changes.

---

## 2. Recurrence System Complexity

### Current Observation

The application supports recurrence intervals ranging from:

- Seconds
- Minutes
- Hours
- Days
- Weeks
- Months
- Years

This provides flexibility but significantly increases edge-case complexity.

### Risks

Potential issues include:

- Daylight Saving Time transitions
- Time zone changes
- Leap years
- Monthly date rollover behavior
- End-of-month handling
- Overdue recurring tasks
- Finite recurrence expiration
- Completion-driven recurrence logic

### Investigation Tasks

Perform a complete recurrence audit.

Document behavior for:

#### Time-Based Edge Cases

- DST forward transitions
- DST backward transitions
- Device time zone changes
- Locale changes

#### Calendar Edge Cases

- February handling
- Leap years
- Months with fewer days
- Year boundaries

#### Task Lifecycle Edge Cases

- Completing overdue recurring tasks
- Completing future recurring tasks
- Deleting recurring tasks
- Archiving recurring tasks

Create automated tests covering every identified edge case.

---

## 3. Increasing Singleton Usage

### Current Observation

The codebase contains singleton-style services such as:

```swift
SyncCoordinator.shared
MigrationService.shared
```

Additional singleton usage should be identified and cataloged.

### Risks

- Hidden dependencies
- Reduced testability
- Increased coupling
- Harder future refactoring

### Investigation Tasks

Produce a complete list of all singleton implementations.

For each singleton:

- Document purpose
- Document dependencies
- Document consumers

Determine whether each singleton should remain:

- Global singleton
- Injected dependency
- Environment object
- Service container dependency

No replacements should occur until a dependency map is completed.

---

## 4. SyncCoordinator Responsibility Growth

### Current Observation

SyncCoordinator currently appears responsible for:

- Sync mode management
- Backend activation
- Migration orchestration
- Sync state management
- Feedback state
- Persistence coordination

### Risks

The coordinator may become a central bottleneck that owns too many unrelated concerns.

### Investigation Tasks

Generate a responsibility map.

Identify:

- State ownership
- Service ownership
- Backend ownership
- UI ownership

Document:

- Which responsibilities are coordination-related
- Which responsibilities are business logic
- Which responsibilities should potentially move elsewhere

No refactoring should occur until ownership boundaries are documented.

---

## 5. CloudKit Backend Maturity

### Current Observation

The CloudKit implementation currently appears incomplete.

Some backend methods currently function as placeholders or coordination stubs.

### Risks

Cloud synchronization remains the highest-risk subsystem in the application.

Potential future problems:

- Duplicate records
- Conflict resolution failures
- Data loss
- Relationship corruption
- Sync loops
- Offline reconciliation issues

### Investigation Tasks

Perform a complete CloudKit audit.

Document:

- Current implementation status
- Implemented functionality
- Missing functionality
- Assumptions made by SyncCoordinator

Create a roadmap for:

1. Upload
2. Download
3. Conflict resolution
4. Recovery
5. Offline synchronization

---

# Data Structures & Algorithms Review

## Positive Findings

### Set Usage

Observed pattern:

```swift
let uniqueToDoIDs = Set(...)
```

This avoids duplicate counting and demonstrates awareness of uniqueness requirements.

### Recommendation

Continue favoring:

- Set
- Dictionary

for uniqueness and lookup operations.

---

## Potential Scaling Concern

### Tag Relationships

Current relationships use arrays:

```swift
[ToDo]
[NanoDo]
```

This is appropriate for SwiftData and should remain unchanged unless profiling demonstrates a problem.

### Risks at Scale

Potential future hotspots:

```swift
filter
contains
map
sort
flatMap
```

performed repeatedly across large collections.

### Investigation Tasks

Profile:

- Tag filtering
- Tag counting
- Tag statistics generation

Measure complexity using realistic datasets:

- 100 tasks
- 1,000 tasks
- 5,000 tasks

Document results before optimizing.

---

## Statistics Engine Review

### Concern

The application computes:

- Focus Pressure
- Momentum
- Planning Accuracy
- Streaks
- Insight Generation

If calculations repeatedly scan the entire dataset, performance may degrade as data grows.

### Investigation Tasks

Review every statistics calculation.

Document:

- Complexity
- Data dependencies
- Recalculation frequency

Identify:

- O(n²) behavior
- Repeated filtering
- Repeated sorting
- Repeated date calculations

Recommend caching or incremental updates only where profiling justifies it.

---

# Industry Practice Review

## Positive Findings

### Strong Domain Modeling

The codebase uses explicit domain concepts such as:

- ToDoState
- ToDoReminderIntent
- ToDoRecurrenceUnit
- ToDoRecurrenceMode

This is preferred over generic strings and magic values.

Maintain this approach.

---

### Clear Naming

Current naming is generally:

- Descriptive
- Consistent
- Domain-driven

Avoid unnecessary renaming.

Continue prioritizing clarity over cleverness.

---

### Feature-Oriented Organization

Current structure follows a feature-oriented approach.

This improves:

- Discoverability
- Scalability
- Team onboarding

Maintain this organization style.

---

# Required Investigation Areas

The following files and systems should be reviewed next.

## Priority 1

### Task Experience

- ToDosView.swift
- ToDoView.swift

Review:

- State ownership
- Filtering
- Sorting
- Rendering performance

---

### Statistics

- StatsView.swift
- Stats services

Review:

- Complexity
- Recalculation frequency
- Memory usage

---

### Notifications

- NotificationManager.swift
- Notification scheduling services

Review:

- Duplicate scheduling
- Cancellation behavior
- Recurrence interaction

---

### Navigation

- NavigationCoordinator.swift

Review:

- Navigation ownership
- Deep-link readiness
- State restoration readiness

---

### Sync Infrastructure

- SyncCoordinator.swift
- CloudKitSyncBackend.swift
- SupabaseSyncBackend.swift
- SupabaseSyncService.swift

Review:

- Dependency boundaries
- Conflict handling
- Failure recovery
- Offline behavior

---

# Deliverables Requested

Produce the following before implementing major architectural changes:

## Report 1

ToDo Responsibility Audit

Document all responsibilities currently owned by the ToDo model.

---

## Report 2

Singleton Dependency Audit

Document every singleton and its dependency graph.

---

## Report 3

Recurrence Edge Case Matrix

Document all supported recurrence behaviors and edge cases.

---

## Report 4

Sync Architecture Audit

Document current CloudKit and Supabase responsibilities and gaps.

---

## Report 5

Performance Audit

Profile:

- Task filtering
- Statistics generation
- Tag operations
- Large datasets

Provide measurements and optimization recommendations.

---

# Refactoring Rule

Do not perform major architectural rewrites based solely on assumptions.

For every proposed optimization:

1. Identify the problem.
2. Measure the problem.
3. Document the findings.
4. Propose the change.
5. Implement only if justified by evidence.

The objective is long-term maintainability and reliability, not architectural churn.