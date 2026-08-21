package dev.iamshift.todo.android.core.sync

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import dev.iamshift.todo.android.ToDoApplication
import kotlinx.coroutines.CancellationException

/**
 * Performs retryable Supabase synchronization outside the foreground UI.
 * Authentication and account-resolution state remain the source of truth;
 * signed-out or unresolved sessions complete as no-ops rather than retrying.
 */
class SupabaseSyncWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {
    override suspend fun doWork(): Result {
        val todoApplication = applicationContext as ToDoApplication

        return try {
            // WorkManager may start the process without an Activity. Restore
            // the Supabase session before deciding whether this is a no-op.
            todoApplication.authSessionProvider.start()
            val account = todoApplication.authSessionProvider.account.value
                ?.takeIf { it.isResolved }
                ?: return Result.success()
            todoApplication.synchronize(SyncScope(userId = account.userId))
            Result.success()
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            // SyncEngine persists individual outbox failures. A worker retry
            // gives a pull-only refresh another opportunity after connectivity
            // or token recovery without exposing provider details to WorkManager.
            Result.retry()
        }
    }
}
