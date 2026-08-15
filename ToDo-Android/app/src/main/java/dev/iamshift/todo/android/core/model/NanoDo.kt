package dev.iamshift.todo.android.core.model

import java.time.Instant
import java.util.UUID

/** A child action belonging to one ToDo. The Supabase column is named `task`. */
data class NanoDo(
    val id: UUID = UUID.randomUUID(),
    val todoId: UUID,
    val ownerUserId: UUID? = null,
    val task: String,
    val isDone: Boolean = false,
    val tagId: UUID? = null,
    val dueAt: Instant? = null,
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = createdAt
) {
    init {
        require(task.isNotBlank()) { "NanoDo task must not be blank" }
    }

    val syncUpdatedAt: Instant
        get() = updatedAt

    fun transitionToDone(done: Boolean, at: Instant = Instant.now()): NanoDo =
        copy(isDone = done, updatedAt = at)

    fun withTask(value: String, at: Instant = Instant.now()): NanoDo {
        val normalized = value.trim()
        require(normalized.isNotEmpty()) { "NanoDo task must not be blank" }
        return copy(task = normalized, updatedAt = at)
    }

    fun withDueAt(value: Instant?, at: Instant = Instant.now()): NanoDo =
        copy(dueAt = value, updatedAt = at)

    fun withTagId(value: UUID?, at: Instant = Instant.now()): NanoDo =
        copy(tagId = value, updatedAt = at)
}
