import Foundation
import Observation
import UserNotifications
import FlashCore

struct PendingIdeaAction {
    var action: String
    var cycles: [String]
    var unreadIDs: [String]
}
@MainActor @Observable final class PeriodicIdeaNotifications {
    static let shared = PeriodicIdeaNotifications()
    private static let legacyIdentifier = "flash-idea-reminder"
    static let prefix = "flash-periodic-"
    static let category = "flash-periodic-ideas"
    private(set) var status = ""
    private var generation = 0
    private var running = false
    private var repository: FlashRepository?
    private var settings: SettingsStore?
    private var unreadIDs: [String] = []
    private let defaults = UserDefaults.standard
    static func register() {
        let actions = [
            UNNotificationAction(identifier:"library-done",title:L("本次已梳理"),options:[.foreground]),
            UNNotificationAction(identifier:"library-snooze",title:L("稍后30分钟"),options:[.foreground]),
            UNNotificationAction(identifier:"library-pause",title:L("暂停提醒"),options:[.foreground])]
        let category = UNNotificationCategory(identifier:category,actions:actions,intentIdentifiers:[],hiddenPreviewsBodyPlaceholder:L("有些想法等你回来看看"),options:[])
        UNUserNotificationCenter.current().setNotificationCategories([TaskReminderScheduler.makeCategory(),category])
    }
    func refresh(repository: FlashRepository, settings: SettingsStore, unreadIDs: [String]) {
        guard !repository.isTemporaryStore else { return }
        self.repository = repository; self.settings = settings; self.unreadIDs = unreadIDs
        generation += 1; let token = generation
        guard !running else { return }
        running = true
        Task {
            defer {
                running = false
                if token != generation, let repository = self.repository, let settings = self.settings {
                    refresh(repository: repository, settings: settings, unreadIDs: self.unreadIDs)
                }
            }
            do {
                var library = try repository.personalLibrary(includeLinks:false)
                if !defaults.bool(forKey:"library-summary-migrated") {
                    library = try repository.personalLibrary()
                    library.summaryEnabled = settings.ideaReminderEnabled
                    library.summaryIntervalDays = settings.ideaReminderFrequency.intervalDays
                    try repository.savePersonalLibrary(library)
                    defaults.set(true,forKey:"library-summary-migrated")
                }
                let center = UNUserNotificationCenter.current()
                let pending = await center.pendingNotificationRequests()
                guard token == generation else { return }
                var rules = library.reminders
                if library.summaryEnabled && unreadIDs.count >= IdeaReminder.threshold {
                    var summary = PersonalReminder(ideaID:"summary",anchorDay:"2026-01-01")
                    summary.hour = library.summaryHour; summary.minute = library.summaryMinute; summary.intervalDays = library.summaryIntervalDays
                    rules.append(summary)
                }
                let now = Date()
                var cycles = library.remindersNeedConfirmation ? [] : rules.flatMap { PeriodicIdeaPlan.cycles(rule:$0,now:now) }
                cycles.removeAll { defaults.bool(forKey:"library-done-" + $0.key) }
                // A snooze consumes the remaining request, never creates a third alert.
                cycles = cycles.compactMap { cycle in
                    guard let snooze = defaults.object(forKey:"library-snooze-" + cycle.key) as? Date else { return cycle }
                    guard cycle.ordinal == 1, snooze > now, (9...21).contains(Calendar.current.component(.hour,from:snooze)) else { return nil }
                    return IdeaCycle(key:cycle.key,ideaID:cycle.ideaID,day:cycle.day,date:snooze,ordinal:1)
                }
                let groups = Dictionary(grouping:cycles,by: { Int($0.date.timeIntervalSince1970 / 60) })
                let other = pending.filter { !$0.identifier.hasPrefix(Self.prefix) && $0.identifier != Self.legacyIdentifier }.count
                let budget = max(0,60-other)
                let groupsToSchedule = groups.sorted { $0.key < $1.key }.prefix(budget)
                if !groupsToSchedule.isEmpty {
                    let granted = try await center.requestAuthorization(options:[.alert,.sound,.badge])
                    guard token == generation else { return }
                    guard granted else { status = L("通知权限未开启，请在系统设置中允许通知"); return }
                }
                var desired = Set<String>()
                for (minute,group) in groupsToSchedule {
                    guard token == generation else { return }
                    let content = UNMutableNotificationContent()
                    content.title = "Flash"
                    content.body = group.allSatisfy { $0.ordinal == 0 } ? L("有些想法等你回来看看，方便时梳理一下吧。") : L("再轻轻提醒一下：那条想法还在，今天有空时再看看。")
                    content.sound = .default; content.categoryIdentifier = Self.category; content.threadIdentifier = Self.category
                    content.userInfo = ["url":"flash://ideas", "libraryCycles": group.map(\.key), "libraryUnreadIDs":unreadIDs]
                    let id = Self.prefix + String(minute); desired.insert(id)
                    let date = Date(timeIntervalSince1970:Double(minute)*60)
                    let trigger = UNCalendarNotificationTrigger(dateMatching:Calendar.current.dateComponents([.year,.month,.day,.hour,.minute],from:date),repeats:false)
                    try await center.add(UNNotificationRequest(identifier:id,content:content,trigger:trigger))
                }
                guard token == generation else { return }
                let obsolete = pending.filter { ($0.identifier.hasPrefix(Self.prefix) && !desired.contains($0.identifier)) || $0.identifier == Self.legacyIdentifier }.map(\.identifier)
                center.removePendingNotificationRequests(withIdentifiers:obsolete)
                if let last = groupsToSchedule.last {
                    status = L("已安排至") + " " + Date(timeIntervalSince1970:Double(last.key)*60).formatted(date:.abbreviated,time:.shortened)
                } else { status = library.remindersNeedConfirmation ? L("导入的提醒等待确认启用") : (budget == 0 ? L("系统通知排期已满，请先处理任务提醒") : L("暂无待提醒的灵感")) }
            } catch { status = L("提醒排期失败，请重试") }
        }
    }
    func complete(ideaID: String, repository: FlashRepository?) {
        let day = DateFormatting.today()
        perform(PendingIdeaAction(action:"library-done",cycles:[ideaID + ":" + day],unreadIDs:[]),repository:repository)
    }
    func perform(_ action: PendingIdeaAction, repository: FlashRepository?) {
        guard let repository, !repository.isTemporaryStore else { return }
        do {
            var library = try repository.personalLibrary()
            for key in action.cycles {
                guard key.count > 11 else { continue }
                let day = String(key.suffix(10)), id = String(key.dropLast(11))
                guard day == DateFormatting.today() else { continue }
                if action.action == "library-done" {
                    defaults.set(true,forKey:"library-done-"+key)
                    if id == "summary" {
                        let store = IdeaViewStateStore()
                        for id in action.unreadIDs { store.markViewed(id) }
                    }
                } else if action.action == "library-snooze" {
                    let now = Date()
                    let pendingCycle = library.reminders.first { $0.id == id }
                    let hour = pendingCycle?.hour ?? library.summaryHour, minute = pendingCycle?.minute ?? library.summaryMinute
                    guard let first = Calendar.current.date(bySettingHour:hour,minute:minute,second:0,of:now), now < first.addingTimeInterval(1800) else { continue }
                    if defaults.object(forKey:"library-snooze-"+key) == nil { defaults.set(now.addingTimeInterval(1800),forKey:"library-snooze-"+key) }
                } else if action.action == "library-pause" {
                    if id == "summary" { library.summaryEnabled = false }
                    else if let i = library.reminders.firstIndex(where: { $0.id == id }) { library.reminders[i].enabled = false }
                }
            }
            try repository.savePersonalLibrary(library)
            if let settings { refresh(repository:repository,settings:settings,unreadIDs: unreadIDs.filter { !IdeaViewStateStore().viewedIDs.contains($0) }) }
        } catch { status = L("提醒操作未保存，请重试") }
    }
}
