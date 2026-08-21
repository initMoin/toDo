package dev.iamshift.todo.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import dev.iamshift.todo.android.core.model.ToDoState

class ToDoRepositoryTest {
    @Test
    fun createTrimsTitleAndIgnoresBlankTitles() {
        val repository = ToDoRepository()

        repository.create("  Plan Android parity  ", "  v3.1  ")
        repository.create("   ")

        assertEquals(1, repository.toDos.value.size)
        assertEquals("Plan Android parity", repository.toDos.value.single().task)
        assertEquals("v3.1", repository.toDos.value.single().notes)
    }

    @Test
    fun toggleDoneRecordsCompletionAndCanReopen() {
        val repository = ToDoRepository()
        repository.create("Ship the Android baseline")
        val id = repository.toDos.value.single().id

        repository.toggleDone(id)
        assertEquals(ToDoState.DONE, repository.toDos.value.single().lifecycleState)
        assertTrue(repository.toDos.value.single().completedAt != null)

        repository.toggleDone(id)
        assertEquals(ToDoState.ACTIVE, repository.toDos.value.single().lifecycleState)
        assertEquals(null, repository.toDos.value.single().completedAt)
    }
}
