package dev.iamshift.todo.android.core.settings

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Android preferences used by Settings and the shared Compose shell. */
class ToDoSettingsStore(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE
    )

    private val _appearanceMode = MutableStateFlow(
        AppearanceMode.fromRawValue(preferences.getString(KEY_APPEARANCE_MODE, null))
    )
    val appearanceMode: StateFlow<AppearanceMode> = _appearanceMode.asStateFlow()

    private val _showTagsWhileCreating = MutableStateFlow(
        preferences.getBoolean(KEY_SHOW_TAGS_WHILE_CREATING, false)
    )
    val showTagsWhileCreating: StateFlow<Boolean> = _showTagsWhileCreating.asStateFlow()

    private val _matchDeletesEverywhere = MutableStateFlow(
        preferences.getBoolean(KEY_MATCH_DELETES_EVERYWHERE, true)
    )
    val matchDeletesEverywhere: StateFlow<Boolean> = _matchDeletesEverywhere.asStateFlow()

    private val _doneSwipeAction = MutableStateFlow(
        DoneSwipeAction.fromRawValue(preferences.getString(KEY_DONE_SWIPE_ACTION, null))
    )
    val doneSwipeAction: StateFlow<DoneSwipeAction> = _doneSwipeAction.asStateFlow()

    fun setAppearanceMode(value: AppearanceMode) {
        preferences.edit().putString(KEY_APPEARANCE_MODE, value.rawValue).apply()
        _appearanceMode.value = value
    }

    fun setShowTagsWhileCreating(value: Boolean) {
        preferences.edit().putBoolean(KEY_SHOW_TAGS_WHILE_CREATING, value).apply()
        _showTagsWhileCreating.value = value
    }

    fun setMatchDeletesEverywhere(value: Boolean) {
        preferences.edit().putBoolean(KEY_MATCH_DELETES_EVERYWHERE, value).apply()
        _matchDeletesEverywhere.value = value
    }

    fun setDoneSwipeAction(value: DoneSwipeAction) {
        preferences.edit().putString(KEY_DONE_SWIPE_ACTION, value.rawValue).apply()
        _doneSwipeAction.value = value
    }

    fun resetChoices() {
        preferences.edit()
            .remove(KEY_SHOW_TAGS_WHILE_CREATING)
            .remove(KEY_MATCH_DELETES_EVERYWHERE)
            .remove(KEY_DONE_SWIPE_ACTION)
            .apply()
        _showTagsWhileCreating.value = false
        _matchDeletesEverywhere.value = true
        _doneSwipeAction.value = DoneSwipeAction.ARCHIVE
    }

    enum class AppearanceMode(val rawValue: String, val title: String) {
        SYSTEM("system", "System default"),
        LIGHT("light", "Light"),
        DARK("dark", "Dark");

        companion object {
            fun fromRawValue(value: String?): AppearanceMode =
                entries.firstOrNull { it.rawValue == value } ?: SYSTEM
        }

        fun resolvesToDark(systemIsDark: Boolean): Boolean = when (this) {
            SYSTEM -> systemIsDark
            LIGHT -> false
            DARK -> true
        }
    }

    enum class DoneSwipeAction(val rawValue: String, val title: String) {
        ARCHIVE("archive", "Archive"),
        TRASH("trash", "Move to Trash");

        companion object {
            fun fromRawValue(value: String?): DoneSwipeAction =
                entries.firstOrNull { it.rawValue == value } ?: ARCHIVE
        }
    }

    private companion object {
        const val PREFERENCES_NAME = "todo_settings"
        const val KEY_APPEARANCE_MODE = "appearance_mode"
        const val KEY_SHOW_TAGS_WHILE_CREATING = "show_tags_while_creating"
        const val KEY_MATCH_DELETES_EVERYWHERE = "match_deletes_everywhere"
        const val KEY_DONE_SWIPE_ACTION = "done_swipe_action"
    }
}
