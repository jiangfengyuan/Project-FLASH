// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data.db

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(
    entities = [LogEntity::class, EmotionEntity::class, IdeaViewStateEntity::class, TaskEntity::class],
    version = 4,
    exportSchema = true,
)
abstract class FlashDatabase : RoomDatabase() {
    abstract fun logDao(): LogDao
    abstract fun emotionDao(): EmotionDao
    abstract fun taskDao(): TaskDao

    companion object {
        /** v2 仅增加本地 Idea 阅读状态，不改动任何跨平台内容字段。 */
        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS `idea_view_state` (
                        `logId` TEXT NOT NULL,
                        `viewedAt` TEXT NOT NULL,
                        PRIMARY KEY(`logId`),
                        FOREIGN KEY(`logId`) REFERENCES `logs`(`id`)
                            ON UPDATE NO ACTION ON DELETE CASCADE
                    )
                    """.trimIndent()
                )
                // v1 没有阅读状态，不能把所有历史 Idea 冒充为“从未查看”。
                // 以原创建时间作为迁移基线；v2 后新建/新导入的 Idea 才进入提醒队列。
                db.execSQL(
                    """
                    INSERT OR IGNORE INTO `idea_view_state` (`logId`, `viewedAt`)
                    SELECT `id`, `createdAt` FROM `logs` WHERE `category` = 'idea'
                    """.trimIndent()
                )
            }
        }

        val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS `tasks` (
                        `id` TEXT NOT NULL,
                        `title` TEXT NOT NULL,
                        `notes` TEXT,
                        `colorTag` TEXT NOT NULL,
                        `importance` INTEGER NOT NULL,
                        `dueKind` TEXT NOT NULL,
                        `dueDate` TEXT,
                        `dueAt` TEXT,
                        `timeZone` TEXT,
                        `reminderAt` TEXT,
                        `completedAt` TEXT,
                        `createdAt` TEXT NOT NULL,
                        `updatedAt` TEXT NOT NULL,
                        PRIMARY KEY(`id`)
                    )
                    """.trimIndent()
                )
            }
        }

        /** Add indexes used by the timeline, calendar and task ordering paths. */
        val MIGRATION_3_4 = object : Migration(3, 4) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_logs_createdAt` ON `logs` (`createdAt`)")
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_logs_recordDate` ON `logs` (`recordDate`)")
                db.execSQL(
                    "CREATE INDEX IF NOT EXISTS `index_logs_category_createdAt` " +
                        "ON `logs` (`category`, `createdAt`)"
                )
                db.execSQL(
                    "CREATE INDEX IF NOT EXISTS `index_emotions_createdAt` ON `emotions` (`createdAt`)"
                )
                db.execSQL(
                    "CREATE INDEX IF NOT EXISTS `index_emotions_recordDate` ON `emotions` (`recordDate`)"
                )
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_tasks_updatedAt` ON `tasks` (`updatedAt`)")
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_tasks_dueDate` ON `tasks` (`dueDate`)")
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_tasks_dueAt` ON `tasks` (`dueAt`)")
            }
        }
    }
}
