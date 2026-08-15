package dev.iamshift.todo.android.core.settings

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Android-native, persisted counterpart to the Apple guided onboarding state. */
enum class GuidedTourStep(
    val title: String,
    val message: String,
    val primaryAction: String
) {
    WELCOME(
        "Welcome to toDō",
        "A focused task system designed for clarity, urgency, and momentum. Create what matters, complete it intentionally, and keep moving.",
        "Begin"
    ),
    HIGHLIGHT_ADD_BUTTON(
        "Create your first toDō",
        "Capture something important: a task, reminder, responsibility, or idea.",
        "Create toDō"
    ),
    OPEN_ADD_VIEW(
        "Start simple",
        "Write the task exactly how you think about it. You can add more detail whenever you need it.",
        "Continue"
    ),
    ENTER_TODO_TEXT(
        "Write the toDō",
        "Use your own words. Submit a project proposal, pick up groceries, or call Sarah at 4 PM all work.",
        "Continue"
    ),
    SAVE_TODO(
        "Save the toDō",
        "toDō keeps your tasks organized and ready to act on.",
        "Continue"
    ),
    CREATION_SUCCESS(
        "Good.",
        "Your first toDō is now active. From here, you can complete, archive, and refine your workflow over time.",
        "Continue"
    ),
    OPEN_CREATED_TODO(
        "Open your toDō",
        "Open the new row when you want to review or edit it. The back arrow returns you to the list.",
        "Continue"
    ),
    EDIT_EXISTING_TODO(
        "Make changes when needed",
        "Review your toDō and adjust it whenever the work changes.",
        "Continue"
    ),
    HIGHLIGHT_SETTINGS(
        "Configure your workflow",
        "Customize how toDō behaves, syncs, and notifies you. These choices can change later in Settings.",
        "Open Settings"
    ),
    SIGN_IN_AND_SYNC(
        "Choose where to keep your toDōs",
        "Stay local on this device or sign in to keep your toDōs available across your connected devices and platforms.",
        "Continue"
    ),
    NOTIFICATION_PERMISSION(
        "Enable reminders when you want them",
        "Reminder alerts only matter after you decide to use them. You can change notification access later in Android Settings.",
        "Continue"
    ),
    ARCHIVE_VS_DELETE(
        "Choose your behavior",
        "Decide whether removing a toDō should archive it or send it to Trash. Review the choice in Settings.",
        "Continue"
    ),
    COMPLETION(
        "You’re ready.",
        "toDō is designed to adapt to your workflow over time. Start small. Refine continuously.",
        "Enter toDō"
    );

    val isCompletion: Boolean
        get() = this == COMPLETION
}

class GuidedTourStore(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE
    )

    private val _isActive = MutableStateFlow(preferences.getBoolean(KEY_ACTIVE, false))
    val isActive: StateFlow<Boolean> = _isActive.asStateFlow()

    private val _currentStep = MutableStateFlow(
        preferences.getString(KEY_STEP, null)
            ?.let { raw -> GuidedTourStep.entries.firstOrNull { it.name == raw } }
            ?: GuidedTourStep.WELCOME
    )
    val currentStep: StateFlow<GuidedTourStep> = _currentStep.asStateFlow()

    fun restart() {
        persist(active = true, step = GuidedTourStep.WELCOME)
    }

    fun advance() {
        val currentIndex = _currentStep.value.ordinal
        val next = GuidedTourStep.entries.getOrNull(currentIndex + 1)
        if (next == null || next.isCompletion) {
            complete()
        } else {
            persist(active = true, step = next)
        }
    }

    fun advanceTo(step: GuidedTourStep) {
        persist(active = true, step = step)
    }

    fun complete() {
        preferences.edit()
            .putBoolean(KEY_ACTIVE, false)
            .remove(KEY_STEP)
            .apply()
        _isActive.value = false
        _currentStep.value = GuidedTourStep.COMPLETION
    }

    private fun persist(active: Boolean, step: GuidedTourStep) {
        preferences.edit()
            .putBoolean(KEY_ACTIVE, active)
            .putString(KEY_STEP, step.name)
            .apply()
        _isActive.value = active
        _currentStep.value = step
    }

    private companion object {
        const val PREFERENCES_NAME = "todo_guided_tour"
        const val KEY_ACTIVE = "active"
        const val KEY_STEP = "step"
    }
}
