package dev.iamshift.todo.android.core.supabase

import android.content.Context
import dev.iamshift.todo.android.core.sync.SyncScope
import dev.iamshift.todo.android.core.network.NetworkConnectivityMonitor
import io.github.jan.supabase.postgrest.query.filter.FilterOperator
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.channel
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.launch

/**
 * Converts Supabase Postgres Changes into invalidation signals.
 *
 * The payload itself is deliberately not applied directly: a debounced signal
 * causes the normal authenticated full-pull path to run, so conflict ordering,
 * tombstones, relationship reconciliation, and local-only fields all have one
 * implementation.
 */
class SupabaseRealtimeSyncService(
    context: Context,
    private val client: io.github.jan.supabase.SupabaseClient = SupabaseService.client
) {
    private val networkConnectivity = NetworkConnectivityMonitor(context)

    @OptIn(ExperimentalCoroutinesApi::class)
    fun changes(scope: SyncScope): Flow<Unit> = networkConnectivity.isOnline
        .flatMapLatest { online ->
            if (online) connectedChanges(scope) else emptyFlow()
        }

    private fun connectedChanges(scope: SyncScope): Flow<Unit> = callbackFlow {
        val channel = client.channel("todo-sync-${scope.userId}")
        val tables = listOf(
            SupabaseRealtimeTable.TODOS,
            SupabaseRealtimeTable.NANODOS,
            SupabaseRealtimeTable.TAGS,
            SupabaseRealtimeTable.TODO_TAGS,
            SupabaseRealtimeTable.TOMBSTONES
        )

        val collectors = tables.map { table ->
            launch {
                channel.postgresChangeFlow<PostgresAction>(schema = "public") {
                    this.table = table
                    // todo_tags has no user_id column. Its subscription is
                    // still protected by the authenticated user's RLS policy.
                    if (table != SupabaseRealtimeTable.TODO_TAGS) {
                        filter("user_id", FilterOperator.EQ, scope.userId.toString())
                    }
                }.collect {
                    trySend(Unit).isSuccess
                }
            }
        }

        try {
            channel.subscribe(blockUntilSubscribed = true)
            awaitClose {
                collectors.forEach { it.cancel() }
                launch { runCatching { channel.unsubscribe() } }
            }
        } catch (error: Throwable) {
            collectors.forEach { it.cancel() }
            close(error)
        }
    }
}

private object SupabaseRealtimeTable {
    const val TODOS = "todos"
    const val NANODOS = "nanodos"
    const val TAGS = "tags"
    const val TODO_TAGS = "todo_tags"
    const val TOMBSTONES = "sync_tombstones"
}
