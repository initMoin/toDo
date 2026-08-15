package dev.iamshift.todo.android.core.model

enum class ToDoState(val rawValue: String) {
    ACTIVE("active"),
    DONE("done"),
    ARCHIVED("archived"),
    TRASHED("trashed");

    val isDone: Boolean
        get() = this == DONE

    companion object {
        fun fromRawValue(value: String?): ToDoState? =
            values().firstOrNull { it.rawValue == value }

        fun fromRawValueOrDefault(value: String?): ToDoState =
            fromRawValue(value) ?: ACTIVE
    }
}
enum class ToDoReminderIntent(val rawValue: String) {
    SOFT("soft"),
    DUE("due"),
    TIME_SENSITIVE("timeSensitive");

    companion object {
        fun fromRawValue(value: String?): ToDoReminderIntent? =
            values().firstOrNull { it.rawValue == value }
    }
}

enum class ToDoRecurrenceUnit(val rawValue: String) {
    SECONDS("seconds"),
    MINUTES("minutes"),
    HOURS("hours"),
    DAYS("days"),
    WEEKS("weeks"),
    MONTHS("months"),
    YEARS("years");

    companion object {
        fun fromRawValue(value: String?): ToDoRecurrenceUnit? =
            values().firstOrNull { it.rawValue == value }
    }
}

enum class ToDoRecurrenceMode(val rawValue: String) {
    FINITE("finite"),
    CONTINUOUS("continuous");

    companion object {
        fun fromRawValue(value: String?): ToDoRecurrenceMode? =
            values().firstOrNull { it.rawValue == value }
    }
}

enum class ToDoLocationReminderTrigger(val rawValue: String) {
    ARRIVING("arriving"),
    LEAVING("leaving");

    companion object {
        fun fromRawValue(value: String?): ToDoLocationReminderTrigger? =
            values().firstOrNull { it.rawValue == value }
    }
}
