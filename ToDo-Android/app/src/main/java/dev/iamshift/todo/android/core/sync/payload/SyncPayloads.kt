package dev.iamshift.todo.android.core.sync.payload

import dev.iamshift.todo.android.core.model.NanoDo
import dev.iamshift.todo.android.core.model.Tag
import dev.iamshift.todo.android.core.model.ToDo
import dev.iamshift.todo.android.core.model.ToDoRecurrence
import dev.iamshift.todo.android.core.model.ToDoRecurrenceMode
import dev.iamshift.todo.android.core.model.ToDoRecurrenceUnit
import dev.iamshift.todo.android.core.model.ToDoReminderIntent
import dev.iamshift.todo.android.core.model.ToDoState
import dev.iamshift.todo.android.core.sync.SyncScope
import java.time.Instant
import java.util.UUID
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

private fun Instant.toWireValue(): String = toString()

private fun String.toInstant(): Instant = Instant.parse(this)

private fun UUID.toWireValue(): String = toString()

private fun String.toUUID(): UUID = UUID.fromString(this)

/** The shared remote field contract used by both provider adapters. */
@Serializable
data class SyncToDoPayload(
    val id: String,
    @SerialName("user_id") val userId: String,
    @SerialName("collab_id") val collabId: String?,
    val task: String,
    val notes: String,
    @SerialName("is_done") val isDone: Boolean,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String,
    @SerialName("completed_at") val completedAt: String?,
    @SerialName("lifecycle_state") val lifecycleState: String,
    @SerialName("reminder_intent") val reminderIntent: String,
    @SerialName("due_at") val dueAt: String?,
    @SerialName("due_time_zone") val dueTimeZone: String?,
    @SerialName("is_recurring") val isRecurring: Boolean,
    @SerialName("recurrence_unit") val recurrenceUnit: String?,
    @SerialName("recurrence_interval") val recurrenceInterval: Int?,
    @SerialName("recurrence_mode") val recurrenceMode: String?,
    @SerialName("recurrence_count") val recurrenceCount: Int?,
    @SerialName("recurrence_anchor_at") val recurrenceAnchorAt: String?,
    @SerialName("recurrence_end_at") val recurrenceEndAt: String?,
    @SerialName("complete_when_all_nanodos_done") val completeWhenAllNanoDosDone: Boolean,
    @SerialName("sort_position") val sortPosition: Double?,
    @SerialName("trashed_at") val trashedAt: String?
) {
    companion object {
        fun fromDomain(toDo: ToDo, scope: SyncScope): SyncToDoPayload = SyncToDoPayload(
            id = toDo.id.toWireValue(),
            userId = scope.userId.toWireValue(),
            collabId = toDo.collabId?.toWireValue() ?: scope.collabId?.toWireValue(),
            task = toDo.task,
            notes = toDo.notes,
            isDone = toDo.isDone,
            createdAt = toDo.createdAt.toWireValue(),
            updatedAt = toDo.updatedAt.toWireValue(),
            completedAt = toDo.completedAt?.toWireValue(),
            lifecycleState = toDo.lifecycleState.rawValue,
            reminderIntent = toDo.reminderIntent.rawValue,
            dueAt = toDo.dueAt?.toWireValue(),
            dueTimeZone = toDo.dueTimeZone,
            isRecurring = toDo.isRecurring,
            recurrenceUnit = toDo.recurrence?.unit?.rawValue,
            recurrenceInterval = toDo.recurrence?.interval,
            recurrenceMode = toDo.recurrence?.mode?.rawValue,
            recurrenceCount = toDo.recurrence?.count,
            recurrenceAnchorAt = toDo.recurrence?.anchorAt?.toWireValue(),
            recurrenceEndAt = toDo.recurrence?.endAt?.toWireValue(),
            completeWhenAllNanoDosDone = toDo.completeWhenAllNanoDosDone,
            sortPosition = toDo.sortPosition,
            trashedAt = toDo.trashedAt?.toWireValue()
        )
    }

    fun toDomain(nanoDos: List<NanoDo> = emptyList(), tagIds: List<UUID> = emptyList()): ToDo {
        val recurrence = recurrenceUnit?.let { unitRaw ->
            val unit = ToDoRecurrenceUnit.fromRawValue(unitRaw)
            val mode = ToDoRecurrenceMode.fromRawValue(recurrenceMode)
            if (unit == null || mode == null || recurrenceInterval == null) {
                null
            } else {
                ToDoRecurrence(
                    unit = unit,
                    interval = recurrenceInterval,
                    mode = mode,
                    count = recurrenceCount,
                    anchorAt = recurrenceAnchorAt?.toInstant(),
                    endAt = recurrenceEndAt?.toInstant()
                )
            }
        }
        val decodedState = ToDoState.fromRawValue(lifecycleState)
            ?: if (isDone) ToDoState.DONE else ToDoState.ACTIVE

        return ToDo(
            id = id.toUUID(),
            ownerUserId = userId.toUUID(),
            collabId = collabId?.toUUID(),
            task = task,
            notes = notes,
            lifecycleState = decodedState,
            dueAt = dueAt?.toInstant(),
            dueTimeZone = dueTimeZone,
            reminderIntent = ToDoReminderIntent.fromRawValue(reminderIntent)
                ?: ToDoReminderIntent.SOFT,
            recurrence = recurrence,
            completeWhenAllNanoDosDone = completeWhenAllNanoDosDone,
            sortPosition = sortPosition,
            trashedAt = trashedAt?.toInstant(),
            createdAt = createdAt.toInstant(),
            updatedAt = updatedAt.toInstant(),
            completedAt = completedAt?.toInstant(),
            tagIds = tagIds,
            nanoDos = nanoDos
        )
    }
}

@Serializable
data class SyncNanoDoPayload(
    val id: String,
    @SerialName("todo_id") val todoId: String,
    @SerialName("user_id") val userId: String,
    val task: String,
    @SerialName("is_done") val isDone: Boolean,
    @SerialName("tag_id") val tagId: String?,
    @SerialName("due_at") val dueAt: String?,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String
) {
    companion object {
        fun fromDomain(nanoDo: NanoDo, scope: SyncScope): SyncNanoDoPayload = SyncNanoDoPayload(
            id = nanoDo.id.toWireValue(),
            todoId = nanoDo.todoId.toWireValue(),
            userId = scope.userId.toWireValue(),
            task = nanoDo.task,
            isDone = nanoDo.isDone,
            tagId = nanoDo.tagId?.toWireValue(),
            dueAt = nanoDo.dueAt?.toWireValue(),
            createdAt = nanoDo.createdAt.toWireValue(),
            updatedAt = nanoDo.updatedAt.toWireValue()
        )
    }

    fun toDomain(): NanoDo = NanoDo(
        id = id.toUUID(),
        todoId = todoId.toUUID(),
        ownerUserId = userId.toUUID(),
        task = task,
        isDone = isDone,
        tagId = tagId?.toUUID(),
        dueAt = dueAt?.toInstant(),
        createdAt = createdAt.toInstant(),
        updatedAt = updatedAt.toInstant()
    )
}

@Serializable
data class SyncTagPayload(
    val id: String,
    @SerialName("user_id") val userId: String,
    val name: String,
    @SerialName("is_default") val isDefault: Boolean,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String
) {
    companion object {
        fun fromDomain(tag: Tag, scope: SyncScope): SyncTagPayload = SyncTagPayload(
            id = tag.id.toWireValue(),
            userId = scope.userId.toWireValue(),
            name = tag.name,
            isDefault = tag.isDefault,
            createdAt = tag.createdAt.toWireValue(),
            updatedAt = tag.updatedAt.toWireValue()
        )
    }

    fun toDomain(): Tag = Tag.create(
        id = id.toUUID(),
        ownerUserId = userId.toUUID(),
        name = name,
        isDefault = isDefault,
        createdAt = createdAt.toInstant(),
        updatedAt = updatedAt.toInstant()
    )
}

@Serializable
data class SyncToDoTagPayload(
    @SerialName("todo_id") val todoId: String,
    @SerialName("tag_id") val tagId: String
)

@Serializable
data class SyncTombstonePayload(
    @SerialName("user_id") val userId: String,
    @SerialName("collab_id") val collabId: String?,
    @SerialName("record_table") val recordTable: String,
    @SerialName("record_id") val recordId: String,
    @SerialName("deleted_at") val deletedAt: String
)

/** Canonical JSON used by the durable outbox; provider adapters decode this contract. */
object SyncPayloadCodec {
    val json: Json = Json {
        encodeDefaults = true
        explicitNulls = true
        ignoreUnknownKeys = true
    }

    fun encodeToDo(toDo: ToDo, scope: SyncScope): String =
        json.encodeToString(SyncToDoPayload.fromDomain(toDo, scope))

    fun decodeToDo(value: String): SyncToDoPayload = json.decodeFromString(value)

    fun encodeNanoDo(nanoDo: NanoDo, scope: SyncScope): String =
        json.encodeToString(SyncNanoDoPayload.fromDomain(nanoDo, scope))

    fun decodeNanoDo(value: String): SyncNanoDoPayload = json.decodeFromString(value)

    fun encodeTag(tag: Tag, scope: SyncScope): String =
        json.encodeToString(SyncTagPayload.fromDomain(tag, scope))

    fun decodeTag(value: String): SyncTagPayload = json.decodeFromString(value)
}

data class FirebaseDocumentPayload(
    val collectionPath: String,
    val documentId: String,
    val fields: Map<String, Any?>
)

/** Firebase transport shape without importing Firebase SDK classes into core code. */
object FirebasePayloadMapper {
    fun toDo(payload: SyncToDoPayload): FirebaseDocumentPayload = document(
        collection = "users/${payload.userId}/todos",
        id = payload.id,
        fields = SyncPayloadCodec.json
            .encodeToJsonElement(SyncToDoPayload.serializer(), payload)
            .toFieldMap()
    )

    fun nanoDo(payload: SyncNanoDoPayload): FirebaseDocumentPayload = document(
        collection = "users/${payload.userId}/nanodos",
        id = payload.id,
        fields = SyncPayloadCodec.json
            .encodeToJsonElement(SyncNanoDoPayload.serializer(), payload)
            .toFieldMap()
    )

    fun tag(payload: SyncTagPayload): FirebaseDocumentPayload = document(
        collection = "users/${payload.userId}/tags",
        id = payload.id,
        fields = SyncPayloadCodec.json
            .encodeToJsonElement(SyncTagPayload.serializer(), payload)
            .toFieldMap()
    )

    fun todoTag(payload: SyncToDoTagPayload, userId: UUID): FirebaseDocumentPayload = document(
        collection = "users/$userId/todo_tags",
        id = "${payload.todoId}_${payload.tagId}",
        fields = SyncPayloadCodec.json
            .encodeToJsonElement(SyncToDoTagPayload.serializer(), payload)
            .toFieldMap()
    )

    private fun document(
        collection: String,
        id: String,
        fields: Map<String, Any?>
    ): FirebaseDocumentPayload = FirebaseDocumentPayload(collection, id, fields)
}

private fun kotlinx.serialization.json.JsonElement.toFieldMap(): Map<String, Any?> =
    (this as? kotlinx.serialization.json.JsonObject).orEmpty().mapValues { (_, value) ->
        value.toFirebaseValue()
    }

private fun kotlinx.serialization.json.JsonElement.toFirebaseValue(): Any? = when (this) {
    kotlinx.serialization.json.JsonNull -> null
    is kotlinx.serialization.json.JsonPrimitive -> when {
        isString -> content
        content == "true" -> true
        content == "false" -> false
        content.toLongOrNull() != null -> content.toLong()
        content.toDoubleOrNull() != null -> content.toDouble()
        else -> content
    }
    is kotlinx.serialization.json.JsonObject -> mapValues { (_, value) -> value.toFirebaseValue() }
    is kotlinx.serialization.json.JsonArray -> map { it.toFirebaseValue() }
}
