package dev.iamshift.todo.android

import android.app.Application
import android.util.Log
import dev.iamshift.todo.android.core.auth.SupabaseAuthSessionProvider
import dev.iamshift.todo.android.core.persistence.ToDoDatabase
import dev.iamshift.todo.android.core.supabase.SupabaseSyncAdapter
import dev.iamshift.todo.android.core.sync.SyncEngine
import dev.iamshift.todo.android.core.sync.RoomSyncSnapshotApplier
import dev.iamshift.todo.android.core.sync.SyncScope
import dev.iamshift.todo.android.core.sync.SyncWorkScheduler
import dev.iamshift.todo.android.core.settings.ToDoSettingsStore
import dev.iamshift.todo.android.core.settings.GuidedTourStore
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class ToDoApplication : Application() {
    private val syncMutex = Mutex()
    private val applicationBackgroundScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    val settingsStore: ToDoSettingsStore by lazy {
        ToDoSettingsStore(this)
    }

    val guidedTourStore: GuidedTourStore by lazy {
        GuidedTourStore(this)
    }

    val authSessionProvider: SupabaseAuthSessionProvider by lazy {
        SupabaseAuthSessionProvider()
    }

    val syncEngine: SyncEngine by lazy {
        SyncEngine(
            database = ToDoDatabase.getInstance(this),
            adapters = listOf(SupabaseSyncAdapter())
        )
    }

    private val snapshotApplier: RoomSyncSnapshotApplier by lazy {
        RoomSyncSnapshotApplier(ToDoDatabase.getInstance(this))
    }

    override fun onCreate() {
        super.onCreate()
        applicationBackgroundScope.launch {
            SyncWorkScheduler.schedulePeriodic(this@ToDoApplication)
        }
    }

    suspend fun synchronize(scope: SyncScope) = syncMutex.withLock {
        try {
            val snapshots = syncEngine.pull(scope)
            snapshots.forEach { snapshot ->
                snapshotApplier.apply(snapshot, scope)
            }
            val report = syncEngine.flush(scope)
            Log.d(
                TAG,
                "Supabase sync completed: snapshots=${snapshots.size}, " +
                    "outboxAttempted=${report.attempted}, " +
                    "outboxCompleted=${report.completed}, " +
                    "outboxFailed=${report.failed}"
            )
            if (report.errors.isNotEmpty()) {
                Log.w(TAG, "Sync provider errors: ${report.errors.joinToString()}")
            }
        } catch (error: kotlinx.coroutines.CancellationException) {
            throw error
        } catch (error: Exception) {
            Log.e(TAG, "Supabase sync failed", error)
            throw error
        }
    }

    private companion object {
        const val TAG = "ToDoSync"
    }
}
