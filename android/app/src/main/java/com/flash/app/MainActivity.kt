// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app

import android.content.Intent
import android.os.Build
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
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.lifecycle.Lifecycle
import com.flash.app.data.AppLockAuthResult
import com.flash.app.data.ThemeMode
import com.flash.app.data.model.Category
import com.flash.app.system.AppLockAuthenticator
import com.flash.app.ui.lock.AppLockGate
import com.flash.app.ui.lock.LocalAppLockAuth
import com.flash.app.ui.lock.AppLockAuth
import com.flash.app.ui.lock.requestUnlock
import com.flash.app.ui.navigation.AppEntry
import com.flash.app.ui.navigation.FlashApp
import com.flash.app.ui.theme.FlashTheme

class MainActivity : ComponentActivity() {
    /** 必须在构造期注册（Android 10 及以下的确认锁屏凭据页走 Activity Result） */
    private val authenticator = AppLockAuthenticator(this)
    private val lockAuth = object : AppLockAuth {
        override fun isAvailable() = authenticator.isAvailable()
        override fun authenticate(title: String, subtitle: String, onResult: (AppLockAuthResult) -> Unit) =
            authenticator.authenticate(title, subtitle, onResult)
    }
    private val appLock get() = (application as FlashApplication).appLock

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // 最近任务里不显示界面快照（日志、情绪、任务正文）；不同于 FLAG_SECURE，不拦截用户截屏。
        // Android 13 以下没有不禁截屏的等价开关，保持系统默认。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) setRecentsScreenshotEnabled(false)
        // 配置变更重建时不重复消费同一个 Intent
        if (savedInstanceState == null) deliver(intent)
        setContent {
            CompositionLocalProvider(LocalAppLockAuth provides lockAuth) {
                FlashRoot()
            }
        }
    }

    override fun onStart() {
        super.onStart()
        appLock.onForeground()
    }

    override fun onResume() {
        super.onResume()
        // 每次上锁自动弹一次系统验证；等窗口就绪再弹，取消后只能手动点「解锁」
        window.decorView.post {
            if (lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED) && appLock.consumeAutoPrompt()) {
                appLock.requestUnlock(lockAuth)
            }
        }
    }

    override fun onStop() {
        super.onStop()
        if (!isChangingConfigurations) appLock.onBackground()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        deliver(intent)
    }

    private fun deliver(intent: Intent?) {
        AppEntry.from(intent)?.let { (application as FlashApplication).pendingEntry.value = it }
    }
}

@Composable
private fun FlashRoot() {
    val app = androidx.compose.ui.platform.LocalContext.current.applicationContext as FlashApplication
    val themeMode by app.settings.themeMode.collectAsStateWithLifecycle()

    val systemDark = isSystemInDarkTheme()
    val darkTheme = when (themeMode) {
        ThemeMode.SYSTEM -> systemDark
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
    }

    // 系统栏图标颜色跟随 App 主题（onCreate 的 enableEdgeToEdge 只按系统主题设一次）
    val view = LocalView.current
    SideEffect {
        val transparent = android.graphics.Color.TRANSPARENT
        val style = if (darkTheme) {
            SystemBarStyle.dark(transparent)
        } else {
            SystemBarStyle.light(transparent, transparent)
        }
        (view.context as? ComponentActivity)?.enableEdgeToEdge(statusBarStyle = style, navigationBarStyle = style)
    }

    val lockAuth = LocalAppLockAuth.current
    FlashTheme(darkTheme = darkTheme) {
        Box(Modifier.fillMaxSize()) {
            FlashApp()
            if (lockAuth != null) {
                AppLockGate(
                    lock = app.appLock,
                    auth = lockAuth,
                    onQuickCapture = { app.pendingEntry.value = AppEntry.Capture(Category.IDEA) },
                )
            }
        }
    }
}
