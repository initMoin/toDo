package dev.iamshift.todo.android.core.persistence

import androidx.room3.Entity
import androidx.room3.Index
import androidx.room3.PrimaryKey
import dev.iamshift.todo.android.core.model.NanoDo
import dev.iamshift.todo.android.core.model.Tag
import dev.iamshift.todo.android.core.model.ToDo
import dev.iamshift.todo.android.core.model.ToDoLocationReminder
import dev.iamshift.todo.android.core.model.ToDoRecurrence
import dev.iamshift.todo.android.core.model.ToDoRecurrenceMode
import dev.iamshift.todo.android.core.model.ToDoRecurrenceUnit
import dev.iamshift.todo.android.core.model.ToDoReminderIntent
import dev.iamshift.todo.android.core.model.ToDoState
import dev.iamshift.todo.android.core.model.ToDoLocationReminderTrigger
import dev.iamshift.todo.android.core.sync.SyncMutation
import dev.iamshift.todo.android.core.sync.SyncOperation
import dev.iamshift.todo.android.core.sync.SyncOutboxStatus
import java.time.Instant
import java.util.UUID

@Entity(
    tableName = "todos",
    indices = [
        Index(value = ["ownerUserId"]),
        Index(value = ["collabId"]),
        Index(value = ["lifecycleState"]),
        Index(value = ["dueAtEpochMillis"]),
        Index(value = ["updatedAtEpochMillis"])
    ]
)
data class ToDoEntity(
    @PrimaryKey val id: String,
    val ownerUserId: String?,
    val collabId: String?,
    val task: String,
    val notes: String,
    val lifecycleState: String,
    val dueAtEpochMillis: Long?,
    val dueTimeZone: String?,
    val reminderIntent: String,
    val recurrenceUnit: String?,
    val recurrenceInterval: Int?,
    val recurrenceMode: String?,
    val recurrenceCount: Int?,
    val recurrenceAnchorAtEpochMillis: Long?,
    val recurrenceEndAtEpochMillis: Long?,
    val completeWhenAllNanoDosDone: Boolean,
    val sortPosition: Double?,
    val trashedAtEpochMillis: Long?,
    val locationLatitude: Double?,
    val locationLongitude: Double?,
    val locationRadiusMeters: Double?,
    val locationTrigger: String?,
    val locationLabel: String?,
    val createdAtEpochMillis: Long,
    val updatedAtEpochMillis: Long,
    val completedAtEpochMillis: Long?
)

@Entity(
    tableName = "nanodos",
    indices = [
        Index(value = ["todoId"]),
        Index(value = ["updatedAtEpochMillis"])
    ]
)
data class NanoDoEntity(
    @PrimaryKey val id: String,
    val todoId: String,
    val ownerUserId: String?,
    val task: String,
    val isDone: Boolean,
    val tagId: String?,
    val dueAtEpochMillis: Long?,
    val createdAtEpochMillis: Long,
    val updatedAtEpochMillis: Long
)

@Entity(
    tableName = "tags",
    indices = [
        Index(value = ["ownerUserId"]),
        Index(value = ["name"]),
        Index(value = ["updatedAtEpochMillis"])
    ]
)
data class TagEntity(
    @PrimaryKey val id: String,
    val ownerUserId: String?,
    val name: String,
    val isDefault: Boolean,
    val createdAtEpochMillis: Long,
    val updatedAtEpochMillis: Long
)

@Entity(
    tableName = "todo_tags",
    primaryKeys = ["todoId", "tagId"],
    indices = [Index(value = ["tagId"])]
)
data class ToDoTagEntity(
    val todoId: String,
    val tagId: String
)

@Entity(
    tableName = "sync_outbox",
    indices = [
        Index(value = ["status", "nextAttemptAtEpochMillis"]),
        Index(value = ["deduplicationKey"]),
        Index(value = ["changedAtEpochMillis"])
    ]
)
data class SyncOutboxEntity(
    @PrimaryKey val mutationId: String,
    val deduplicationKey: String,
    val tableName: String,
    val recordId: String,
    val relatedRecordId: String?,
    val userId: String,
    val collabId: String?,
    val operation: String,
    val payloadJson: String?,
    val changedAtEpochMillis: Long,
    val originDeviceId: String,
    val payloadDigest: String?,
    val status: String,
    val attemptCount: Int,
    val nextAttemptAtEpochMillis: Long,
    val lastError: String?,
    val createdAtEpochMillis: Long
) {
    companion object {
        fun fromMutation(mutation: SyncMutation, payloadJson: String? = null): SyncOutboxEntity {
            val deduplicationKey = buildDeduplicationKey(mutation)
            return SyncOutboxEntity(
                mutationId = mutation.mutationId.toString(),
                deduplicationKey = deduplicationKey,
                tableName = mutation.recordKey.table.rawValue,
                recordId = mutation.recordKey.recordId.toString(),
                relatedRecordId = mutation.recordKey.relatedRecordId?.toString(),
                userId = mutation.scope.userId.toString(),
                collabId = mutation.scope.collabId?.toString(),
                operation = mutation.operation.name,
                payloadJson = payloadJson,
                changedAtEpochMillis = mutation.changedAt.toEpochMilli(),
                originDeviceId = mutation.originDeviceId.toString(),
                payloadDigest = mutation.payloadDigest,
                status = SyncOutboxStatus.PENDING.rawValue,
                attemptCount = 0,
                nextAttemptAtEpochMillis = mutation.changedAt.toEpochMilli(),
                lastError = null,
                createdAtEpochMillis = mutation.changedAt.toEpochMilli()
            )
        }

        /** Scope plus composite record identity; used to coalesce active mutations. */
        fun buildDeduplicationKey(mutation: SyncMutation): String = listOf(
            mutation.scope.userId,
            mutation.scope.collabId,
            mutation.recordKey.table.rawValue,
            mutation.recordKey.recordId,
            mutation.recordKey.relatedRecordId
        ).joinToString("|")
    }
}

fun ToDo.toEntity(): ToDoEntity = ToDoEntity(
    id = id.toString(),
    ownerUserId = ownerUserId?.toString(),
    collabId = collabId?.toString(),
    task = task,
    notes = notes,
    lifecycleState = lifecycleState.rawValue,
    dueAtEpochMillis = dueAt?.toEpochMilli(),
    dueTimeZone = dueTimeZone,
    reminderIntent = reminderIntent.rawValue,
    recurrenceUnit = recurrence?.unit?.rawValue,
    recurrenceInterval = recurrence?.interval,
    recurrenceMode = recurrence?.mode?.rawValue,
    recurrenceCount = recurrence?.count,
    recurrenceAnchorAtEpochMillis = recurrence?.anchorAt?.toEpochMilli(),
    recurrenceEndAtEpochMillis = recurrence?.endAt?.toEpochMilli(),
    completeWhenAllNanoDosDone = completeWhenAllNanoDosDone,
    sortPosition = sortPosition,
    trashedAtEpochMillis = trashedAt?.toEpochMilli(),
    locationLatitude = locationReminder?.latitude,
    locationLongitude = locationReminder?.longitude,
    locationRadiusMeters = locationReminder?.radiusMeters,
    locationTrigger = locationReminder?.trigger?.rawValue,
    locationLabel = locationReminder?.label,
    createdAtEpochMillis = createdAt.toEpochMilli(),
    updatedAtEpochMillis = updatedAt.toEpochMilli(),
    completedAtEpochMillis = completedAt?.toEpochMilli()
)

fun ToDoEntity.toDomain(nanoDos: List<NanoDo>, tagIds: List<UUID>): ToDo = ToDo(
    id = UUID.fromString(id),
    ownerUserId = ownerUserId?.let(UUID::fromString),
    collabId = collabId?.let(UUID::fromString),
    task = task,
    notes = notes,
    lifecycleState = ToDoState.fromRawValueOrDefault(lifecycleState),
    dueAt = dueAtEpochMillis?.let { Instant.ofEpochMilli(it) },
    dueTimeZone = dueTimeZone,
    reminderIntent = ToDoReminderIntent.fromRawValue(reminderIntent) ?: ToDoReminderIntent.SOFT,
    recurrence = recurrenceUnit?.let { unitRaw ->
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
                anchorAt = recurrenceAnchorAtEpochMillis?.let { Instant.ofEpochMilli(it) },
                endAt = recurrenceEndAtEpochMillis?.let { Instant.ofEpochMilli(it) }
            )
        }
    },
    completeWhenAllNanoDosDone = completeWhenAllNanoDosDone,
    sortPosition = sortPosition,
    trashedAt = trashedAtEpochMillis?.let { Instant.ofEpochMilli(it) },
    locationReminder = if (locationLatitude != null && locationLongitude != null) {
        ToDoLocationReminder(
            latitude = locationLatitude,
            longitude = locationLongitude,
            radiusMeters = locationRadiusMeters ?: 150.0,
            trigger = ToDoLocationReminderTrigger.fromRawValue(locationTrigger)
                ?: ToDoLocationReminderTrigger.ARRIVING,
            label = locationLabel
        )
    } else {
        null
    },
    createdAt = Instant.ofEpochMilli(createdAtEpochMillis),
    updatedAt = Instant.ofEpochMilli(updatedAtEpochMillis),
    completedAt = completedAtEpochMillis?.let { Instant.ofEpochMilli(it) },
    tagIds = tagIds,
    nanoDos = nanoDos
)

fun NanoDo.toEntity(): NanoDoEntity = NanoDoEntity(
    id = id.toString(),
    todoId = todoId.toString(),
    ownerUserId = ownerUserId?.toString(),
    task = task,
    isDone = isDone,
    tagId = tagId?.toString(),
    dueAtEpochMillis = dueAt?.toEpochMilli(),
    createdAtEpochMillis = createdAt.toEpochMilli(),
    updatedAtEpochMillis = updatedAt.toEpochMilli()
)

fun NanoDoEntity.toDomain(): NanoDo = NanoDo(
    id = UUID.fromString(id),
    todoId = UUID.fromString(todoId),
    ownerUserId = ownerUserId?.let(UUID::fromString),
    task = task,
    isDone = isDone,
    tagId = tagId?.let(UUID::fromString),
    dueAt = dueAtEpochMillis?.let { Instant.ofEpochMilli(it) },
    createdAt = Instant.ofEpochMilli(createdAtEpochMillis),
    updatedAt = Instant.ofEpochMilli(updatedAtEpochMillis)
)

fun Tag.toEntity(): TagEntity = TagEntity(
    id = id.toString(),
    ownerUserId = ownerUserId?.toString(),
    name = name,
    isDefault = isDefault,
    createdAtEpochMillis = createdAt.toEpochMilli(),
    updatedAtEpochMillis = updatedAt.toEpochMilli()
)

fun TagEntity.toDomain(): Tag = Tag.create(
    id = UUID.fromString(id),
    ownerUserId = ownerUserId?.let(UUID::fromString),
    name = name,
    isDefault = isDefault,
    createdAt = Instant.ofEpochMilli(createdAtEpochMillis),
    updatedAt = Instant.ofEpochMilli(updatedAtEpochMillis)
)
