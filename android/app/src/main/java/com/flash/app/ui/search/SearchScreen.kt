// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.search

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.EditNote
import androidx.compose.material.icons.filled.Mood
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.flash.app.FlashApplication
import com.flash.app.domain.GlobalSearch
import com.flash.app.domain.SearchMatch
import com.flash.app.domain.SearchMatchKind
import com.flash.app.i18n.tr
import com.flash.app.ui.components.FlashEmptyState
import com.flash.app.ui.paper.PaperCard
import com.flash.app.ui.paper.pageGutter
import com.flash.app.ui.theme.FlashTokens
import com.flash.app.ui.theme.ModuleColors
import java.time.LocalDate
import kotlinx.coroutines.delay

/** 全局搜索（对齐 iOS）：跨日志 / 灵感 / 情绪 / 任务，200ms 防抖，分组，命中词高亮，跨 Tab 定位。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchScreen(
    onBack: () -> Unit,
    onOpenLog: (String) -> Unit,
    onOpenEmotion: () -> Unit,
    onOpenTask: (date: String?) -> Unit,
) {
    val app = LocalContext.current.applicationContext as FlashApplication
    val logs by app.repository.logs.collectAsState(emptyList())
    val emotions by app.repository.emotions.collectAsState(emptyList())
    val tasks by app.repository.tasks.collectAsState(emptyList())
    var query by remember { mutableStateOf("") }
    var applied by remember { mutableStateOf("") }
    val focus = remember { FocusRequester() }

    LaunchedEffect(Unit) { focus.requestFocus() }
    LaunchedEffect(query) {
        if (query.isBlank()) {
            applied = ""
        } else {
            delay(200)
            applied = query
        }
    }
    val matches = remember(applied, logs, emotions, tasks) { GlobalSearch.search(logs, emotions, tasks, applied) }
    val groups = remember(matches) {
        listOf(SearchMatchKind.LOG, SearchMatchKind.EMOTION, SearchMatchKind.TASK).mapNotNull { kind ->
            matches.filter { it.kind == kind }.takeIf { it.isNotEmpty() }?.let { kind to it }
        }
    }

    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(tr("搜索")) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = tr("关闭"))
                    }
                },
            )
        },
    ) { padding ->
        val gutter = pageGutter()
        Column(Modifier.padding(padding).fillMaxSize().padding(horizontal = gutter)) {
            OutlinedTextField(
                value = query,
                onValueChange = { query = it.take(200) },
                placeholder = { Text(tr("关键词或标签")) },
                leadingIcon = { Icon(Icons.Filled.Search, null, tint = MaterialTheme.colorScheme.primary) },
                trailingIcon = if (query.isNotEmpty()) {
                    {
                        IconButton(onClick = { query = "" }) {
                            Icon(Icons.Filled.Close, contentDescription = tr("清除搜索"))
                        }
                    }
                } else {
                    null
                },
                singleLine = true,
                shape = RoundedCornerShape(FlashTokens.Radius.Field),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                    unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                    unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant,
                ),
                modifier = Modifier.fillMaxWidth().focusRequester(focus),
            )
            when {
                applied.isBlank() -> FlashEmptyState(
                    title = tr("搜索记录、灵感、情绪与任务"),
                    icon = Icons.Filled.Search,
                    ringSeed = "search",
                    description = tr("输入关键词或标签名"),
                )
                matches.isEmpty() -> FlashEmptyState(
                    title = tr("没有找到相关记录"),
                    icon = Icons.Filled.Search,
                    ringSeed = "search-none",
                )
                else -> LazyColumn(
                    contentPadding = PaddingValues(vertical = FlashTokens.Spacing.SM),
                    verticalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.XS),
                ) {
                    groups.forEach { (kind, items) ->
                        item(key = "h-$kind") {
                            Text(
                                "${kind.displayName} · ${items.size}",
                                style = MaterialTheme.typography.titleSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(top = FlashTokens.Spacing.XS).semantics { heading() },
                            )
                        }
                        items(items, key = { "${it.kind}-${it.id}" }) { match ->
                            SearchRow(match, applied) {
                                when (match.kind) {
                                    SearchMatchKind.LOG -> onOpenLog(match.id)
                                    SearchMatchKind.EMOTION -> onOpenEmotion()
                                    SearchMatchKind.TASK -> onOpenTask(tasks.firstOrNull { it.id == match.id }?.calendarDate)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SearchRow(match: SearchMatch, query: String, onClick: () -> Unit) {
    val (icon, tint) = when (match.kind) {
        SearchMatchKind.LOG -> Icons.Filled.EditNote to ModuleColors.Log
        SearchMatchKind.EMOTION -> Icons.Filled.Mood to ModuleColors.Emotion
        SearchMatchKind.TASK -> Icons.Filled.CheckCircle to ModuleColors.CalendarText
    }
    val brand = MaterialTheme.colorScheme.primary
    PaperCard(
        seed = match.id,
        cornerRadius = FlashTokens.Radius.Row,
        contentPadding = FlashTokens.Spacing.SM,
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(FlashTokens.Spacing.SM)) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(20.dp))
            Text(
                highlighted(match.title, query, SpanStyle(color = brand, fontWeight = FontWeight.SemiBold)),
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            Text(
                relativeDay(match.createdAt),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.outline,
            )
        }
    }
}

/** 命中词加粗 + 品牌色（大小写不敏感，与 GlobalSearch 同口径） */
internal fun highlighted(title: String, query: String, style: SpanStyle): AnnotatedString {
    val needle = query.trim()
    if (needle.isEmpty()) return AnnotatedString(title)
    return buildAnnotatedString {
        var start = 0
        while (start < title.length) {
            val hit = title.indexOf(needle, start, ignoreCase = true)
            if (hit < 0) break
            append(title.substring(start, hit))
            withStyle(style) { append(title.substring(hit, hit + needle.length)) }
            start = hit + needle.length
        }
        append(title.substring(start))
    }
}

/** 今天 / 昨天 / 否则原日期（只取日期部分，语言无关） */
private fun relativeDay(createdAt: String): String {
    val day = createdAt.take(10)
    val today = LocalDate.now()
    return when (day) {
        today.toString() -> tr("今天")
        today.minusDays(1).toString() -> tr("昨天")
        else -> day
    }
}
