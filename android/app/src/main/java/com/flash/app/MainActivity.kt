// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalView
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.flash.app.data.ThemeMode
import com.flash.app.ui.navigation.FlashApp
import com.flash.app.ui.theme.FlashTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            FlashRoot()
        }
    }
}

@Composable
private fun FlashRoot() {
    val app = androidx.compose.ui.platform.LocalContext.current.applicationContext as FlashApplication
    val themeMode by app.settings.themeMode.collectAsStateWithLifecycle()
    val uiStyle by app.settings.uiStyle.collectAsStateWithLifecycle()

    val systemDark = isSystemInDarkTheme()
    val darkTheme = when (themeMode) {
        ThemeMode.SYSTEM -> systemDark
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
    }

    // 系统栏图标颜色跟随 App 主题（onCreate 的 enableEdgeToEdge 只按系统主题设一次）
    val view = LocalView.current
    SideEffect {
        (view.context as? ComponentActivity)?.enableEdgeToEdge(
            statusBarStyle = if (darkTheme) {
                SystemBarStyle.dark(android.graphics.Color.TRANSPARENT)
            } else {
                SystemBarStyle.light(
                    android.graphics.Color.TRANSPARENT,
                    android.graphics.Color.TRANSPARENT,
                )
            },
            navigationBarStyle = if (darkTheme) {
                SystemBarStyle.dark(android.graphics.Color.TRANSPARENT)
            } else {
                SystemBarStyle.light(
                    android.graphics.Color.TRANSPARENT,
                    android.graphics.Color.TRANSPARENT,
                )
            },
        )
    }

    FlashTheme(darkTheme = darkTheme, uiStyle = uiStyle) {
        FlashApp(darkTheme = darkTheme, uiStyle = uiStyle)
    }
}
