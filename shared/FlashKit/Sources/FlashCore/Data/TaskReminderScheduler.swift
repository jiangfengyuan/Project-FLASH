import Foundation
import UserNotifications

public actor TaskReminderScheduler {
    public static let shared = TaskReminderScheduler()

    /// 任务提醒通知类别与操作（「完成」「稍后 10 分钟」）
    public static let categoryIdentifier = "flash-task-reminder"
    public static let completeActionIdentifier = "flash.task.complete"
    public static let snoozeActionIdentifier = "flash.task.snooze"
    public static let taskIDKey = "taskId"
    public static let snoozeMinutes = 10

    /// 隐藏预览时（锁屏且系统「显示预览」为「解锁时」——iOS 默认）代替任务标题显示的正文（F-17）
    public static let hiddenPreviewBodyPlaceholder = L("你有一个任务提醒")

    /// 注册任务提醒的通知类别（App 启动时调用一次）
    public nonisolated static func registerCategories() {
        UNUserNotificationCenter.current().setNotificationCategories([makeCategory()])
    }

    /// 任务提醒类别：「完成 / 稍后」操作 + 锁屏隐私。
    /// 任务标题只在正文里；隐藏预览时系统显示通用标题与占位正文，不泄露标题（F-17）
    public nonisolated static func makeCategory() -> UNNotificationCategory {
        let complete = UNNotificationAction(identifier: completeActionIdentifier, title: L("完成"),
                                            options: [], icon: UNNotificationActionIcon(systemImageName: "checkmark"))
        let snooze = UNNotificationAction(identifier: snoozeActionIdentifier, title: L("稍后 \(snoozeMinutes) 分钟"),
                                          options: [], icon: UNNotificationActionIcon(systemImageName: "clock"))
        return UNNotificationCategory(identifier: categoryIdentifier, actions: [complete, snooze],
                                      intentIdentifiers: [],
                                      hiddenPreviewsBodyPlaceholder: hiddenPreviewBodyPlaceholder,
                                      options: [.hiddenPreviewsShowTitle])
    }
    private let center: any ReminderNotificationCenter
    private let prefix = "flash-task-reminder-"

    /// 进行中的 rebuild 数，以及期间被 schedule（true）/ cancel（false）动过的提醒标识（F-26）。
    /// rebuild 按调用方的旧快照工作，且在 await 处让出 actor：期间新保存的任务提醒不能被它的
    /// 清理步骤当作「过期」删掉，期间被撤销的提醒也不能被它按旧快照加回来。
    private var rebuildsInFlight = 0
    private var touchedDuringRebuild: [String: Bool] = [:]

    init(center: any ReminderNotificationCenter = SystemReminderCenter()) {
        self.center = center
    }

    public func schedule(_ task: TaskItem) async throws {
        guard let request = request(for: task) else {
            await cancel(task.id)
            return
        }
        noteTouched(request.identifier, keep: true)
        let granted = try await center.requestAuthorization()
        guard granted else { throw TaskReminderError.permissionDenied }
        try await center.add(request)
    }

    public func cancel(_ id: String) async {
        noteTouched(prefix + id, keep: false)
        await center.removePending(withIdentifiers: [prefix + id])
    }

    public func rebuild(_ tasks: [TaskItem]) async throws {
        rebuildsInFlight += 1
        defer {
            rebuildsInFlight -= 1
            if rebuildsInFlight == 0 { touchedDuringRebuild = [:] }
        }
        let desired = tasks.compactMap(request(for:))
        if !desired.isEmpty {
            let granted = try await center.requestAuthorization()
            guard granted else { throw TaskReminderError.permissionDenied }
        }
        // Adding the same identifier replaces it. Stage every desired request
        // before removing stale reminders so a partial add failure loses none.
        // 期间被 schedule / cancel 动过的任务以那次操作为准，不再用旧快照覆盖
        for request in desired where touchedDuringRebuild[request.identifier] == nil {
            try await center.add(request)
        }
        let desiredIdentifiers = Set(desired.map(\.identifier))
        let stale = await center.pendingIdentifiers()
            .filter { $0.hasPrefix(prefix) && !desiredIdentifiers.contains($0) }
            .filter { touchedDuringRebuild[$0] != true }
        // 期间被撤销的提醒可能被并发中的 add 重新挂上：清理时一并移除
        let cancelledDuringRebuild = touchedDuringRebuild.filter { !$0.value }.map(\.key)
        let removals = Set(stale).union(cancelledDuringRebuild)
        if !removals.isEmpty {
            await center.removePending(withIdentifiers: removals.sorted())
        }
    }

    private func noteTouched(_ identifier: String, keep: Bool) {
        guard rebuildsInFlight > 0 else { return }
        touchedDuringRebuild[identifier] = keep
    }

    private func request(for task: TaskItem) -> ReminderRequest? {
        guard !task.isCompleted, let value = task.reminderAt,
              let date = Self.iso.date(from: value) ?? Self.isoWhole.date(from: value), date > Date() else { return nil }
        return ReminderRequest(identifier: prefix + task.id, taskID: task.id, title: task.title, fireDate: date)
    }

    /// 任务带有已过期的提醒时间（会被静默跳过）：供保存路径给用户可见提示
    public nonisolated static func hasPastReminder(_ task: TaskItem) -> Bool {
        guard !task.isCompleted, let value = task.reminderAt,
              let date = iso.date(from: value) ?? isoWhole.date(from: value) else { return false }
        return date <= Date()
    }

    nonisolated(unsafe) private static let iso: ISO8601DateFormatter = {
        let value = ISO8601DateFormatter(); value.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return value
    }()
    nonisolated(unsafe) private static let isoWhole: ISO8601DateFormatter = {
        let value = ISO8601DateFormatter(); value.formatOptions = [.withInternetDateTime]; return value
    }()
}

public enum TaskReminderError: Error, Sendable {
    case permissionDenied
}

/// 一条任务提醒的值描述（Sendable，可跨 actor 传递）；系统适配层再组装成 UNNotificationRequest
struct ReminderRequest: Equatable, Sendable {
    let identifier: String
    let taskID: String
    let title: String
    let fireDate: Date
}

/// 通知中心最小接口：生产走 `UNUserNotificationCenter`，测试注入替身以复现 rebuild 与
/// schedule 的交错（F-26）。全部 async，便于 actor 替身实现。
protocol ReminderNotificationCenter: Sendable {
    func requestAuthorization() async throws -> Bool
    func add(_ request: ReminderRequest) async throws
    func pendingIdentifiers() async -> [String]
    func removePending(withIdentifiers identifiers: [String]) async
}

/// 系统通知中心适配（每次调用取 `current()`，构造本身不触达通知中心）
struct SystemReminderCenter: ReminderNotificationCenter {
    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func add(_ request: ReminderRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = L("Flash 任务提醒")
        content.body = request.title
        content.sound = .default
        // 通知操作（iOS 注册「完成 / 稍后」；未注册类别的平台只显示普通通知）
        content.categoryIdentifier = TaskReminderScheduler.categoryIdentifier
        content.userInfo = [TaskReminderScheduler.taskIDKey: request.taskID]
        let interval = max(1, request.fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        try await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger))
    }

    func pendingIdentifiers() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    func removePending(withIdentifiers identifiers: [String]) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
