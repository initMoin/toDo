package dev.iamshift.todo.android.core.model

import java.time.Instant
import java.util.UUID

data class Tag(
    val id: UUID = UUID.randomUUID(),
    val ownerUserId: UUID? = null,
    val name: String,
    val isDefault: Boolean = false,
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = createdAt
) {
    init {
        require(name.isNotBlank()) { "Tag name must not be blank" }
        require(name == normalizeName(name)) { "Tag name must be normalized before construction" }
    }

    val displayName: String
        get() = name

    val syncUpdatedAt: Instant
        get() = updatedAt

    fun withName(value: String, at: Instant = Instant.now()): Tag =
        create(
            name = value,
            id = id,
            ownerUserId = ownerUserId,
            isDefault = isDefault,
            createdAt = createdAt,
            updatedAt = at
        )

    companion object {
        const val MAX_NAME_LENGTH = 80
        val defaultTagNames = listOf("personal", "work", "health", "shopping", "ideas")

        fun normalizeName(value: String): String =
            value.trim().lowercase()

        fun create(
            name: String,
            id: UUID = UUID.randomUUID(),
            ownerUserId: UUID? = null,
            isDefault: Boolean = false,
            createdAt: Instant = Instant.now(),
            updatedAt: Instant = createdAt
        ): Tag {
            val normalized = normalizeName(name)
            require(normalized.isNotEmpty()) { "Tag name must not be blank" }
            require(normalized.length <= MAX_NAME_LENGTH) { "Tag name is too long" }
            return Tag(
                id = id,
                ownerUserId = ownerUserId,
                name = normalized,
                isDefault = isDefault,
                createdAt = createdAt,
                updatedAt = updatedAt
            )
        }

        /** Keeps one deterministic tag for each normalized name. */
        fun canonicalTags(tags: Iterable<Tag>): List<Tag> =
            tags.groupBy { normalizeName(it.name) }
                .values
                .mapNotNull { duplicates ->
                    duplicates
                        .sortedWith(
                            compareByDescending<Tag> { it.updatedAt }
                                .thenBy { it.createdAt }
                                .thenBy { it.id.toString() }
                        )
                        .firstOrNull()
                }
                .sortedBy { it.name }
    }
}
