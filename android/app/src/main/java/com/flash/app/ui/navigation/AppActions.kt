// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.navigation

import androidx.compose.runtime.compositionLocalOf
import com.flash.app.data.model.Category

/** 全局动作：任何页面都能唤起快速记录、新建任务（可带灵感来源）、提示与撤销。 */
data class AppActions(
    val quickCapture: (Category) -> Unit = {},
    val newTask: () -> Unit = {},
    /** 灵感转任务：保留来源回链（sourceLogId） */
    val newTaskFromIdea: (id: String, title: String) -> Unit = { _, _ -> },
    val openTab: (String) -> Unit = {},
    val openSearch: () -> Unit = {},
    val openRecord: (String) -> Unit = {},
    /** 轻提示：纯文案 1.6 秒，带操作（撤销）4 秒 */
    val toast: (message: String, actionLabel: String?, action: (suspend () -> Unit)?) -> Unit = { _, _, _ -> },
)

val LocalAppActions = compositionLocalOf { AppActions() }
