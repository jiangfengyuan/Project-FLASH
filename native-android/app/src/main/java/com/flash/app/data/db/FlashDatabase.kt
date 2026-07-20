package com.flash.app.data.db

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [LogEntity::class, EmotionEntity::class],
    version = 1,
    exportSchema = false,
)
abstract class FlashDatabase : RoomDatabase() {
    abstract fun logDao(): LogDao
    abstract fun emotionDao(): EmotionDao
}
