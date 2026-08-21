package dev.iamshift.todo.android

import dev.iamshift.todo.android.core.model.ToDo
import dev.iamshift.todo.android.core.model.ToDoRecurrence
import dev.iamshift.todo.android.core.model.ToDoRecurrenceMode
import dev.iamshift.todo.android.core.model.ToDoRecurrenceUnit
import dev.iamshift.todo.android.core.sync.SyncScope
import dev.iamshift.todo.android.core.sync.payload.FirebasePayloadMapper
import dev.iamshift.todo.android.core.sync.payload.SyncPayloadCodec
import dev.iamshift.todo.android.core.sync.payload.SyncToDoPayload
import dev.iamshift.todo.android.core.sync.payload.SupabasePayloadMapper
import java.time.Instant
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SyncPayloadTest {
    private val baseline = Instant.parse("2026-08-08T12:00:00Z")
    private val userId = UUID.fromString("00000000-0000-0000-0000-000000000030")
    private val scope = SyncScope(userId = userId)

    @Test
    fun sharedPayloadUsesAppleAndSupabaseSnakeCaseContract() {
        val toDo = ToDo.create(
            task = "Ship Android sync",
            dueAt = baseline.plusSeconds(3_600),
            recurrence = ToDoRecurrence(
                unit = ToDoRecurrenceUnit.DAYS,
                interval = 2,
                mode = ToDoRecurrenceMode.CONTINUOUS
            ),
            at = baseline
        )

        val encoded = SupabasePayloadMapper.encodeToDo(toDo, scope)
        val decoded = SyncPayloadCodec.decodeToDo(encoded)

        assertTrue(encoded.contains("\"user_id\""))
        assertTrue(encoded.contains("\"due_at\""))
        assertTrue(encoded.contains("\"recurrence_interval\""))
        assertFalse(encoded.contains("\"userId\""))
        assertEquals(toDo.id.toString(), decoded.id)
        assertEquals(toDo.task, decoded.task)
        assertEquals(userId.toString(), decoded.userId)
        assertEquals(toDo.recurrence?.interval, decoded.recurrenceInterval)
    }

    @Test
    fun firebaseMapperCreatesUserScopedDocumentWithoutFirebaseSdkTypes() {
        val toDo = ToDo.create(task = "Sync across Android devices", at = baseline)
        val payload = SyncToDoPayload.fromDomain(toDo, scope)

        val document = FirebasePayloadMapper.toDo(payload)

        assertEquals("users/$userId/todos", document.collectionPath)
        assertEquals(toDo.id.toString(), document.documentId)
        assertEquals(toDo.task, document.fields["task"])
        assertEquals(userId.toString(), document.fields["user_id"])
    }
}
