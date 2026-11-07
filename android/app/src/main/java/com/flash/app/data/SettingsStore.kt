// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class ThemeMode(val storageKey: String) {
    SYSTEM("system"),
    LIGHT("light"),
    DARK("dark");

    companion object {
        fun fromStorage(key: String?): ThemeMode =
            entries.firstOrNull { it.storageKey == key } ?: SYSTEM
    }
}

/** 灵感提醒频率（对齐 iOS：每天 / 每 3 天 / 每周，晚上 8 点） */
enum class IdeaReminderFrequency(val storageKey: String, val intervalDays: Long) {
    DAILY("daily", 1),
    EVERY_THREE_DAYS("every3days", 3),
    WEEKLY("weekly", 7);

    val displayName: String
        get() = when (this) {
            DAILY -> com.flash.app.i18n.tr("每天")
            EVERY_THREE_DAYS -> com.flash.app.i18n.tr("每 3 天")
            WEEKLY -> com.flash.app.i18n.tr("每周")
        }

    companion object {
        fun fromStorage(key: String?): IdeaReminderFrequency =
            entries.firstOrNull { it.storageKey == key } ?: DAILY
    }
}

/** 应用设置，SharedPreferences 持久化。对应 Web 版 themeStore。 */
class SettingsStore(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("flash-settings", Context.MODE_PRIVATE)

    private val _themeMode = MutableStateFlow(
        ThemeMode.fromStorage(prefs.getString(KEY_THEME_MODE, null))
    )
    val themeMode: StateFlow<ThemeMode> = _themeMode.asStateFlow()

    private val _welcomed = MutableStateFlow(prefs.getBoolean(KEY_WELCOMED, false))
    val welcomed: StateFlow<Boolean> = _welcomed.asStateFlow()

    fun setThemeMode(mode: ThemeMode) {
        _themeMode.value = mode
        prefs.edit { putString(KEY_THEME_MODE, mode.storageKey) }
    }

    private val _ideaReminderEnabled = MutableStateFlow(prefs.getBoolean(KEY_IDEA_REMINDER_ENABLED, true))
    val ideaReminderEnabled: StateFlow<Boolean> = _ideaReminderEnabled.asStateFlow()

    private val _ideaReminderFrequency = MutableStateFlow(
        IdeaReminderFrequency.fromStorage(prefs.getString(KEY_IDEA_REMINDER_FREQUENCY, null))
    )
    val ideaReminderFrequency: StateFlow<IdeaReminderFrequency> = _ideaReminderFrequency.asStateFlow()

    fun setIdeaReminderEnabled(enabled: Boolean) {
        _ideaReminderEnabled.value = enabled
        prefs.edit { putBoolean(KEY_IDEA_REMINDER_ENABLED, enabled) }
    }

    fun setIdeaReminderFrequency(frequency: IdeaReminderFrequency) {
        _ideaReminderFrequency.value = frequency
        prefs.edit { putString(KEY_IDEA_REMINDER_FREQUENCY, frequency.storageKey) }
    }

    /** 上次发出灵感提醒的时刻（毫秒），控制「每 3 天 / 每周」的间隔 */
    var ideaReminderLastFiredAt: Long
        get() = prefs.getLong(KEY_IDEA_REMINDER_LAST_FIRED, 0L)
        set(value) = prefs.edit { putLong(KEY_IDEA_REMINDER_LAST_FIRED, value) }

    /** 快速记录草稿（未提交时保留）；只存本机，不进备份 */
    var quickCaptureDraft: String
        get() = prefs.getString(KEY_QUICK_DRAFT, "").orEmpty()
        set(value) = prefs.edit { putString(KEY_QUICK_DRAFT, value) }

    /** Welcome 页完成后调用 */
    fun setWelcomed() {
        _welcomed.value = true
        prefs.edit { putBoolean(KEY_WELCOMED, true) }
    }

    private companion object {
        const val KEY_THEME_MODE = "themeMode"
        const val KEY_IDEA_REMINDER_ENABLED = "ideaReminderEnabled"
        const val KEY_IDEA_REMINDER_FREQUENCY = "ideaReminderFrequency"
        const val KEY_IDEA_REMINDER_LAST_FIRED = "ideaReminderLastFiredAt"
        const val KEY_QUICK_DRAFT = "quickCaptureDraft"
        const val KEY_WELCOMED = "welcomed"
    }
}
