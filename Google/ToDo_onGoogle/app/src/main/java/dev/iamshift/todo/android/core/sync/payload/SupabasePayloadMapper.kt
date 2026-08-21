package dev.iamshift.todo.android.core.sync.payload

import dev.iamshift.todo.android.core.model.NanoDo
import dev.iamshift.todo.android.core.model.Tag
import dev.iamshift.todo.android.core.model.ToDo
import dev.iamshift.todo.android.core.sync.SyncScope

/**
 * Supabase wire mapping kept separate from the client SDK. The eventual
 * postgrest adapter can pass these serializable DTOs to supabase-kt.
 */
object SupabasePayloadMapper {
    const val TODOS_TABLE = "todos"
    const val NANODOS_TABLE = "nanodos"
    const val TAGS_TABLE = "tags"
    const val TODO_TAGS_TABLE = "todo_tags"
    const val TOMBSTONES_TABLE = "sync_tombstones"

    fun toDo(toDo: ToDo, scope: SyncScope): SyncToDoPayload =
        SyncToDoPayload.fromDomain(toDo, scope)

    fun nanoDo(nanoDo: NanoDo, scope: SyncScope): SyncNanoDoPayload =
        SyncNanoDoPayload.fromDomain(nanoDo, scope)

    fun tag(tag: Tag, scope: SyncScope): SyncTagPayload =
        SyncTagPayload.fromDomain(tag, scope)

    fun encodeToDo(toDo: ToDo, scope: SyncScope): String =
        SyncPayloadCodec.encodeToDo(toDo, scope)

    fun encodeNanoDo(nanoDo: NanoDo, scope: SyncScope): String =
        SyncPayloadCodec.encodeNanoDo(nanoDo, scope)

    fun encodeTag(tag: Tag, scope: SyncScope): String =
        SyncPayloadCodec.encodeTag(tag, scope)
}
