// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AppLockTest {
    private val start = 1_800_000_000_000L

    private class Env(var enabled: Boolean = true, var available: Boolean = true, var now: Long = 1_800_000_000_000L)

    private fun controller(env: Env) = AppLockController(
        isEnabled = { env.enabled },
        isAvailable = { env.available },
        policy = AppLockPolicy.MOBILE,
        clock = { env.now },
    )

    @Test fun policyHonoursGraceAndClockRollback() {
        val policy = AppLockPolicy.MOBILE
        assertFalse(policy.shouldLockOnReturn(false, start, start + 3_600_000))
        assertFalse(policy.shouldLockOnReturn(true, null, start))
        assertFalse(policy.shouldLockOnReturn(true, start, start + 59_999))
        assertTrue(policy.shouldLockOnReturn(true, start, start + 60_000))
        assertTrue(policy.shouldLockOnReturn(true, start, start - 1))
        assertEquals(0L, AppLockPolicy(-5).gracePeriodMillis)
    }

    @Test fun coldStartLocksOnlyWhenEnabledAndAvailable() {
        assertTrue(controller(Env()).locked.value)
        assertFalse(controller(Env(enabled = false)).locked.value)
        assertFalse(controller(Env(available = false)).locked.value)
    }

    @Test fun unlockFlow() {
        val lock = controller(Env())
        assertTrue(lock.beginUnlock())
        assertTrue(lock.authenticating.value)
        assertFalse("second tap while prompting is ignored", lock.beginUnlock())
        lock.finishUnlock(AppLockAuthResult.CANCELLED)
        assertTrue(lock.locked.value)
        assertFalse(lock.lastAttemptFailed.value)
        assertTrue(lock.beginUnlock())
        lock.finishUnlock(AppLockAuthResult.FAILED)
        assertTrue(lock.locked.value)
        assertTrue(lock.lastAttemptFailed.value)
        assertTrue(lock.beginUnlock())
        lock.finishUnlock(AppLockAuthResult.SUCCESS)
        assertFalse(lock.locked.value)
        assertFalse(lock.authenticating.value)
    }

    @Test fun screenLockRemovedWhileLockedLetsUserIn() {
        val env = Env()
        val lock = controller(env)
        env.available = false
        assertFalse(lock.beginUnlock())
        assertFalse(lock.locked.value)
    }

    @Test fun backgroundGrace() {
        val env = Env()
        val lock = controller(env)
        lock.beginUnlock(); lock.finishUnlock(AppLockAuthResult.SUCCESS)

        lock.onBackground(); env.now += 30_000; lock.onForeground()
        assertFalse(lock.locked.value)

        lock.onBackground(); env.now += 61_000; lock.onForeground()
        assertTrue(lock.locked.value)
    }

    @Test fun authenticationActivityDoesNotCountAsBackground() {
        val env = Env()
        val lock = controller(env)
        assertTrue(lock.beginUnlock())
        lock.onBackground() // 确认锁屏凭据页盖住 Activity
        env.now += 120_000
        lock.onForeground()
        lock.finishUnlock(AppLockAuthResult.SUCCESS)
        assertFalse(lock.locked.value)
        lock.onForeground()
        assertFalse(lock.locked.value)
    }

    @Test fun autoPromptOncePerLock() {
        val env = Env()
        val lock = controller(env)
        assertTrue(lock.consumeAutoPrompt())
        assertFalse(lock.consumeAutoPrompt())
        lock.beginUnlock(); lock.finishUnlock(AppLockAuthResult.SUCCESS)
        assertFalse(lock.consumeAutoPrompt())
        lock.lockNow()
        assertTrue(lock.consumeAutoPrompt())
    }

    @Test fun toggleRules() {
        val env = Env(enabled = false)
        val lock = controller(env)
        assertEquals(AppLockToggleStart.VERIFY, lock.beginToggle(true))
        assertEquals(AppLockToggleStart.BUSY, lock.beginToggle(true))
        assertEquals(AppLockToggleOutcome.APPLY, lock.finishToggle(true, AppLockAuthResult.SUCCESS))
        lock.beginToggle(true)
        assertEquals(AppLockToggleOutcome.NONE, lock.finishToggle(true, AppLockAuthResult.CANCELLED))
        lock.beginToggle(false)
        assertEquals(AppLockToggleOutcome.REFUSE_FAILED, lock.finishToggle(false, AppLockAuthResult.FAILED))
        lock.beginToggle(true)
        assertEquals(AppLockToggleOutcome.REFUSE_UNAVAILABLE, lock.finishToggle(true, AppLockAuthResult.UNAVAILABLE))
        env.available = false
        assertEquals(AppLockToggleStart.REFUSE_UNAVAILABLE, lock.beginToggle(true))
        assertEquals(AppLockToggleStart.APPLY, lock.beginToggle(false))
    }

    @Test fun disablingUnlocks() {
        val env = Env()
        val lock = controller(env)
        env.enabled = false
        lock.settingChanged(false)
        assertFalse(lock.locked.value)
        lock.lockNow()
        assertFalse(lock.locked.value)
    }
}
