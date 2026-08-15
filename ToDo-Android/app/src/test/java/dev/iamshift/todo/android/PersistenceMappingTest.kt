package dev.iamshift.todo.android

import dev.iamshift.todo.android.core.model.NanoDo
import dev.iamshift.todo.android.core.model.ToDo
import dev.iamshift.todo.android.core.model.ToDoLocationReminder
import dev.iamshift.todo.android.core.model.ToDoLocationReminderTrigger
import dev.iamshift.todo.android.core.model.ToDoRecurrence
import dev.iamshift.todo.android.core.model.ToDoRecurrenceMode
import dev.iamshift.todo.android.core.model.ToDoRecurrenceUnit
import dev.iamshift.todo.android.core.persistence.SyncOutboxEntity
import dev.iamshift.todo.android.core.persistence.toDomain
import dev.iamshift.todo.android.core.persistence.toEntity
import dev.iamshift.todo.android.core.sync.SyncMutation
import dev.iamshift.todo.android.core.sync.SyncOperation
import dev.iamshift.todo.android.core.sync.SyncRecordKey
import dev.iamshift.todo.android.core.sync.SyncRecordTable
import dev.iamshift.todo.android.core.sync.SyncScope
import java.time.Instant
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Test

class PersistenceMappingTest {
    private val baseline = Instant.parse("2026-08-08T12:00:00Z")

    @Test
    fun todoEntityRoundTripPreservesDomainSemantics() {
        val tagId = UUID.fromString("00000000-0000-0000-0000-000000000020")
        val toDo = ToDo.create(
            task = "Prepare release",
            notes = "Android parity",
            dueAt = baseline.plusSeconds(3_600),
            dueTimeZone = "America/Chicago",
            recurrence = ToDoRecurrence(
                unit = ToDoRecurrenceUnit.WEEKS,
                interval = 1,
                mode = ToDoRecurrenceMode.CONTINUOUS,
                anchorAt = baseline
            ),
            at = baseline
        ).copy(
            tagIds = listOf(tagId),
            locationReminder = ToDoLocationReminder(
                latitude = 41.8781,
                longitude = -87.6298,
                radiusMeters = 250.0,
                trigger = ToDoLocationReminderTrigger.LEAVING,
                label = "Office"
            )
        )
        val nanoDo = NanoDo(
            todoId = toDo.id,
            task = "Run the test suite",
            dueAt = baseline.plusSeconds(1_800),
            createdAt = baseline,
            updatedAt = baseline
        )

        val restored = toDo.toEntity().toDomain(
            nanoDos = listOf(nanoDo.toEntity().toDomain()),
            tagIds = listOf(tagId)
        )

        assertEquals(toDo.id, restored.id)
        assertEquals(toDo.task, restored.task)
        assertEquals(toDo.dueAt, restored.dueAt)
        assertEquals(toDo.recurrence, restored.recurrence)
        assertEquals(toDo.locationReminder, restored.locationReminder)
        assertEquals(listOf(tagId), restored.tagIds)
        assertEquals(listOf(nanoDo), restored.nanoDos)
    }

    @Test
    fun outboxDeduplicationKeyIncludesScopeAndCompositeRecordIdentity() {
        val scope = SyncScope(userId = UUID.randomUUID(), collabId = UUID.randomUUID())
        val todoId = UUID.randomUUID()
        val tagId = UUID.randomUUID()
        val changedAt = baseline

        fun mutation(relatedRecordId: UUID?) = SyncMutation(
            recordKey = SyncRecordKey(
                table = SyncRecordTable.TODO_TAGS,
                recordId = todoId,
                relatedRecordId = relatedRecordId
            ),
            scope = scope,
            operation = SyncOperation.UPSERT,
            changedAt = changedAt,
            originDeviceId = UUID.randomUUID()
        )

        val tagMutation = SyncOutboxEntity.fromMutation(mutation(tagId))
        val otherTagMutation = SyncOutboxEntity.fromMutation(mutation(UUID.randomUUID()))

        assertEquals(tagMutation.deduplicationKey, SyncOutboxEntity.fromMutation(mutation(tagId)).deduplicationKey)
        assertEquals(false, tagMutation.deduplicationKey == otherTagMutation.deduplicationKey)
    }
}
