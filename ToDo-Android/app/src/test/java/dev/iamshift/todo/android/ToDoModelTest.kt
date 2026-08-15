package dev.iamshift.todo.android

import dev.iamshift.todo.android.core.model.NanoDo
import dev.iamshift.todo.android.core.model.Tag
import dev.iamshift.todo.android.core.model.ToDo
import dev.iamshift.todo.android.core.model.ToDoRecurrence
import dev.iamshift.todo.android.core.model.ToDoRecurrenceMode
import dev.iamshift.todo.android.core.model.ToDoRecurrenceUnit
import dev.iamshift.todo.android.core.model.ToDoState
import java.time.Instant
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ToDoModelTest {
    private val baseline = Instant.parse("2026-08-08T12:00:00Z")

    @Test
    fun transitionToDoneAndBackMaintainsCompletionActivitySemantics() {
        val toDo = ToDo.create(task = "Ship Android parity", at = baseline)

        val completed = toDo.transition(ToDoState.DONE, baseline.plusSeconds(60))
        assertTrue(completed.isDone)
        assertEquals(baseline.plusSeconds(60), completed.completedAt)
        assertEquals(completed.completedAt, completed.completionActivityDate)

        val reopened = completed.transition(ToDoState.ACTIVE, baseline.plusSeconds(120))
        assertFalse(reopened.isDone)
        assertNull(reopened.completedAt)
        assertNull(reopened.completionActivityDate)
    }

    @Test
    fun parentCompletesWhenEveryNanoDoIsDone() {
        val toDo = ToDo.create(
            task = "Prepare release",
            completeWhenAllNanoDosDone = true,
            at = baseline
        )
        val children = listOf(
            NanoDo(todoId = toDo.id, task = "Run tests", isDone = true, createdAt = baseline),
            NanoDo(todoId = toDo.id, task = "Upload build", isDone = true, createdAt = baseline)
        )

        val completed = toDo.copy(nanoDos = children).completeIfAllNanoDosAreDone(baseline.plusSeconds(60))
        assertEquals(ToDoState.DONE, completed.lifecycleState)
    }

    @Test
    fun dueSoonAndRecurringUseTheSharedDomainRules() {
        val recurring = ToDo.create(
            task = "Review metrics",
            dueAt = baseline.plusSeconds(60 * 60),
            recurrence = ToDoRecurrence(
                unit = ToDoRecurrenceUnit.WEEKS,
                interval = 1,
                mode = ToDoRecurrenceMode.CONTINUOUS
            ),
            at = baseline
        )
        val outsideHorizon = ToDo.create(
            task = "Plan next quarter",
            dueAt = baseline.plusSeconds(60 * 60 * 24 * 4),
            at = baseline
        )

        assertTrue(recurring.isRecurring)
        assertEquals(listOf(recurring), ToDo.dueSoon(listOf(recurring, outsideHorizon), baseline))
    }

    @Test
    fun canonicalKeepsNewestRecordForEachStableIdInFirstSeenOrder() {
        val stableId = UUID.fromString("00000000-0000-0000-0000-000000000010")
        val first = ToDo.create(task = "Older local copy", at = baseline, id = stableId)
        val other = ToDo.create(task = "Other task", at = baseline.plusSeconds(30))
        val newer = first.withTask("Newer remote copy", baseline.plusSeconds(60))

        val canonical = ToDo.canonical(listOf(first, other, newer))

        assertEquals(listOf(stableId, other.id), canonical.map { it.id })
        assertEquals("Newer remote copy", canonical.first().task)
    }

    @Test
    fun tagsNormalizeAndCanonicalizeByLatestUpdate() {
        val older = Tag.create(
            name = " Work ",
            id = java.util.UUID.fromString("00000000-0000-0000-0000-000000000001"),
            createdAt = baseline,
            updatedAt = baseline
        )
        val newer = Tag.create(
            name = "work",
            id = java.util.UUID.fromString("00000000-0000-0000-0000-000000000002"),
            createdAt = baseline,
            updatedAt = baseline.plusSeconds(60)
        )

        val canonical = Tag.canonicalTags(listOf(older, newer))
        assertEquals(1, canonical.size)
        assertEquals(newer.id, canonical.single().id)
        assertEquals("work", canonical.single().name)
    }
}
