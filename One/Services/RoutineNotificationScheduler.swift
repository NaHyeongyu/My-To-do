import Foundation
import UserNotifications

struct RoutineNotificationSchedule: Sendable {
    let routineID: UUID
    let title: String
    let notes: String
    let taskDate: Date?
    let startTime: Date
    let endTime: Date?
    let repeatWeekdayMask: Int
    let activeFrom: Date?
    let activeUntil: Date?
    let sourceRoutineID: UUID?

    init?(item: ScheduleItem) {
        guard item.canScheduleRoutineNotifications(), let startTime = item.startTime else {
            return nil
        }

        self.routineID = item.id
        self.title = item.title
        self.notes = item.notes
        self.taskDate = item.taskDate
        self.startTime = startTime
        self.endTime = item.endTime
        self.repeatWeekdayMask = item.repeatWeekdayMask
        self.activeFrom = item.activeFrom
        self.activeUntil = item.activeUntil
        self.sourceRoutineID = item.sourceRoutineID
    }
}

struct RoutineNotificationOccurrenceState: Sendable {
    let routineID: UUID
    let dayStart: Date
    let isHidden: Bool

    init(state: RoutineOccurrenceState) {
        self.routineID = state.routineID
        self.dayStart = state.dayStart
        self.isHidden = state.isHidden
    }
}

actor RoutineNotificationScheduler {
    static let shared = RoutineNotificationScheduler()

    private let identifierPrefix = "one.routine.start."
    private let allRoutineIdentifierPrefix = "one.routine."
    private let horizonDays = 60
    private let maxScheduledNotifications = 60

    private var center: UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }

    func syncNotifications(
        enabled: Bool,
        for schedules: [RoutineNotificationSchedule],
        routineStates: [RoutineNotificationOccurrenceState] = [],
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

        let requestPayloads = notificationRequestPayloads(
            for: schedules,
            routineStates: routineStates,
            now: now,
            calendar: calendar
        )
        await withTaskGroup(of: Void.self) { group in
            for payload in requestPayloads {
                group.addTask {
                    await Self.add(payload)
                }
            }
        }
    }

    func cancelRoutineNotifications() async {
        let identifiers = await pendingRoutineNotificationIdentifiers()
        guard !identifiers.isEmpty else {
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func notificationRequestPayloads(
        for schedules: [RoutineNotificationSchedule],
        routineStates: [RoutineNotificationOccurrenceState],
        now: Date,
        calendar: Calendar
    ) -> [RoutineNotificationRequestPayload] {
        let overrideSourceIDsByDay = overrideSourceIDsByDay(for: schedules, calendar: calendar)
        let hiddenRoutineIDsByDay = hiddenRoutineIDsByDay(for: routineStates, calendar: calendar)

        return schedules
            .flatMap {
                notificationEvents(
                    for: $0,
                    now: now,
                    calendar: calendar,
                    overrideSourceIDsByDay: overrideSourceIDsByDay,
                    hiddenRoutineIDsByDay: hiddenRoutineIDsByDay
                )
            }
            .sorted { $0.fireDate < $1.fireDate }
            .prefix(maxScheduledNotifications)
            .map { requestPayload(for: $0, calendar: calendar) }
    }

    private func notificationEvents(
        for schedule: RoutineNotificationSchedule,
        now: Date,
        calendar: Calendar,
        overrideSourceIDsByDay: [Int: Set<UUID>],
        hiddenRoutineIDsByDay: [Int: Set<UUID>]
    ) -> [RoutineNotificationEvent] {
        if let taskDate = schedule.taskDate {
            let dayStart = calendar.startOfDay(for: taskDate)
            guard isSchedule(schedule, activeOn: dayStart, calendar: calendar) else {
                return []
            }

            return events(for: schedule, dayStart: dayStart, now: now, calendar: calendar)
        }

        let today = calendar.startOfDay(for: now)
        return (0..<horizonDays).flatMap { dayOffset -> [RoutineNotificationEvent] in
            guard let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: today) else {
                return []
            }

            guard
                isSchedule(schedule, activeOn: dayStart, calendar: calendar),
                repeats(schedule, on: dayStart, calendar: calendar),
                !isRepeatingScheduleSuppressed(
                    schedule,
                    on: dayStart,
                    calendar: calendar,
                    overrideSourceIDsByDay: overrideSourceIDsByDay,
                    hiddenRoutineIDsByDay: hiddenRoutineIDsByDay
                )
            else {
                return []
            }

            return events(for: schedule, dayStart: dayStart, now: now, calendar: calendar)
        }
    }

    private func overrideSourceIDsByDay(
        for schedules: [RoutineNotificationSchedule],
        calendar: Calendar
    ) -> [Int: Set<UUID>] {
        schedules.reduce(into: [:]) { result, schedule in
            guard let taskDate = schedule.taskDate, let sourceRoutineID = schedule.sourceRoutineID else {
                return
            }

            result[dayKey(for: taskDate, calendar: calendar), default: []].insert(sourceRoutineID)
        }
    }

    private func hiddenRoutineIDsByDay(
        for states: [RoutineNotificationOccurrenceState],
        calendar: Calendar
    ) -> [Int: Set<UUID>] {
        states.reduce(into: [:]) { result, state in
            guard state.isHidden else {
                return
            }

            result[dayKey(for: state.dayStart, calendar: calendar), default: []].insert(state.routineID)
        }
    }

    private func isRepeatingScheduleSuppressed(
        _ schedule: RoutineNotificationSchedule,
        on dayStart: Date,
        calendar: Calendar,
        overrideSourceIDsByDay: [Int: Set<UUID>],
        hiddenRoutineIDsByDay: [Int: Set<UUID>]
    ) -> Bool {
        guard schedule.taskDate == nil else {
            return false
        }

        let dayKey = dayKey(for: dayStart, calendar: calendar)
        return overrideSourceIDsByDay[dayKey]?.contains(schedule.routineID) == true
            || hiddenRoutineIDsByDay[dayKey]?.contains(schedule.routineID) == true
    }

    private func dayKey(for date: Date, calendar: Calendar) -> Int {
        Int(calendar.startOfDay(for: date).timeIntervalSince1970)
    }

    private func events(
        for schedule: RoutineNotificationSchedule,
        dayStart: Date,
        now: Date,
        calendar: Calendar
    ) -> [RoutineNotificationEvent] {
        RoutineNotificationEventKind.allCases.compactMap { kind in
            guard
                let fireDate = fireDate(for: kind, schedule: schedule, dayStart: dayStart, calendar: calendar),
                fireDate > now
            else {
                return nil
            }

            return RoutineNotificationEvent(
                kind: kind,
                schedule: schedule,
                dayStart: dayStart,
                fireDate: fireDate
            )
        }
    }

    private func requestPayload(
        for event: RoutineNotificationEvent,
        calendar: Calendar
    ) -> RoutineNotificationRequestPayload {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: event.fireDate
        )

        return RoutineNotificationRequestPayload(
            identifier: identifier(for: event),
            title: event.kind.notificationTitle,
            body: event.schedule.title,
            subtitle: event.schedule.notes.isEmpty ? nil : event.schedule.notes,
            routineID: event.schedule.routineID.uuidString,
            dayStartTimestamp: event.dayStart.timeIntervalSince1970,
            eventRawValue: event.kind.rawValue,
            year: components.year,
            month: components.month,
            day: components.day,
            hour: components.hour,
            minute: components.minute
        )
    }

    private static func request(for payload: RoutineNotificationRequestPayload) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.body
        content.sound = .default
        content.threadIdentifier = "routine"
        content.userInfo = [
            "routineID": payload.routineID,
            "dayStart": payload.dayStartTimestamp,
            "event": payload.eventRawValue
        ]

        if let subtitle = payload.subtitle {
            content.subtitle = subtitle
        }

        var components = DateComponents()
        components.year = payload.year
        components.month = payload.month
        components.day = payload.day
        components.hour = payload.hour
        components.minute = payload.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        return UNNotificationRequest(
            identifier: payload.identifier,
            content: content,
            trigger: trigger
        )
    }

    private func identifier(for event: RoutineNotificationEvent) -> String {
        [
            allRoutineIdentifierPrefix + event.kind.rawValue,
            event.schedule.routineID.uuidString,
            Int(event.dayStart.timeIntervalSince1970).description
        ].joined(separator: ".")
    }

    private func pendingRoutineNotificationIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { [identifierPrefix, allRoutineIdentifierPrefix] requests in
                continuation.resume(
                    returning: requests
                        .map(\.identifier)
                        .filter {
                            $0.hasPrefix(identifierPrefix) || $0.hasPrefix(allRoutineIdentifierPrefix)
                        }
                )
            }
        }
    }

    private static func add(_ payload: RoutineNotificationRequestPayload) async {
        let request = request(for: payload)
        try? await add(request, to: .current())
    }

    private static func add(_ request: UNNotificationRequest, to center: UNUserNotificationCenter) async throws {
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
        for kind: RoutineNotificationEventKind,
        schedule: RoutineNotificationSchedule,
        dayStart: Date,
        calendar: Calendar
    ) -> Date? {
        guard let startDate = fireDate(for: dayStart, time: schedule.startTime, calendar: calendar) else {
            return nil
        }

        switch kind {
        case .start:
            return startDate
        case .end:
            guard
                let endTime = schedule.endTime,
                let endDate = fireDate(for: dayStart, time: endTime, calendar: calendar)
            else {
                return nil
            }

            if endDate > startDate {
                return endDate
            }

            return calendar.date(byAdding: .day, value: 1, to: endDate)
        }
    }

    private func fireDate(
        for dayStart: Date,
        time: Date,
        calendar: Calendar
    ) -> Date? {
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(
            bySettingHour: timeComponents.hour ?? 0,
            minute: timeComponents.minute ?? 0,
            second: 0,
            of: dayStart
        )
    }
}

private enum RoutineNotificationEventKind: String, CaseIterable, Sendable {
    case start
    case end

    var notificationTitle: String {
        switch self {
        case .start: "Routine starts"
        case .end: "Routine ends"
        }
    }
}

private struct RoutineNotificationEvent: Sendable {
    let kind: RoutineNotificationEventKind
    let schedule: RoutineNotificationSchedule
    let dayStart: Date
    let fireDate: Date
}

private struct RoutineNotificationRequestPayload: Sendable {
    let identifier: String
    let title: String
    let body: String
    let subtitle: String?
    let routineID: String
    let dayStartTimestamp: TimeInterval
    let eventRawValue: String
    let year: Int?
    let month: Int?
    let day: Int?
    let hour: Int?
    let minute: Int?
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
