// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
