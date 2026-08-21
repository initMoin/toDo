package dev.iamshift.todo.android.core.persistence

import androidx.room3.Dao
import androidx.room3.Query
import androidx.room3.Upsert
import dev.iamshift.todo.android.core.sync.SyncOutboxStatus
import kotlinx.coroutines.flow.Flow

@Dao
interface ToDoDao {
    @Query(
        """
        SELECT * FROM todos
        ORDER BY
            CASE WHEN sortPosition IS NULL THEN 1 ELSE 0 END,
            sortPosition ASC,
            createdAtEpochMillis DESC,
            id ASC
        """
    )
    fun observeAll(): Flow<List<ToDoEntity>>

    @Query("SELECT * FROM todos WHERE id = :id LIMIT 1")
    suspend fun findById(id: String): ToDoEntity?

    @Upsert
    suspend fun upsert(toDo: ToDoEntity)

    @Upsert
    suspend fun upsertAll(toDos: List<ToDoEntity>)

    @Query("DELETE FROM todos WHERE id = :id")
    suspend fun deleteById(id: String)
}

@Dao
interface NanoDoDao {
    @Query("SELECT * FROM nanodos ORDER BY createdAtEpochMillis ASC, id ASC")
    fun observeAll(): Flow<List<NanoDoEntity>>

    @Upsert
    suspend fun upsert(nanoDo: NanoDoEntity)

    @Upsert
    suspend fun upsertAll(nanoDos: List<NanoDoEntity>)

    @Query("SELECT * FROM nanodos WHERE id = :id LIMIT 1")
    suspend fun findById(id: String): NanoDoEntity?

    @Query("SELECT * FROM nanodos WHERE todoId = :todoId ORDER BY createdAtEpochMillis ASC, id ASC")
    suspend fun findForToDo(todoId: String): List<NanoDoEntity>

    @Query("DELETE FROM nanodos WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("DELETE FROM nanodos WHERE todoId = :todoId")
    suspend fun deleteForToDo(todoId: String)
}

@Dao
interface TagDao {
    @Query("SELECT * FROM tags ORDER BY name ASC, id ASC")
    fun observeAll(): Flow<List<TagEntity>>

    @Upsert
    suspend fun upsert(tag: TagEntity)

    @Upsert
    suspend fun upsertAll(tags: List<TagEntity>)

    @Query("SELECT * FROM tags WHERE id = :id LIMIT 1")
    suspend fun findById(id: String): TagEntity?

    @Query("DELETE FROM tags WHERE id = :id")
    suspend fun deleteById(id: String)
}

@Dao
interface ToDoTagDao {
    @Query("SELECT * FROM todo_tags ORDER BY todoId ASC, tagId ASC")
    fun observeAll(): Flow<List<ToDoTagEntity>>

    @Upsert
    suspend fun upsert(link: ToDoTagEntity)

    @Upsert
    suspend fun upsertAll(links: List<ToDoTagEntity>)

    @Query("SELECT * FROM todo_tags WHERE todoId = :todoId ORDER BY tagId ASC")
    suspend fun findForToDo(todoId: String): List<ToDoTagEntity>

    @Query("DELETE FROM todo_tags WHERE todoId = :todoId AND tagId = :tagId")
    suspend fun delete(todoId: String, tagId: String)

    @Query("DELETE FROM todo_tags WHERE todoId = :todoId")
    suspend fun deleteForToDo(todoId: String)

    @Query("DELETE FROM todo_tags WHERE tagId = :tagId")
    suspend fun deleteForTag(tagId: String)
}

@Dao
interface SyncOutboxDao {
    @Query(
        """
        SELECT * FROM sync_outbox
        WHERE userId = :userId
          AND (collabId = :collabId OR (:collabId IS NULL AND collabId IS NULL))
          AND (
              status = :pending
              OR (status = :failed AND nextAttemptAtEpochMillis <= :nowEpochMillis)
          )
        ORDER BY nextAttemptAtEpochMillis ASC, changedAtEpochMillis ASC, mutationId ASC
        LIMIT :limit
        """
    )
    suspend fun pending(
        userId: String,
        collabId: String?,
        nowEpochMillis: Long,
        limit: Int,
        pending: String = SyncOutboxStatus.PENDING.rawValue,
        failed: String = SyncOutboxStatus.FAILED.rawValue
    ): List<SyncOutboxEntity>

    @Query(
        """
        DELETE FROM sync_outbox
        WHERE deduplicationKey = :deduplicationKey
          AND status IN (:pending, :failed)
        """
    )
    suspend fun deleteActiveForKey(
        deduplicationKey: String,
        pending: String = SyncOutboxStatus.PENDING.rawValue,
        failed: String = SyncOutboxStatus.FAILED.rawValue
    )

    @Upsert
    suspend fun upsert(mutation: SyncOutboxEntity)

    @Query("UPDATE sync_outbox SET status = :status WHERE mutationId = :mutationId")
    suspend fun updateStatus(mutationId: String, status: String)

    @Query(
        """
        UPDATE sync_outbox
        SET status = :status,
            attemptCount = attemptCount + 1,
            nextAttemptAtEpochMillis = :nextAttemptAtEpochMillis,
            lastError = :lastError
        WHERE mutationId = :mutationId
        """
    )
    suspend fun recordFailure(
        mutationId: String,
        status: String = SyncOutboxStatus.FAILED.rawValue,
        nextAttemptAtEpochMillis: Long,
        lastError: String?
    )

    @Query(
        """
        UPDATE sync_outbox
        SET status = :completed
        WHERE mutationId = :mutationId
        """
    )
    suspend fun markCompleted(
        mutationId: String,
        completed: String = SyncOutboxStatus.COMPLETED.rawValue
    )

    @Query("SELECT COUNT(*) FROM sync_outbox WHERE status != :completed")
    suspend fun pendingCount(completed: String = SyncOutboxStatus.COMPLETED.rawValue): Int
}
