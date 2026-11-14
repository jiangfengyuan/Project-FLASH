// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app

import android.app.Application
import androidx.room.Room
import com.flash.app.data.FlashRepository
import com.flash.app.data.BackupTransfer
import com.flash.app.data.SettingsStore
import com.flash.app.data.db.FlashDatabase
import com.flash.app.data.reminder.TaskReminderScheduler

class FlashApplication : Application() {

    lateinit var repository: FlashRepository
        private set
    lateinit var settings: SettingsStore
        private set
    lateinit var taskReminders: TaskReminderScheduler
        private set
    /** 应用锁状态随进程存活：配置变更重建 Activity 不重新上锁，进程重启即冷启动上锁 */
    lateinit var appLock: com.flash.app.data.AppLockController
        private set

    /** 深链、通知与系统分享交给界面层的待处理入口 */
    val pendingEntry = kotlinx.coroutines.flow.MutableStateFlow<com.flash.app.ui.navigation.AppEntry?>(null)

    override fun onCreate() {
        super.onCreate()
        com.flash.app.i18n.Strings.install(this)
        BackupTransfer.cleanupExpired(this)
        // 数据库名与 Capacitor 版保持一致
        val db = Room.databaseBuilder(this, FlashDatabase::class.java, "flash-db")
            .addMigrations(FlashDatabase.MIGRATION_1_2)
            .addMigrations(FlashDatabase.MIGRATION_2_3)
            .addMigrations(FlashDatabase.MIGRATION_3_4)
            .addMigrations(FlashDatabase.MIGRATION_4_5)
            .build()
        repository = FlashRepository(db)
        settings = SettingsStore(this)
        appLock = com.flash.app.data.AppLockController(
            isEnabled = { settings.appLockEnabled.value },
            isAvailable = { com.flash.app.system.AppLockAuthenticator.isDeviceSecure(this) },
        )
        taskReminders = TaskReminderScheduler(this)
        com.flash.app.data.reminder.IdeaReminderWork.sync(this, settings.ideaReminderEnabled.value)
        com.flash.app.widget.TodayWidgetUpdater.observe(this, repository)
    }
}
