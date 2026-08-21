package dev.iamshift.todo.android.core.sync

import androidx.room3.withWriteTransaction
import dev.iamshift.todo.android.core.persistence.ToDoDatabase
import dev.iamshift.todo.android.core.persistence.ToDoEntity
import dev.iamshift.todo.android.core.persistence.ToDoTagEntity
import dev.iamshift.todo.android.core.persistence.toEntity
import dev.iamshift.todo.android.core.persistence.toDomain
import dev.iamshift.todo.android.core.sync.payload.SyncToDoPayload
import java.util.UUID

/** Applies remote rows only when their timestamps are newer than local rows. */
class RoomSyncSnapshotApplier(
    private val database: ToDoDatabase
) {
    suspend fun apply(snapshot: SyncRemoteSnapshot, scope: SyncScope) {
        require(snapshot.provider == SyncProvider.SUPABASE) {
            "Room snapshot application currently supports Supabase snapshots."
        }

        database.withWriteTransaction {
            val scopedTodos = snapshot.todos.filter { payload ->
                payload.userId == scope.userId.toString() &&
                    (scope.collabId == null || payload.collabId == scope.collabId.toString())
            }
            val scopedTodoIds = scopedTodos.mapTo(mutableSetOf(), SyncToDoPayload::id)
            val scopedNanoDos = snapshot.nanoDos.filter { payload ->
                payload.userId == scope.userId.toString() &&
                    (scope.collabId == null || payload.todoId in scopedTodoIds)
            }
            val nanoDosByToDo = scopedNanoDos.groupBy { it.todoId }
            val scopedTodoTags = snapshot.todoTags.filter { it.todoId in scopedTodoIds }
            val todoTagsByToDo = scopedTodoTags.groupBy { it.todoId }
            val tagIdsByToDo = todoTagsByToDo
                .mapValues { (_, links) -> links.map { UUID.fromString(it.tagId) } }

            scopedTodos.forEach { payload ->
                val existing = database.toDoDao().findById(payload.id)
                if (existing != null && !payload.updatedAt.isNewerThan(existing.updatedAtEpochMillis)) {
                    return@forEach
                }

                val existingLocation = existing?.toDomainLocationReminder()
                payload.toDomain(
                    nanoDos = nanoDosByToDo[payload.id].orEmpty().map { it.toDomain() },
                    tagIds = tagIdsByToDo[payload.id].orEmpty()
                ).copy(locationReminder = existingLocation).toEntity().let {
                    database.toDoDao().upsert(it)
                }
            }

            scopedNanoDos.forEach { payload ->
                val existing = database.nanoDoDao().findById(payload.id)
                if (existing == null || payload.updatedAt.isNewerThan(existing.updatedAtEpochMillis)) {
                    database.nanoDoDao().upsert(payload.toDomain().toEntity())
                }
            }

            snapshot.tags.forEach { payload ->
                if (payload.userId != scope.userId.toString()) return@forEach
                val existing = database.tagDao().findById(payload.id)
                if (existing == null || payload.updatedAt.isNewerThan(existing.updatedAtEpochMillis)) {
                    database.tagDao().upsert(payload.toDomain().toEntity())
                }
            }

            snapshot.tombstones.forEach { tombstone ->
                if (tombstone.userId != scope.userId.toString()) return@forEach
                if (scope.collabId != null && tombstone.collabId != scope.collabId.toString()) {
                    return@forEach
                }
                val deletedAt = runCatching {
                    java.time.Instant.parse(tombstone.deletedAt).toEpochMilli()
                }.getOrNull() ?: return@forEach
                val recordTable = SyncRecordTable.fromRawValue(tombstone.recordTable)
                    ?: return@forEach

                when (recordTable) {
                    SyncRecordTable.TODOS -> {
                        val existing = database.toDoDao().findById(tombstone.recordId)
                        if (existing != null && deletedAt >= existing.updatedAtEpochMillis) {
                            database.toDoDao().deleteById(tombstone.recordId)
                            database.nanoDoDao().deleteForToDo(tombstone.recordId)
                            database.toDoTagDao().deleteForToDo(tombstone.recordId)
                        }
                    }
                    SyncRecordTable.NANODOS -> {
                        val existing = database.nanoDoDao().findById(tombstone.recordId)
                        if (existing != null && deletedAt >= existing.updatedAtEpochMillis) {
                            database.nanoDoDao().deleteById(tombstone.recordId)
                        }
                    }
                    SyncRecordTable.TAGS -> {
                        val existing = database.tagDao().findById(tombstone.recordId)
                        if (existing != null && deletedAt >= existing.updatedAtEpochMillis) {
                            database.tagDao().deleteById(tombstone.recordId)
                            database.toDoTagDao().deleteForTag(tombstone.recordId)
                        }
                    }
                    SyncRecordTable.TODO_TAGS -> {
                        // The current shared tombstone schema stores one
                        // record_id, while todo_tags has a composite key.
                        // Parent ToDo tombstones remove all links; relation
                        // tombstone refinement belongs in the shared schema.
                    }
                }
            }

            if (snapshot.isFullSnapshot) {
                // A full pull is authoritative for every returned ToDo. Replacing
                // each relationship set removes stale links that a simple upsert
                // would leave behind after a deletion on another device.
                scopedTodoIds.forEach { todoId ->
                    database.toDoTagDao().deleteForToDo(todoId)
                    database.toDoTagDao().upsertAll(
                        todoTagsByToDo[todoId]
                            .orEmpty()
                            .map { link -> ToDoTagEntity(todoId = link.todoId, tagId = link.tagId) }
                    )
                }
            } else {
                scopedTodoTags.forEach { link ->
                    database.toDoTagDao().upsert(
                        ToDoTagEntity(todoId = link.todoId, tagId = link.tagId)
                    )
                }
            }
        }
    }
}

private fun String.isNewerThan(localEpochMillis: Long): Boolean =
    runCatching { java.time.Instant.parse(this).toEpochMilli() > localEpochMillis }
        .getOrDefault(false)

private fun ToDoEntity.toDomainLocationReminder() =
    toDomain(nanoDos = emptyList(), tagIds = emptyList()).locationReminder
