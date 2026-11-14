// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
import Foundation
@testable import FlashCore

private final class FakeAuthenticator: AppLockAuthenticating, @unchecked Sendable {
    var available = AppLockAvailability.available
    var results: [AppLockAuthResult] = []
    private(set) var calls = 0

    func availability() -> AppLockAvailability { available }

    func authenticate(reason: String) async -> AppLockAuthResult {
        calls += 1
        return results.isEmpty ? .success : results.removeFirst()
    }
}

private final class Clock: @unchecked Sendable {
    var now = Date(timeIntervalSince1970: 1_800_000_000)
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

@Suite("AppLockPolicy")
struct AppLockPolicyTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func disabledNeverLocks() {
        #expect(!AppLockPolicy.mobile.shouldLockOnReturn(enabled: false, backgroundedAt: start,
                                                          now: start.addingTimeInterval(3600)))
    }

    @Test func withinGraceStaysOpen() {
        #expect(!AppLockPolicy.mobile.shouldLockOnReturn(enabled: true, backgroundedAt: start,
                                                          now: start.addingTimeInterval(59)))
    }

    @Test func atOrPastGraceLocks() {
        #expect(AppLockPolicy.mobile.shouldLockOnReturn(enabled: true, backgroundedAt: start,
                                                         now: start.addingTimeInterval(60)))
        #expect(AppLockPolicy.desktop.shouldLockOnReturn(enabled: true, backgroundedAt: start,
                                                          now: start.addingTimeInterval(301)))
        #expect(!AppLockPolicy.desktop.shouldLockOnReturn(enabled: true, backgroundedAt: start,
                                                           now: start.addingTimeInterval(120)))
    }

    @Test func neverBackgroundedDoesNotLock() {
        #expect(!AppLockPolicy.mobile.shouldLockOnReturn(enabled: true, backgroundedAt: nil, now: start))
    }

    @Test func clockMovedBackwardsLocks() {
        #expect(AppLockPolicy.mobile.shouldLockOnReturn(enabled: true, backgroundedAt: start,
                                                         now: start.addingTimeInterval(-5)))
    }

    @Test func negativeGraceClampsToZero() {
        #expect(AppLockPolicy(gracePeriod: -10).gracePeriod == 0)
    }
}

@MainActor
@Suite("AppLockController")
struct AppLockControllerTests {
    private func make(enabled: Bool = true, auth: FakeAuthenticator = FakeAuthenticator(),
                      clock: Clock = Clock()) -> (AppLockController, FakeAuthenticator, Clock, Box) {
        let box = Box(enabled)
        let controller = AppLockController(isEnabled: { box.value }, authenticator: auth,
                                           policy: .mobile, clock: { clock.now })
        return (controller, auth, clock, box)
    }

    final class Box: @unchecked Sendable {
        var value: Bool
        init(_ value: Bool) { self.value = value }
    }

    @Test func coldStartLocksOnlyWhenEnabled() {
        #expect(make(enabled: true).0.isLocked)
        #expect(!make(enabled: false).0.isLocked)
    }

    @Test func coldStartWithoutPasscodeDoesNotLockUserOut() {
        let auth = FakeAuthenticator()
        auth.available = .unavailable
        #expect(!make(auth: auth).0.isLocked)
    }

    @Test func unlockSucceeds() async {
        let (lock, auth, _, _) = make()
        #expect(await lock.unlock(reason: "r"))
        #expect(!lock.isLocked)
        #expect(auth.calls == 1)
    }

    @Test func cancelKeepsLockedWithoutFailureHint() async {
        let auth = FakeAuthenticator()
        auth.results = [.cancelled]
        let (lock, _, _, _) = make(auth: auth)
        #expect(!(await lock.unlock(reason: "r")))
        #expect(lock.isLocked)
        #expect(!lock.lastAttemptFailed)
    }

    @Test func failureKeepsLockedAndFlags() async {
        let auth = FakeAuthenticator()
        auth.results = [.failed]
        let (lock, _, _, _) = make(auth: auth)
        await lock.unlock(reason: "r")
        #expect(lock.isLocked)
        #expect(lock.lastAttemptFailed)
    }

    @Test func passcodeRemovedWhileLockedLetsUserIn() async {
        let auth = FakeAuthenticator()
        let (lock, _, _, _) = make(auth: auth)
        auth.available = .unavailable
        #expect(await lock.unlock(reason: "r"))
        #expect(auth.calls == 0)
    }

    @Test func returnWithinGraceStaysUnlocked() async {
        let (lock, _, clock, _) = make()
        await lock.unlock(reason: "r")
        lock.didEnterBackground()
        clock.advance(30)
        lock.willEnterForeground()
        #expect(!lock.isLocked)
    }

    @Test func returnAfterGraceLocks() async {
        let (lock, _, clock, _) = make()
        await lock.unlock(reason: "r")
        lock.didEnterBackground()
        clock.advance(61)
        lock.willEnterForeground()
        #expect(lock.isLocked)
    }

    @Test func repeatedBackgroundKeepsFirstTimestamp() async {
        let (lock, _, clock, _) = make()
        await lock.unlock(reason: "r")
        lock.didEnterBackground()
        clock.advance(40)
        lock.didEnterBackground()
        clock.advance(30)
        lock.willEnterForeground()
        #expect(lock.isLocked)
    }

    @Test func autoPromptRunsOncePerLock() async {
        let auth = FakeAuthenticator()
        auth.results = [.cancelled]
        let (lock, _, _, _) = make(auth: auth)
        await lock.autoPromptIfNeeded(reason: "r")
        await lock.autoPromptIfNeeded(reason: "r")
        #expect(auth.calls == 1)
        #expect(lock.isLocked)
        // 手动重试仍可用
        await lock.unlock(reason: "r")
        #expect(!lock.isLocked)
    }

    @Test func disablingSettingUnlocks() {
        let (lock, _, _, box) = make()
        box.value = false
        lock.settingChanged(enabled: false)
        #expect(!lock.isLocked)
    }

    @Test func lockNowIgnoredWhenDisabled() {
        let (lock, _, _, box) = make(enabled: false)
        lock.lockNow()
        #expect(!lock.isLocked)
        box.value = true
        lock.lockNow()
        #expect(lock.isLocked)
    }

    @Test func toggleVerificationReportsRefusals() async {
        let auth = FakeAuthenticator()
        let (lock, _, _, _) = make(enabled: false, auth: auth)
        auth.results = [.success, .cancelled, .failed]
        #expect(await lock.verifyToggle(reason: "r") == nil)
        #expect(await lock.verifyToggle(reason: "r") == .cancelled)
        #expect(await lock.verifyToggle(reason: "r") == .failed)
        auth.available = .unavailable
        #expect(await lock.verifyToggle(reason: "r") == .unavailable)
    }
}
