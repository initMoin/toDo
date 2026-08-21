package dev.iamshift.todo.android.core.supabase

import dev.iamshift.todo.android.core.sync.SyncDispatch
import dev.iamshift.todo.android.core.sync.SyncOperation
import dev.iamshift.todo.android.core.sync.SyncProvider
import dev.iamshift.todo.android.core.sync.SyncProviderAdapter
import dev.iamshift.todo.android.core.sync.SyncPullRequest
import dev.iamshift.todo.android.core.sync.SyncPushReceipt
import dev.iamshift.todo.android.core.sync.SyncRecordTable
import dev.iamshift.todo.android.core.sync.SyncRemoteSnapshot
import dev.iamshift.todo.android.core.sync.payload.SupabasePayloadMapper
import dev.iamshift.todo.android.core.sync.payload.SyncNanoDoPayload
import dev.iamshift.todo.android.core.sync.payload.SyncPayloadCodec
import dev.iamshift.todo.android.core.sync.payload.SyncTagPayload
import dev.iamshift.todo.android.core.sync.payload.SyncToDoPayload
import dev.iamshift.todo.android.core.sync.payload.SyncToDoTagPayload
import dev.iamshift.todo.android.core.sync.payload.SyncTombstonePayload
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from

/** PostgREST adapter for the provider-neutral sync contracts. */
class SupabaseSyncAdapter(
    private val client: SupabaseClient = SupabaseService.client
) : SyncProviderAdapter {
    override val provider: SyncProvider = SyncProvider.SUPABASE

    override suspend fun push(dispatch: SyncDispatch): SyncPushReceipt {
        when (dispatch.mutation.operation) {
            SyncOperation.UPSERT -> upsert(dispatch)
            SyncOperation.DELETE -> delete(dispatch)
        }

        return SyncPushReceipt(provider = provider)
    }

    override suspend fun pull(request: SyncPullRequest): SyncRemoteSnapshot {
        val userId = request.scope.userId.toString()
        val cursor = request.cursor

        val todos = client.from(SupabasePayloadMapper.TODOS_TABLE)
            .select {
                filter {
                    eq("user_id", userId)
                    cursor?.let { gt("updated_at", it) }
                }
            }
            .decodeList<SyncToDoPayload>()

        val nanoDos = client.from(SupabasePayloadMapper.NANODOS_TABLE)
            .select {
                filter {
                    eq("user_id", userId)
                    cursor?.let { gt("updated_at", it) }
                }
            }
            .decodeList<SyncNanoDoPayload>()

        val tags = client.from(SupabasePayloadMapper.TAGS_TABLE)
            .select {
                filter {
                    eq("user_id", userId)
                    cursor?.let { gt("updated_at", it) }
                }
            }
            .decodeList<SyncTagPayload>()

        val todoTags = if (todos.isEmpty()) {
            emptyList()
        } else {
            client.from(SupabasePayloadMapper.TODO_TAGS_TABLE)
                .select {
                    filter { isIn("todo_id", todos.map(SyncToDoPayload::id)) }
                }
                .decodeList<SyncToDoTagPayload>()
        }

        val tombstones = client.from(SupabasePayloadMapper.TOMBSTONES_TABLE)
            .select {
                filter {
                    eq("user_id", userId)
                    cursor?.let { gt("deleted_at", it) }
                }
            }
            .decodeList<SyncTombstonePayload>()

        val nextCursor = sequenceOf(
            todos.asSequence().map(SyncToDoPayload::updatedAt),
            nanoDos.asSequence().map(SyncNanoDoPayload::updatedAt),
            tags.asSequence().map(SyncTagPayload::updatedAt),
            tombstones.asSequence().map(SyncTombstonePayload::deletedAt)
        ).flatten().maxOrNull()

        return SyncRemoteSnapshot(
            provider = provider,
            cursor = nextCursor,
            isFullSnapshot = cursor == null,
            todos = todos,
            nanoDos = nanoDos,
            tags = tags,
            todoTags = todoTags,
            tombstones = tombstones
        )
    }

    private suspend fun upsert(dispatch: SyncDispatch) {
        val payloadJson = dispatch.payloadJson ?: error("UPSERT mutation has no payload")
        when (dispatch.mutation.recordKey.table) {
            SyncRecordTable.TODOS -> client.from(SupabasePayloadMapper.TODOS_TABLE)
                .upsert(SyncPayloadCodec.decodeToDo(payloadJson))
            SyncRecordTable.NANODOS -> client.from(SupabasePayloadMapper.NANODOS_TABLE)
                .upsert(SyncPayloadCodec.decodeNanoDo(payloadJson))
            SyncRecordTable.TAGS -> client.from(SupabasePayloadMapper.TAGS_TABLE)
                .upsert(SyncPayloadCodec.decodeTag(payloadJson))
            SyncRecordTable.TODO_TAGS -> client.from(SupabasePayloadMapper.TODO_TAGS_TABLE)
                .upsert(SyncPayloadCodec.json.decodeFromString<SyncToDoTagPayload>(payloadJson))
        }
    }

    private suspend fun delete(dispatch: SyncDispatch) {
        val table = when (dispatch.mutation.recordKey.table) {
            SyncRecordTable.TODOS -> SupabasePayloadMapper.TODOS_TABLE
            SyncRecordTable.NANODOS -> SupabasePayloadMapper.NANODOS_TABLE
            SyncRecordTable.TAGS -> SupabasePayloadMapper.TAGS_TABLE
            SyncRecordTable.TODO_TAGS -> SupabasePayloadMapper.TODO_TAGS_TABLE
        }
        val recordKey = dispatch.mutation.recordKey

        client.from(table).delete {
            filter {
                if (recordKey.table == SyncRecordTable.TODO_TAGS) {
                    eq("todo_id", recordKey.recordId.toString())
                    eq("tag_id", recordKey.relatedRecordId!!.toString())
                } else {
                    eq("id", recordKey.recordId.toString())
                }
            }
        }
    }
}
