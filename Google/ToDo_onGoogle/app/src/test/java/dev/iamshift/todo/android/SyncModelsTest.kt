package dev.iamshift.todo.android

import dev.iamshift.todo.android.core.sync.ProviderSyncState
import dev.iamshift.todo.android.core.sync.RecordSyncMetadata
import dev.iamshift.todo.android.core.sync.SyncProvider
import dev.iamshift.todo.android.core.sync.SyncRecordKey
import dev.iamshift.todo.android.core.sync.SyncRecordTable
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Test

class SyncModelsTest {
    @Test
    fun recordMetadataKeepsSupabaseAndFirebaseStateIndependent() {
        val key = SyncRecordKey(SyncRecordTable.TODOS, UUID.randomUUID())
        val metadata = RecordSyncMetadata(
            recordKey = key,
            supabase = ProviderSyncState(
                provider = SyncProvider.SUPABASE,
                remoteVersion = "supabase-updated-at"
            ),
            firebase = ProviderSyncState(
                provider = SyncProvider.FIREBASE,
                remoteVersion = "firestore-update-time"
            )
        )

        assertEquals(SyncProvider.SUPABASE, metadata.supabase.provider)
        assertEquals("supabase-updated-at", metadata.supabase.remoteVersion)
        assertEquals(SyncProvider.FIREBASE, metadata.firebase.provider)
        assertEquals("firestore-update-time", metadata.firebase.remoteVersion)
    }

    @Test
    fun todoTagRecordsUseACompositeSyncIdentity() {
        val todoId = UUID.randomUUID()
        val tagId = UUID.randomUUID()
        val key = SyncRecordKey(
            table = SyncRecordTable.TODO_TAGS,
            recordId = todoId,
            relatedRecordId = tagId
        )

        assertEquals(todoId, key.recordId)
        assertEquals(tagId, key.relatedRecordId)
    }
}
