import Foundation
import UserNotifications

struct RoutineNotificationSchedule {
    let routineID: UUID
    let title: String
    let notes: String
    let taskDate: Date?
    let startTime: Date
    let repeatWeekdayMask: Int
    let activeFrom: Date?
    let activeUntil: Date?

    init?(item: ScheduleItem) {
        guard item.canScheduleRoutineNotifications(), let startTime = item.startTime else {
            return nil
        }

        self.routineID = item.id
        self.title = item.title
        self.notes = item.notes
        self.taskDate = item.taskDate
        self.startTime = startTime
        self.repeatWeekdayMask = item.repeatWeekdayMask
        self.activeFrom = item.activeFrom
        self.activeUntil = item.activeUntil
    }
}

actor RoutineNotificationScheduler {
    static let shared = RoutineNotificationScheduler()

    private let identifierPrefix = "one.routine.start."
    private let horizonDays = 60
    private let maxScheduledNotifications = 60

    private var center: UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }

    func syncNotifications(
        enabled: Bool,
        for schedules: [RoutineNotificationSchedule],
        now: Date = .now,
        calendar: Calendar = .current
    ) async {
        guard enabled else {
            await cancelRoutineNotifications()
            return
        }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus.allowsRoutineNotifications else {
            await cancelRoutineNotifications()
            return
        }

        await cancelRoutineNotifications()

        let requests = notificationRequests(for: schedules, now: now, calendar: calendar)
        for request in requests {
            try? await add(request)
        }
    }

    func cancelRoutineNotifications() async {
        let identifiers = await pendingRoutineNotificationIdentifiers()
        guard !identifiers.isEmpty else {
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func notificationRequests(
        for schedules: [RoutineNotificationSchedule],
        now: Date,
        calendar: Calendar
    ) -> [UNNotificationRequest] {
        schedules
            .flatMap { occurrences(for: $0, now: now, calendar: calendar) }
            .sorted { $0.fireDate < $1.fireDate }
            .prefix(maxScheduledNotifications)
            .map { request(for: $0, calendar: calendar) }
    }

    private func occurrences(
        for schedule: RoutineNotificationSchedule,
        now: Date,
        calendar: Calendar
    ) -> [RoutineNotificationOccurrence] {
        if let taskDate = schedule.taskDate {
            let dayStart = calendar.startOfDay(for: taskDate)
            guard
                isSchedule(schedule, activeOn: dayStart, calendar: calendar),
                let fireDate = fireDate(for: dayStart, startTime: schedule.startTime, calendar: calendar),
                fireDate > now
            else {
                return []
            }

            return [RoutineNotificationOccurrence(schedule: schedule, dayStart: dayStart, fireDate: fireDate)]
        }

        let today = calendar.startOfDay(for: now)
        return (0..<horizonDays).compactMap { dayOffset in
            guard let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: today) else {
                return nil
            }

            guard
                isSchedule(schedule, activeOn: dayStart, calendar: calendar),
                repeats(schedule, on: dayStart, calendar: calendar),
                let fireDate = fireDate(for: dayStart, startTime: schedule.startTime, calendar: calendar),
                fireDate > now
            else {
                return nil
            }

            return RoutineNotificationOccurrence(schedule: schedule, dayStart: dayStart, fireDate: fireDate)
        }
    }

    private func request(
        for occurrence: RoutineNotificationOccurrence,
        calendar: Calendar
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Routine starts"
        content.body = occurrence.schedule.title
        content.sound = .default
        content.threadIdentifier = "routine"
        content.userInfo = [
            "routineID": occurrence.schedule.routineID.uuidString,
            "dayStart": occurrence.dayStart.timeIntervalSince1970
        ]

        if !occurrence.schedule.notes.isEmpty {
            content.subtitle = occurrence.schedule.notes
        }

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: occurrence.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        return UNNotificationRequest(
            identifier: identifier(for: occurrence),
            content: content,
            trigger: trigger
        )
    }

    private func identifier(for occurrence: RoutineNotificationOccurrence) -> String {
        "\(identifierPrefix)\(occurrence.schedule.routineID.uuidString).\(Int(occurrence.dayStart.timeIntervalSince1970))"
    }

    private func pendingRoutineNotificationIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { [identifierPrefix] requests in
                continuation.resume(
                    returning: requests
                        .map(\.identifier)
                        .filter { $0.hasPrefix(identifierPrefix) }
                )
            }
        }
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func isSchedule(
        _ schedule: RoutineNotificationSchedule,
        activeOn dayStart: Date,
        calendar: Calendar
    ) -> Bool {
        if let activeFrom = schedule.activeFrom, dayStart < calendar.startOfDay(for: activeFrom) {
            return false
        }

        if let activeUntil = schedule.activeUntil, dayStart >= calendar.startOfDay(for: activeUntil) {
            return false
        }

        return true
    }

    private func repeats(
        _ schedule: RoutineNotificationSchedule,
        on dayStart: Date,
        calendar: Calendar
    ) -> Bool {
        let weekdayNumber = calendar.component(.weekday, from: dayStart)
        guard let weekday = RepeatWeekday(rawValue: weekdayNumber) else {
            return false
        }

        return RepeatWeekdayMask.contains(weekday, in: schedule.repeatWeekdayMask)
    }

    private func fireDate(
        for dayStart: Date,
        startTime: Date,
        calendar: Calendar
    ) -> Date? {
        let timeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        return calendar.date(
            bySettingHour: timeComponents.hour ?? 0,
            minute: timeComponents.minute ?? 0,
            second: 0,
            of: dayStart
        )
    }
}

private struct RoutineNotificationOccurrence {
    let schedule: RoutineNotificationSchedule
    let dayStart: Date
    let fireDate: Date
}

private extension UNAuthorizationStatus {
    var allowsRoutineNotifications: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied:
            false
        @unknown default:
            false
        }
    }
}
