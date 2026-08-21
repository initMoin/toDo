package dev.iamshift.todo.android.core.persistence

import androidx.room3.withWriteTransaction
import dev.iamshift.todo.android.core.model.NanoDo
import dev.iamshift.todo.android.core.model.ToDo
import dev.iamshift.todo.android.core.model.ToDoState
import dev.iamshift.todo.android.core.sync.SyncMutation
import dev.iamshift.todo.android.core.sync.SyncOperation
import dev.iamshift.todo.android.core.sync.SyncRecordKey
import dev.iamshift.todo.android.core.sync.SyncRecordTable
import dev.iamshift.todo.android.core.sync.SyncScope
import dev.iamshift.todo.android.core.sync.payload.SyncPayloadCodec
import java.util.UUID
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine

/**
 * Durable local ToDo service. Room is the local source of truth; remote
 * providers are reached by sync services that consume the outbox.
 */
class RoomToDoRepository(
    private val database: ToDoDatabase,
    private val syncScopeProvider: () -> SyncScope? = { null },
    private val originDeviceId: UUID = UUID.randomUUID()
) {
    val toDos: Flow<List<ToDo>> = combine(
        database.toDoDao().observeAll(),
        database.nanoDoDao().observeAll(),
        database.toDoTagDao().observeAll()
    ) { toDoEntities, nanoDoEntities, tagLinks ->
        val nanoDosByToDo = nanoDoEntities
            .map(NanoDoEntity::toDomain)
            .groupBy { it.todoId }
        val tagIdsByToDo = tagLinks
            .groupBy { it.todoId }
            .mapValues { (_, links) -> links.map { UUID.fromString(it.tagId) } }

        toDoEntities.map { entity ->
            val id = UUID.fromString(entity.id)
            entity.toDomain(
                nanoDos = nanoDosByToDo[id].orEmpty(),
                tagIds = tagIdsByToDo[entity.id].orEmpty()
            )
        }
    }

    suspend fun create(title: String, notes: String = "") {
        val trimmedTitle = title.trim()
        if (trimmedTitle.isEmpty()) return

        val scope = syncScopeProvider()
        persist(
            ToDo.create(
                task = trimmedTitle,
                notes = notes.trim(),
                ownerUserId = scope?.userId,
                collabId = scope?.collabId
            )
        )
    }

    suspend fun update(toDo: ToDo) {
        persist(toDo)
    }

    suspend fun toggleDone(id: UUID) {
        val current = load(id) ?: return
        if (current.lifecycleState == ToDoState.ACTIVE || current.lifecycleState == ToDoState.DONE) {
            persist(current.toggleDone())
        }
    }

    suspend fun moveToTrash(id: UUID) {
        val current = load(id) ?: return
        if (!current.isTrashed) {
            persist(current.transition(ToDoState.TRASHED))
        }
    }

    private suspend fun load(id: UUID): ToDo? {
        val entity = database.toDoDao().findById(id.toString()) ?: return null
        return entity.toDomain(
            nanoDos = database.nanoDoDao().findForToDo(id.toString()).map(NanoDoEntity::toDomain),
            tagIds = database.toDoTagDao().findForToDo(id.toString()).map { UUID.fromString(it.tagId) }
        )
    }

    private suspend fun persist(toDo: ToDo) {
        database.withWriteTransaction {
            database.toDoDao().upsert(toDo.toEntity())

            database.nanoDoDao().deleteForToDo(toDo.id.toString())
            database.nanoDoDao().upsertAll(toDo.nanoDos.map(NanoDo::toEntity))

            database.toDoTagDao().deleteForToDo(toDo.id.toString())
            database.toDoTagDao().upsertAll(
                toDo.tagIds.map { tagId ->
                    ToDoTagEntity(todoId = toDo.id.toString(), tagId = tagId.toString())
                }
            )

            enqueueToDoMutation(toDo)
        }
    }

    private suspend fun enqueueToDoMutation(toDo: ToDo) {
        val scope = syncScopeProvider() ?: return
        val mutation = SyncMutation(
            recordKey = SyncRecordKey(SyncRecordTable.TODOS, toDo.id),
            scope = scope,
            operation = SyncOperation.UPSERT,
            changedAt = toDo.updatedAt,
            originDeviceId = originDeviceId
        )
        val entity = SyncOutboxEntity.fromMutation(
            mutation = mutation,
            payloadJson = SyncPayloadCodec.encodeToDo(toDo, scope)
        )

        // Pending and failed mutations for the same record are coalesced. An
        // in-flight mutation is retained so an active upload is never hidden.
        database.syncOutboxDao().deleteActiveForKey(entity.deduplicationKey)
        database.syncOutboxDao().upsert(entity)
    }
}
