package dev.iamshift.todo.android.core.model

import java.time.Duration
import java.time.Instant
import java.util.UUID

data class ToDoRecurrence(
    val unit: ToDoRecurrenceUnit,
    val interval: Int,
    val mode: ToDoRecurrenceMode,
    val count: Int? = null,
    val anchorAt: Instant? = null,
    val endAt: Instant? = null
) {
    init {
        require(interval > 0) { "Recurrence interval must be greater than zero" }
        if (mode == ToDoRecurrenceMode.FINITE) {
            require(count != null && count >= 1) {
                "Finite recurrence requires a count of at least one"
            }
        }
        if (anchorAt != null && endAt != null) {
            require(!endAt.isBefore(anchorAt)) { "Recurrence end cannot precede its anchor" }
        }
    }
}

data class ToDoLocationReminder(
    val latitude: Double,
    val longitude: Double,
    val radiusMeters: Double = 150.0,
    val trigger: ToDoLocationReminderTrigger = ToDoLocationReminderTrigger.ARRIVING,
    val label: String? = null
) {
    init {
        require(latitude in -90.0..90.0) { "Latitude must be between -90 and 90" }
        require(longitude in -180.0..180.0) { "Longitude must be between -180 and 180" }
        require(radiusMeters > 0.0) { "Location reminder radius must be positive" }
    }

    /** Matches the Apple app's supported location-radius range. */
    val resolvedRadiusMeters: Double
        get() = radiusMeters.coerceIn(100.0, 1_000.0)
}

data class ToDo(
    /** Stable logical identity used as the Supabase row ID and Firebase document ID. */
    val id: UUID = UUID.randomUUID(),
    val ownerUserId: UUID? = null,
    val collabId: UUID? = null,
    val task: String,
    val notes: String = "",
    val lifecycleState: ToDoState = ToDoState.ACTIVE,
    val dueAt: Instant? = null,
    val dueTimeZone: String? = null,
    val reminderIntent: ToDoReminderIntent = ToDoReminderIntent.SOFT,
    val recurrence: ToDoRecurrence? = null,
    val completeWhenAllNanoDosDone: Boolean = false,
    val sortPosition: Double? = null,
    val trashedAt: Instant? = null,
    val locationReminder: ToDoLocationReminder? = null,
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = createdAt,
    val completedAt: Instant? = null,
    val tagIds: List<UUID> = emptyList(),
    val nanoDos: List<NanoDo> = emptyList()
) {
    init {
        require(task.isNotBlank()) { "ToDo task must not be blank" }
        require(tagIds.distinct().size == tagIds.size) { "ToDo tag IDs must be unique" }
        require(tagIds.size <= MAX_TAG_SELECTION) {
            "A ToDo may have at most $MAX_TAG_SELECTION tags"
        }
        require(nanoDos.all { it.todoId == id }) {
            "Every NanoDo must reference its parent ToDo"
        }
    }

    /** Supabase retains this legacy field; derive it to prevent state drift locally. */
    val isDone: Boolean
        get() = lifecycleState == ToDoState.DONE

    val isActive: Boolean
        get() = lifecycleState == ToDoState.ACTIVE

    val isArchived: Boolean
        get() = lifecycleState == ToDoState.ARCHIVED

    val isTrashed: Boolean
        get() = lifecycleState == ToDoState.TRASHED

    val syncUpdatedAt: Instant
        get() = updatedAt

    val completionActivityDate: Instant?
        get() = if (isDone) completedAt ?: syncUpdatedAt else null

    val isRecurring: Boolean
        get() = dueAt != null && recurrence != null

    val orderedNanoDos: List<NanoDo>
        get() = nanoDos.sortedWith(
            compareBy<NanoDo> { it.createdAt }.thenBy { it.id.toString() }
        )

    fun isLate(now: Instant = Instant.now()): Boolean =
        isActive && dueAt?.isBefore(now) == true

    fun transition(to: ToDoState, at: Instant = Instant.now()): ToDo {
        val nextCompletedAt = when {
            to == ToDoState.DONE && lifecycleState != ToDoState.DONE -> at
            to == ToDoState.DONE -> completedAt ?: at
            else -> null
        }
        val nextTrashedAt = when {
            to == ToDoState.TRASHED && lifecycleState != ToDoState.TRASHED -> at
            to == ToDoState.TRASHED -> trashedAt ?: at
            else -> null
        }

        return copy(
            lifecycleState = to,
            completedAt = nextCompletedAt,
            trashedAt = nextTrashedAt,
            updatedAt = at
        )
    }

    fun toggleDone(at: Instant = Instant.now()): ToDo = when (lifecycleState) {
        ToDoState.ACTIVE -> transition(ToDoState.DONE, at)
        ToDoState.DONE -> transition(ToDoState.ACTIVE, at)
        ToDoState.ARCHIVED, ToDoState.TRASHED -> this
    }

    fun completeIfAllNanoDosAreDone(at: Instant = Instant.now()): ToDo {
        if (!completeWhenAllNanoDosDone || nanoDos.isEmpty() || !nanoDos.all { it.isDone }) {
            return this
        }
        return transition(ToDoState.DONE, at)
    }

    fun withTask(value: String, at: Instant = Instant.now()): ToDo {
        val normalized = value.trim()
        require(normalized.isNotEmpty()) { "ToDo task must not be blank" }
        return copy(task = normalized, updatedAt = at)
    }

    fun withNotes(value: String, at: Instant = Instant.now()): ToDo =
        copy(notes = value, updatedAt = at)

    fun withSchedule(
        dueAt: Instant?,
        dueTimeZone: String?,
        reminderIntent: ToDoReminderIntent,
        at: Instant = Instant.now()
    ): ToDo = copy(
        dueAt = dueAt,
        dueTimeZone = dueTimeZone,
        reminderIntent = reminderIntent,
        updatedAt = at
    )

    fun withTagIds(ids: Iterable<UUID>, at: Instant = Instant.now()): ToDo =
        copy(tagIds = ids.distinct().take(MAX_TAG_SELECTION), updatedAt = at)

    fun withNanoDos(items: Iterable<NanoDo>, at: Instant = Instant.now()): ToDo =
        copy(nanoDos = items.toList(), updatedAt = at)

    companion object {
        const val MAX_TAG_SELECTION = 5

        fun create(
            task: String,
            notes: String = "",
            ownerUserId: UUID? = null,
            collabId: UUID? = null,
            dueAt: Instant? = null,
            dueTimeZone: String? = null,
            reminderIntent: ToDoReminderIntent = if (dueAt == null) {
                ToDoReminderIntent.SOFT
            } else {
                ToDoReminderIntent.DUE
            },
            recurrence: ToDoRecurrence? = null,
            completeWhenAllNanoDosDone: Boolean = false,
            at: Instant = Instant.now(),
            id: UUID = UUID.randomUUID()
        ): ToDo = ToDo(
            id = id,
            ownerUserId = ownerUserId,
            collabId = collabId,
            task = task.trim().also {
                require(it.isNotEmpty()) { "ToDo task must not be blank" }
            },
            notes = notes,
            dueAt = dueAt,
            dueTimeZone = dueTimeZone,
            reminderIntent = reminderIntent,
            recurrence = recurrence,
            completeWhenAllNanoDosDone = completeWhenAllNanoDosDone,
            createdAt = at,
            updatedAt = at
        )

        fun active(from: Iterable<ToDo>): List<ToDo> =
            from.filter { it.lifecycleState == ToDoState.ACTIVE }

        fun dueSoon(
            from: Iterable<ToDo>,
            now: Instant = Instant.now(),
            horizon: Duration = Duration.ofDays(3)
        ): List<ToDo> {
            val upperBound = now.plus(horizon)
            return active(from)
                .filter { todo ->
                    val dueAt = todo.dueAt ?: return@filter false
                    !dueAt.isBefore(now) && !dueAt.isAfter(upperBound)
                }
                .sortedWith(presentationDueDateComparator(now))
        }

        fun timeSensitive(from: Iterable<ToDo>, now: Instant = Instant.now()): List<ToDo> =
            active(from)
                .filter { it.reminderIntent == ToDoReminderIntent.TIME_SENSITIVE }
                .sortedWith(presentationDueDateComparator(now))

        fun presentationDueDateComparator(now: Instant = Instant.now()): Comparator<ToDo> =
            Comparator { left, right ->
                val leftDue = left.dueAt ?: Instant.MAX
                val rightDue = right.dueAt ?: Instant.MAX
                val dueComparison = leftDue.compareTo(rightDue)
                if (dueComparison != 0) {
                    return@Comparator dueComparison
                }

                val lateComparison = compareValues(right.isLate(now), left.isLate(now))
                if (lateComparison != 0) {
                    return@Comparator lateComparison
                }

                val createdComparison = right.createdAt.compareTo(left.createdAt)
                if (createdComparison != 0) {
                    return@Comparator createdComparison
                }
                left.id.toString().compareTo(right.id.toString())
            }

        /** Deduplicates records by stable ID while preserving first-seen ordering. */
        fun canonical(from: Iterable<ToDo>): List<ToDo> {
            val preferredById = linkedMapOf<UUID, ToDo>()
            for (candidate in from) {
                val existing = preferredById[candidate.id]
                if (existing == null || candidate.updatedAt.isAfter(existing.updatedAt)) {
                    preferredById[candidate.id] = candidate
                }
            }
            return preferredById.values.toList()
        }
    }
}
