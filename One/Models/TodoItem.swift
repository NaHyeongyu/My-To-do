import Foundation
import SwiftData

@Model
final class ScheduleItem: Identifiable {
    var id: UUID
    var kindRawValue: String
    var title: String
    var notes: String
    var createdAt: Date
    var taskDate: Date?
    var completedAt: Date?
    var startTime: Date?
    var endTime: Date?
    var repeatWeekdayMask: Int
    var activeFrom: Date?
    var activeUntil: Date?

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
        activeUntil: Date? = nil
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
    }
}

extension ScheduleItem {
    var kind: ScheduleKind {
        get { ScheduleKind(rawValue: kindRawValue) ?? .task }
        set { kindRawValue = newValue.rawValue }
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
        return max(0, calendar.minuteOfDay(for: endTime) - calendar.minuteOfDay(for: startTime))
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
