// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.lock

import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.flash.app.data.AppLockAuthResult
import com.flash.app.data.AppLockController
import com.flash.app.i18n.tr
import com.flash.app.ui.paper.paperBackground
import com.flash.app.ui.theme.FlashTokens

/** Activity 提供的系统验证入口（设置页开关也要用） */
interface AppLockAuth {
    fun isAvailable(): Boolean
    fun authenticate(title: String, subtitle: String, onResult: (AppLockAuthResult) -> Unit)
}

val LocalAppLockAuth = compositionLocalOf<AppLockAuth?> { null }

/** 发起一次解锁验证（锁定页按钮与自动弹出共用） */
fun AppLockController.requestUnlock(auth: AppLockAuth) {
    if (!beginUnlock()) return
    auth.authenticate(tr("解锁 Flash"), tr("解锁 Flash 以查看你的记录")) { finishUnlock(it) }
}

/**
 * 锁定遮挡：窗口内先铺一层纸面（首帧就不露正文），再用全屏 Dialog 盖住此前已打开的弹窗。
 * 锁定后才打开的快速记录面板（磁贴 / 小组件 / 分享）在更上层，照常可写；只写不读。
 * 返回键把任务退到后台，不会绕过锁定页。
 */
@Composable
fun AppLockGate(lock: AppLockController, auth: AppLockAuth, onQuickCapture: () -> Unit) {
    val locked by lock.locked.collectAsStateWithLifecycle()
    if (!locked) return
    val activity = LocalActivity.current
    Box(Modifier.fillMaxSize().paperBackground())
    Dialog(
        onDismissRequest = { activity?.moveTaskToBack(true) },
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            decorFitsSystemWindows = false,
            dismissOnClickOutside = false,
        ),
    ) {
        AppLockScreen(
            lock = lock,
            onUnlock = { lock.requestUnlock(auth) },
            onQuickCapture = onQuickCapture,
        )
    }
}

@Composable
private fun AppLockScreen(lock: AppLockController, onUnlock: () -> Unit, onQuickCapture: () -> Unit) {
    val failed by lock.lastAttemptFailed.collectAsStateWithLifecycle()
    val authenticating by lock.authenticating.collectAsStateWithLifecycle()
    Box(
        Modifier
            .fillMaxSize()
            .paperBackground()
            .safeDrawingPadding()
            .padding(FlashTokens.Spacing.LG),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.XS),
        ) {
            Icon(
                Icons.Outlined.Lock,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(36.dp),
            )
            Spacer(Modifier.height(FlashTokens.Spacing.XS))
            Text(
                "✦ Flash",
                style = MaterialTheme.typography.headlineMedium,
                fontFamily = FontFamily.Serif,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.semantics { heading() },
            )
            Text(
                tr("Flash 已锁定"),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
            if (failed) {
                Text(
                    tr("未能验证身份，请重试"),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                    textAlign = TextAlign.Center,
                )
            }
            Spacer(Modifier.height(FlashTokens.Spacing.MD))
            Button(onClick = onUnlock, enabled = !authenticating, modifier = Modifier.widthIn(min = 160.dp)) {
                Text(tr("解锁"))
            }
            // 锁定时也能只写不读：面板开在锁定层之上
            TextButton(onClick = onQuickCapture) {
                Icon(Icons.Outlined.Edit, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(FlashTokens.Spacing.XS))
                Text(tr("快速记录"))
            }
        }
    }
}
