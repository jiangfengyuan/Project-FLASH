// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.welcome

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.EditNote
import androidx.compose.material.icons.filled.Mood
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.flash.app.i18n.tr
import com.flash.app.ui.components.rememberFlashHaptics
import com.flash.app.ui.paper.HandDrawnRing
import com.flash.app.ui.theme.FlashTokens
import com.flash.app.ui.theme.ModuleColors
import kotlinx.coroutines.launch

private data class WelcomePage(val icon: ImageVector, val tint: @Composable () -> Color, val title: String, val subtitle: String)

/** 欢迎页（对齐 iOS）：首次启动三页横滑，手绘圈图标；「开始使用」后不再出现。 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun WelcomeScreen(onStart: () -> Unit) {
    val pages = listOf(
        WelcomePage(Icons.Filled.Bolt, { MaterialTheme.colorScheme.primary }, tr("欢迎来到 Flash"), tr("一闪而过的想法，值得被记住")),
        WelcomePage(Icons.Filled.EditNote, { ModuleColors.Log }, tr("随手记录"), tr("日志与灵感，一键即达")),
        WelcomePage(Icons.Filled.Mood, { ModuleColors.Emotion }, tr("情绪觉察"), tr("七级情绪记录，看见自己的变化")),
    )
    val pager = rememberPagerState { pages.size }
    val scope = rememberCoroutineScope()
    val haptics = rememberFlashHaptics()
    val last = pager.currentPage == pages.lastIndex

    LaunchedEffect(pager) {
        var previous = pager.currentPage
        snapshotFlow { pager.currentPage }.collect {
            if (it != previous) haptics.selection()
            previous = it
        }
    }

    Column(
        Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(horizontal = FlashTokens.Spacing.XL, vertical = FlashTokens.Spacing.LG),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        HorizontalPager(state = pager, modifier = Modifier.weight(1f).fillMaxWidth()) { index ->
            val page = pages[index]
            val tint = page.tint()
            Column(
                Modifier.fillMaxSize(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Box(contentAlignment = Alignment.Center) {
                    HandDrawnRing(seed = page.title, tint = tint, modifier = Modifier.size(128.dp))
                    Icon(page.icon, contentDescription = null, tint = tint, modifier = Modifier.size(56.dp))
                }
                Spacer(Modifier.height(FlashTokens.Spacing.XL))
                Text(
                    page.title,
                    style = MaterialTheme.typography.headlineLarge,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.semantics { heading() },
                )
                Spacer(Modifier.height(FlashTokens.Spacing.SM))
                Text(
                    page.subtitle,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            repeat(pages.size) { index ->
                Box(
                    Modifier
                        .size(if (index == pager.currentPage) 8.dp else 6.dp)
                        .clip(CircleShape)
                        .background(
                            if (index == pager.currentPage) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.outlineVariant,
                        ),
                )
            }
        }
        Spacer(Modifier.height(FlashTokens.Spacing.LG))
        Button(
            onClick = {
                if (last) onStart() else scope.launch { pager.animateScrollToPage(pager.currentPage + 1) }
            },
            colors = ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary,
            ),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(if (last) tr("开始使用") else tr("下一步"), modifier = Modifier.padding(vertical = 4.dp))
        }
    }
}
