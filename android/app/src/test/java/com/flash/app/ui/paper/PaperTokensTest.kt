// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.paper

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import com.flash.app.ui.theme.PaperColors
import com.flash.app.ui.theme.PaperPair
import java.io.File
import kotlin.math.abs
import kotlin.math.pow
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** 「纸上书写」：Android 色值与跨端令牌文件逐项一致、满足 WCAG AA、不含纯黑；抖动算法与其他两端相同。 */
class PaperTokensTest {
    private val tokens: JSONObject = run {
        var dir = File("").absoluteFile
        while (!File(dir, "docs/design/paper-tokens.json").exists()) dir = dir.parentFile!!
        JSONObject(File(dir, "docs/design/paper-tokens.json").readText())
    }

    private fun hex(color: Color): String = "#%06X".format(color.toArgb() and 0xFFFFFF)

    private fun assertPair(pair: PaperPair?, json: JSONObject, name: String) {
        assertEquals("$name light", json.getString("light"), pair?.light?.let(::hex))
        assertEquals("$name dark", json.getString("dark"), pair?.dark?.let(::hex))
    }

    private fun luminance(hex: String): Double {
        val v = hex.removePrefix("#").toInt(16)
        val c = listOf((v shr 16) and 255, (v shr 8) and 255, v and 255).map {
            val x = it / 255.0
            if (x <= 0.03928) x / 12.92 else ((x + 0.055) / 1.055).pow(2.4)
        }
        return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    }

    private fun contrast(a: String, b: String): Double {
        val (x, y) = luminance(a) to luminance(b)
        return (maxOf(x, y) + 0.05) / (minOf(x, y) + 0.05)
    }

    @Test
    fun colorsMatchSharedTokens() {
        val colors = tokens.getJSONObject("colors")
        assertEquals(colors.keys().asSequence().toSet(), PaperColors.named.keys)
        colors.keys().forEach { assertPair(PaperColors.named[it], colors.getJSONObject(it), it) }
    }

    @Test
    fun dataColorsMatchSharedTokens() {
        val tags = tokens.getJSONObject("tags")
        assertEquals(tags.keys().asSequence().toSet(), PaperColors.tags.keys)
        tags.keys().forEach { name ->
            assertPair(PaperColors.tags[name]?.fill, tags.getJSONObject(name).getJSONObject("fill"), "$name fill")
            assertPair(PaperColors.tags[name]?.text, tags.getJSONObject(name).getJSONObject("text"), "$name text")
        }
        val moods = tokens.getJSONObject("moods")
        moods.keys().forEach { assertPair(PaperColors.moods[it.toInt()], moods.getJSONObject(it), "mood $it") }
        val subs = tokens.getJSONObject("subEmotions")
        subs.keys().forEach { assertPair(PaperColors.subEmotions[it], subs.getJSONObject(it), it) }
    }

    @Test
    fun contrastRulesPass() {
        val rules = tokens.getJSONArray("contrast")
        assertTrue(rules.length() > 0)
        for (i in 0 until rules.length()) {
            val rule = rules.getJSONObject(i)
            val fg = PaperColors.named.getValue(rule.getString("fg"))
            val min = rule.getDouble("min")
            val bgs = rule.getJSONArray("bg")
            for (j in 0 until bgs.length()) {
                val bg = PaperColors.named.getValue(bgs.getString(j))
                assertTrue("${rule.getString("fg")} on ${bgs.getString(j)} light", contrast(hex(fg.light), hex(bg.light)) >= min)
                assertTrue("${rule.getString("fg")} on ${bgs.getString(j)} dark", contrast(hex(fg.dark), hex(bg.dark)) >= min)
            }
        }
    }

    @Test
    fun noPureBlack() {
        PaperColors.named.forEach { (name, pair) ->
            assertNotEquals(name, "#000000", hex(pair.light))
            assertNotEquals(name, "#000000", hex(pair.dark))
        }
    }

    @Test
    fun jitterMatchesCrossPlatformVectors() {
        val vectors = tokens.getJSONArray("jitterVectors")
        assertTrue(vectors.length() > 0)
        for (i in 0 until vectors.length()) {
            val vector = vectors.getJSONObject(i)
            val jitter = SeededJitter(vector.getString("seed"))
            val values = vector.getJSONArray("values")
            for (j in 0 until values.length()) {
                assertTrue(abs(jitter.nextDouble() - values.getDouble(j)) < 1e-9)
            }
        }
    }
}
