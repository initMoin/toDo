package dev.iamshift.todo.android.core.sync

import dev.iamshift.todo.android.core.persistence.SyncOutboxEntity
import dev.iamshift.todo.android.core.persistence.ToDoDatabase
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext
import java.time.Clock
import java.time.Instant
import java.util.UUID

data class SyncFlushReport(
    val attempted: Int,
    val completed: Int,
    val failed: Int,
    val errors: List<String>
)

/**
 * Coordinates local outbox delivery to both providers. A mutation is complete
 * only after every configured provider accepts it; provider writes must be
 * idempotent because a successful provider may be retried when another fails.
 */
class SyncEngine(
    private val database: ToDoDatabase,
    private val adapters: List<SyncProviderAdapter>,
    private val clock: Clock = Clock.systemUTC()
) {
    suspend fun flush(scope: SyncScope, batchSize: Int = DEFAULT_BATCH_SIZE): SyncFlushReport {
        require(batchSize > 0) { "Sync batch size must be positive" }

        val pending = database.syncOutboxDao().pending(
            userId = scope.userId.toString(),
            collabId = scope.collabId?.toString(),
            nowEpochMillis = Instant.now(clock).toEpochMilli(),
            limit = batchSize
        )
        var completed = 0
        var failed = 0
        val errors = mutableListOf<String>()

        for (entity in pending) {
            val dispatch = entity.toDispatch()
            database.syncOutboxDao().updateStatus(
                mutationId = entity.mutationId,
                status = SyncOutboxStatus.IN_FLIGHT.rawValue
            )

            val providerErrors = mutableListOf<String>()
            try {
                for (adapter in adapters) {
                    try {
                        adapter.push(dispatch)
                    } catch (error: CancellationException) {
                        throw error
                    } catch (error: Exception) {
                        providerErrors += "${adapter.provider.rawValue}: ${error.message ?: error::class.simpleName}"
                    }
                }
            } catch (error: CancellationException) {
                // A lifecycle stop or worker cancellation must not strand the
                // mutation in IN_FLIGHT forever. Restore it as immediately
                // retryable before propagating cancellation to the caller.
                withContext(NonCancellable) {
                    database.syncOutboxDao().recordFailure(
                        mutationId = entity.mutationId,
                        nextAttemptAtEpochMillis = Instant.now(clock).toEpochMilli(),
                        lastError = "Sync cancelled"
                    )
                }
                throw error
            }

            if (providerErrors.isEmpty()) {
                database.syncOutboxDao().markCompleted(entity.mutationId)
                completed += 1
            } else {
                val errorMessage = providerErrors.joinToString("; ")
                database.syncOutboxDao().recordFailure(
                    mutationId = entity.mutationId,
                    nextAttemptAtEpochMillis = nextRetryAt(entity).toEpochMilli(),
                    lastError = errorMessage
                )
                errors += errorMessage
                failed += 1
            }
        }

        return SyncFlushReport(
            attempted = pending.size,
            completed = completed,
            failed = failed,
            errors = errors
        )
    }

    suspend fun pull(scope: SyncScope, cursors: Map<SyncProvider, String?> = emptyMap()): List<SyncRemoteSnapshot> =
        adapters.map { adapter ->
            adapter.pull(
                SyncPullRequest(
                    scope = scope,
                    cursor = cursors[adapter.provider]
                )
            )
        }

    private fun nextRetryAt(entity: SyncOutboxEntity): Instant {
        val exponent = entity.attemptCount.coerceIn(0, MAX_BACKOFF_EXPONENT)
        val delaySeconds = (BASE_RETRY_SECONDS shl exponent)
            .coerceAtMost(MAX_RETRY_SECONDS)
        return Instant.now(clock).plusSeconds(delaySeconds)
    }

    private companion object {
        const val DEFAULT_BATCH_SIZE = 50
        const val BASE_RETRY_SECONDS = 5L
        const val MAX_RETRY_SECONDS = 3_600L
        const val MAX_BACKOFF_EXPONENT = 10
    }
}

private fun SyncOutboxEntity.toDispatch(): SyncDispatch {
    val table = SyncRecordTable.fromRawValue(tableName)
        ?: error("Unknown sync table: $tableName")
    val operationValue = runCatching { SyncOperation.valueOf(operation) }
        .getOrElse { error("Unknown sync operation: $operation") }
    val mutation = SyncMutation(
        mutationId = UUID.fromString(mutationId),
        recordKey = SyncRecordKey(
            table = table,
            recordId = UUID.fromString(recordId),
            relatedRecordId = relatedRecordId?.let(UUID::fromString)
        ),
        scope = SyncScope(
            userId = UUID.fromString(userId),
            collabId = collabId?.let(UUID::fromString)
        ),
        operation = operationValue,
        changedAt = Instant.ofEpochMilli(changedAtEpochMillis),
        originDeviceId = UUID.fromString(originDeviceId),
        payloadDigest = payloadDigest
    )
    return SyncDispatch(
        outboxId = UUID.fromString(mutationId),
        mutation = mutation,
        payloadJson = payloadJson
    )
}
