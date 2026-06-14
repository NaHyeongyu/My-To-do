import Foundation
import UserNotifications

struct RoutineNotificationSchedule: Sendable {
    let id: UUID
    let title: String
    let notes: String
    let taskDate: Date?
    let startTime: Date?
    let repeatWeekdayMask: Int

    init?(item: ScheduleItem) {
        guard item.kind == .routine else {
            return nil
        }

        self.id = item.id
        self.title = item.title
        self.notes = item.notes
        self.taskDate = item.taskDate
        self.startTime = item.startTime
        self.repeatWeekdayMask = item.repeatWeekdayMask
    }
}

actor RoutineNotificationScheduler {
    static let shared = RoutineNotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "routine-notification"

    private init() {}

    func syncNotifications(for schedules: [RoutineNotificationSchedule]) async {
        await cancelAllRoutineNotifications()

        guard await requestAuthorizationIfNeeded() else {
            return
        }

        for schedule in schedules {
            await addNotifications(for: schedule)
        }
    }

    func syncNotificationsIfAuthorized(for schedules: [RoutineNotificationSchedule]) async {
        guard await hasNotificationAuthorization() else {
            return
        }

        await cancelAllRoutineNotifications()

        for schedule in schedules {
            await addNotifications(for: schedule)
        }
    }

    func scheduleNotifications(for schedule: RoutineNotificationSchedule) async {
        await cancelNotifications(for: schedule.id)

        guard await requestAuthorizationIfNeeded() else {
            return
        }

        await addNotifications(for: schedule)
    }

    func cancelNotifications(for itemID: UUID) async {
        let prefix = notificationPrefix(for: itemID)
        let pending = await center.pendingNotificationRequests()
        let pendingIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }

        center.removePendingNotificationRequests(withIdentifiers: pendingIDs)

        let delivered = await center.deliveredNotifications()
        let deliveredIDs = delivered
            .map(\.request.identifier)
            .filter { $0.hasPrefix(prefix) }

        center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
    }

    private func cancelAllRoutineNotifications() async {
        let pending = await center.pendingNotificationRequests()
        let pendingIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }

        center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
    }

    private func addNotifications(for schedule: RoutineNotificationSchedule) async {
        for request in notificationRequests(for: schedule) {
            do {
                try await center.add(request)
            } catch {
                continue
            }
        }
    }

    private func notificationRequests(for schedule: RoutineNotificationSchedule) -> [UNNotificationRequest] {
        guard let startTime = schedule.startTime else {
            return []
        }

        if let taskDate = schedule.taskDate {
            return dateAnchoredRequest(for: schedule, taskDate: taskDate, startTime: startTime).map { [$0] } ?? []
        }

        let mask = schedule.repeatWeekdayMask == 0 ? RepeatWeekdayMask.everyDay : schedule.repeatWeekdayMask
        return RepeatWeekday.allCases
            .filter { RepeatWeekdayMask.contains($0, in: mask) }
            .map { weekday in
                var components = Calendar.current.dateComponents([.hour, .minute], from: startTime)
                components.weekday = weekday.rawValue

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                return UNNotificationRequest(
                    identifier: notificationID(for: schedule.id, suffix: "weekday-\(weekday.rawValue)"),
                    content: notificationContent(for: schedule),
                    trigger: trigger
                )
            }
    }

    private func dateAnchoredRequest(
        for schedule: RoutineNotificationSchedule,
        taskDate: Date,
        startTime: Date
    ) -> UNNotificationRequest? {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: taskDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: startTime)

        var components = DateComponents()
        components.year = dateComponents.year
        components.month = dateComponents.month
        components.day = dateComponents.day
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute

        guard let fireDate = calendar.date(from: components), fireDate > Date.now else {
            return nil
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(
            identifier: notificationID(for: schedule.id, suffix: "date"),
            content: notificationContent(for: schedule),
            trigger: trigger
        )
    }

    private func notificationContent(for schedule: RoutineNotificationSchedule) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = schedule.title
        content.body = schedule.notes.isEmpty ? "Routine starts now." : schedule.notes
        content.sound = .default
        return content
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func hasNotificationAuthorization() async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func notificationPrefix(for itemID: UUID) -> String {
        "\(identifierPrefix)-\(itemID.uuidString)"
    }

    private func notificationID(for itemID: UUID, suffix: String) -> String {
        "\(notificationPrefix(for: itemID))-\(suffix)"
    }
}
