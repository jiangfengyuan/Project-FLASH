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

/** 界面风格：MD3（Material Design 3 规范）或 GLASS（插画 × 玻璃拟态） */
enum class UiStyle(val storageKey: String, val displayName: String) {
    MD3("md3", "Material Design 3"),
    GLASS("glass", "玻璃拟态");

    companion object {
        fun fromStorage(key: String?): UiStyle =
            entries.firstOrNull { it.storageKey == key } ?: GLASS
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

    private val _uiStyle = MutableStateFlow(
        UiStyle.fromStorage(prefs.getString(KEY_UI_STYLE, null))
    )
    val uiStyle: StateFlow<UiStyle> = _uiStyle.asStateFlow()

    private val _welcomed = MutableStateFlow(prefs.getBoolean(KEY_WELCOMED, false))
    val welcomed: StateFlow<Boolean> = _welcomed.asStateFlow()

    fun setThemeMode(mode: ThemeMode) {
        _themeMode.value = mode
        prefs.edit { putString(KEY_THEME_MODE, mode.storageKey) }
    }

    fun setUiStyle(style: UiStyle) {
        _uiStyle.value = style
        prefs.edit { putString(KEY_UI_STYLE, style.storageKey) }
    }

    /** Welcome 页完成后调用 */
    fun setWelcomed() {
        _welcomed.value = true
        prefs.edit { putBoolean(KEY_WELCOMED, true) }
    }

    private companion object {
        const val KEY_THEME_MODE = "themeMode"
        const val KEY_UI_STYLE = "uiStyle"
        const val KEY_WELCOMED = "welcomed"
    }
}
