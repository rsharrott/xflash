package com.japaneseinaflash.app.data

import com.japaneseinaflash.app.study.LEARNED_LEVEL
import com.japaneseinaflash.app.study.levelTimesCount
import com.japaneseinaflash.app.study.nextLevel
import com.japaneseinaflash.app.study.pickCardLevel
import com.japaneseinaflash.app.study.probabilityOfUnseen
import com.japaneseinaflash.app.study.seenCount
import com.japaneseinaflash.app.study.selectableLevelCount

data class TagRecord(
    val id: Long,
    val name: String,
    val nameJa: String,
    val count: Int,
    val editable: Boolean,
)

data class PracticePick(
    val card: PracticeCard,
    val allLearned: Boolean,
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
    ): PracticePick? {
        val levels = levelCounts(tag, userId)
        val total = levels.sum()
        if (total == 0) return null
        val learned = levels.getOrElse(LEARNED_LEVEL) { 0 }
        if (hideLearned && learned > 0 && total - learned == 0) {
            val id = cardAtLevel(tag, userId, LEARNED_LEVEL, avoid) ?: return null
            val card = practiceCard(id, userId) ?: return null
            return PracticePick(card, allLearned = true)
        }
        val numLevels = selectableLevelCount(levels, hideLearned)
        val seen = seenCount(levels, numLevels)
        val totalForMath = if (hideLearned) total - learned else total
        val unseen = probabilityOfUnseen(
            cardsSeen = seen,
            totalCards = totalForMath,
            levelTimesCount = levelTimesCount(levels, numLevels),
            studyingCount = levels.getOrElse(1) { 0 },
            maxCards = maxCards,
            frequency = frequency,
        )
        val level = pickCardLevel(levels, numLevels, unseen, random)
        if (level < 0) return null
        val id = cardAtLevel(tag, userId, level, avoid) ?: return null
        val card = practiceCard(id, userId) ?: return null
        return PracticePick(card, allLearned = false)
    }

    fun record(card: PracticeCard, userId: Long, right: Boolean) {
        val level = nextLevel(card.level, right)
        val rightCount = card.rightCount + if (right) 1 else 0
        val wrongCount = card.wrongCount + if (right) 0 else 1
        repository.exec(StudySql.RECORD, card.detail.id, userId, rightCount, wrongCount, level)
    }

    private fun readTag(cursor: android.database.Cursor) = TagRecord(
        id = cursor.getLong(0),
        name = cursor.getString(1).orEmpty(),
        nameJa = cursor.getString(2).orEmpty(),
        count = cursor.getInt(3),
        editable = cursor.getInt(4) != 0 || cursor.getLong(0) == 0L,
    )

    companion object {
        const val MAX_LEARNED = LEARNED_LEVEL
    }
}
