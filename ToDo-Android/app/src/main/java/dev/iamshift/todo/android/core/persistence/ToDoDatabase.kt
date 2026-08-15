package dev.iamshift.todo.android.core.persistence

import android.content.Context
import androidx.room3.Database
import androidx.room3.Room
import androidx.room3.RoomDatabase
import androidx.sqlite.driver.bundled.BundledSQLiteDriver

@Database(
    entities = [
        ToDoEntity::class,
        NanoDoEntity::class,
        TagEntity::class,
        ToDoTagEntity::class,
        SyncOutboxEntity::class
    ],
    version = 1,
    exportSchema = true
)
abstract class ToDoDatabase : RoomDatabase() {
    abstract fun toDoDao(): ToDoDao
    abstract fun nanoDoDao(): NanoDoDao
    abstract fun tagDao(): TagDao
    abstract fun toDoTagDao(): ToDoTagDao
    abstract fun syncOutboxDao(): SyncOutboxDao

    companion object {
        private const val DATABASE_NAME = "todo_android.db"

        @Volatile
        private var instance: ToDoDatabase? = null

        fun getInstance(context: Context): ToDoDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder<ToDoDatabase>(
                    context.applicationContext,
                    DATABASE_NAME
                )
                    .setDriver(BundledSQLiteDriver())
                    .build()
                    .also { instance = it }
            }
    }
}
