// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.i18n

import com.flash.app.data.model.Category
import com.flash.app.ui.capture.isTypedTrailingReturn
import com.flash.app.ui.home.greetingSource
import com.flash.app.ui.navigation.AppEntry
import java.io.File
import java.time.LocalDate
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class EntryAndLocaleTest {
    @Test
    fun deepLinksOnlyOpenScreens() {
        assertEquals(AppEntry.Capture(Category.IDEA), AppEntry.parse("flash://capture"))
        assertEquals(AppEntry.Capture(Category.LOG), AppEntry.parse("flash://capture?category=log"))
        assertEquals(AppEntry.Today, AppEntry.parse("flash://today"))
        assertEquals(AppEntry.Ideas, AppEntry.parse("flash://ideas"))
        // 不接受正文或其他路径
        assertEquals(AppEntry.Capture(Category.IDEA), AppEntry.parse("flash://capture?text=secret"))
        assertNull(AppEntry.parse("flash://delete"))
        assertNull(AppEntry.parse("https://example.com"))
        assertNull(AppEntry.parse(null))
    }

    @Test
    fun typedReturnSavesButPasteKeepsNewlines() {
        assertTrue(isTypedTrailingReturn("想法", "想法\n"))
        assertFalse(isTypedTrailingReturn("想法", "想法\n第二行\n"))
        assertFalse(isTypedTrailingReturn("想法", "想\n法"))
        assertFalse(isTypedTrailingReturn("", "粘贴"))
    }

    @Test
    fun greetingFollowsHour() {
        assertEquals("早上好 ☀️", greetingSource(5))
        assertEquals("下午好 🌤", greetingSource(11))
        assertEquals("晚上好 🌙", greetingSource(18))
        assertEquals("晚上好 🌙", greetingSource(4))
    }

    @Test
    fun placeholdersFillWithoutLocaleDigits() {
        val saved = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("ar"))
            assertEquals("共 12 条", tr("共 {0} 条", 12))
        } finally {
            Locale.setDefault(saved)
        }
    }

    /** 阿拉伯语等环境下，导出与存储值仍是 ASCII 数字，备份才能跨设备解析 */
    @Test
    fun exportsStayAsciiInArabicAndGerman() {
        val saved = Locale.getDefault()
        try {
            for (tag in listOf("ar", "de", "ar-EG", "fa")) {
                Locale.setDefault(Locale.forLanguageTag(tag))
                assertEquals("2026-08-13", LocalDate.of(2026, 8, 13).toString())
                val json = com.flash.app.data.Backup.exportJson(emptyList(), emptyList(), emptyList())
                assertFalse("non-ASCII digits under $tag: $json", Regex("[\\u0660-\\u0669\\u06F0-\\u06F9]").containsMatchIn(json))
                assertTrue(Regex("\"exportedAt\":\\s*\"\\d{4}-\\d{2}-\\d{2}T").containsMatchIn(json))
                com.flash.app.data.Backup.parseStrict(json)
            }
        } finally {
            Locale.setDefault(saved)
        }
    }

    /** 生成的各语言资源：键齐全，占位符一致（未生成时跳过） */
    @Test
    fun translatedResourcesAreComplete() {
        var dir = File("").absoluteFile
        while (!File(dir, "android/app/src/main/res").exists()) dir = dir.parentFile!!
        val res = File(dir, "android/app/src/main/res")
        val base = File(res, "values/strings_generated.xml")
        if (!base.exists()) return
        fun keys(file: File): Map<String, List<String>> {
            val text = file.readText()
            return Regex("<(?:string|plurals) name=\"([^\"]+)\"[^>]*>(.*?)</(?:string|plurals)>", RegexOption.DOT_MATCHES_ALL)
                .findAll(text)
                .associate { m -> m.groupValues[1] to Regex("\\{\\d+\\}").findAll(m.groupValues[2]).map { it.value }.toSet().sorted() }
        }
        val expected = keys(base)
        for (lang in listOf("zh", "fr", "ko", "de", "ru", "ar", "ja")) {
            val actual = keys(File(res, "values-$lang/strings_generated.xml"))
            assertEquals("values-$lang keys", expected.keys, actual.keys)
            expected.forEach { (key, placeholders) -> assertEquals("$lang $key", placeholders, actual[key]) }
        }
    }
}
