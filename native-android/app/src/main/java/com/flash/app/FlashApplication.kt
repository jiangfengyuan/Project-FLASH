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
