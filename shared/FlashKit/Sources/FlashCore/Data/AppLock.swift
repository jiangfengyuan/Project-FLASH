// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import LocalAuthentication
import Observation

/// 应用锁（可选，默认关闭）：冷启动时锁定；离开前台超过宽限期后回来再锁定。
/// 与 Android `AppLockPolicy`、HarmonyOS `AppLockPolicy.ets` 同口径。
public struct AppLockPolicy: Sendable, Equatable {
    /// 手机端宽限期：短暂切走（回消息、看一眼别的应用）不打断
    public static let mobile = AppLockPolicy(gracePeriod: 60)
    /// Mac 上频繁切换应用是常态，宽限期放宽；睡眠与锁屏另行立即锁定
    public static let desktop = AppLockPolicy(gracePeriod: 5 * 60)

    public let gracePeriod: TimeInterval

    public init(gracePeriod: TimeInterval) {
        self.gracePeriod = max(0, gracePeriod)
    }

    /// 回到前台时是否锁定。`backgroundedAt` 为 nil 表示本次进程内没离开过前台。
    /// 系统时间被往回拨（now 早于离开时刻）按超时处理，不能靠改时钟绕过。
    public func shouldLockOnReturn(enabled: Bool, backgroundedAt: Date?, now: Date) -> Bool {
        guard enabled, let backgroundedAt else { return false }
        let elapsed = now.timeIntervalSince(backgroundedAt)
        return elapsed < 0 || elapsed >= gracePeriod
    }
}

/// 设备能否做身份验证。只有「设备根本没设密码」才算不可用：此时绝不锁住用户。
public enum AppLockAvailability: Sendable, Equatable {
    case available
    case unavailable
}

public enum AppLockAuthResult: Sendable, Equatable {
    case success
    /// 用户或系统取消（来电、切走），留在锁定页，可再点「解锁」
    case cancelled
    case failed
    /// 验证途中发现设备没有密码：视同放行
    case unavailable
}

public protocol AppLockAuthenticating: Sendable {
    func availability() -> AppLockAvailability
    func authenticate(reason: String) async -> AppLockAuthResult
}

/// LocalAuthentication：面容 / 触控 / Optic ID，失败或锁死时由系统回退到设备密码
/// （`.deviceOwnerAuthentication`，不是仅生物识别），所以只要设备有密码就一定能解开。
public struct DeviceOwnerAuthenticator: AppLockAuthenticating {
    public init() {}

    public func availability() -> AppLockAvailability {
        var error: NSError?
        if LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) { return .available }
        // 生物识别锁死 / 未录入等都还能用密码；只有没设密码才不可用
        return (error as? LAError)?.code == .passcodeNotSet ? .unavailable : .available
    }

    public func authenticate(reason: String) async -> AppLockAuthResult {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
                ? .success : .failed
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .systemCancel, .appCancel: return .cancelled
            case .passcodeNotSet: return .unavailable
            default: return .failed
            }
        } catch {
            return .failed
        }
    }
}

/// 锁定状态机。界面只读 `isLocked`；生命周期事件由各端外壳转发。
@MainActor
@Observable
public final class AppLockController {
    public private(set) var isLocked: Bool
    public private(set) var isAuthenticating = false
    /// 最近一次解锁 / 开关验证没通过（取消不算），锁定页据此提示重试
    public private(set) var lastAttemptFailed = false

    @ObservationIgnored private let isEnabled: () -> Bool
    @ObservationIgnored private let authenticator: AppLockAuthenticating
    @ObservationIgnored private let policy: AppLockPolicy
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private var backgroundedAt: Date?
    /// 每次上锁后自动弹一次验证；用户取消后只能手动点「解锁」，不循环弹窗
    @ObservationIgnored private var autoPromptPending: Bool

    public init(isEnabled: @escaping () -> Bool,
                authenticator: AppLockAuthenticating = DeviceOwnerAuthenticator(),
                policy: AppLockPolicy,
                clock: @escaping () -> Date = Date.init) {
        self.isEnabled = isEnabled
        self.authenticator = authenticator
        self.policy = policy
        self.clock = clock
        // 冷启动：开启且设备能验证才锁（设备密码被移除后不能把用户关在门外）
        let locked = isEnabled() && authenticator.availability() == .available
        self.isLocked = locked
        self.autoPromptPending = locked
    }

    /// 离开前台（iOS 进入后台 / Mac 失去激活）。验证弹窗本身引起的切换不计时。
    public func didEnterBackground() {
        guard !isAuthenticating, backgroundedAt == nil else { return }
        backgroundedAt = clock()
    }

    /// 回到前台：超过宽限期就上锁。
    public func willEnterForeground() {
        defer { backgroundedAt = nil }
        guard !isAuthenticating else { return }
        if policy.shouldLockOnReturn(enabled: isEnabled(), backgroundedAt: backgroundedAt, now: clock()) {
            lockNow()
        }
    }

    /// 立即上锁（Mac 睡眠 / 锁屏）。
    public func lockNow() {
        guard isEnabled(), !isLocked, authenticator.availability() == .available else { return }
        isLocked = true
        lastAttemptFailed = false
        autoPromptPending = true
    }

    /// 锁定页出现且应用处于前台时调用：每次上锁只自动弹一次。
    public func autoPromptIfNeeded(reason: String) async {
        guard isLocked, autoPromptPending, !isAuthenticating else { return }
        autoPromptPending = false
        await unlock(reason: reason)
    }

    @discardableResult
    public func unlock(reason: String) async -> Bool {
        guard isLocked else { return true }
        guard !isAuthenticating else { return false }
        // 设置被关、或设备密码已移除：直接放行
        guard isEnabled(), authenticator.availability() == .available else {
            isLocked = false
            return true
        }
        let result = await authenticate(reason: reason)
        if result == .success || result == .unavailable {
            isLocked = false
            backgroundedAt = nil
        }
        return !isLocked
    }

    /// 设置页开关：开启和关闭都先验证一次（开启时确认用户此刻能解开，避免把自己锁在外面）。
    /// 返回 nil 表示可以改；否则是不能改的原因。
    public func verifyToggle(reason: String) async -> AppLockToggleRefusal? {
        guard !isAuthenticating else { return .busy }
        guard authenticator.availability() == .available else { return .unavailable }
        switch await authenticate(reason: reason) {
        case .success: return nil
        case .cancelled: return .cancelled
        case .failed: return .failed
        case .unavailable: return .unavailable
        }
    }

    /// 设置变化后同步：关闭即解锁。
    public func settingChanged(enabled: Bool) {
        if !enabled {
            isLocked = false
            autoPromptPending = false
        }
    }

    private func authenticate(reason: String) async -> AppLockAuthResult {
        isAuthenticating = true
        let result = await authenticator.authenticate(reason: reason)
        isAuthenticating = false
        lastAttemptFailed = result == .failed
        return result
    }
}

public enum AppLockToggleRefusal: Sendable, Equatable {
    case busy, cancelled, failed, unavailable
}
