// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app

import android.app.Application
import androidx.room.Room
import com.flash.app.data.FlashRepository
import com.flash.app.data.SettingsStore
import com.flash.app.data.db.FlashDatabase

class FlashApplication : Application() {

    lateinit var repository: FlashRepository
        private set
    lateinit var settings: SettingsStore
        private set

    override fun onCreate() {
        super.onCreate()
        // 数据库名与 Capacitor 版保持一致
        val db = Room.databaseBuilder(this, FlashDatabase::class.java, "flash-db").build()
        repository = FlashRepository(db)
        settings = SettingsStore(this)
    }
}
