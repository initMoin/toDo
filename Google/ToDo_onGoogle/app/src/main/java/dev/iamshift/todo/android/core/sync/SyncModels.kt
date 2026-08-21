package dev.iamshift.todo.android.core.sync

import java.time.Instant
import java.util.UUID
import dev.iamshift.todo.android.core.sync.payload.SyncNanoDoPayload
import dev.iamshift.todo.android.core.sync.payload.SyncTagPayload
import dev.iamshift.todo.android.core.sync.payload.SyncToDoPayload
import dev.iamshift.todo.android.core.sync.payload.SyncToDoTagPayload
import dev.iamshift.todo.android.core.sync.payload.SyncTombstonePayload

/** Remote providers are adapters; domain models do not contain Firebase or Supabase SDK types. */
enum class SyncProvider(val rawValue: String) {
    SUPABASE("supabase"),
    FIREBASE("firebase");

    companion object {
        fun fromRawValue(value: String?): SyncProvider? =
            values().firstOrNull { it.rawValue == value }
    }
}

enum class SyncOperation {
    UPSERT,
    DELETE
}

enum class SyncOutboxStatus(val rawValue: String) {
    PENDING("pending"),
    IN_FLIGHT("inFlight"),
    FAILED("failed"),
    COMPLETED("completed")
}

enum class SyncRecordTable(val rawValue: String) {
    TODOS("todos"),
    NANODOS("nanodos"),
    TAGS("tags"),
    TODO_TAGS("todo_tags");

    companion object {
        fun fromRawValue(value: String?): SyncRecordTable? =
            values().firstOrNull { it.rawValue == value }
    }
}

data class SyncScope(
    val userId: UUID,
    val collabId: UUID? = null
)

data class SyncRecordKey(
    val table: SyncRecordTable,
    val recordId: UUID,
    /** `todo_tags` has no standalone ID; this is its tag ID when applicable. */
    val relatedRecordId: UUID? = null
) {
    init {
        require(
            table != SyncRecordTable.TODO_TAGS || relatedRecordId != null
        ) {
            "todo_tags sync records require both todo and tag IDs"
        }
    }
}

/** Matches the shared Supabase tombstone contract and is also usable by Firebase adapters. */
data class SyncTombstone(
    val userId: UUID,
    val collabId: UUID?,
    val recordTable: SyncRecordTable,
    val recordId: UUID,
    val deletedAt: Instant
)

/**
 * Provider state is intentionally separate from ToDo/NanoDo/Tag. Supabase and
 * Firebase may expose different remote cursors or versions, and neither one
 * should leak into the product model.
 */
data class ProviderSyncState(
    val provider: SyncProvider,
    val remoteCursor: String? = null,
    val remoteVersion: String? = null,
    val remoteUpdatedAt: Instant? = null,
    val lastUploadedAt: Instant? = null,
    val lastDownloadedAt: Instant? = null,
    val lastError: String? = null
)

data class RecordSyncMetadata(
    val recordKey: SyncRecordKey,
    val supabase: ProviderSyncState = ProviderSyncState(SyncProvider.SUPABASE),
    val firebase: ProviderSyncState = ProviderSyncState(SyncProvider.FIREBASE)
)

/** A local mutation identity for durable outbox/idempotency work in the sync layer. */
data class SyncMutation(
    val mutationId: UUID = UUID.randomUUID(),
    val recordKey: SyncRecordKey,
    val scope: SyncScope,
    val operation: SyncOperation,
    val changedAt: Instant,
    val originDeviceId: UUID,
    val payloadDigest: String? = null
)

data class SyncDispatch(
    val outboxId: UUID,
    val mutation: SyncMutation,
    val payloadJson: String?
)

data class SyncPullRequest(
    val scope: SyncScope,
    val cursor: String? = null
)

data class SyncPushReceipt(
    val provider: SyncProvider,
    val remoteVersion: String? = null,
    val remoteUpdatedAt: Instant? = null
)

data class SyncRemoteSnapshot(
    val provider: SyncProvider,
    val cursor: String?,
    /** True when the snapshot is authoritative for the requested scope. */
    val isFullSnapshot: Boolean = true,
    val todos: List<SyncToDoPayload> = emptyList(),
    val nanoDos: List<SyncNanoDoPayload> = emptyList(),
    val tags: List<SyncTagPayload> = emptyList(),
    val todoTags: List<SyncToDoTagPayload> = emptyList(),
    val tombstones: List<SyncTombstonePayload> = emptyList()
)

interface SyncProviderAdapter {
    val provider: SyncProvider

    suspend fun push(dispatch: SyncDispatch): SyncPushReceipt

    suspend fun pull(request: SyncPullRequest): SyncRemoteSnapshot
}
