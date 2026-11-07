// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.theme

import androidx.compose.ui.graphics.Color
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.EmotionLevel
import com.flash.app.data.model.SubEmotion

/** 一对浅/深色值 */
data class PaperPair(val light: Color, val dark: Color) {
    fun resolve(isDark: Boolean): Color = if (isDark) dark else light
}

private fun pair(light: Long, dark: Long) = PaperPair(Color(light), Color(dark))

/**
 * 「纸上书写」色值（品牌标准 §08）。唯一来源是 `docs/design/paper-tokens.json`，
 * 由 PaperTokensTest 逐项核对。任何外观都不用纯黑。
 */
object PaperColors {
    val PageBackground = pair(0xFFFFF9ED, 0xFF1F1A16)
    val CardSurface = pair(0xFFFFFDF6, 0xFF2B2520)
    val WeakSurface = pair(0xFFF3EADA, 0xFF362E28)
    val Parchment = pair(0xFFEADFCB, 0xFF40372F)
    val WeakBorder = pair(0xFFE4D8C2, 0xFF4A4039)
    val TextPrimary = pair(0xFF2E2A26, 0xFFF4ECDF)
    val TextSecondary = pair(0xFF5E5044, 0xFFBFB2A3)
    val TextTertiary = pair(0xFF6B655E, 0xFFA89C8F)
    val BrandPrimary = pair(0xFFA84A24, 0xFFE9926C)
    val OnBrandPrimary = pair(0xFFFFFDF6, 0xFF26201B)
    val BrandFill = pair(0xFFD0683C, 0xFFE9926C)
    val ChipSelectedBackground = pair(0xFF2E2A26, 0xFFF4ECDF)
    val ChipSelectedForeground = pair(0xFFFFFDF6, 0xFF26201B)
    val LogPurple = pair(0xFF8A6A9E, 0xFFB79BC9)
    val IdeaYellow = pair(0xFFA9812A, 0xFFDDB565)
    val IdeaYellowText = pair(0xFF7A5A12, 0xFFDDB565)
    val CalendarGreen = pair(0xFF74906B, 0xFFA6C09C)
    val AccessibleGreen = pair(0xFF55714F, 0xFFA6C09C)
    val EmotionPink = pair(0xFFB47A80, 0xFFD9A5A8)
    val EmotionPinkText = pair(0xFF9C5560, 0xFFD9A5A8)
    val Destructive = pair(0xFFA63A2E, 0xFFE89A8E)
    val ShadowTint = pair(0xFF3B2A1E, 0xFF120D0A)
    val Scrim = pair(0xFF3B2A1E, 0xFF120D0A)

    /** 键同 paper-tokens.json 的 colors，供测试逐项比对 */
    val named: Map<String, PaperPair> = mapOf(
        "pageBackground" to PageBackground, "cardSurface" to CardSurface,
        "weakSurface" to WeakSurface, "parchment" to Parchment, "weakBorder" to WeakBorder,
        "textPrimary" to TextPrimary, "textSecondary" to TextSecondary, "textTertiary" to TextTertiary,
        "brandPrimary" to BrandPrimary, "onBrandPrimary" to OnBrandPrimary, "brandFill" to BrandFill,
        "chipSelectedBackground" to ChipSelectedBackground,
        "chipSelectedForeground" to ChipSelectedForeground,
        "logPurple" to LogPurple, "ideaYellow" to IdeaYellow, "ideaYellowText" to IdeaYellowText,
        "calendarGreen" to CalendarGreen, "accessibleGreen" to AccessibleGreen,
        "emotionPink" to EmotionPink, "emotionPinkText" to EmotionPinkText,
        "destructive" to Destructive, "shadowTint" to ShadowTint, "scrim" to Scrim,
    )

    data class TagTone(val fill: PaperPair, val text: PaperPair)

    val tags: Map<String, TagTone> = mapOf(
        "urgent" to TagTone(pair(0xFFC96A5E, 0xFFDB8C80), pair(0xFFA63A2E, 0xFFE89A8E)),
        "inspiration" to TagTone(pair(0xFFD6B04E, 0xFFC9A54F), pair(0xFF7A5A12, 0xFFDDB565)),
        "daily" to TagTone(pair(0xFF6E8FB3, 0xFF8FA9C6), pair(0xFF476A8F, 0xFFA5BBD3)),
        "memo" to TagTone(pair(0xFF7FA276, 0xFF9DB894), pair(0xFF55714F, 0xFFA6C09C)),
        "emotion" to TagTone(pair(0xFF94739F, 0xFFB79BC9), pair(0xFF7A5A86, 0xFFC4ACD3)),
        "idea" to TagTone(pair(0xFFD08A4E, 0xFFDDA26E), pair(0xFF94531C, 0xFFE5B288)),
    )

    val moods: Map<Int, PaperPair> = mapOf(
        -3 to pair(0xFF7A5A86, 0xFFA98BB5),
        -2 to pair(0xFFB08FB8, 0xFFC3A8CB),
        -1 to pair(0xFF9FB0C3, 0xFFA5B5C7),
        0 to pair(0xFFA9C7C8, 0xFFA3C2C3),
        1 to pair(0xFFA5C49A, 0xFF9DBB92),
        2 to pair(0xFFDDC57A, 0xFFDCC47C),
        3 to pair(0xFFE0A25E, 0xFFE3A768),
    )

    val subEmotions: Map<String, PaperPair> = mapOf(
        "sad" to pair(0xFFA393C2, 0xFFBCAED4),
        "angry" to pair(0xFFC97B70, 0xFFDB9A90),
        "uncomfortable" to pair(0xFFD59A62, 0xFFE0AF80),
    )
}

fun ColorTag.fillColor(isDark: Boolean): Color = PaperColors.tags.getValue(storageKey).fill.resolve(isDark)

fun ColorTag.textColor(isDark: Boolean): Color = PaperColors.tags.getValue(storageKey).text.resolve(isDark)

fun EmotionLevel.moodColor(isDark: Boolean): Color = PaperColors.moods.getValue(value).resolve(isDark)

fun SubEmotion.moodColor(isDark: Boolean): Color = PaperColors.subEmotions.getValue(storageKey).resolve(isDark)
