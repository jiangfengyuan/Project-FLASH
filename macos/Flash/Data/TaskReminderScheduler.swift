import Foundation
import UserNotifications

actor TaskReminderScheduler {
    static let shared = TaskReminderScheduler()
    private let center = UNUserNotificationCenter.current()
    private let prefix = "flash-task-reminder-"

    func schedule(_ task: TaskItem) async throws {
        guard let request = request(for: task) else {
            cancel(task.id)
            return
        }
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else { throw TaskReminderError.permissionDenied }
        try await center.add(request)
    }

    func cancel(_ id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [prefix + id])
    }

    func rebuild(_ tasks: [TaskItem]) async throws {
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
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        return UNNotificationRequest(identifier: prefix + task.id, content: content, trigger: trigger)
    }

    /// 任务带有已过期的提醒时间（会被静默跳过）：供保存路径给用户可见提示
    nonisolated static func hasPastReminder(_ task: TaskItem) -> Bool {
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

enum TaskReminderError: Error {
    case permissionDenied
}
