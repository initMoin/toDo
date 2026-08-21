package dev.iamshift.todo.android

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.view.WindowCompat
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.getValue
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.SideEffect
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.repeatOnLifecycle
import dev.iamshift.todo.android.core.supabase.SupabaseRealtimeSyncService
import dev.iamshift.todo.android.core.supabase.SupabaseConfig
import dev.iamshift.todo.android.ui.ToDoApp
import dev.iamshift.todo.android.ui.theme.ToDoTheme
import dev.iamshift.todo.android.core.sync.SyncScope
import dev.iamshift.todo.android.core.sync.SyncWorkScheduler
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@OptIn(FlowPreview::class)
class MainActivity : ComponentActivity() {
    private val todoApplication: ToDoApplication
        get() = application as ToDoApplication

    private val authSessionProvider
        get() = todoApplication.authSessionProvider

    private val realtimeSyncService by lazy { SupabaseRealtimeSyncService(applicationContext) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleAuthDeepLink(intent)
        val store = ViewModelProvider(this)[ToDoStore::class.java]
        setContent {
            val appearanceMode by todoApplication.settingsStore.appearanceMode.collectAsState()
            val darkTheme = appearanceMode.resolvesToDark(isSystemInDarkTheme())
            ToDoTheme(
                darkTheme = darkTheme
            ) {
                SideEffect {
                    WindowCompat.getInsetsController(window, window.decorView).apply {
                        isAppearanceLightStatusBars = !darkTheme
                        isAppearanceLightNavigationBars = !darkTheme
                    }
                }
                ToDoApp(
                    store = store,
                    authSessionProvider = authSessionProvider,
                    settingsStore = todoApplication.settingsStore,
                    guidedTourStore = todoApplication.guidedTourStore
                )
            }
        }

        lifecycleScope.launch {
            // Supabase session initialization can touch storage and client
            // setup. Do it away from the first Compose frame.
            withContext(Dispatchers.Default) {
                todoApplication.authSessionProvider.start()
            }
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                authSessionProvider.account
                    .filterNotNull()
                    .filter { it.isResolved }
                    .distinctUntilChangedBy { it.userId }
                    .collectLatest { account ->
                        val syncScope = SyncScope(userId = account.userId)
                        synchronizeSafely(syncScope)
                        launch {
                            try {
                                realtimeSyncService.changes(syncScope)
                                    .debounce(500)
                                    .collect { synchronizeSafely(syncScope) }
                            } catch (error: CancellationException) {
                                throw error
                            } catch (_: Exception) {
                                // Periodic WorkManager sync remains the
                                // recovery path if the realtime socket drops.
                            }
                        }.join()
                    }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        if (authSessionProvider.account.value?.isResolved == true) {
            SyncWorkScheduler.requestImmediate(this)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAuthDeepLink(intent)
    }

    private fun handleAuthDeepLink(intent: Intent?) {
        val data = intent?.data ?: return
        if (data.scheme == SupabaseConfig.redirectScheme &&
            data.host == SupabaseConfig.redirectHost
        ) {
            intent?.let(authSessionProvider::handleDeepLink)
        }
    }

    private suspend fun synchronizeSafely(scope: SyncScope) {
        withContext(Dispatchers.IO) {
            try {
                todoApplication.synchronize(scope)
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                // Keep foreground rendering alive; the worker and the next
                // realtime/foreground event will retry the same sync scope.
            }
        }
    }
}
