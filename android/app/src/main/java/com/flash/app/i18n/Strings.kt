// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.i18n

import android.content.Context
import android.os.Build
import java.util.Locale

/**
 * 界面文案入口（键即简体中文原文，占位符写成 {0}、{1}）。
 *
 * 与 iOS / HarmonyOS 共用 `docs/i18n/translations.json`：`tools/i18n/generate.py` 生成
 * 各语言的 strings.xml 和 [I18nKeys]。未 [install] 时（JVM 单测）直接返回中文原文，
 * 所以领域层测试不依赖语言。存储值（日期、ID、备份字段）不得走这里。
 */
object Strings {
    @Volatile
    private var context: Context? = null

    fun install(appContext: Context) {
        context = appContext.applicationContext
    }

    fun get(source: String, args: Array<out Any?>): String {
        val ctx = context
        val strings = ctx?.resources
        val rendered = if (strings == null) {
            source
        } else {
            val plural = I18nKeys.plurals[source]
            val single = I18nKeys.strings[source]
            val count = args.firstOrNull { it is Int } as? Int
            val template = when {
                plural != null && count != null -> strings.getQuantityString(plural, count)
                single != null -> strings.getString(single)
                else -> source
            }
            template
        }
        return fill(rendered, args)
    }

    /** 替换 {0} {1}：不用 String.format，避免默认语言把数字改成本地数字 */
    private fun fill(template: String, args: Array<out Any?>): String {
        if (args.isEmpty()) return template
        var out = template
        args.forEachIndexed { index, value -> out = out.replace("{$index}", value.toString()) }
        return out
    }

    /** 当前界面语言是否使用随包的霞鹜文楷（只有中文） */
    fun usesBundledDisplayFont(): Boolean {
        val strings = context?.resources ?: return true
        val locale: Locale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            strings.configuration.locales[0]
        } else {
            @Suppress("DEPRECATION")
            strings.configuration.locale
        }
        return locale.language == "zh"
    }
}

/** 简写：tr("共 {0} 条", n) */
fun tr(source: String, vararg args: Any?): String = Strings.get(source, args)
