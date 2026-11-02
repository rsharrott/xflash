package com.japaneseinaflash.app.data

import com.japaneseinaflash.app.study.LEARNED_LEVEL
import com.japaneseinaflash.app.study.STARRED_TAG_ID
import com.japaneseinaflash.app.study.levelTimesCount
import com.japaneseinaflash.app.study.nextLevel
import com.japaneseinaflash.app.study.pickCardLevel
import com.japaneseinaflash.app.study.probabilityOfUnseen
import com.japaneseinaflash.app.study.seenCount
import com.japaneseinaflash.app.study.selectableLevelCount
import com.japaneseinaflash.app.study.starredFirst

data class TagRecord(
    val id: Long,
    val name: String,
    val nameJa: String,
    val count: Int,
    val editable: Boolean,
)

data class GroupRecord(
    val id: Long,
    val name: String,
    val nameJa: String,
    val recommended: Int,
    val setCount: Int,
    val childGroups: Int,
)

data class PracticeCard(
    val detail: CardDetail,
    val kanaOnly: Boolean,
    val level: Int,
    val rightCount: Int,
    val wrongCount: Int,
)

class StudyStore(private val repository: DictionaryRepository) {
    fun tag(id: Long): TagRecord? =
        repository.query(StudySql.tagById(), arrayOf(id.toString()), ::readTag).firstOrNull()

    fun levelCounts(tag: TagRecord, userId: Long): IntArray {
        val rows = repository.query(
            StudySql.levelCounts(StudySql.owns(tag.id, if (tag.editable) 1 else 0)),
            arrayOf(userId.toString(), tag.id.toString()),
        ) { cursor -> cursor.getInt(0) to cursor.getInt(1) }
        return StudySql.levelsFrom(rows)
    }

    fun practiceCard(cardId: Long, userId: Long): PracticeCard? {
        val detail = repository.query(StudySql.PRACTICE_CARD, arrayOf(cardId.toString())) { cursor ->
            val senses = parseMeaning(cursor.getString(4))
            val kanaOnly = cursor.getInt(5) != 0
            kanaOnly to CardDetail(
                id = cursor.getLong(0),
                headword = cursor.getString(1).orEmpty(),
                reading = cursor.getString(2).orEmpty(),
                romaji = cursor.getString(3).orEmpty(),
                senses = senses,
            )
        }.firstOrNull() ?: return null
        val history = repository.query(
            StudySql.HISTORY,
            arrayOf(cardId.toString(), userId.toString()),
        ) { cursor ->
            Triple(cursor.getInt(0), cursor.getInt(1), cursor.getInt(2))
        }.firstOrNull()
        val sentences = repository.loadCard(cardId)?.sentences.orEmpty()
        return PracticeCard(
            detail = detail.second.copy(sentences = sentences),
            kanaOnly = detail.first,
            level = history?.third ?: 0,
            rightCount = history?.first ?: 0,
            wrongCount = history?.second ?: 0,
        )
    }

    fun cardAtLevel(tag: TagRecord, userId: Long, level: Int, avoid: Long?): Long? {
        val owned = StudySql.owns(tag.id, if (tag.editable) 1 else 0)
        val picked = avoid?.let { skip ->
            repository.query(
                StudySql.cardAtLevel(owned, avoid = true),
                arrayOf(userId.toString(), tag.id.toString(), level.toString(), skip.toString()),
            ) { it.getLong(0) }.firstOrNull()
        }
        if (picked != null) return picked
        return repository.query(
            StudySql.cardAtLevel(owned, avoid = false),
            arrayOf(userId.toString(), tag.id.toString(), level.toString()),
        ) { it.getLong(0) }.firstOrNull()
    }

    fun nextPracticeCard(
        tag: TagRecord,
        userId: Long,
        maxCards: Int,
        frequency: Int,
        hideLearned: Boolean,
        random: Double,
        avoid: Long?,
    ): PracticeCard? {
        val levels = levelCounts(tag, userId)
        if (levels.sum() == 0) return null
        val numLevels = selectableLevelCount(levels, hideLearned)
        val seen = seenCount(levels, numLevels)
        val unseen = probabilityOfUnseen(
            cardsSeen = seen,
            totalCards = levels.sum(),
            levelTimesCount = levelTimesCount(levels, numLevels),
            studyingCount = levels.getOrElse(1) { 0 },
            maxCards = maxCards,
            frequency = frequency,
        )
        val level = pickCardLevel(levels, numLevels, unseen, random)
        if (level < 0) return null
        val id = cardAtLevel(tag, userId, level, avoid) ?: return null
        return practiceCard(id, userId)
    }

    fun record(card: PracticeCard, userId: Long, right: Boolean) {
        val level = nextLevel(card.level, right)
        val rightCount = card.rightCount + if (right) 1 else 0
        val wrongCount = card.wrongCount + if (right) 0 else 1
        repository.exec(StudySql.RECORD, card.detail.id, userId, rightCount, wrongCount, level)
    }

    fun topGroupId(): Long? =
        repository.query(StudySql.TOP_GROUP, emptyArray()) { it.getLong(0) }.firstOrNull()

    fun groups(ownerId: Long): List<GroupRecord> =
        repository.query(StudySql.GROUPS_BY_OWNER, arrayOf(ownerId.toString()), ::readGroup)

    fun group(id: Long): GroupRecord? =
        repository.query(StudySql.GROUP_BY_ID, arrayOf(id.toString()), ::readGroup).firstOrNull()

    fun tagsInGroup(groupId: Long): List<TagRecord> =
        repository.query(StudySql.TAGS_IN_GROUP, arrayOf(groupId.toString()), ::readTag)

    fun mySets(): List<TagRecord> =
        starredFirst(
            repository.query(StudySql.USER_SETS, emptyArray(), ::readTag),
        ) { it.id }

    fun searchTags(query: String, groupId: Long?): List<TagRecord> {
        val like = "%${query.replace("%", "").replace("_", "")}%"
        return if (groupId == null) {
            repository.query(StudySql.SEARCH_TAGS, arrayOf(like, like), ::readTag)
        } else {
            repository.query(
                StudySql.SEARCH_TAGS_IN_GROUP,
                arrayOf(groupId.toString(), like, like),
                ::readTag,
            )
        }
    }

    fun createSet(name: String): Long? {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return null
        val owner = topGroupId() ?: return null
        return repository.transaction {
            repository.exec(StudySql.INSERT_TAG, trimmed)
            val id = repository.query("SELECT last_insert_rowid()", emptyArray()) { it.getLong(0) }.first()
            repository.exec(StudySql.LINK_TAG, id, owner)
            repository.exec(StudySql.BUMP_GROUP, owner)
            id
        }
    }

    fun userSetsForCard(cardId: Long): List<Pair<TagRecord, Boolean>> =
        mySets().map { tag ->
            val member = repository.query(
                StudySql.MEMBER_USER,
                arrayOf(tag.id.toString(), cardId.toString()),
            ) { 1 }.isNotEmpty()
            tag to member
        }

    fun builtInSetsWithCard(cardId: Long): List<TagRecord> =
        repository.query(StudySql.BUILTIN_WITH_CARD, arrayOf(cardId.toString())) { cursor ->
            TagRecord(
                id = cursor.getLong(0),
                name = cursor.getString(1).orEmpty(),
                nameJa = cursor.getString(2).orEmpty(),
                count = 0,
                editable = false,
            )
        }

    fun setMembership(tagId: Long, cardId: Long, member: Boolean) {
        if (tagId != STARRED_TAG_ID) {
            val tag = tag(tagId) ?: return
            if (!tag.editable) return
        }
        repository.transaction {
            val already = repository.query(
                StudySql.MEMBER_USER,
                arrayOf(tagId.toString(), cardId.toString()),
            ) { 1 }.isNotEmpty()
            if (member && !already) {
                repository.exec(StudySql.INSERT_MEMBER, cardId, tagId)
                repository.exec(StudySql.BUMP_TAG_COUNT, 1, 1, tagId)
            } else if (!member && already) {
                repository.exec(StudySql.DELETE_MEMBER, cardId, tagId)
                repository.exec(StudySql.BUMP_TAG_COUNT, -1, -1, tagId)
            }
        }
    }

    fun setActive(tagId: Long) {
        // The preference store holds the active id. This only checks the tag exists.
        check(tag(tagId) != null)
    }

    private fun readTag(cursor: android.database.Cursor) = TagRecord(
        id = cursor.getLong(0),
        name = cursor.getString(1).orEmpty(),
        nameJa = cursor.getString(2).orEmpty(),
        count = cursor.getInt(3),
        editable = cursor.getInt(4) != 0 || cursor.getLong(0) == STARRED_TAG_ID,
    )

    private fun readGroup(cursor: android.database.Cursor) = GroupRecord(
        id = cursor.getLong(0),
        name = cursor.getString(1).orEmpty(),
        nameJa = cursor.getString(2).orEmpty(),
        recommended = cursor.getInt(3),
        setCount = cursor.getInt(4),
        childGroups = cursor.getInt(5),
    )

    companion object {
        const val MAX_LEARNED = LEARNED_LEVEL
    }
}
