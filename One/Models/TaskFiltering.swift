import Foundation

extension Calendar {
    func minuteOfDay(for date: Date) -> Int {
        let components = dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    func dateBySnappingToFiveMinute(_ date: Date) -> Date {
        let components = dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let snappedMinute = Int((Double(components.minute ?? 0) / 5.0).rounded()) * 5
        var hourComponents = components
        hourComponents.minute = 0
        hourComponents.second = 0
        hourComponents.nanosecond = 0

        guard
            let hourStart = self.date(from: hourComponents),
            let snappedDate = self.date(byAdding: .minute, value: snappedMinute, to: hourStart)
        else {
            return date
        }

        return snappedDate
    }
}

extension Array where Element == ScheduleItem {
    func openTasks() -> [ScheduleItem] {
        filter { $0.kind == .task && !$0.isCompleted }
            .sorted { lhs, rhs in
                (lhs.taskDate ?? lhs.createdAt) < (rhs.taskDate ?? rhs.createdAt)
            }
    }

    func completedTasks() -> [ScheduleItem] {
        filter { $0.kind == .task && $0.isCompleted }
            .sorted { lhs, rhs in
                (lhs.completedAt ?? .distantPast) > (rhs.completedAt ?? .distantPast)
            }
    }

    func oneOffTasksForToday(_ date: Date = .now, calendar: Calendar = .current) -> [ScheduleItem] {
        filter { $0.isTodayTask(on: date, calendar: calendar) }
            .sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted {
                    return !lhs.isCompleted
                }

                let lhsDate = lhs.taskDate ?? lhs.createdAt
                let rhsDate = rhs.taskDate ?? rhs.createdAt

                if lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }

                return lhs.createdAt > rhs.createdAt
            }
    }

    func routines(repeating weekday: RepeatWeekday, calendar: Calendar = .current) -> [ScheduleItem] {
        filter {
            $0.kind == .routine
                && $0.taskDate == nil
                && RepeatWeekdayMask.contains(weekday, in: $0.repeatWeekdayMask)
        }
            .sorted { lhs, rhs in
                calendar.minuteOfDay(for: lhs.startTime ?? .distantFuture)
                    < calendar.minuteOfDay(for: rhs.startTime ?? .distantFuture)
            }
    }

    func routines(on date: Date, calendar: Calendar = .current) -> [ScheduleItem] {
        filter { item in
            guard item.kind == .routine else { return false }

            if let taskDate = item.taskDate {
                return calendar.isDate(taskDate, inSameDayAs: date)
            }

            return item.repeats(on: date, calendar: calendar)
        }
            .sorted { lhs, rhs in
                calendar.minuteOfDay(for: lhs.startTime ?? .distantFuture)
                    < calendar.minuteOfDay(for: rhs.startTime ?? .distantFuture)
            }
    }
}
