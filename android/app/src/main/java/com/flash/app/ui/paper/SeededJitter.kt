// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.paper

/** 种子确定的伪随机序列（FNV-1a 散列 + SplitMix64），与 iOS / HarmonyOS 同算法，只用于装饰形状。 */
class SeededJitter(seed: String) {
    private var state: Long

    init {
        var hash = -0x340d631b7bdddcdbL // 0xcbf29ce484222325
        for (byte in seed.toByteArray(Charsets.UTF_8)) {
            hash = hash xor (byte.toLong() and 0xFF)
            hash *= 0x100000001b3L
        }
        state = hash
    }

    /** [-1, 1] 区间的下一个值 */
    fun next(): Float = nextDouble().toFloat()

    fun nextDouble(): Double {
        state += -0x61c8864680b583ebL // 0x9E3779B97F4A7C15
        var z = state
        z = (z xor (z ushr 30)) * -0x40a7b892e31b1a47L // 0xBF58476D1CE4E5B9
        z = (z xor (z ushr 27)) * -0x6b2fb644ecceee15L // 0x94D049BB133111EB
        z = z xor (z ushr 31)
        return (z ushr 11).toDouble() / (1L shl 53).toDouble() * 2 - 1
    }
}
