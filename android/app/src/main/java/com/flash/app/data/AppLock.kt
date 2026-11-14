// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * 应用锁（可选，默认关闭）：冷启动锁定；离开前台超过宽限期后回来再锁定。
 * 与 Apple `AppLockPolicy`、HarmonyOS `AppLock.ets` 同口径。
 */
class AppLockPolicy(gracePeriodMillis: Long) {
    val gracePeriodMillis: Long = gracePeriodMillis.coerceAtLeast(0)

    /** 系统时间被往回拨（now 早于离开时刻）按超时处理，不能靠改时钟绕过 */
    fun shouldLockOnReturn(enabled: Boolean, backgroundedAt: Long?, now: Long): Boolean {
        if (!enabled || backgroundedAt == null) return false
        val elapsed = now - backgroundedAt
        return elapsed < 0 || elapsed >= gracePeriodMillis
    }

    companion object {
        val MOBILE = AppLockPolicy(60_000)
    }
}

enum class AppLockAuthResult {
    SUCCESS,
    /** 用户或系统取消：留在锁定页，可再点「解锁」 */
    CANCELLED,
    FAILED,
    /** 验证途中发现设备没有锁屏凭据：视同放行 */
    UNAVAILABLE,
}

/** 设置页开关在验证前的判定 */
enum class AppLockToggleStart { VERIFY, APPLY, REFUSE_UNAVAILABLE, BUSY }

/** 设置页开关在验证后的结果 */
enum class AppLockToggleOutcome { APPLY, REFUSE_UNAVAILABLE, REFUSE_FAILED, NONE }

/**
 * 锁定状态机（纯逻辑，系统验证由 Activity 侧的 AppLockAuthenticator 发起）。
 * 只有「设备没设锁屏」时才不可用：此时绝不锁住用户。
 */
class AppLockController(
    private val isEnabled: () -> Boolean,
    private val isAvailable: () -> Boolean,
    private val policy: AppLockPolicy = AppLockPolicy.MOBILE,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    private val _locked = MutableStateFlow(isEnabled() && isAvailable())
    val locked: StateFlow<Boolean> = _locked.asStateFlow()

    private val _lastAttemptFailed = MutableStateFlow(false)
    /** 最近一次验证没通过（取消不算），锁定页据此提示重试 */
    val lastAttemptFailed: StateFlow<Boolean> = _lastAttemptFailed.asStateFlow()

    private val _authenticating = MutableStateFlow(false)
    val authenticating: StateFlow<Boolean> = _authenticating.asStateFlow()

    private var backgroundedAt: Long? = null
    /** 每次上锁后自动弹一次验证；取消后只能手动点「解锁」，不循环弹窗 */
    private var autoPromptPending = _locked.value

    /** Activity onStop（非配置变更）。验证界面本身引起的切换不计时。 */
    fun onBackground() {
        if (_authenticating.value || backgroundedAt != null) return
        backgroundedAt = clock()
    }

    /** Activity onStart：超过宽限期就上锁。 */
    fun onForeground() {
        val at = backgroundedAt
        backgroundedAt = null
        if (_authenticating.value) return
        if (policy.shouldLockOnReturn(isEnabled(), at, clock())) lockNow()
    }

    fun lockNow() {
        if (!isEnabled() || _locked.value || !isAvailable()) return
        _locked.value = true
        _lastAttemptFailed.value = false
        autoPromptPending = true
    }

    /** 锁定页可见且 Activity 已恢复时调用：true 表示现在该自动弹一次验证。 */
    fun consumeAutoPrompt(): Boolean {
        if (!_locked.value || !autoPromptPending || _authenticating.value) return false
        autoPromptPending = false
        return true
    }

    /** 准备解锁：true 表示需要调起系统验证；false 表示已直接放行（设置被关 / 设备无锁屏）或正在验证。 */
    fun beginUnlock(): Boolean {
        if (!_locked.value || _authenticating.value) return false
        if (!isEnabled() || !isAvailable()) {
            _locked.value = false
            return false
        }
        _authenticating.value = true
        return true
    }

    fun finishUnlock(result: AppLockAuthResult) {
        _authenticating.value = false
        _lastAttemptFailed.value = result == AppLockAuthResult.FAILED
        if (result == AppLockAuthResult.SUCCESS || result == AppLockAuthResult.UNAVAILABLE) {
            _locked.value = false
            backgroundedAt = null
        }
    }

    /** 设置页开关：开、关都先验证；设备没锁屏时不许开启（关闭总是允许）。 */
    fun beginToggle(enable: Boolean): AppLockToggleStart {
        if (_authenticating.value) return AppLockToggleStart.BUSY
        if (!isAvailable()) return if (enable) AppLockToggleStart.REFUSE_UNAVAILABLE else AppLockToggleStart.APPLY
        _authenticating.value = true
        return AppLockToggleStart.VERIFY
    }

    fun finishToggle(enable: Boolean, result: AppLockAuthResult): AppLockToggleOutcome {
        _authenticating.value = false
        return when (result) {
            AppLockAuthResult.SUCCESS -> AppLockToggleOutcome.APPLY
            AppLockAuthResult.CANCELLED -> AppLockToggleOutcome.NONE
            AppLockAuthResult.FAILED -> AppLockToggleOutcome.REFUSE_FAILED
            AppLockAuthResult.UNAVAILABLE ->
                if (enable) AppLockToggleOutcome.REFUSE_UNAVAILABLE else AppLockToggleOutcome.APPLY
        }
    }

    /** 设置变化后同步：关闭即解锁。 */
    fun settingChanged(enabled: Boolean) {
        if (!enabled) {
            _locked.value = false
            autoPromptPending = false
        }
    }
}
