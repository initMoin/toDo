package dev.iamshift.todo.android

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import dev.iamshift.todo.android.core.auth.DeviceIdentityStore
import dev.iamshift.todo.android.core.auth.AuthenticatedSyncScopeProvider
import dev.iamshift.todo.android.core.model.ToDo
import dev.iamshift.todo.android.core.model.ToDoState
import dev.iamshift.todo.android.core.persistence.RoomToDoRepository
import dev.iamshift.todo.android.core.persistence.ToDoDatabase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.emitAll
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * In-memory implementation of the local repository boundary used by fast JVM
 * unit tests. The running app uses RoomToDoRepository below.
 *
 * The domain model is production-shaped; this small implementation keeps
 * repository behavior testable without Android database setup.
 */
class ToDoRepository {
    private val _toDos = MutableStateFlow<List<ToDo>>(emptyList())
    val toDos: StateFlow<List<ToDo>> = _toDos.asStateFlow()

    fun create(title: String, notes: String = "") {
        val trimmedTitle = title.trim()
        if (trimmedTitle.isEmpty()) return

        _toDos.value = _toDos.value + ToDo.create(
            task = trimmedTitle,
            notes = notes.trim()
        )
    }

    fun toggleDone(id: java.util.UUID) {
        _toDos.value = _toDos.value.map { toDo ->
            if (toDo.id != id) return@map toDo

            when (toDo.lifecycleState) {
                ToDoState.ACTIVE, ToDoState.DONE -> toDo.toggleDone()
                ToDoState.ARCHIVED, ToDoState.TRASHED -> toDo
            }
        }
    }

    fun moveToTrash(id: java.util.UUID) {
        _toDos.value = _toDos.value.map { toDo ->
            if (toDo.id == id) toDo.transition(ToDoState.TRASHED) else toDo
        }
    }

    fun update(toDo: ToDo) {
        _toDos.value = _toDos.value.map { current ->
            if (current.id == toDo.id) toDo else current
        }
    }
}

/** Lifecycle-scoped presentation store; this is not a ViewModel architecture boundary. */
class ToDoStore(application: Application) : AndroidViewModel(application) {
    private val todoApplication = application as ToDoApplication
    private val syncScopeProvider: AuthenticatedSyncScopeProvider by lazy {
        AuthenticatedSyncScopeProvider(todoApplication.authSessionProvider)
    }
    private val database: ToDoDatabase by lazy { ToDoDatabase.getInstance(application) }
    private val repository: RoomToDoRepository by lazy {
        RoomToDoRepository(
            database = database,
            syncScopeProvider = { syncScopeProvider.currentScope() },
            originDeviceId = DeviceIdentityStore(application).deviceId
        )
    }

    // Database construction and domain aggregate assembly stay off the main
    // thread. The StateFlow itself remains lifecycle-scoped and lightweight for
    // Compose collectors.
    val toDos: StateFlow<List<ToDo>> = flow {
        emitAll(repository.toDos)
    }.flowOn(Dispatchers.IO).stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(stopTimeoutMillis = 5_000),
        initialValue = emptyList()
    )

    fun create(title: String, notes: String = "") {
        viewModelScope.launch(Dispatchers.IO) {
            repository.create(title, notes)
            flushAuthenticatedOutbox()
        }
    }

    fun toggleDone(id: java.util.UUID) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.toggleDone(id)
            flushAuthenticatedOutbox()
        }
    }

    fun update(toDo: ToDo) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.update(toDo)
            flushAuthenticatedOutbox()
        }
    }

    fun moveToTrash(id: java.util.UUID) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.moveToTrash(id)
            flushAuthenticatedOutbox()
        }
    }

    private suspend fun flushAuthenticatedOutbox() {
        syncScopeProvider.currentScope()?.let { scope ->
            todoApplication.syncEngine.flush(scope)
        }
    }
}
