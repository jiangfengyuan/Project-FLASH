// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

/**
 * 用户输入长度上限，与 macOS TextLimits.swift 对齐：
 * 超限不再静默截断，而是拒绝写入，由各写入口 UI 给出可见提示并阻止保存。
 * 导入路径（Backup.parse*）逐条校验跳过，不走这里。
 */
object TextLimits {

    /** 正文/备注上限（备份契约 §3），与 Backup.MAX_FIELD_LENGTH 同值 */
    const val MAX_CONTENT_LENGTH = Backup.MAX_FIELD_LENGTH

    class ContentTooLongException(val actual: Int, val limit: Int) :
        IllegalArgumentException("内容过长（$actual 字），最多 $limit 字，请删减后再保存")

    fun fits(value: String, limit: Int = MAX_CONTENT_LENGTH): Boolean = value.length <= limit

    /** @throws ContentTooLongException 超限时抛出，绝不截断 */
    fun requireFits(value: String, limit: Int = MAX_CONTENT_LENGTH) {
        if (!fits(value, limit)) throw ContentTooLongException(value.length, limit)
    }
}
