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

    /// 注册任务提醒的通知类别（App 启动时调用一次）
    public nonisolated static func registerCategories() {
        let complete = UNNotificationAction(identifier: completeActionIdentifier, title: "完成",
                                            options: [], icon: UNNotificationActionIcon(systemImageName: "checkmark"))
        let snooze = UNNotificationAction(identifier: snoozeActionIdentifier, title: "稍后 \(snoozeMinutes) 分钟",
                                          options: [], icon: UNNotificationActionIcon(systemImageName: "clock"))
        let category = UNNotificationCategory(identifier: categoryIdentifier, actions: [complete, snooze],
                                              intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    private let center = UNUserNotificationCenter.current()
    private let prefix = "flash-task-reminder-"

    public func schedule(_ task: TaskItem) async throws {
        guard let request = request(for: task) else {
            cancel(task.id)
            return
        }
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else { throw TaskReminderError.permissionDenied }
        try await center.add(request)
    }

    public func cancel(_ id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [prefix + id])
    }

    public func rebuild(_ tasks: [TaskItem]) async throws {
        let desired = tasks.compactMap(request(for:))
        if !desired.isEmpty {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            guard granted else { throw TaskReminderError.permissionDenied }
        }
        // Adding the same identifier replaces it. Stage every desired request
        // before removing stale reminders so a partial add failure loses none.
        for request in desired { try await center.add(request) }
        let desiredIdentifiers = Set(desired.map(\.identifier))
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) && !desiredIdentifiers.contains($0) }
        center.removePendingNotificationRequests(withIdentifiers: stale)
    }

    private func request(for task: TaskItem) -> UNNotificationRequest? {
        guard !task.isCompleted, let value = task.reminderAt,
              let date = Self.iso.date(from: value) ?? Self.isoWhole.date(from: value), date > Date() else { return nil }
        let content = UNMutableNotificationContent()
        content.title = "Flash 任务提醒"
        content.body = task.title
        content.sound = .default
        // 通知操作（iOS 注册「完成 / 稍后」；未注册类别的平台只显示普通通知）
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = [Self.taskIDKey: task.id]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        return UNNotificationRequest(identifier: prefix + task.id, content: content, trigger: trigger)
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
