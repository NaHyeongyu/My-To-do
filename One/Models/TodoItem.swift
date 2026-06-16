import Foundation
import SwiftData

@Model
final class ScheduleItem: Identifiable {
    var id: UUID = UUID()
    var kindRawValue: String = ScheduleKind.task.rawValue
    var title: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    var taskDate: Date?
    var completedAt: Date?
    var startTime: Date?
    var endTime: Date?
    var repeatWeekdayMask: Int = RepeatWeekdayMask.everyDay
    var activeFrom: Date?
    var activeUntil: Date?
    var routineLabelRawValue: String?

    init(
        id: UUID = UUID(),
        kind: ScheduleKind,
        title: String,
        notes: String = "",
        createdAt: Date = .now,
        taskDate: Date? = nil,
        completedAt: Date? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        repeatWeekdayMask: Int = RepeatWeekdayMask.everyDay,
        activeFrom: Date? = nil,
        activeUntil: Date? = nil,
        routineLabel: RoutineLabel? = nil
    ) {
        self.id = id
        self.kindRawValue = kind.rawValue
        self.title = title
        self.notes = notes
        self.createdAt = createdAt
        self.taskDate = taskDate
        self.completedAt = completedAt
        self.startTime = startTime
        self.endTime = endTime
        self.repeatWeekdayMask = repeatWeekdayMask
        self.activeFrom = activeFrom
        self.activeUntil = activeUntil
        self.routineLabelRawValue = kind == .routine ? routineLabel?.rawValue : nil
    }
}

enum RoutineLabel: String, CaseIterable, Identifiable, Hashable {
    case study
    case coding
    case work
    case life
    case play
    case hobby
    case rest
    case sleep
    case health
    case money
    case admin
    case social

    var id: String { rawValue }

    var title: String {
        switch self {
        case .study: "Study"
        case .coding: "Coding"
        case .work: "Work"
        case .life: "Life"
        case .play: "Play"
        case .hobby: "Hobby"
        case .rest: "Rest"
        case .sleep: "Sleep"
        case .health: "Health"
        case .money: "Money"
        case .admin: "Admin"
        case .social: "Social"
        }
    }

    var symbolName: String {
        switch self {
        case .study: "book.closed.fill"
        case .coding: "chevron.left.forwardslash.chevron.right"
        case .work: "briefcase.fill"
        case .life: "heart.fill"
        case .play: "gamecontroller.fill"
        case .hobby: "paintpalette.fill"
        case .rest: "pause.circle.fill"
        case .sleep: "bed.double.fill"
        case .health: "figure.run"
        case .money: "banknote.fill"
        case .admin: "tray.full.fill"
        case .social: "person.2.fill"
        }
    }
}

extension ScheduleItem {
    static let minutesPerDay = 24 * 60

    var kind: ScheduleKind {
        get { ScheduleKind(rawValue: kindRawValue) ?? .task }
        set { kindRawValue = newValue.rawValue }
    }

    var routineLabel: RoutineLabel? {
        get {
            guard let routineLabelRawValue else {
                return nil
            }

            return RoutineLabel(rawValue: routineLabelRawValue)
        }
        set { routineLabelRawValue = newValue?.rawValue }
    }

    var isCompleted: Bool {
        completedAt != nil
    }

    var repeatSummary: String {
        RepeatWeekdayMask.summary(for: repeatWeekdayMask)
    }

    func repeats(on date: Date, calendar: Calendar = .current) -> Bool {
        guard kind == .routine, isRoutineActive(on: date, calendar: calendar) else { return false }
        let weekdayNumber = calendar.component(.weekday, from: date)
        guard let weekday = RepeatWeekday(rawValue: weekdayNumber) else { return false }
        return RepeatWeekdayMask.contains(weekday, in: repeatWeekdayMask)
    }

    func isRoutineActive(on date: Date, calendar: Calendar = .current) -> Bool {
        guard kind == .routine else { return false }

        let dayStart = calendar.startOfDay(for: date)

        if let activeFrom, dayStart < calendar.startOfDay(for: activeFrom) {
            return false
        }

        if let activeUntil, dayStart >= calendar.startOfDay(for: activeUntil) {
            return false
        }

        return true
    }

    func canScheduleRoutineNotifications(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard kind == .routine else { return false }

        if let activeUntil, calendar.startOfDay(for: activeUntil) <= calendar.startOfDay(for: now) {
            return false
        }

        return true
    }

    func isTodayTask(on date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard kind == .task else { return false }
        return calendar.isDate(taskDate ?? createdAt, inSameDayAs: date)
    }

    func toggleCompleted(now: Date = .now) {
        guard kind == .task else { return }
        completedAt = isCompleted ? nil : now
    }

    func durationMinutes(calendar: Calendar = .current) -> Int {
        guard let startTime, let endTime else { return 0 }
        return Self.durationMinutes(startTime: startTime, endTime: endTime, calendar: calendar)
    }

    func crossesMidnight(calendar: Calendar = .current) -> Bool {
        guard let startTime, let endTime else { return false }
        return Self.crossesMidnight(startTime: startTime, endTime: endTime, calendar: calendar)
    }

    func normalizedEndMinute(calendar: Calendar = .current) -> Int? {
        guard let startTime, let endTime else { return nil }
        let startMinute = calendar.minuteOfDay(for: startTime)
        let endMinute = calendar.minuteOfDay(for: endTime)
        return endMinute > startMinute ? endMinute : endMinute + Self.minutesPerDay
    }

    func timeRangeText(calendar: Calendar = .current) -> String {
        guard let startTime, let endTime else { return "No time set" }

        let startText = startTime.formatted(.dateTime.hour().minute())
        let endText = endTime.formatted(.dateTime.hour().minute())
        let suffix = crossesMidnight(calendar: calendar) ? " +1d" : ""
        return "\(startText) - \(endText)\(suffix)"
    }

    static func durationMinutes(startTime: Date, endTime: Date, calendar: Calendar = .current) -> Int {
        let startMinute = calendar.minuteOfDay(for: startTime)
        let endMinute = calendar.minuteOfDay(for: endTime)
        let normalizedEndMinute = endMinute > startMinute ? endMinute : endMinute + minutesPerDay
        return max(0, normalizedEndMinute - startMinute)
    }

    static func crossesMidnight(startTime: Date, endTime: Date, calendar: Calendar = .current) -> Bool {
        calendar.minuteOfDay(for: endTime) <= calendar.minuteOfDay(for: startTime)
    }

    func durationText(calendar: Calendar = .current) -> String {
        let minutes = durationMinutes(calendar: calendar)
        guard minutes > 0 else { return "No time set" }

        return minutes.readableDuration
    }
}

extension Int {
    var readableDuration: String {
        guard self > 0 else { return "0m" }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0, remainingMinutes > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }

        if hours > 0 {
            return "\(hours)h"
        }

        return "\(remainingMinutes)m"
    }

    private var minutes: Int { self }
}
